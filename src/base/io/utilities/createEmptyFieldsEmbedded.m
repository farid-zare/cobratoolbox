function model = createEmptyFieldsEmbedded(model, fieldNames)
%CREATEEMPTYFIELDS_EMBEDDED  Create model fields from an embedded table.
% No file I/O. Safe for compiled runtime.
%
% Usage:
%   model = createEmptyFieldsEmbedded(model, fieldNames)
%
% Inputs
%   model       COBRA model struct, may be partial
%   fieldNames  char or cellstr of fields to ensure exist
%
% Behaviour
%   - Sizes are derived from existing model content:
%       m = size(S,1)    or numel(mets)
%       n = size(S,2)    or numel(rxns) or numel(lb) or numel(ub) or numel(c)
%       g = numel(genes)
%       c = numel(comps)
%       ctrs = size(C,1) or numel(d) or numel(dsense) or numel(ctrs)
%       evars = size(E,2) or numel(evarlb) or numel(evarub) or numel(evarc) or numel(evars)
%   - Types supported: 'sparse', 'numeric', 'char', 'cell'
%   - Defaults chosen to be harmless and solver friendly.
%
% .. Author: - Farid Zare 1/09/2025


if ischar(fieldNames), fieldNames = {fieldNames}; end

% -------- derive canonical sizes from whatever is present --------
[m, n]     = deriveMN(model);
g          = deriveLen(model, 'genes');
c          = deriveLen(model, 'comps');
ctrs       = deriveCtrs(model);
evars      = deriveEVars(model);

% -------- embedded definitions for known fields --------
% Columns: {name, xdim, ydim, type, default}
% xdim/ydim may be numeric or one of {'m','n','g','c','ctrs','evars'}.
defs = {
    % Core pieces used by buildOptProblemFromModel
    'b',           'm',     1,   'numeric',  0;
    'csense',      'm',     1,   'char',     'E';
    'osenseStr',     1,     1,   'char',     'max';

    % Coupling rows
    'C',         'ctrs',   'n',  'sparse',   0;
    'd',         'ctrs',    1,   'numeric',  0;
    'dsense',    'ctrs',    1,   'char',     'L';
    'ctrs',      'ctrs',    1,   'cell',     '';

    % Extra variables
    'E',            'n', 'evars', 'sparse',  0;
    'D',         'ctrs','evars',  'sparse',  0;
    'evarlb',    'evars',  1,     'numeric', 0;
    'evarub',    'evars',  1,     'numeric', 0;
    'evarc',     'evars',  1,     'numeric', 0;
    'evars',     'evars',  1,     'cell',    '';
    'evarNames', 'evars',  1,     'cell',    '';

    % Helpful common fields
    'S',            'm',    'n',  'sparse',  0;
    'c',            'n',     1,   'numeric', 0;
    'lb',           'n',     1,   'numeric', 0;
    'ub',           'n',     1,   'numeric', 0;
    'mets',         'm',     1,   'cell',    '';
    'rxns',         'n',     1,   'cell',    '';
    'grRules',      'n',     1,   'cell',    '';
    'rxnNames',     'n',     1,   'cell',    '';
    'genes',        'g',     1,   'cell',    '';
    'geneNames',    'g',     1,   'cell',    '';
    'compNames',    'c',     1,   'cell',    '';
    'comps',        'c',     1,   'cell',    '';

    % Numeric exception often needed
    'metCharges',   'm',     1,   'numeric', NaN;
    };

% map from field name to row index
nameToIdx = containers.Map(defs(:,1), num2cell(1:size(defs,1)));

