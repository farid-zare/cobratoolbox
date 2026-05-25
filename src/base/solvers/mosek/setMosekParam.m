function [cmd, mosekParam] = setMosekParam(param)
% setMosekParam
%
% Single source of truth for MOSEK parameter materialisation.
%
% The input param may contain solveSCLP/COBRA portfolio controls, for example:
%
%     param.mosekParam = 'default'
%     param.mosekParam = 'cobra'
%     param.mosekParam = 'manual'
%     param.mosekParam = 'cobraNoPresolve'
%     param.mosekParam = 'cobraVerbose'
%
% Policy:
%   'default'
%       Do not pass any internal MSK_* parameters to MOSEK.  MOSEK defaults
%       are obtained precisely by not setting the parameters.
%
%   'manual'
%       Pass through caller-supplied MSK_* fields, but do not add derived
%       COBRA defaults.
%
%   'cobra'
%       Materialise the historical COBRA/MOSEK parameter portfolio.
%
%   'cobraNoPresolve'
%       Same as cobra, but with MSK_IPAR_PRESOLVE_USE set to OFF.
%
%   'cobraVerbose'
%       Same as cobra, but with increased MOSEK logging.
%
%   'cobraNoPresolveVerbose'
%       Same as cobra, with presolve off and increased logging.
%
% All actual MSK_* assignments should occur in this function only.
%
% MOSEK print behaviour
% 
% With any profile:
% 
% param.printLevel = 0;
% 
% you get:
% 
% cmd = 'minimize echo(0)';
% mosekParam.MSK_IPAR_LOG = 0;
% mosekParam.MSK_IPAR_LOG_INTPNT = 0;
% mosekParam.MSK_IPAR_LOG_SIM = 0;
% mosekParam.MSK_IPAR_LOG_PRESOLVE = 0;
% 
% With:
% 
% param.printLevel = 1;
% 
% you get:
% 
% cmd = 'minimize';
% 
% and explicit MSK_IPAR_LOG* fields are removed, so MOSEK uses its default logging.
% 
% With:
% 
% param.printLevel = 2;
% param.mosekParam = 'SCLP_noPresolveVerbose';
% 
% you get:
% 
% cmd = 'minimize';
% mosekParam.MSK_IPAR_LOG = 10;
% mosekParam.MSK_IPAR_LOG_INTPNT = 10;
% mosekParam.MSK_IPAR_LOG_SIM = 10;
% mosekParam.MSK_IPAR_LOG_PRESOLVE = 10;
% 
% That implements the rule that printLevel controls whether MOSEK prints, while the profile controls what extra detail is available once printLevel > 1.

if nargin < 1 || isempty(param)
    param = struct();
end

if ~isfield(param,'printLevel') || isempty(param.printLevel)
    param.printLevel = 0;
else
    param.printLevel = param.printLevel - 1;
end

if ~isfield(param,'debug') || isempty(param.debug)
    param.debug = 0;
end

if ~isfield(param,'problemType') || isempty(param.problemType)
    % solveSCLP solves conic linear subproblems.
    param.problemType = 'CLP';
end

profile = normaliseMosekParamProfile(param);

% Centralised MOSEK print policy.
%
% printLevel = 0
%     Force complete MOSEK silence at the MATLAB-interface command level.
%
% printLevel > 0
%     Do not force an echo level.  This allows MOSEK to use its ordinary
%     default command-window behaviour.
%
% printLevel > 1
%     In addition, allow profile-specific MSK_IPAR_LOG* settings to pass
%     through to MOSEK.  These are applied later by applyMosekPrintPolicy.
cmd = buildMosekCommandFromPrintLevel(param);

