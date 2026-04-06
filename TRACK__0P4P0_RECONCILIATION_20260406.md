# 0.4.0 Reconciliation Tracker

Date: 2026-04-06

## Scope

Goal: re-establish `cransub/0.4.0` as the canonical shared base for:

- upstream `origin/cransub/0.4.0`
- active exdqlm validation work on `validation/rerun-after-0.4.0-sync`
- qdesn validation work on `feature/qdesn-mcmc-alternative`

Constraints:

- Do not interrupt the live validation run in `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`.
- Do not kill tmux sessions `original288-dynamic-tail7-rw-20260406` or `original288-dynamic-tail7-rw-monitor-20260406`.
- Do not use destructive git operations.
- Treat the live validation worktree as read-only for this reconciliation.

## Working Snapshot

- Main repo worktree: `/home/jaguir26/local/src/exdqlm`
  - branch: `main`
  - commit: `9c715b7`
- Canonical 0.4.0 worktree: `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile`
  - branch: `cransub/0.4.0`
  - local commit before sync: `a95ee8c`
  - fetched upstream tip: `af2dbba`
  - actual status after fetch: local branch was behind upstream by 5 commits, not 1
  - current commit after fast-forward: `af2dbba`
- Parallel 0.4.0 scratch worktree: `/home/jaguir26/local/src/exdqlm__wt__0p4p0_parallel`
  - branch: `work/0.4.0-parallel`
  - commit: `a95ee8c`
- Active exdqlm validation worktree: `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`
  - branch: `validation/rerun-after-0.4.0-sync`
  - commit: `3011695`
  - confirmed live tmux sessions:
    - `original288-dynamic-tail7-rw-20260406`
    - `original288-dynamic-tail7-rw-monitor-20260406`
  - current dirty files are live-run report artifacts only:
    - `tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_case_best_20260406.csv`
    - `tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_config_summary_20260406.csv`
    - `tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_manifest_status_20260406.csv`
    - `tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_phase_summary_20260406.csv`
    - `tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_unresolved_after_run_20260406.csv`
- QDESN validation worktree: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`
  - branch: `feature/qdesn-mcmc-alternative`
  - commit: `eb141cc`
  - dirty tracked changes:
    - `R/qdesn_static_exdqlm_crossstudy.R`
    - `R/run_esn_pipeline.R`
  - dirty untracked files:
    - `R/qdesn_dynamic_exdqlm_crossstudy.R`
    - `config/validation/qdesn_dynamic_exdqlm_crossstudy_defaults.yaml`
    - `config/validation/qdesn_dynamic_exdqlm_crossstudy_grid.csv`
    - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R`
    - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R`
    - `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_grid.R`
    - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`

## Upstream 0.4.0 Delta

Fetched-only upstream commits after local `a95ee8c`:

- `188bfd5` move diagnostic output in exdqlmMCMC doc
- `7798f0e` return class fix for dqlm path
- `722de0a` fix check_ts() so it preserves ts object info
- `3dfac39` fix .run_dynamic_dqlm_cavi so it preserves ts object info
- `af2dbba` exdqlmLDVB objects compatible with exdqlmForecast()

Immediate implication: local `cransub/0.4.0` must be fast-forwarded before any shared-base backports are applied.

## Branch Topology

- `merge-base(origin/cransub/0.4.0, validation/rerun-after-0.4.0-sync) = a95ee8c`
- `merge-base(origin/cransub/0.4.0, feature/qdesn-mcmc-alternative) = 091d0e8`
- `merge-base(validation/rerun-after-0.4.0-sync, feature/qdesn-mcmc-alternative) = 091d0e8`

Divergence counts relative to `origin/cransub/0.4.0`:

- `validation/rerun-after-0.4.0-sync`: 5 upstream-only commits, 120 validation-only commits
- `feature/qdesn-mcmc-alternative`: 165 upstream-only commits, 284 qdesn-only commits

Interpretation:

- The validation branch started from the current local 0.4.0 tip and then accumulated focused package/base work plus a large validation-orchestration layer.
- The qdesn branch is a long-lived branch from an older ancestor and is not a safe merge candidate into `0.4.0`.
- The right mental model is not "merge qdesn into 0.4.0"; it is "update 0.4.0 canonically, then reconcile qdesn against that base."

## Validation Branch Findings

### Shared/base package files changed relative to `origin/cransub/0.4.0`

- `DESCRIPTION`
- `R/RcppExports.R`
- `R/exal_static_LDVB.R`
- `R/exal_static_mcmc.R`
- `R/exdqlmISVB.R`
- `R/exdqlmLDVB.R`
- `R/exdqlmMCMC.R`
- `R/static_beta_prior.R`
- `R/transfn_exdqlmISVB.R`
- `R/utils.R`
- `man/exal_static_LDVB.Rd`
- `man/exal_static_mcmc.Rd`
- `man/exdqlmISVB.Rd`
- `man/exdqlmLDVB.Rd`
- `man/exdqlmMCMC.Rd`
- `man/transfn_exdqlmISVB.Rd`
- `src/RcppExports.cpp`
- `src/sampling_utils.cpp`