% -------- create requested fields --------
for k = 1:numel(fieldNames)
    fname = fieldNames{k};

    if isfield(model, fname)
        continue
    end

    if nameToIdx.isKey(fname)
        row = defs(nameToIdx(fname), :);         % keep as 1×5 cell row
        x = resolveDim(row{2}, m, n, g, c, ctrs, evars);
        y = resolveDim(row{3}, m, n, g, c, ctrs, evars);
        ftype = row{4};
        deflt = row{5};
        model.(fname) = makeField(ftype, x, y, deflt);
        continue
    end

    % Generic rules for annotation-like fields
    if startsWith(fname, 'met')
        model.(fname) = makeField('cell', m, 1, '');
    elseif startsWith(fname, 'rxn')
        model.(fname) = makeField('cell', n, 1, '');
    elseif startsWith(fname, 'gene')
        model.(fname) = makeField('cell', g, 1, '');
    elseif startsWith(fname, 'comp')
        model.(fname) = makeField('cell', c, 1, '');
    elseif startsWith(fname, 'protein')
        model.(fname) = makeField('cell', g, 1, '');
    else
        % Fallback that will not break linear algebra
        model.(fname) = sparse(0,0);
    end
end

% -------------- nested helpers --------------

    function A = makeField(ftype, xdim, ydim, deflt)
        xdim = max(0, xdim);
        ydim = max(0, ydim);
        switch ftype
            case 'sparse'
                A = sparse(xdim, ydim);
            case 'numeric'
                if xdim == 0 || ydim == 0
                    A = zeros(xdim, ydim);
                else
                    if isnumeric(deflt) && isnan(deflt)
                        A = nan(xdim, ydim);
                    else
                        A = repmat(deflt, xdim, ydim);
                    end
                end
            case 'char'
                if xdim == 1 && ydim == 1
                    % whole string like 'max' or 'min'
                    A = deflt;
                else
                    if ~(ischar(deflt) && numel(deflt) == 1)
                        error('Default for char field must be a single character when size is not 1×1.');
                    end
                    A = repmat(deflt, xdim, ydim);
                end
            case 'cell'
                A = cell(xdim, ydim);
                if xdim > 0 && ydim > 0
                    A(:) = {deflt};
                end
            otherwise
                error('Unknown field type "%s".', ftype);
        end
    end

    function d = resolveDim(token, m_, n_, g_, c_, ctrs_, evars_)
        if isnumeric(token)
            d = token;  return
        end
        if isstring(token), token = char(token); end
        switch token
            case 'm',     d = m_;
            case 'n',     d = n_;
            case 'g',     d = g_;
            case 'c',     d = c_;
            case 'ctrs',  d = ctrs_;
            case 'evars', d = evars_;
            otherwise,    error('Unknown dim token "%s".', token);
        end
    end

    function [m_, n_] = deriveMN(M)
        if isfield(M, 'S') && ~isempty(M.S)
            [m_, n_] = size(M.S);
        else
            m_ = deriveLen(M, 'mets');
            n_ = firstNonzero([deriveLen(M,'rxns'), deriveLen(M,'lb'), deriveLen(M,'ub'), deriveLen(M,'c')]);
        end
    end

    function L = deriveLen(M, fname)
        if isfield(M, fname) && ~isempty(M.(fname))
            v = M.(fname);
            if ischar(v) || isstring(v)
                L = 1;
            else
                L = size(v,1);
            end
        else
            L = 0;
        end
    end

    function q = firstNonzero(vec)
        q = 0;
        for ii = 1:numel(vec)
            if vec(ii) > 0, q = vec(ii); return; end
        end
    end

    function r = deriveCtrs(M)
        if isfield(M,'C') && ~isempty(M.C)
            r = size(M.C,1);
        elseif isfield(M,'d') && ~isempty(M.d)
            r = size(M.d,1);
        elseif isfield(M,'dsense') && ~isempty(M.dsense)
            r = size(M.dsense,1);
        elseif isfield(M,'ctrs') && ~isempty(M.ctrs)
            r = size(M.ctrs,1);
        else
            r = 0;
        end
    end

    function p = deriveEVars(M)
        if isfield(M,'E') && ~isempty(M.E)
            p = size(M.E,2);
        elseif isfield(M,'evarlb') && ~isempty(M.evarlb)
            p = size(M.evarlb,1);
        elseif isfield(M,'evarub') && ~isempty(M.evarub)
            p = size(M.evarub,1);
        elseif isfield(M,'evarc') && ~isempty(M.evarc)
            p = size(M.evarc,1);
        elseif isfield(M,'evars') && ~isempty(M.evars)
            p = size(M.evars,1);
        else
            p = 0;
        end
    end
end