switch profile
    case 'default'
        % True MOSEK default mode.  Remove all MSK_* fields, including any
        % accidentally created upstream.  Passing no MOSEK parameters is the
        % mechanism by which MOSEK uses its own defaults.
        paramForMosek = removeMosekParameterFields(param);

    case 'manual'
        % Pass only user-provided MSK_* fields through mosekParamStrip.
        % Do not add derived COBRA settings.
        paramForMosek = param;

    case {'cobra','cobraNoPresolve','cobraVerbose','cobraNoPresolveVerbose'}
        paramForMosek = applyCobraMosekPortfolio(param, profile);

    case {'SCLP_default', ...
          'SCLP_normalPresolve', ...
          'SCLP_noPresolve', ...
          'SCLP_verbose', ...
          'SCLP_noPresolveVerbose'}

        % Materialise the solveSCLP-specific MOSEK profile.
        %
        % This is the only place where solveSCLP-owned MOSEK profiles are
        % converted into actual MSK_* fields.  solveSCLP itself should only
        % set param.mosekParam to one of the SCLP_* names and then call
        % setMosekParam.

        if strcmp(profile, 'SCLP_default')
            % True MOSEK-default solve for solveSCLP.
            %
            % Do not set any MSK_* fields.  Leaving the fields absent is the
            % mechanism by which MOSEK uses its own defaults.
            paramForMosek = removeMosekParameterFields(param);

        else
            paramForMosek = applySCLPMosekPortfolio(param, profile);
        end

    otherwise
        error('setMosekParam:badProfile', ...
            'Unsupported param.mosekParam profile: %s', profile);
end

% Apply the print policy after the selected profile has materialised its
% ordinary MOSEK parameters.  This is deliberately last, so printLevel = 0
% can override even a verbose profile such as SCLP_noPresolveVerbose.
paramForMosek = applyMosekPrintPolicy(paramForMosek, param.printLevel);

% Remove outer-function fields to avoid passing non-MOSEK names to MOSEK.
mosekParam = mosekParamStrip(paramForMosek);

end


function profile = normaliseMosekParamProfile(param)
% normaliseMosekParamProfile
%
% Return a canonical lower-level profile name while preserving readable
% names in caller-facing parameter files.

if ~isfield(param,'mosekParam') || isempty(param.mosekParam)
    profile = 'cobra';
else
    profile = char(string(param.mosekParam));
end

allowed = { ...
    'default', ...
    'manual', ...
    'cobra', ...
    'cobraNoPresolve', ...
    'cobraVerbose', ...
    'cobraNoPresolveVerbose', ...
    'SCLP_default', ...
    'SCLP_normalPresolve', ...
    'SCLP_noPresolve', ...
    'SCLP_verbose', ...
    'SCLP_noPresolveVerbose'};

if ~any(strcmp(profile, allowed))
    error('setMosekParam:badMosekParam', ...
        'param.mosekParam = %s is not valid. Allowed values are: %s.', ...
        profile, strjoin(allowed, ', '));
end
end

function cmd = buildMosekCommandFromPrintLevel(param)
% buildMosekCommandFromPrintLevel
%
% Build the MOSEK command string using only param.printLevel.
%
% This command-level policy is intentionally independent of the selected
% parameter profile.  In particular, verbose profiles must not override
% printLevel = 0.

if param.printLevel <= 0
    % echo(0) suppresses MATLAB-interface echoing from mosekopt.
    cmd = 'minimize echo(0)';
else
    % No explicit echo(...) token.  Let MOSEK use its ordinary default
    % command-window behaviour.  Extra solver logs, if any, are controlled
    % by MSK_IPAR_LOG* fields and are allowed only for printLevel > 1.
    cmd = 'minimize';
end
end


function param = applyMosekPrintPolicy(param, printLevel)
% applyMosekPrintPolicy
%
% Enforce a single print policy after the selected MOSEK profile has been
% materialised.
%
% Policy:
%
%   printLevel = 0
%       Force silence.  This overrides every profile, including verbose
%       profiles and manually supplied log fields.
%
%   printLevel = 1
%       Use MOSEK's default printing.  Remove explicit log-verbosity fields
%       so profiles do not increase output.
%
%   printLevel > 1
%       Keep profile-specific log fields.  This is where verbose profiles
%       such as SCLP_verbose or SCLP_noPresolveVerbose take effect.

