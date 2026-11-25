# Tasks: c13 tests run their generated solver files outside src

**Input**: `specs/20261125-154813-c13-tests-coverage/` (spec.md, plan.md)

**Tests**: required (the reproduction proves the fix; the eight tests are the change).

`F` = this feature folder; `D` = `test/verifiedTests/dataIntegration/testFitC13Data`.

## Phase 1: Setup

- [X] T001 Download upstream MOcov into the session scratchpad (own empty folder; untrusted download, not committed); write the reproduction script `F/verification/reproduceMocov.m` (profile on, run a test, mocov with `-profile_info` and `-cover_method profile` on a cover folder containing c13solver, report "Not found" or the coverage.xml written)
- [X] T002 Save the local generated files of `src/dataIntegration/fluxomics/c13solver/` (gitignored, from earlier runs) to the scratchpad, and record the folder listing with checksums; remove them, so the run starts as on CI (none present)

## Phase 2: Foundational

None.

## Phase 3: User Story 1 - Coverage is measured again in CI (P1) 🎯 MVP

- [X] T003 [US1] Run `F/verification/reproduceMocov.m` with the OLD testSlvrEMU_fast: MOcov stops with "Not found: .../c13solver/..." (test-first evidence; record in `F/verification/`)
- [X] T004 [US1] Edit the eight tests in `D/` (testConvertCarbonInput, testErrorComputation2, testErrorComputation2_grad, testGradtest, testSlvrCumomer, testSlvrCumomer_fast, testSlvrEMU, testSlvrEMU_fast): move the generated files to a tempname folder on the path after generation, run from there, remove it and restore pre-existing files at the end (plan.md, Design); header Purpose bullet and Authors line
- [X] T005 [US1] Run `F/verification/reproduceMocov.m` with the NEW testSlvrEMU_fast: MOcov completes and writes coverage.xml (record in `F/verification/`)

## Phase 4: User Story 2 - The c13 tests keep testing the same thing (P1)

- [X] T006 [US2] Run the eight tests (runScriptFile) with no generated files in src: all pass; c13solver listing afterwards equals the tracked files only
- [X] T007 [US2] Put the saved generated files back (T002), run the eight tests again: all pass; listing and checksums equal the T002 record
- [X] T008 [US2] Diff check: only the eight tests and `F/` (and `.specify/feature.json`) changed; assertions unchanged (`assert(` counts before and after equal)

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T009 Receipt `F/agent-runs/<UTC>-implement/implementation-receipt.md`; tasks [X]
- [X] T010 Privacy scan (`specs/20261113-142115-test-backfill-tiers/tools/privacy_check.sh`, the repository's scan; there is no `tools/privacy_check.sh`); commit as the maintainer, no co-author line, submodule pointers not staged; no push (the maintainer pushes on request)

## Dependencies & Execution Order

T001, T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010. T003 must see the failure
before T004 changes the tests.
