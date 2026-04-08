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

## 2) Current Failed-Root Queue

| Family | Tau | Fit Size | Prior | Root ID | Current Status | Current Error |
|---|---:|---:|---|---|---|---|
| `gausmix` | `0.05` | `5000` | `ridge` | `root__dynamic__dlm_constV_smallW__gausmix__tau_0p05__lasttt_5000__qdesn_ridge` | `FAIL` | `arguments imply differing number of rows: 1, 0` |
| `gausmix` | `0.25` | `5000` | `rhs_ns` | `root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_rhs_ns` | `FAIL` | `arguments imply differing number of rows: 1, 0` |
| `gausmix` | `0.25` | `5000` | `ridge` | `root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_ridge` | `FAIL` | `arguments imply differing number of rows: 1, 0` |
| `gausmix` | `0.95` | `5000` | `ridge` | `root__dynamic__dlm_constV_smallW__gausmix__tau_0p95__lasttt_5000__qdesn_ridge` | `FAIL` | `arguments imply differing number of rows: 1, 0` |
| `laplace` | `0.05` | `5000` | `ridge` | `root__dynamic__dlm_constV_smallW__laplace__tau_0p05__lasttt_5000__qdesn_ridge` | `FAIL` | `arguments imply differing number of rows: 1, 0` |
| `laplace` | `0.25` | `5000` | `ridge` | `root__dynamic__dlm_constV_smallW__laplace__tau_0p25__lasttt_5000__qdesn_ridge` | `FAIL` | `arguments imply differing number of rows: 1, 0` |

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

## 4) Operational Use

Next execution step:

1. use this file as the frozen failed-root source list
2. run the failed-root-only relaunch once from the repaired code path
3. mark roots resolved only after the rerun produces `PASS` or `WARN`
4. reconcile repaired roots back into the authoritative effective-w300 state