if printLevel <= 0
    % Force MOSEK logging off.  Set the global log to zero and also set the
    % common sublogs to zero in case a MOSEK interface honours them
    % independently.
    param.MSK_IPAR_LOG = 0;
    param.MSK_IPAR_LOG_INTPNT = 0;
    param.MSK_IPAR_LOG_SIM = 0;
    param.MSK_IPAR_LOG_PRESOLVE = 0;
    param.MSK_IPAR_LOG_FEAS_REPAIR = 0;

    % Do not print infeasibility reports in silent mode.
    param.MSK_IPAR_INFEAS_REPORT_AUTO = 'MSK_OFF';

    % Defensive cleanup for fields that request extra output or data writing.
    param = removeMosekPrintFieldsExceptSilenceFields(param);

elseif printLevel == 1
    % Default MOSEK printing.  Remove explicit logging fields so the profile
    % does not increase or decrease MOSEK's own default output.
    param = removeMosekPrintFields(param);

else
    % printLevel > 1:
    % Keep whatever log fields the selected profile materialised.
    % No action required.
end
end


function paramOut = removeMosekPrintFields(paramIn)
% removeMosekPrintFields
%
% Remove MOSEK fields whose purpose is logging, reports, or output.  This is
% used for printLevel = 1, where the requested behaviour is MOSEK default
% printing rather than explicit setMosekParam logging.

paramOut = paramIn;

fieldsToRemove = { ...
    'MSK_IPAR_LOG', ...
    'MSK_IPAR_LOG_INTPNT', ...
    'MSK_IPAR_LOG_SIM', ...
    'MSK_IPAR_LOG_PRESOLVE', ...
    'MSK_IPAR_LOG_FEAS_REPAIR', ...
    'MSK_IPAR_INFEAS_REPORT_AUTO', ...
    'MSK_IPAR_INFEAS_REPORT_LEVEL', ...
    'MSK_IPAR_WRITE_DATA_PARAM'};

for i = 1:numel(fieldsToRemove)
    if isfield(paramOut, fieldsToRemove{i})
        paramOut = rmfield(paramOut, fieldsToRemove{i});
    end
end
end


function paramOut = removeMosekPrintFieldsExceptSilenceFields(paramIn)
% removeMosekPrintFieldsExceptSilenceFields
%
% Remove optional extra-output fields while preserving the explicit
% silence-enforcing log fields set by applyMosekPrintPolicy.

paramOut = paramIn;

fieldsToRemove = { ...
    'MSK_IPAR_INFEAS_REPORT_LEVEL', ...
    'MSK_IPAR_WRITE_DATA_PARAM'};

for i = 1:numel(fieldsToRemove)
    if isfield(paramOut, fieldsToRemove{i})
        paramOut = rmfield(paramOut, fieldsToRemove{i});
    end
end
end



function param = applyCobraMosekPortfolio(param, profile)
% applyCobraMosekPortfolio
%
% Materialise the historical COBRA/MOSEK parameter choices.
%
% This is the only place, apart from explicit user-supplied manual fields,
% where MSK_* fields are created.

% -------------------------------------------------------------------------
% Logging requested by this profile.
% -------------------------------------------------------------------------
%
% These fields describe what the COBRA profile would like to print in
% verbose mode.  The final decision is made by applyMosekPrintPolicy:
%
%   printLevel = 0  removes/overrides these fields and prints nothing;
%   printLevel = 1  removes these fields and uses MOSEK defaults;
%   printLevel > 1  allows these fields to pass through.
if any(strcmp(profile, {'cobraVerbose','cobraNoPresolveVerbose'}))
    param.MSK_IPAR_LOG = 10;
    param.MSK_IPAR_LOG_INTPNT = 10;
    param.MSK_IPAR_LOG_SIM = 10;
    param.MSK_IPAR_LOG_PRESOLVE = 10;
    param.MSK_IPAR_INFEAS_REPORT_AUTO = 'MSK_ON';
    param.MSK_IPAR_INFEAS_REPORT_LEVEL = 1;
