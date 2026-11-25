# Feature Specification: c13 tests run their generated solver files outside src

**Feature Branch**: `20261125-154813-c13-tests-coverage`

**Created**: 2026-11-25

**Status**: Approved (maintainer, 2026-11-25: "Yes fix it with speckit. No need to make the error a
real failure at the moment.")

**Input**: Codecov no longer comments on pull requests. Since 2026-11-20 every CI run has ended
with the warning "Coverage measurement failed: Not found:
dataIntegration/fluxomics/c13solver/slvrEMU_fast.m" (or convertCarbonInput.m). No coverage.xml is
written, the Codecov upload is empty, Codecov marks it as an error with 0% coverage, and it posts
no comment. The last processed upload was on 2026-11-18 (PR #2726).

## Cause

Commit 13803253e (2026-11-20, feature 20261113-142115-test-backfill-tiers, T034-T038) made the
eight tests of the generated c13 solver files generate those files themselves, because the CI
machine has none. generateIsotopomerSolver writes them into its own folder,
`src/dataIntegration/fluxomics/c13solver/`. The tests run them there and delete them at the end,
because they did not exist before. MATLAB's profiler has recorded them as files under `src`. At
the end of `test/testAll.m`, MOcov (`-profile_info`, `-cover_method profile`) lists the `.m` files
under `src` as they are at that moment. It then looks up every profiled file under `src` in that
list. A file the profiler saw that is no longer on disk raises `error('Not found: %s')`
(`MOcovMFileCollection/get_mfile.m`). testAll.m treats coverage as best-effort, so the run stays
green but writes no coverage.xml. MOcov skips profiled files outside `src`
(`set_lines_executed.m`: `if ~has_prefix(filename) continue`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Coverage is measured again in CI (Priority: P1)

A maintainer opens a pull request. CI runs the selected tests, which include the c13 tests. MOcov
writes coverage.xml, and Codecov processes the upload and comments on the pull request again.

**Why this priority**: the coverage gate (patch coverage) and the pull-request comment are the
project's view of test coverage; both have been silently off since 2026-11-20.

**Independent Test**: in a MATLAB session with the profiler on, run one of the eight tests, then
run MOcov the way testAll.m does (`-profile_info`, `-cover_method profile`, a cover folder that
contains `c13solver`). With the old test MOcov stops with "Not found: ...". With the new test it
writes coverage.xml.

**Acceptance Scenarios**:

1. **Given** a checkout without generated solver files (as on CI), **When** a c13 test runs under
   the profiler and MOcov runs afterwards, **Then** MOcov completes and writes coverage.xml.
2. **Given** the same run, **When** the test ends, **Then** `src/dataIntegration/fluxomics/c13solver/`
   holds exactly the files it held before the test.

### User Story 2 - The c13 tests keep testing the same thing (Priority: P1)

The eight tests keep their assertions, fixtures, requirements and tiers. Only where the generated
files run from changes, together with the header text that says so.

**Independent Test**: all eight tests pass, both with and without generated solver files present
in `src` beforehand. Files present beforehand are back in `src`, byte for byte, afterwards.

**Acceptance Scenarios**:

1. **Given** no generated files in `src`, **When** each test runs, **Then** it passes and leaves
   none in `src`.
2. **Given** generated files in `src` from an earlier run (possibly for another model), **When**
   each test runs, **Then** it passes and those files are back unchanged.

### Edge Cases

- A test fails part-way: as now, the restore code at the end does not run (the tests use no
  onCleanup today, and this feature does not change their error handling). Before this feature a
  failure left the generated files in `src`. Now, after the move, it leaves them in the temporary
  folder, which stays on the path for the rest of that MATLAB session. In both cases the
  pre-existing files stay in the backup folder under tempdir. Either way the next c13 test
  regenerates what it needs, and nothing tracked by git changes, so this is not a regression.
- generateIsotopomerSolver does not produce one of the six files: moving it fails with an error,
  so the test fails loudly instead of running a stale file.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Right after generateIsotopomerSolver, each of the eight tests MUST move the six files
  it writes (`IsotopomerModel.txt`, `convertCarbonInput.m`, `slvrCumomer.m`,
  `slvrCumomer_fast.m`, `slvrEMU.m`, `slvrEMU_fast.m`) from
  `src/dataIntegration/fluxomics/c13solver/` into a new temporary folder outside `src`. It then
  puts that folder on the MATLAB path, and calls rehash and clear for the five function names
  before the first call.
- **FR-002**: No generated solver file may run from `src` during the test.
- **FR-003**: At the end, the test MUST remove the temporary folder from the path, delete it, and
  copy back into `src` the files that existed there before (as now). `src` is left as it was
  found.
- **FR-004**: Assertions, fixtures, tolerances, requirements (`prepareTest`), tiers and coverage
  exemptions stay as they are. Each header states that the generated files run from a temporary
  copy outside `src`, so CI coverage, which measures toolbox source only, does not count them. The
  Authors list gains a dated line for this feature.
- **FR-005**: No change to `src`, `test/testAll.m`, the CI workflows or `codecov.yml`. The
  maintainer asked that the MOcov failure not be made a hard CI failure for now.

### Key Entities

- **Generated solver files**: model-specific code written by generateIsotopomerSolver from Perl
  scripts under `external/`. They are gitignored and are not toolbox source.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a local reproduction, MOcov stops with "Not found:
  dataIntegration/fluxomics/c13solver/..." after an old c13 test, and writes coverage.xml after
  the new one.
- **SC-002**: All eight tests pass, with and without pre-existing generated files. The c13solver
  folder listing and checksums are identical before and after.
- **SC-003**: After the change is merged, the next CI run on opencobra uploads a coverage
  artifact. Codecov processes the upload and comments. This is observed after merge, not part of
  this feature's gate.

## Assumptions

- The CI image's patched MOcov keeps upstream MOcov's lookup logic (`get_mfile`, prefix filter in
  `set_lines_executed`). The CI warning text and line (`get_mfile.m line 42`) match upstream.
- The generated files are not toolbox source. Leaving them in `src` until MOcov runs would count
  several MB of generated code (slvrCumomer.m alone is 5.9 MB) as source, so that option is
  rejected.

## Out of scope (known follow-ups)

- `testFitC13Data.m` also calls generateIsotopomerSolver, and leaves the files in `src`. It needs
  an NLP solver, so it is skipped on CI. It also prints `solverPkgs.LP{1}`, an undefined variable,
  so it would stop wherever it runs. It is a legacy test with its own defect; changing it is a
  separate change.
- Making a MOcov failure fail CI, or skipping the Codecov upload when coverage.xml is missing:
  deferred by the maintainer.

## Traceability

| Acceptance criterion | Discharging test | src/<domain>/ function under test |
|----------------------|------------------|-----------------------------------|
| US1-1, FR-001, FR-002, SC-001 | local MOcov reproduction (receipt), with testSlvrEMU_fast | src/dataIntegration/fluxomics/c13solver/slvrEMU_fast.m (generated) |
| US1-2, US2, FR-003, SC-002 | the eight tests in test/verifiedTests/dataIntegration/testFitC13Data/, with a before/after listing of c13solver | convertCarbonInput, errorComputation2, errorComputation2_grad, src/dataIntegration/fluxomics/gradtest.m, slvrCumomer, slvrCumomer_fast, slvrEMU, slvrEMU_fast |
| FR-004 | review of the eight headers | — (no source function) |
| FR-005 | git diff limited to the eight tests and specs/ | — (no source function) |