### Validation branch base-change themes

The committed package-side delta is concentrated in these themes:

- C++ GIG sampler propagation and enforcement
  - new `sample_gig_devroye_pairs()` export/binding
  - helper wrappers in `R/utils.R`
  - dynamic VB/LDVB moved to required C++ GIG pairwise sampling
  - `exdqlmMCMC()` tightened around required C++ GIG sampling
- Dynamic MCMC diagnostics and telemetry
  - joint `laplace_rw` default
  - chain-health diagnostics
  - progress callback support
  - laplace refresh controls
- Static exAL / RHS / RHS_NS shared logic
  - `R/static_beta_prior.R` adds reusable prior parsing/state helpers
  - `R/exal_static_mcmc.R` adds joint sigma-gamma kernels, slice-eta support, gamma substeps, global eta jumps
  - `R/exal_static_LDVB.R` and docs align RHS_NS to the closed-form static hierarchy
- Dynamic/static convergence and normalization helpers
  - `R/utils.R` gains chain-health helpers
  - helper/test support for normalized static VB/MCMC output

Path-scoped validation commits touching the package/base layer:

- `c356b61` refactor(static-api): add static fit normalization adapters with compatibility tests
- `1e852ff` feat(static-exal): harden signoff guards and focused verification
- `81457ec` feat(static-vb): align exal sigma-gamma updates with qdesn
- `550ab6c` feat(dynamic-static): standardize sigma-gamma diagnostics
- `d1e87db` perf(mcmc): cache gamma slice path and make traces optional
- `909a62c` feat(validation): sync remaining static-dynamic audit and test work
- `9e0145a` feat(static-rhs): add ridge and horseshoe priors to static al exal
- `dfcf1ce` Fix lean-schema dynamic resume rebuild
- `d83ac43` fix(check): make helper-sourced tests tarball-safe and qualify utils::tail
- `2ec9b67` sync(validation): align package code to 0.4.0 and keep normalization helpers test-local
- `402494c` Add RHS guardrails for init semantics and collapse health
- `94d71cf` Improve static gamma mixing with substeps and global eta jumps
- `51de06d` exal static: add eta-slice gamma kernel for S12 recovery
- `2ed0937` static exAL MCMC: joint sigma-gamma MH block for rw kernels
- `f5d01ee` mcmc: default to joint laplace-rw and expose chain-health diagnostics
- `13cb72c` Add optional progress callback to exdqlmMCMC for run telemetry
- `bc77e34` Wave 2: port static RHS-NS closed-form hierarchy and tests
- `2134ba5` force cpp GIG sampler in exdqlmMCMC
- `6843feb` propagate cpp GIG sampler package-wide

### Validation-only artifacts that should not be merged into `0.4.0`

- Root docs/trackers:
  - `REFRESH_AUDIT_VALIDATION_20260329.md`
  - `TRACK__RHS_NS_CROSS_BRANCH_EXECUTION_PLAN_20260329.md`
- Operational reports:
  - `reports/rhs_ns_alignment_20260329/...`
  - `reports/static_exal_tuning_20260331/...`
  - `reports/static_exal_tuning_20260401/...`
  - `reports/static_exal_tuning_20260403/...`
  - `reports/static_exal_tuning_20260404/...`
  - `reports/static_exal_tuning_20260405/...`
  - `reports/static_exal_tuning_20260406/...`
- Validation tooling / state:
  - `tools/merge_reports/...`
  - `scripts/static_rhs_vs_rhsns_median_compare.R`

### Validation tests split

Safe package-test candidates:

- `tests/testthat/test-dqlm-vb-sim-smoke.R`
- `tests/testthat/test-static-beta-prior-rhs.R`
- `tests/testthat/test-static-regression-regmod.R`
- `tests/testthat/test-static-fit-normalization.R`
- `tests/testthat/test-vb-mcmc-convergence-controls.R`
- `tests/testthat/helper-static-fit-normalization.R`

Validation-harness tests that should stay out of `0.4.0` unless their tool layer is intentionally ported:

- `tests/testthat/test-dynamic-dgp-resume-rebuild.R`
  - depends on `tools/merge_reports/20260305_dynamic_dgp_model_helpers.R`
- `tests/testthat/test-family-qspec-repair-queue-smoke.R`
- `tests/testthat/test-family-qspec-root-signoff-smoke.R`
- `tests/testthat/test-family-qspec-signoff-helpers.R`
- `tests/testthat/test-static-vb-mcmc-pipeline-report-smoke.R`
  - depends on `tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R`
  - depends on `tools/merge_reports/20260305_static_vb_mcmc_report.R`