end

% -------------------------------------------------------------------------
% Time limit.
% -------------------------------------------------------------------------
if ~isfield(param, 'MSK_DPAR_OPTIMIZER_MAX_TIME') && ...
        isfield(param,'timelimit') && ~isempty(param.timelimit)
    param.MSK_DPAR_OPTIMIZER_MAX_TIME = param.timelimit;
end

% -------------------------------------------------------------------------
% Generic LP/QP/conic tolerances.
% Prefer solveSCLP-derived controls if present.  Otherwise fall back to
% historical feasTol/optTol behaviour.
% -------------------------------------------------------------------------
if isfield(param,'mosekInnerTol') && ~isempty(param.mosekInnerTol)
    primalTol = param.mosekInnerTol;
else
    primalTol = getScalarFieldOrDefault(param, 'feasTol', 1e-8);
end

if isfield(param,'mosekInnerTol') && ~isempty(param.mosekInnerTol)
    dualTol = param.mosekInnerTol;
else
    dualTol = getScalarFieldOrDefault(param, 'optTol', primalTol);
end

if isfield(param,'mosekInnerMuTol') && ~isempty(param.mosekInnerMuTol)
    muTol = param.mosekInnerMuTol;
else
    muTol = primalTol * 1e-2;
end

if ~isfield(param, 'MSK_DPAR_INTPNT_TOL_PFEAS')
    param.MSK_DPAR_INTPNT_TOL_PFEAS = primalTol;
end

if ~isfield(param, 'MSK_DPAR_INTPNT_QO_TOL_PFEAS')
    param.MSK_DPAR_INTPNT_QO_TOL_PFEAS = primalTol;
end

if ~isfield(param, 'MSK_DPAR_INTPNT_CO_TOL_PFEAS')
    param.MSK_DPAR_INTPNT_CO_TOL_PFEAS = primalTol;
end

if ~isfield(param, 'MSK_DPAR_INTPNT_TOL_DFEAS')
    param.MSK_DPAR_INTPNT_TOL_DFEAS = dualTol;
end

if ~isfield(param, 'MSK_DPAR_INTPNT_QO_TOL_DFEAS')
    param.MSK_DPAR_INTPNT_QO_TOL_DFEAS = dualTol;
end

if ~isfield(param, 'MSK_DPAR_INTPNT_CO_TOL_DFEAS')
    param.MSK_DPAR_INTPNT_CO_TOL_DFEAS = dualTol;
end

if ~isfield(param, 'MSK_DPAR_INTPNT_CO_TOL_REL_GAP')
    param.MSK_DPAR_INTPNT_CO_TOL_REL_GAP = primalTol;
end

if ~isfield(param, 'MSK_DPAR_INTPNT_CO_TOL_MU_RED')
    param.MSK_DPAR_INTPNT_CO_TOL_MU_RED = muTol;
end

% -------------------------------------------------------------------------
% solveSCLP-specific conic solve form and presolve/data tolerances.
% These are created only in the COBRA portfolio.
% -------------------------------------------------------------------------
if ~isfield(param, 'MSK_IPAR_INTPNT_SOLVE_FORM')
    param.MSK_IPAR_INTPNT_SOLVE_FORM = ...
        getTextFieldOrDefault(param, 'mosekSolveForm', 'MSK_SOLVE_PRIMAL');
end

if any(strcmp(profile, {'cobraNoPresolve','cobraNoPresolveVerbose'}))
    param.MSK_IPAR_PRESOLVE_USE = 'MSK_PRESOLVE_MODE_OFF';
