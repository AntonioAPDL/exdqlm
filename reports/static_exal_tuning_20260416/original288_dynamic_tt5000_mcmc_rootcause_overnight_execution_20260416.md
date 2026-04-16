# Dynamic TT5000 MCMC Root-Cause Overnight Execution

Date: 2026-04-16

## Objective

Run a small, representative, reproducible debug matrix in the package repo to
answer the remaining `TT5000` MCMC question efficiently:

- isolate `VB` init vs pure `MCMC` path
- isolate regularization sensitivity
- capture the first invalid state in durable debug dumps
- record whether each debug row is using a preserved `reference_fit` or a
  `synthetic_baseline`

## Current confirmed starting point

- the validation repair manifest currently drops reference-fit provenance for the
  TT5000 phase-1 rows
- representative debug reproduction confirms at least one current failing MCMC case
  is running with `baseline_mode = synthetic_baseline`
- the first clean reproduced failure is:
  - `dynamic::gausmix::0p05::5000::default::dqlm::mcmc`
  - variant: `no_vb_init_short`
  - failure: `dqlm_mcmc_pre_uts (iter=1) invalid state before chi update`
  - first-invalid-state dump shows `theta` and `reg1` already massively non-finite

## Artifacts

- plan:
  - `reports/static_exal_tuning_20260416/original288_dynamic_tt5000_mcmc_rootcause_overnight_plan_20260416.md`
- prepare:
  - `tools/merge_reports/LOCAL_original288_dynamic_tt5000_mcmc_rootcause_prepare_20260416.R`
- runner:
  - `tools/merge_reports/LOCAL_original288_dynamic_tt5000_mcmc_rootcause_run_case_20260416.R`
- summarize:
  - `tools/merge_reports/LOCAL_original288_dynamic_tt5000_mcmc_rootcause_summarize_20260416.R`
- launcher:
  - `tools/merge_reports/LOCAL_original288_dynamic_tt5000_mcmc_rootcause_launch_20260416.sh`

## Safety / isolation

- this lane runs from the **package repo**
- it does **not** modify the currently running validation rerun lane
- it uses a separate run root under:
  - `tools/merge_reports/full288_original288_dynamic_tt5000_mcmc_rootcause_20260416`
- it is intentionally serial / low-parallel to avoid interfering with the live
  validation repair pocket

## Intended overnight outcome

Tomorrow morning we want:

1. a per-variant success/failure table
2. exact first-invalid-state debug dumps for failing MCMC anchors
3. a clear decision on whether the next fix should target:
   - `VB` init
   - `MCMC` FFBS/state sampling
   - stronger dynamic regularization
