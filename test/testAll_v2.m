originalUserPath = path; 

[result, resultTable] = runTestSuite();

% Write the JUnit XML report (this block is largely unchanged).
xmlFileName = 'CodeCovTestResults.xml';
fid = fopen(xmlFileName, 'w');
if fid == -1
    error('Could not open file for writing: %s', xmlFileName);
end

fprintf(fid, '<?xml version="1.0" encoding="UTF-8"?>\n');
numTests    = height(resultTable);
numFailures = sum(resultTable.Failed);
numErrors   = sum(resultTable.Failed);  % for simplicity, using same count here
numSkipped  = sum(resultTable.Skipped);
totalTime   = sum(resultTable.Time);

% Wrap the report in <testsuites> and a single <testsuite> element.
fprintf(fid, '<testsuites name="COBRA Toolbox Test Suites" tests="%d" failures="%d" errors="%d" time="%.3f">\n', ...
    numTests, numFailures, numErrors, totalTime);
fprintf(fid, '  <testsuite name="COBRA Toolbox Test Suite" tests="%d" failures="%d" errors="%d" skipped="%d" time="%.3f">\n', ...
    numTests, numFailures, numErrors, numSkipped, totalTime);

for i = 1:numTests
    testName = resultTable.TestName{i};
    if isnan(resultTable.Time(i))
        tVal = 0;
    else
        tVal = resultTable.Time(i);
    end

    fprintf(fid, '    <testcase classname="COBRA Toolbox" name="%s" time="%.3f"', testName, tVal);
    if resultTable.Passed(i)
        fprintf(fid, '/>\n');
    elseif resultTable.Skipped(i)
        fprintf(fid, '>\n');
        fprintf(fid, '      <skipped message="%s"/>\n', escapeXML(resultTable.Details{i}));
        fprintf(fid, '    </testcase>\n');
    else
        % If not passed and not skipped, decide between failure and error.
        errMsg = result(i).Error.message;
        if contains(errMsg, 'Assertion') || contains(errMsg, 'assert')
            fprintf(fid, '>\n');
            fprintf(fid, '      <failure message="%s"/>\n', escapeXML(errMsg));
        else
            fprintf(fid, '>\n');
            fprintf(fid, '      <error message="%s"/>\n', escapeXML(errMsg));
        end
        fprintf(fid, '    </testcase>\n');
    end
end

fprintf(fid, '  </testsuite>\n');
fprintf(fid, '</testsuites>\n');
fclose(fid);

% Restore the original path.
restoredefaultpath;
addpath(originalUserPath);

if sum(resultTable.Failed) > 0
    exit_code = 1;
end

fprintf(['\n > The exit code is ', num2str(exit_code), '.\n\n']);

    %% Local helper function to escape XML special characters.
    function out = escapeXML(in)
        if isempty(in)
            out = '';
            return;
        end
        out = strrep(in, '&', '&amp;');
        out = strrep(out, '<', '&lt;');
        out = strrep(out, '>', '&gt;');
        out = strrep(out, '"', '&quot;');
        out = strrep(out, '''', '&apos;');
    end
