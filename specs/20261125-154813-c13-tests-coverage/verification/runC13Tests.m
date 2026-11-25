function runC13Tests()
% Runs the eight tests of feature 20261125-154813-c13-tests-coverage with runScriptFile, as
% testAll.m does, and prints one line per test (RESULT: name status) and whether a generated
% solver folder (c13Generated) was left on the MATLAB path.
%
% USAGE:
%
%    runC13Tests()
%
% NOTE:
%    The COBRA Toolbox must be initialised.

testNames = {'testConvertCarbonInput', 'testErrorComputation2', 'testErrorComputation2_grad', ...
    'testGradtest', 'testSlvrCumomer', 'testSlvrCumomer_fast', 'testSlvrEMU', 'testSlvrEMU_fast'};
pathBefore = path;
for k = 1:numel(testNames)
    result = runScriptFile(which(testNames{k}));
    fprintf('RESULT: %s %s %s\n', testNames{k}, result.status, result.statusMessage);
    if ~isempty(result.Error) && ~isempty(result.Error.message)
        fprintf('ERROR: %s\n', result.Error.message);
    end
end
% path entries added or removed by the tests; a generated solver folder would be a tempname
% folder (under tempdir) left on the path
entriesBefore = strsplit(pathBefore, pathsep);
entriesAfter = strsplit(path, pathsep);
added = setdiff(entriesAfter, entriesBefore);
removed = setdiff(entriesBefore, entriesAfter);
fprintf('PATH-ADDED: %d, of which under tempdir: %d\n', numel(added), ...
    sum(strncmp(added, tempdir, numel(tempdir))));
fprintf('PATH-REMOVED: %d\n', numel(removed));
for k = 1:numel(added)
    fprintf('  added: %s\n', added{k});
end
end