elseif ~isfield(param, 'MSK_IPAR_PRESOLVE_USE')
    param.MSK_IPAR_PRESOLVE_USE = ...
        getTextFieldOrDefault(param, 'mosekPresolveUse', 'MSK_PRESOLVE_MODE_FREE');
end

if ~isfield(param, 'MSK_DPAR_PRESOLVE_TOL_PRIMAL_INFEAS_PERTURBATION')
    param.MSK_DPAR_PRESOLVE_TOL_PRIMAL_INFEAS_PERTURBATION = ...
        getScalarFieldOrDefault(param, 'mosekPrimalInfeasPerturbationTol', 0);
end

if ~isfield(param, 'MSK_DPAR_PRESOLVE_TOL_X')
    param.MSK_DPAR_PRESOLVE_TOL_X = ...
        getScalarFieldOrDefault(param, 'mosekPresolveTolX', ...
        100 * getScalarFieldOrDefault(param, 'numTol', 1e-12));
end

if ~isfield(param, 'MSK_DPAR_PRESOLVE_TOL_S')
    param.MSK_DPAR_PRESOLVE_TOL_S = ...
        getScalarFieldOrDefault(param, 'mosekPresolveTolS', ...
        100 * getScalarFieldOrDefault(param, 'numTol', 1e-12));
end

if ~isfield(param, 'MSK_DPAR_DATA_TOL_X')
    param.MSK_DPAR_DATA_TOL_X = ...
        getScalarFieldOrDefault(param, 'mosekDataTolX', ...
        getScalarFieldOrDefault(param, 'numTol', 1e-12));
end

if ~isfield(param, 'MSK_DPAR_INTPNT_CO_TOL_NEAR_REL')
    param.MSK_DPAR_INTPNT_CO_TOL_NEAR_REL = ...
        getScalarFieldOrDefault(param, 'mosekNearRel', 1.0);
end

% -------------------------------------------------------------------------
% Historical special cases retained inside the COBRA portfolio.
% -------------------------------------------------------------------------
if isfield(param,'lifted') && param.lifted == 1
    if ~isfield(param,'MSK_IPAR_PRESOLVE_ELIMINATOR_MAX_NUM_TRIES')
        param.MSK_IPAR_PRESOLVE_ELIMINATOR_MAX_NUM_TRIES = 0;
    end
end

if isfield(param,'multiscale') && param.multiscale == 1 && ...
        (~isfield(param,'lifted') || param.lifted == 0)

    if ~isfield(param,'MSK_IPAR_PRESOLVE_LINDEP_NEW')
        param.MSK_IPAR_PRESOLVE_LINDEP_NEW = 'MSK_OFF';
    end

    if ~isfield(param,'MSK_IPAR_INTPNT_SCALING')
        param.MSK_IPAR_INTPNT_SCALING = 'MSK_SCALING_NONE';
    end

    if ~isfield(param,'MSK_IPAR_SIM_SCALING')
        param.MSK_IPAR_SIM_SCALING = 'MSK_SCALING_NONE';
    end
end

% Debug may request an infeasibility report, but the final print policy
% still has priority.  Thus printLevel = 0 will turn this off, and
% printLevel = 1 will remove it to keep MOSEK default printing.
if isfield(param,'debug') && param.debug == 1
    param.MSK_IPAR_INFEAS_REPORT_AUTO = 'MSK_ON';
end

if isfield(param,'strict')
    if ~isfield(param,'MSK_IPAR_BI_IGNORE_MAX_ITER')
        param.MSK_IPAR_BI_IGNORE_MAX_ITER = 'MSK_OFF';
    end

    if ~isfield(param,'MSK_IPAR_INTPNT_SOLVE_FORM')
        param.MSK_IPAR_INTPNT_SOLVE_FORM = 'MSK_SOLVE_FREE';
    end

    if ~isfield(param,'MSK_DPAR_INTPNT_TOL_INFEAS')
        param.MSK_DPAR_INTPNT_TOL_INFEAS = 1e-8;
    end
