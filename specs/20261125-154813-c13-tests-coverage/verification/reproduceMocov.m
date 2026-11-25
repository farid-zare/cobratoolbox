function reproduceMocov(mocovPath, testName, coverDir, outDir)
% Reproduces the CI coverage step of test/testAll.m for one test (feature
% 20261125-154813-c13-tests-coverage): the profiler records the test run, then MOcov reads
% profile('info') and writes a Cobertura XML file, as testAll.m does on CI.
%
% USAGE:
%
%    reproduceMocov(mocovPath, testName, coverDir, outDir)
%
% INPUTS:
%    mocovPath:    folder of a MOcov checkout (https://github.com/MOcov/MOcov) with the patch
%                  the CI image carries (commit 14e51d602): mocov_line_covered accepts the
%                  four-argument call (index, key, line, count) of the profile path, which
%                  upstream rejects with 'illegal input'
%    testName:     name of the test script, for example 'testSlvrEMU_fast'
%    coverDir:     folder whose coverage is measured (testAll.m uses 'src'; a subfolder that
%                  contains src/dataIntegration/fluxomics/c13solver shows the same behaviour)
%    outDir:       folder for coverage.xml
%
% NOTE:
%    Prints one line starting with MOCOV-OK or MOCOV-FAILED, and one starting with TEST-PASSED
%    or TEST-FAILED. The COBRA Toolbox must be initialised.

addpath(genpath(mocovPath));
xmlFile = fullfile(outDir, 'coverage.xml');
if exist(xmlFile, 'file')
    delete(xmlFile);
end

profile clear;
profile on;
try
    run(which(testName));
    fprintf('TEST-PASSED: %s\n', testName);
catch ME
    fprintf('TEST-FAILED: %s: %s (%s line %d)\n', testName, ME.message, ME.stack(1).file, ME.stack(1).line);
end

% as in testAll.m, the profiler is still on when MOcov runs (MOcov's own 'profile on' would
% otherwise restart it and discard what the test recorded)
try
    mocov('-cover', coverDir, ...
        '-profile_info', ...
        '-cover_xml_file', xmlFile, ...
        '-cover_method', 'profile');
    xmlInfo = dir(xmlFile);
    fprintf('MOCOV-OK: coverage.xml written (%d bytes)\n', xmlInfo.bytes);
catch ME
    fprintf('MOCOV-FAILED: %s (%s line %d)\n', ME.message, ME.stack(1).name, ME.stack(1).line);
end
profile off;
end
