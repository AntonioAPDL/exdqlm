# REPORT: QDESN Dynamic Effective-W300 Failure Investigation

Date: 2026-04-08  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Source Campaign

Completed rerun:

- `qdesn-dynamic-exdqlm-crossstudy-full-20260407-233147__git-cdfd1a9`

Observed outcome:

- `36/36` roots completed execution
- `30/36 SUCCESS`
- `6/36 FAIL`
- fail pocket localized to the effective `5000` surface

## 2) Exact Failed Roots

- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p05__lasttt_5000__qdesn_ridge`
- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_rhs_ns`
- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_ridge`
- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p95__lasttt_5000__qdesn_ridge`
- `root__dynamic__dlm_constV_smallW__laplace__tau_0p05__lasttt_5000__qdesn_ridge`
- `root__dynamic__dlm_constV_smallW__laplace__tau_0p25__lasttt_5000__qdesn_ridge`

Uniform outer root symptom:

- `arguments imply differing number of rows: 1, 0`

## 3) What Actually Failed

Representative fit-level reproductions showed that the outer root error was not the primary cause.

Primary fit-level failure:

- `mcmc_al` crashed inside `exal_mcmc_fit()` during the latent-`v` GIG draw with:
  - `exal_mcmc_fit::latent_v returned 1 invalid draws ... value=NA`

Important clarification:

- the log label `fit_exAL_on_X_train(...)` is shared pipeline wording and is not itself evidence of
  wrong likelihood dispatch
- the saved `fit_request.json` files correctly identified the failing requests as:
  - `likelihood_family = "al"`

## 4) Confirmed Failure Mechanism

Inner mechanism:

- `src/sampling_utils.cpp` could return `NA` from the Devroye GIG sampler on numerically fragile
  proposals
- `R/utils.R` then hard-stopped on the first invalid draw
- `R/exal_mcmc_fit.R` used that path for the latent-`v` update

Outer aggregation mechanism:

- on the failed-fit path, `R/qdesn_static_exdqlm_crossstudy.R` wrote:
  - `health_summary.csv`
  - `signoff_summary.csv`
- but did not always write:
  - `fit_summary_row.csv`
- this made root/campaign aggregation brittle and produced the later row-mismatch symptom

## 5) Implemented Repair

Numerical repair:

- stabilized the C++ GIG sampler with safer `omega/alpha/out` calculations
- changed nonfinite proposal branches from immediate `NA` return to retrying the acceptance loop
- added retry batches in the R GIG wrappers for sporadic invalid draws

Aggregation repair:

- failed fits now always write `fit_summary_row.csv`
- failure-path metric objects now include the full degenerate structure expected by the fit summary
  writer

Runner repair:

- the dynamic validation runner now supports auditable subset-grid reruns via:
  - `--allow-grid-subset`

## 6) Validation Evidence

Regression tests:

- `tests/testthat/test-qdesn-dynamic-failure-repair.R`
- both targeted checks passed:
  - GIG retry repair
  - failed-fit summary-row writing

Exact failed-fit reproductions after the patch:

- previously failing `mcmc_al` request under `ridge`:
  - reran successfully
  - wrote `timing_summary.csv`
  - wrote `forecast_objects.rds`
- previously failing `mcmc_al` request under `rhs_ns`:
  - reran successfully
  - wrote `timing_summary.csv`
  - wrote `forecast_objects.rds`

## 7) Completion Status And Next Action

The failed-root-only rerun is now complete and the original execution-failure pocket is closed:

- relaunch run:
  - `qdesn-dynamic-exdqlm-crossstudy-failedrelaunch-20260408-012443__git-bcdb438`
- relaunch outcome:
  - `6/6 SUCCESS`
  - `24/24` fit summaries written
  - `0` repeated execution failures

The next action is therefore no longer another implementation repair wave.

The next branch-local step is the repaired effective-w300 comparison analysis:

- report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_outputs_20260408.md`
- queue closeout:
  - `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_effective_w300_relaunch_queue_20260408.md`
- relaunch driver retained for reproducibility:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_failed_root_relaunch.R`