end

param = applyProblemTypeOptimizerPortfolio(param);

if ~isfield(param,'MSK_IPAR_LOG_FEAS_REPAIR') && ...
        isfield(param,'repairInfeasibility')
    param.MSK_IPAR_LOG_FEAS_REPAIR = param.repairInfeasibility;
end
end


function param = applyProblemTypeOptimizerPortfolio(param)
% applyProblemTypeOptimizerPortfolio
%
% Apply historical problemType-dependent optimiser selections.

problemType = upper(char(string(param.problemType)));

switch problemType
    case 'LP'
        if isfield(param,'lpmethod') && ~isempty(param.lpmethod)
            param.MSK_IPAR_OPTIMIZER = normaliseMosekOptimizerName(param.lpmethod);
        end

    case 'QP'
        if isfield(param,'qpmethod') && ~isempty(param.qpmethod)
            param.MSK_IPAR_OPTIMIZER = normaliseMosekOptimizerName(param.qpmethod);
        end

    case 'CLP'
        if isfield(param,'clpmethod') && ~isempty(param.clpmethod)
            % The old code tested param.qpmethod here; this should test
            % param.clpmethod.
            param.MSK_IPAR_OPTIMIZER = normaliseMosekOptimizerName(param.clpmethod);
        end

        if ~isfield(param,'MSK_IPAR_INTPNT_REGULARIZATION_USE')
            param.MSK_IPAR_INTPNT_REGULARIZATION_USE = 'MSK_ON';
        end

    case 'EP'
        if isfield(param,'epmethod') && ~isempty(param.epmethod)
            param.MSK_IPAR_OPTIMIZER = normaliseMosekOptimizerName(param.epmethod);
        end

        if ~isfield(param,'MSK_IPAR_INTPNT_REGULARIZATION_USE')
            param.MSK_IPAR_INTPNT_REGULARIZATION_USE = 'MSK_ON';
        end

        if ~isfield(param,'MSK_IPAR_INTPNT_MAX_ITERATIONS')
            param.MSK_IPAR_INTPNT_MAX_ITERATIONS = 400;
        end

    case 'VK'
        % Retained as a placeholder for VK-specific MOSEK portfolio choices.

    otherwise
        % Do nothing for unrecognised problemType values.  This preserves
        % compatibility with callers that do not use problemType-specific
        % fields.
end
end

function param = applySCLPMosekPortfolio(param, profile)
% applySCLPMosekPortfolio
%
% Materialise solveSCLP-owned MOSEK parameter profiles.
%
% This is intentionally kept compact and explicit.  solveSCLP chooses one
% of the SCLP_* profile names through param.mosekParam, then all actual
% MSK_* assignments happen here and nowhere else.

if ~isfield(param,'timelimit') || isempty(param.timelimit)
    param.timelimit = 600;
end

if ~isfield(param,'innerMosekTolFactor') || isempty(param.innerMosekTolFactor)
    param.innerMosekTolFactor = 1e-3;
end

if ~isfield(param,'innerMosekTolFloorFactor') || isempty(param.innerMosekTolFloorFactor)
    param.innerMosekTolFloorFactor = 10;
end

if ~isfield(param,'innerMosekMuTolFactor') || isempty(param.innerMosekMuTolFactor)
    param.innerMosekMuTolFactor = 1e-5;
end

if ~isfield(param,'innerMosekMuTolFloorFactor') || isempty(param.innerMosekMuTolFloorFactor)
    param.innerMosekMuTolFloorFactor = 1;
end

innerTol = max( ...
    param.innerMosekTolFactor * param.feasTol, ...
    param.innerMosekTolFloorFactor * param.numTol);

innerMuTol = max( ...
    param.innerMosekMuTolFactor * param.feasTol, ...
    param.innerMosekMuTolFloorFactor * param.numTol);

