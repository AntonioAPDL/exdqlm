# TRACK: QDESN Dynamic exdqlm Effective-W300 Relaunch Queue

Date: 2026-04-08  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Maintain the authoritative relaunch queue for the effective-w300 posterior-draw rerun after the
first full batch completed with a localized failure pocket.

Queue rule:

- every root that reaches `root_status = FAIL` is added here
- a queued root stays in the relaunch list until a later targeted rerun brings it back as:
  - `PASS`, or
  - `WARN`
- do not remove historical failures silently; mark them resolved only after a documented successful
  rerun

Source full rerun:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260407-233147__git-cdfd1a9`
- tmux session:
  - `qdesn_dynx_0407_233147`

Final source snapshot used for this queue:

- `2026-04-08 00:47:53 EDT`

Root-status counts at this final source snapshot:

- `30` `SUCCESS`
- `6` `FAIL`

## 2) Historical Failed-Root Queue

| Family | Tau | Fit Size | Prior | Root ID | Original Status | Original Error | Relaunch Outcome | Current Queue Status |
|---|---:|---:|---|---|---|---|---|---|
| `gausmix` | `0.05` | `5000` | `ridge` | `root__dynamic__dlm_constV_smallW__gausmix__tau_0p05__lasttt_5000__qdesn_ridge` | `FAIL` | `arguments imply differing number of rows: 1, 0` | `SUCCESS` | `RESOLVED_EXECUTION` |
| `gausmix` | `0.25` | `5000` | `rhs_ns` | `root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_rhs_ns` | `FAIL` | `arguments imply differing number of rows: 1, 0` | `SUCCESS` | `RESOLVED_EXECUTION` |
| `gausmix` | `0.25` | `5000` | `ridge` | `root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_ridge` | `FAIL` | `arguments imply differing number of rows: 1, 0` | `SUCCESS` | `RESOLVED_EXECUTION` |
| `gausmix` | `0.95` | `5000` | `ridge` | `root__dynamic__dlm_constV_smallW__gausmix__tau_0p95__lasttt_5000__qdesn_ridge` | `FAIL` | `arguments imply differing number of rows: 1, 0` | `SUCCESS` | `RESOLVED_EXECUTION` |
| `laplace` | `0.05` | `5000` | `ridge` | `root__dynamic__dlm_constV_smallW__laplace__tau_0p05__lasttt_5000__qdesn_ridge` | `FAIL` | `arguments imply differing number of rows: 1, 0` | `SUCCESS` | `RESOLVED_EXECUTION` |
| `laplace` | `0.25` | `5000` | `ridge` | `root__dynamic__dlm_constV_smallW__laplace__tau_0p25__lasttt_5000__qdesn_ridge` | `FAIL` | `arguments imply differing number of rows: 1, 0` | `SUCCESS` | `RESOLVED_EXECUTION` |

## 3) Current Pattern

Current fail pocket characteristics:

- all current failures are on the long-horizon effective `5000` surface
- `gausmix` is the most affected family so far
- `ridge` is the most affected prior so far
- there is one current `rhs_ns` failure in the same horizon band
- the current root-level failure message is uniform across all queued roots:
  - `arguments imply differing number of rows: 1, 0`

Confirmed root cause:

- inner fit failure:
  - `mcmc_al` latent-`v` GIG draw returning `NA` in `exal_mcmc_fit()`
- outer aggregation symptom:
  - failed-fit summary rows not always written on disk

Current repair state:

- numerical repair implemented
- failed-fit artifact repair implemented
- exact failing fit requests reproduced successfully after the patch
- subset-grid failed-root relaunch path implemented

Completed relaunch execution state:

- repaired commit:
  - `bcdb438`
- relaunch run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-failedrelaunch-20260408-012443__git-bcdb438`
- relaunch scope:
  - `6` failed roots only
- relaunch outcome:
  - `6/6 SUCCESS`
  - `24/24` fit summaries written
  - `0` repeated `root_error.txt` files
- relaunch summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_validation/qdesn-dynamic-exdqlm-crossstudy-failedrelaunch-20260408-012443__git-bcdb438/launch/failed_root_relaunch_summary.md`
- repaired comparison pack:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/summary/qdesn_dynamic_main_comparison_analysis.md`

## 4) Operational Use

Current queue state:

1. treat this file as the frozen historical inventory of the original `6` execution failures
2. treat the relaunch as **execution-resolved**
3. use the repaired effective-w300 comparison pack as the current authoritative analysis source
4. if future scientific follow-up is needed, start from the repaired pack rather than reopening this
   execution queue
