# RHS_NS Stage 9 Submission Memo (0.4.0)

Date: 2026-03-27
Branch: `cransub/0.4.0`
Repo path: `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile`

## 1) Scope Completed

1. Native `rhs_ns` support added for static exAL VB/MCMC on `0.4.0`.
2. Existing `rhs` and `ridge` behavior preserved as additive compatibility paths.
3. User-facing docs and NEWS updated to include finalized `rhs_ns` API usage.
4. Tracker closure evidence synced on `feature/qdesn-mcmc-alternative`.

## 2) Key Commits

1. `9876844` - Add `rhs_ns` support to static exAL VB/MCMC on `0.4.0`.
2. `293d1ca` - Finalize `rhs_ns` release docs and static API examples.

## 3) Validation Evidence

### 3.1 Test Suites

1. `testthat::test_local('tests/testthat', stop_on_failure = TRUE)` -> PASS (1348)
2. `testthat::test_local(filter = 'smoke|static-beta-prior-rhs', stop_on_failure = TRUE)` -> PASS (90)

### 3.2 CRAN-style Packaging/Checks

1. `R CMD build .` -> `exdqlm_0.4.0.tar.gz`
2. `env _R_CHECK_DONTTEST_EXAMPLES_=false R CMD check --as-cran exdqlm_0.4.0.tar.gz`
   - Result: `DONE`
   - Status: `4 NOTEs`, `0 WARNING`, `0 ERROR`

Primary logs:

1. `check-logs/rhs_ns_stage9_R_CMD_build.log`
2. `check-logs/rhs_ns_stage9_R_CMD_check_as_cran_tarball.log`
3. `exdqlm.Rcheck/00check.log`

## 4) NOTE Triage (Non-blocking)

1. Installed size note (`30.1Mb`, mostly `libs`).
2. Future timestamp note (environment clock verification unavailable).
3. Pandoc availability note for top-level README/NEWS checks in this environment.
4. Toolchain portability-flags note from local compiler config.

These are environmental/toolchain notes; no `rhs_ns` functional regressions were detected.

## 5) Release Recommendation

1. Keep default prior behavior unchanged (`rhs` remains default) for `0.4.0` release stability.
2. Ship `rhs_ns` as additive opt-in (`beta_prior = 'rhs_ns'`).
3. Proceed with CRAN submission flow using this branch state and attached evidence logs.