% Interior-point solve form and conic tolerances used by solveSCLP.
param.MSK_IPAR_INTPNT_SOLVE_FORM = 'MSK_SOLVE_PRIMAL';

param.MSK_DPAR_INTPNT_CO_TOL_PFEAS   = innerTol;
param.MSK_DPAR_INTPNT_CO_TOL_DFEAS   = innerTol;
param.MSK_DPAR_INTPNT_CO_TOL_REL_GAP = innerTol;
param.MSK_DPAR_INTPNT_CO_TOL_MU_RED  = innerMuTol;

% Presolve profile.
switch profile
    case {'SCLP_normalPresolve','SCLP_verbose'}
        param.MSK_IPAR_PRESOLVE_USE = 'MSK_PRESOLVE_MODE_FREE';

    case {'SCLP_noPresolve','SCLP_noPresolveVerbose'}
        param.MSK_IPAR_PRESOLVE_USE = 'MSK_PRESOLVE_MODE_OFF';

    otherwise
        error('setMosekParam:badSCLPProfile', ...
            'Unsupported SCLP MOSEK profile: %s', profile);
end

% Presolve and data tolerances are numerical interpretation tolerances, not
% model feasibility targets.
if ~isfield(param,'mosekPresolveTolXFactor') || isempty(param.mosekPresolveTolXFactor)
    param.mosekPresolveTolXFactor = 100;
end

if ~isfield(param,'mosekPresolveTolSFactor') || isempty(param.mosekPresolveTolSFactor)
    param.mosekPresolveTolSFactor = 100;
end

if ~isfield(param,'mosekDataTolXFactor') || isempty(param.mosekDataTolXFactor)
    param.mosekDataTolXFactor = 1;
end

param.MSK_DPAR_PRESOLVE_TOL_PRIMAL_INFEAS_PERTURBATION = 0;
param.MSK_DPAR_PRESOLVE_TOL_X = ...
    param.mosekPresolveTolXFactor * param.numTol;
param.MSK_DPAR_PRESOLVE_TOL_S = ...
    param.mosekPresolveTolSFactor * param.numTol;
param.MSK_DPAR_DATA_TOL_X = ...
    param.mosekDataTolXFactor * param.numTol;
param.MSK_DPAR_INTPNT_CO_TOL_NEAR_REL = 1.0;

% -------------------------------------------------------------------------
% Logging requested by this profile.
% -------------------------------------------------------------------------
%
% These fields describe what the SCLP profile would like to print in
% verbose mode.  The final decision is made by applyMosekPrintPolicy.
if any(strcmp(profile, {'SCLP_verbose','SCLP_noPresolveVerbose'}))
    param.MSK_IPAR_LOG = 10;
    param.MSK_IPAR_LOG_INTPNT = 10;
    param.MSK_IPAR_LOG_SIM = 10;
    param.MSK_IPAR_LOG_PRESOLVE = 10;
end

if ~isfield(param, 'MSK_DPAR_OPTIMIZER_MAX_TIME') && ...
        isfield(param,'timelimit') && ~isempty(param.timelimit)
    param.MSK_DPAR_OPTIMIZER_MAX_TIME = param.timelimit;
end

% Retain the CLP regularisation setting for solveSCLP conic subproblems.
if ~isfield(param,'MSK_IPAR_INTPNT_REGULARIZATION_USE')
    param.MSK_IPAR_INTPNT_REGULARIZATION_USE = 'MSK_ON';
end
end


function name = normaliseMosekOptimizerName(value)
% normaliseMosekOptimizerName
%
% Accept either 'INTPNT' or 'MSK_OPTIMIZER_INTPNT'-style input.

name = char(string(value));

if ~contains(name, 'MSK_OPTIMIZER_')
    name = ['MSK_OPTIMIZER_' name];
end
end


function paramOut = removeMosekParameterFields(paramIn)
% removeMosekParameterFields
%
% Remove every actual MOSEK parameter field.  This is required for true
% default mode, because a parameter is default only when it is not supplied.

