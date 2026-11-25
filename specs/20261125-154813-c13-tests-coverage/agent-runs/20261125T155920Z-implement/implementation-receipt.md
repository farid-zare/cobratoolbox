# Implementation receipt: c13 tests run their generated solver files outside src

## Prompt

Maintainer (2026-11-25): "Yes fix it with speckit. No need to make the error a real failure at the
moment." Run the full Spec Kit workflow for feature 20261125-154813-c13-tests-coverage (specify,
plan, tasks, analyze, implement). In the eight c13 tests, move the files generateIsotopomerSolver
writes into src to a temporary folder outside src, and run them from there, so that MOcov in CI no
longer stops with "Not found". No CI change. testFitC13Data is out of scope. Reproduce the failure
with MOcov first. Commit as the maintainer, no co-author line, no push.

## Final response

c13 coverage fix done on branch 20261125-154813-c13-tests-coverage, one commit, not pushed.

- Cause confirmed locally: with the old testSlvrEMU_fast, MOcov (upstream plus the CI image's
  one-line patch, profiler left on as testAll.m does) stops with "Not found:
  dataIntegration/fluxomics/c13solver/convertCarbonInput.m (get_mfile_by_name line 42)". That is
  the same function and line as the CI warning.
- Fix: in the eight tests, the six generated files are moved right after generation to a
  tempname folder outside src, put on the path, run from there, and removed at the end. Files
  that existed in src before are put back as before. Headers say so; assertions are unchanged
  (assert counts equal).
- With the new test, MOcov completes and writes coverage.xml (1,056 lines covered, no generated
  file counted).
- All eight tests pass, both without generated files in src and with files from an earlier run.
  The c13solver folder is identical afterwards (checksums), and no folder is left on the path.
- Not changed: src, testAll.m, the workflows, codecov.yml. testFitC13Data is recorded in the spec
  as a follow-up: it needs an NLP solver and prints an undefined variable.
- Codecov comments again only after this is merged and CI runs on opencobra; that is still to be
  observed.

## Diff summary

- `test/verifiedTests/dataIntegration/testFitC13Data/` (8 files): testConvertCarbonInput,
  testErrorComputation2, testErrorComputation2_grad, testGradtest, testSlvrCumomer,
  testSlvrCumomer_fast, testSlvrEMU, testSlvrEMU_fast.
  - After generateIsotopomerSolver, the six generated files move to `c13Generated = tempname`,
    which is added to the path.
  - At the end: rmpath, rmdir, then the pre-existing files are copied back from the backup.
  - Header: a Purpose bullet and an Authors line.
  - +21/-7 lines each.
- `specs/20261125-154813-c13-tests-coverage/`: spec.md, plan.md, tasks.md,
  checklists/requirements.md, this receipt, and `verification/`.
  - verification/reproduceMocov.m, verification/runC13Tests.m.
  - Logs: mocov-old-tests.txt, mocov-new-tests.txt, tests-without-generated-files.txt,
    tests-with-generated-files.txt.
- `.specify/feature.json`: points to this feature.

## Tests

MATLAB R2025a, via matlab-safe, one session at a time.

- T003, old testSlvrEMU_fast under the profiler, then MOcov on src: TEST-PASSED; MOCOV-FAILED
  "Not found: dataIntegration/fluxomics/c13solver/convertCarbonInput.m (get_mfile_by_name
  line 42)".
- T005, new testSlvrEMU_fast, same steps: TEST-PASSED; MOCOV-OK, coverage.xml of 6,613,532 bytes,
  lines-covered 1056 of 140939, no slvr*/convertCarbonInput entry.
- T006, the eight tests through runScriptFile, no generated files in src: 8 passed; path entries
  added 0, removed 0; c13solver equals the tracked files only.
- T007, the eight tests with the earlier generated files in src: 8 passed; path unchanged;
  c13solver listing and md5 checksums identical to before.
- T008: only the eight tests, `.specify/feature.json` and the feature folder changed; the
  `assert(` counts are equal in every file.

## Unresolved issues

- The local reproduction uses upstream MOcov with the patch described in commit 14e51d602, not
  the CI image itself. The CI warning (`get_mfile.m line 42`) matches upstream's code line. The
  first local attempt stopped the profiler before MOcov; MOcov's own `profile on` then discarded
  the data, giving 0 lines and no error. The script now leaves the profiler on, as testAll.m does.
- Codecov's comment returning is confirmed only by the first CI run after merge.
- testFitC13Data.m still generates the files into src and leaves them there. It is skipped on CI
  (NLP). Follow-up in spec.md.

## Other information

The local generated files in c13solver, gitignored and from earlier runs, were set aside during
T003-T006 and put back for T007. They are present again, unchanged.