## QDESN Branch Findings

### True committed overlap with validation/shared base

These 15 paths are changed on both the validation branch and the qdesn branch relative to `origin/cransub/0.4.0`:

- `DESCRIPTION`
- `R/RcppExports.R`
- `R/exal_static_LDVB.R`
- `R/exal_static_mcmc.R`
- `R/exdqlmISVB.R`
- `R/exdqlmLDVB.R`
- `R/exdqlmMCMC.R`
- `R/utils.R`
- `man/exal_static_LDVB.Rd`
- `man/exal_static_mcmc.Rd`
- `man/exdqlmISVB.Rd`
- `man/exdqlmLDVB.Rd`
- `man/exdqlmMCMC.Rd`
- `src/RcppExports.cpp`
- `src/sampling_utils.cpp`

Important finding: all 15 of these files have different content in all three places:

- `origin/cransub/0.4.0`
- `validation/rerun-after-0.4.0-sync`
- `feature/qdesn-mcmc-alternative`

That means there is no zero-conflict shared-core fast path between validation and qdesn.

### Broader shared/base drift on the qdesn line

The qdesn branch also changes several generic package files beyond the 15-file overlap set:

- `.Rbuildignore`
- `.gitignore`
- `NAMESPACE`
- `NEWS.md`
- `R/exdqlm-package.R`
- `README.Rmd`
- `README.md`
- `R/transfn_exdqlmLDVB.R`
- `R/regMod.R`
- `man/transfn_exdqlmLDVB.Rd`
- `src/exAL.cpp`

These represent broader package evolution on the qdesn line, not targeted `0.4.0` backports.

### Broader package evolution on the qdesn line

The qdesn branch also contains substantial package growth not suitable for wholesale backport into `0.4.0` during this reconciliation, for example:

- generic additions:
  - `R/00_utils.R`
  - `R/exdqlm_synthesize_from_draws.R`
  - `R/gamma_bounds.R`
  - `R/priors_beta.R`
  - `R/tfRegMod.R`
  - `R/utils_require_fun.R`
  - `R/vb_diagnostics.R`
  - `src/Makevars`
  - `src/Makevars.win`
  - `src/forecast_paths.cpp`
  - `src/kalman.cpp`
  - `src/kalman_ndlm.cpp`
  - `src/omp_compat.h`
  - `src/sampling_truncnorm.cpp`
- qdesn-specific implementation:
  - `R/qdesn_*`
  - `config/validation/qdesn_*`
  - `scripts/run_qdesn_*`
  - `scripts/healthcheck_qdesn_*`
  - `reports/qdesn_*`
  - `results/...`

Working assumption for this reconciliation: these remain qdesn-side concerns and are not candidates for automatic `0.4.0` ingestion.

### Current dirty qdesn worktree state

The current uncommitted qdesn worktree changes are qdesn-only and should stay isolated:

- `R/qdesn_static_exdqlm_crossstudy.R`
  - adds a YAML boolean-coercion guard for `external_data.y_column`
- `R/run_esn_pipeline.R`
  - local qdesn-side tracked change discovered during final safety check
- untracked dynamic cross-study workflow files
  - all are qdesn-only validation orchestration
  - they point at absolute paths inside the active validation worktree:
    - `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/...`

This is a compatibility risk, but also a reason not to touch or move those files during the base sync.

## Discrepancy Categories To Resolve

1. Upstream-only `0.4.0` delta
   - fast-forward the base to `af2dbba`
2. Validation-branch shared/base delta
   - port package-core improvements that belong in the canonical base
3. Validation-only run artifacts
   - keep out of the canonical base
4. QDESN shared-base drift
   - do not merge into `0.4.0`
   - instead reconcile updated `0.4.0` back into qdesn later
5. Dirty qdesn local changes
   - preserve in place
   - do not force-clean or overwrite

## Conflict Hotspots

Highest-risk shared-core files for later qdesn reconciliation:

- `R/exal_static_mcmc.R`
- `R/exal_static_LDVB.R`
- `R/exdqlmMCMC.R`
- `R/utils.R`
- `R/exdqlmISVB.R`
- `R/exdqlmLDVB.R`
- `R/RcppExports.R`
- `src/sampling_utils.cpp`
- `src/RcppExports.cpp`
- `DESCRIPTION`

Why these are risky:

- validation branch ports focused `0.4.0`-compatible fixes and diagnostics
- qdesn branch versions are part of a much larger 0.5/0.6-era evolution
- file contents already differ across all three lines

Operational risks:

- live validation worktree is writing CSVs under `tools/merge_reports`
- qdesn worktree is dirty
- qdesn dynamic cross-study files depend on active validation outputs by absolute path

## Recommended Sync Order