paramOut = paramIn;
fields = fieldnames(paramOut);

for i = 1:numel(fields)
    name = fields{i};

    if strncmp(name, 'MSK_', 4)
        paramOut = rmfield(paramOut, name);
    end
end
end


function value = getScalarFieldOrDefault(s, fieldName, defaultValue)
% getScalarFieldOrDefault
%
% Return s.(fieldName) when it is a finite scalar numeric value; otherwise
% return defaultValue.

value = defaultValue;

if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    candidate = s.(fieldName);

    if isnumeric(candidate) || islogical(candidate)
        candidate = double(candidate(1));

        if isfinite(candidate)
            value = candidate;
        end
    end
end
end


function value = getTextFieldOrDefault(s, fieldName, defaultValue)
% getTextFieldOrDefault
%
% Return s.(fieldName) as char text when present; otherwise defaultValue.

value = defaultValue;

if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    candidate = char(string(s.(fieldName)));

    if ~isempty(strtrim(candidate))
        value = candidate;
    end
end
end



% This is the old code
% function mosekParamStart = makeInitialStartMosekParam(mosekParam, param, profile)
% % makeInitialStartMosekParam
% %
% % Return a MOSEK parameter structure specialised for initial-start solves.
% %
% % This function no longer introduces independent absolute tolerances. It
% % only uses values already created by setSCLPparamPortfolio.
% 
% if nargin < 3 || isempty(profile)
%     profile = 'normalPresolve';
% end
% 
% mosekParamStart = mosekParam;
% 
% % Initial-start solves need accurate primal coordinates. Use the same
% % solveSCLP-owned MOSEK tolerances as ordinary inner solves.
% mosekParamStart.MSK_DPAR_INTPNT_CO_TOL_PFEAS = ...
%     param.MSK_DPAR_INTPNT_CO_TOL_PFEAS;
% 
% mosekParamStart.MSK_DPAR_INTPNT_CO_TOL_DFEAS = ...
%     param.MSK_DPAR_INTPNT_CO_TOL_DFEAS;
% 
% mosekParamStart.MSK_DPAR_INTPNT_CO_TOL_REL_GAP = ...
%     param.MSK_DPAR_INTPNT_CO_TOL_REL_GAP;
% 
% mosekParamStart.MSK_DPAR_INTPNT_CO_TOL_MU_RED = ...
%     param.MSK_DPAR_INTPNT_CO_TOL_MU_RED;
% 
% mosekParamStart.MSK_DPAR_DATA_TOL_X = ...
%     param.MSK_DPAR_DATA_TOL_X;
% 
% mosekParamStart.MSK_DPAR_PRESOLVE_TOL_X = ...
%     param.MSK_DPAR_PRESOLVE_TOL_X;
% 
% mosekParamStart.MSK_DPAR_PRESOLVE_TOL_S = ...
%     param.MSK_DPAR_PRESOLVE_TOL_S;
% 
% mosekParamStart.MSK_DPAR_PRESOLVE_TOL_PRIMAL_INFEAS_PERTURBATION = ...
%     param.MSK_DPAR_PRESOLVE_TOL_PRIMAL_INFEAS_PERTURBATION;
% 
% mosekParamStart.MSK_DPAR_INTPNT_CO_TOL_NEAR_REL = ...
%     param.MSK_DPAR_INTPNT_CO_TOL_NEAR_REL;
% 
% mosekParamStart.MSK_IPAR_INTPNT_SOLVE_FORM = ...
%     param.MSK_IPAR_INTPNT_SOLVE_FORM;
% 
% mosekParamStart.MSK_IPAR_PRESOLVE_USE = ...
%     param.MSK_IPAR_PRESOLVE_USE;
% 
% if strcmp(char(string(profile)), 'noPresolve')
%     mosekParamStart.MSK_IPAR_PRESOLVE_USE = 'MSK_PRESOLVE_MODE_OFF';
% end
% 
% end