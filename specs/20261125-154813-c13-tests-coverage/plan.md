# Implementation Plan: c13 tests run their generated solver files outside src

**Branch**: `20261125-154813-c13-tests-coverage` | **Date**: 2026-11-25 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/20261125-154813-c13-tests-coverage/spec.md`

## Summary

The eight c13 tests generate the solver files into `src/.../c13solver/`, run them there, then
delete them. MOcov, run at the end of testAll.m, then fails on the profiled files that are gone,
so CI writes no coverage. After generating, each test will move the six generated files into a
temporary folder outside `src`, put it on the path, and run them from there. At the end it removes
the folder and restores what `src` held before. MOcov ignores profiled files outside `src`.

## Technical Context

**Language/Version**: MATLAB R2024b or newer (local verification on R2025a)

**Primary Dependencies**: COBRA Toolbox; generateIsotopomerSolver with the Perl scripts under
`external/dataIntegration/fluxomics/c13solver/` (unchanged); MOcov (CI image; for the local reproduction
only, upstream MOcov downloaded to the session scratchpad and not added to the repository, with
the one patch the CI image carries according to commit 14e51d602: mocov_line_covered accepts the
four-argument call of the profile path. Without it, upstream MOcov stops with 'illegal input'.
As in testAll.m, the profiler stays on when MOcov runs. MOcov's own `profile on` otherwise
restarts it and discards the test's data, which in a first attempt gave 0 lines covered and
hid the failure.)

**Storage**: temporary folders from `tempname`

**Testing**: runScriptFile / testAll harness. Local reproduction: `profile on`, run the test, then
`mocov('-cover', <folder containing c13solver>, '-profile_info', '-cover_xml_file', <tmp>,
'-cover_method', 'profile')`

**Target Platform**: Linux CI (Docker, headless); tests stay OS-independent (Perl declared outside
Windows only, unchanged)

**Project Type**: library test suite

**Performance Goals**: none; one extra file move per test

**Constraints**: no change to src, testAll.m, workflows or codecov.yml (FR-005)

**Scale/Scope**: 8 test files, the same two blocks in each

## Constitution Check

- **Scientific code quality**: no source or numerical change. The tests assert exactly what they
  assert now.
- **Testing and reproducibility**: the eight tests pass, with and without generated files present
  beforehand. A before/after listing with checksums of c13solver shows `src` is left as found.
  The local MOcov reproduction shows the failure (old tests) and the fix (new tests).
- **User experience and diagnostics**: no new console output. A missing generated file makes
  movefile raise an error (the test fails loudly).
- **Performance and numerical integrity**: unchanged.
- **External-solver configuration audit**: N/A (the LP solver is used by generateIsotopomerSolver
  as now; no option changed).
- **Dependency minimisation**: unchanged. The LP solver and Perl, outside Windows, are still needed
  to generate the files, and are declared with their reasons in each header. MOcov is CI tooling
  and is not added.
- **Spec-driven scope control**: edits only to the eight files in
  `test/verifiedTests/dataIntegration/testFitC13Data/` (testConvertCarbonInput,
  testErrorComputation2, testErrorComputation2_grad, testGradtest, testSlvrCumomer,
  testSlvrCumomer_fast, testSlvrEMU, testSlvrEMU_fast) and this feature folder. testFitC13Data.m
  is not touched (spec, Out of scope). `external/` stays read-only.
- **MATLAB coding standards**: no evalc; warnings stay visible; no new try/catch; movefile,
  addpath and rmpath are base MATLAB.
- **Parameter-setting fidelity**: N/A.
- **Artifact placement**: generated files now live only in a tempname folder during the test, so
  generated output no longer passes through `src` while it runs (Principle IX). Records go under
  `specs/20261125-154813-c13-tests-coverage/`.

Gate: pass.

## Design

Set-up block, after `generateIsotopomerSolver(...)` and `clear c13Fixtures`:

```matlab
% generateIsotopomerSolver writes the files into its own folder of src; move them to a temporary
% folder placed on the path and run them from there. CI measures the coverage of src with
% MOcov, which stops when a file it saw run under src is gone at the end; files outside src
% are not measured
c13Generated = tempname;
mkdir(c13Generated);
for k = 1:numel(c13Files)
    movefile(fullfile(c13Dir, c13Files{k}), c13Generated);
end
addpath(c13Generated);
% make MATLAB read the new files, not versions of them it may hold in memory
rehash;
clear convertCarbonInput slvrCumomer slvrCumomer_fast slvrEMU slvrEMU_fast
```

Restore block, replacing the current one:

```matlab
% remove the generated files, and put back the solver files present in src before the test
rmpath(c13Generated);
rmdir(c13Generated, 's');
for k = find(c13Existed)'
    copyfile(fullfile(c13Backup, c13Files{k}), c13Dir);
end
rmdir(c13Backup, 's');
rehash;
clear convertCarbonInput slvrCumomer slvrCumomer_fast slvrEMU slvrEMU_fast
```

All six files are moved, including IsotopomerModel.txt (only the Perl scripts read it, during
generation), so `src` holds none of them while the test runs. Pre-existing files were already
copied to `c13Backup` before generation overwrote them, and are copied back, as now.

Header: a Purpose bullet before "Function under test" stating that the files run from a temporary
copy outside `src`, so CI coverage (toolbox source only) does not count them, and an Authors line
dated 2026-11-25.

Rejected alternatives:

- Leaving the generated files in `src` (no deletion): MOcov would count several MB of generated
  code as toolbox source, and the run would leave untracked files in the checkout.
- Changing generateIsotopomerSolver to write elsewhere: an interface/behaviour change of a source
  function (Principle II), not needed to fix the tests.
- Changing testAll.m or the workflow to tolerate the error: masks the cause, and the maintainer
  deferred CI changes.

## Project Structure

### Documentation (this feature)

```text
specs/20261125-154813-c13-tests-coverage/
├── spec.md
├── plan.md
├── tasks.md
├── checklists/requirements.md
├── verification/          # MATLAB scripts and logs of the reproduction (no machine paths)
└── agent-runs/<UTC>-implement/implementation-receipt.md
```

### Source Code (repository root)

```text
test/verifiedTests/dataIntegration/testFitC13Data/   # the eight tests (edited)
```

## Complexity Tracking

None.