1. Fast-forward `cransub/0.4.0` to `origin/cransub/0.4.0`.
2. Add this tracker and keep updating it as the execution trail.
3. Port the validation branch's package-core dynamic/C++ sampler changes onto `cransub/0.4.0`.
4. Port the static exAL / RHS / RHS_NS package-core changes that truly belong in shared base.
5. Keep validation-only docs, reports, `tools/merge_reports`, and run-state files out of `0.4.0`.
6. Keep package-core tests that validate shared code, but do not pull in tests that require validation scripts or live run state.
7. Commit the shared-base sync in small reviewable units.
8. Push updated `cransub/0.4.0`.
9. Defer downstream sync into the live validation branch until its active run is at a safe checkpoint.
10. Defer qdesn branch sync until done in a clean integration context; merge/rebase updated `0.4.0` into qdesn rather than trying to merge qdesn into `0.4.0`.

## Execution Results

Implemented on `cransub/0.4.0`:

- Fast-forwarded local `cransub/0.4.0` from `a95ee8c` to upstream `af2dbba`
- Added reconciliation tracker commit:
  - `cf9e9ba` `docs: add 0.4.0 reconciliation tracker`
- Added static shared-base backport commit:
  - `51a6261` `feat(static): backport rhs_ns static shared base`
- Added dynamic/C++ sampler backport commit:
  - `33f4f00` `feat(dynamic): backport cpp gig sampler and mcmc diagnostics`

Focused verification:

- Ran:
  - `Rscript -e "pkgload::load_all('.', quiet = TRUE); testthat::test_dir('tests/testthat', reporter = 'summary', filter = 'dqlm-vb-sim-smoke|static-beta-prior-rhs|static-fit-normalization|static-regression-regmod|vb-mcmc-convergence-controls')"`
- Result:
  - passed
  - one skip only:
    - `LDVB smoke on synthetic dynamic quantiles (exDQLM vs DQLM) stays finite and sensible`
    - skip reason: `skip_on_cran()`

Intentional residual differences from the validation branch after the backport:

- `R/exdqlmLDVB.R`
  - kept upstream `0.4.0` fixes that preserve `ts` object handling in reduced DQLM mode
  - kept upstream `exdqlmLDVB` class return so `exdqlmForecast()` compatibility stays intact
- `R/exdqlmMCMC.R`
  - kept upstream propagation of `verbose` into the VB warm-start controls
- `R/utils.R`
  - kept upstream `check_ts()` preservation of `ts` metadata
  - kept upstream reduced-DQLM `VB` wording and non-coercive handling

Interpretation:

- The canonical `0.4.0` base now contains the validation branch's shared package implementation changes plus the newer upstream April fixes from Raquel.
- Validation-only reports/tools were intentionally left out.
- QDESN-specific code and dirty local qdesn work were intentionally left out.

## Downstream Sync Notes

### Validation branch (`validation/rerun-after-0.4.0-sync`)

Do not touch until the active run is at a safe checkpoint.

When safe:

- merge updated `cransub/0.4.0` into `validation/rerun-after-0.4.0-sync`
- expect the important reconciliation to be concentrated in:
  - `R/exdqlmLDVB.R`
  - `R/exdqlmMCMC.R`
  - `R/utils.R`
- reason:
  - the validation branch already had most shared package changes
  - the new `0.4.0` base mainly adds the upstream-preserving fixes that validation had not yet absorbed

### QDESN branch (`feature/qdesn-mcmc-alternative`)

Do not sync in place while the worktree is dirty.

Recommended next step:

- first preserve or intentionally commit the current qdesn-only local changes
- then merge updated `cransub/0.4.0` into a clean qdesn integration context
- do not attempt the reverse direction

Expected qdesn conflict surface remains:

- the 15 shared package-core files listed above
- plus the broader generic package drift on the qdesn line:
  - `.Rbuildignore`
  - `.gitignore`
  - `NAMESPACE`
  - `NEWS.md`
  - `R/exdqlm-package.R`
  - `README.Rmd`
  - `README.md`
  - `R/transfn_exdqlmLDVB.R`
  - `R/regMod.R`
  - `man/transfn_exdqlmLDVB.Rd`
  - `src/exAL.cpp`

## Execution Checklist

- [x] Fast-forward local `cransub/0.4.0` to `origin/cransub/0.4.0`
- [x] Map current branch/worktree topology
- [x] Confirm live validation sessions and preserve them
- [x] Identify validation shared/base package files
- [x] Identify validation-only artifacts
- [x] Identify qdesn overlap/conflict surface
- [x] Identify qdesn-only dirty local files
- [x] Port validation package-core changes into `cransub/0.4.0`
- [x] Keep only package-core tests/docs needed for the shared base
- [ ] Push updated `cransub/0.4.0`
- [x] Record downstream sync instructions for validation branch
- [x] Record downstream sync instructions for qdesn branch
