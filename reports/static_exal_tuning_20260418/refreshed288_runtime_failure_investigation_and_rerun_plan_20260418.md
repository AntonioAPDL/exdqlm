# Refreshed288 Runtime-Failure Investigation And Rerun Plan

Snapshot time: `2026-04-18 18:13:01 EDT`

This note focuses only on the numerical/runtime-crash cohort from the active canonical run
`full288_refreshed288_paperaligned_20260417_canonical_v1`.

The goal is to keep numerical crashes separate from post-fit mixing failures, then define a
reproducible rerun lane with stronger warmup/init controls for the crash cohort only.

## Snapshot artifacts

Machine-readable artifacts for this snapshot:

- `tools/merge_reports/LOCAL_refreshed288_runtime_failure_manifest_20260418.csv`
- `tools/merge_reports/LOCAL_refreshed288_runtime_failure_watchlist_20260418.csv`
- `tools/merge_reports/LOCAL_refreshed288_runtime_failure_summary_20260418.csv`
- `tools/merge_reports/LOCAL_refreshed288_runtime_failure_rerun_contract_20260418.csv`
- generator: `tools/merge_reports/LOCAL_refreshed288_extract_runtime_failure_audit_20260418.R`

Important caveat:

- the canonical run is still active
- this snapshot captured `18` runtime failures and `3` active dynamic-MCMC watchlist rows
- rerun the audit script after the canonical run finishes before launching the numerical rerun

## Failure split

At this snapshot:

- runtime/numerical failures: `18`
- post-fit gate failures: `26`
- active watchlist rows: `3`

The split is clean:

- runtime failures are dynamic-only
- gate failures are static-MCMC-only

So the numerical rerun should be a dedicated dynamic crash lane, not a mixed “all FAIL rows”
lane.

## Runtime-crash pattern

The numerical cohort is concentrated in dynamic rows:

- `15` rows in `full_dynamic_mcmc`
- `2` rows in `smoke_dynamic_mcmc`
- `1` row in `full_dynamic_vb`

Runtime mode split:

- `8` `invalid_pre_chi`
- `8` `nonfinite_chi`
- `2` `ldvb_q_t1_na`

Structural pattern:

- almost all runtime crashes are `dynamic_mcmc`
- almost all dynamic-MCMC runtime crashes are `TT5000`
- DQLM rows fail as `invalid state before chi update`
- exDQLM rows fail as `chi has ... non-finite values`
- the two `ldvb_q_t1 is NA` rows are one direct dynamic VB row and one dynamic MCMC row whose
  saved VB init is missing

Family / size pattern:

- `gausmix`: failures at `0p05/0p25/0p50`, mainly `TT5000`, plus the `TT500` `ldvb_q_t1` pair
- `laplace`: failures at `0p05/0p25/0p50`, all `TT5000`
- `normal`: failures observed so far at `0p05/0p50`, all `TT5000`
- active watchlist rows still in flight: `60`, `62`, `64`

## Why slice tuning is probably secondary

Current dynamic MCMC settings come from
`tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R:347-377`:

- VB init max iter `300`
- VB init tol `0.03`
- VB init samples `1000`
- VB-init sigmagam VB warmup `10`
- sigmagam MCMC warmup `50`
- `mh_proposal = "slice"`
- `slice_width = 0.10`
- `slice_max_steps = Inf`

In `R/exdqlmMCMC.R:873-950`, the update order is:

1. derive `tau`, `a_tau`, `b_tau`, `c_tau`
2. sample `theta`
3. sample `Ut`
4. sample `st`
5. only then update `sigma/gamma`
6. only inside that later block does the gamma slice sampler run

That matters because the dominant DQLM crash is
`invalid state before chi update`, and the dominant exDQLM crash is
`chi has non-finite values`. Those signatures appear before the slice gamma step is the main
driver.

Conclusion:

- changing `slice_width` may still be worth a secondary sensitivity arm
- but it is not the primary lever for the current crash signatures

## VB-init evidence

The audit manifest includes saved VB-init diagnostics per failed row.

The strongest pattern is on exDQLM crashes:

- several exDQLM failed rows have saved VB-init fits with `iter = 300`, `converged = FALSE`
- their saved posterior objects are not fully finite
- representative rows:
  - `8`: non-finite theta/post-pred/sfe, gamma range roughly `1.88` to `15.66`
  - `72`: non-finite theta/post-pred/sfe, gamma range roughly `-1.00` to `1.05`

The DQLM crashes look different:

- saved VB-init fits are finite when present
- but several already have very large sigma ranges before MCMC starts
- representative rows:
  - `14`: sigma roughly `80.9` to `87.5`
  - `22`: sigma roughly `158.1` to `170.2`
  - `46`: sigma roughly `148.4` to `159.6`

Interpretation:

- exDQLM runtime crashes are strongly consistent with unstable or incomplete VB initialization
- DQLM runtime crashes also point to poor initial state quality, but more through large sigma
  scaling than through obviously non-finite VB outputs

## Primary rerun strategy

The primary rerun should be a dedicated runtime-crash lane with a fresh run tag and a fresh run
root.

Do not mix it with:

- the current canonical run root
- the static gate-fail rows
- the post-fit mixing repair lane

Primary rerun contract, encoded in
`tools/merge_reports/LOCAL_refreshed288_runtime_failure_rerun_contract_20260418.csv`:

### 1. Direct dynamic-VB runtime rerun

Applies to:

- row `11`

Proposed settings:

- `vb_max_iter = 800`
- `vb_min_iter = 80`
- `vb_tol = 0.01`
- `sigmagam_vb_warmup_iters = 50`
- `sigmagam_vb_min_postwarmup_updates = 5`
- `sigmagam_vb_postwarmup_damping = 0.5`
- `sigmagam_vb_postwarmup_damping_iters = 5`

Rationale:

- this row failed in the LDVB layer itself
- MCMC or slice changes are irrelevant here

### 2. Primary dynamic-MCMC runtime rerun

Applies to:

- DQLM runtime rows: `6,14,22,30,38,46,54,70`
- exDQLM runtime rows: `8,12,16,24,32,40,48,56,72`
- refresh these exact row lists after the canonical run finishes

Proposed settings:

- `vb_init_max_iter = 800`
- `vb_init_min_iter = 80`
- `vb_init_tol = 0.01`
- `vb_init_n_samp = 5000`
- `vb_init_sigmagam_warmup_iters = 50`
- `vb_init_sigmagam_min_postwarmup_updates = 5`
- `vb_init_sigmagam_postwarmup_damping = 0.5`
- `vb_init_sigmagam_postwarmup_damping_iters = 5`
- `sigmagam_mcmc_warmup_iters = 500`
- keep `slice_width = 0.10`
- keep `slice_max_steps = Inf`

Additional guard:

- require a saved VB-init fit before entering MCMC
- require finite VB-init theta/post-pred/sfe summaries before entering MCMC

Rationale:

- strengthen the initial state first
- make the larger warmup coherent across the rerun lane
- avoid changing the slice kernel and the init quality at the same time in the primary arm

## Secondary options

These should stay secondary and only be explored if the primary stronger-init rerun still crashes.

### Secondary arm A: exDQLM slice-width sensitivity

Applies only to exDQLM dynamic MCMC runtime failures.

Proposed change:

- keep the stronger VB-init and larger MCMC warmup
- reduce `slice_width` from `0.10` to `0.05`
- keep `slice_max_steps = Inf`

Why secondary:

- the dominant crash signatures appear before slice gamma is the main lever
- this is best treated as a sensitivity arm, not the first intervention

### Secondary arm B: stricter pre-MCMC init gate

If the stronger-init rerun still produces non-finite MCMC starts:

- reject VB-init objects with non-finite theta/post-pred/sfe summaries
- regenerate init under the stronger VB profile before allowing MCMC

Why reasonable:

- rows `8` and `72` already show that the saved init object itself can be the problem

## What not to do

- do not resume the numerical cohort inside the current canonical run root
- do not mix static gate failures into this rerun lane
- do not change slice width in the primary arm and then attribute improvement solely to “larger
  warmup”
- do not launch the crash rerun until the active canonical run has finished and the runtime-fail
  manifest has been refreshed

## Reproducibility requirements

Before launching the crash-focused rerun:

1. rerun `tools/merge_reports/LOCAL_refreshed288_extract_runtime_failure_audit_20260418.R`
2. freeze the refreshed runtime-failure manifest and watchlist for that final snapshot
3. copy the rerun contract CSV into the new rerun run root or reports folder
4. use a new run tag and a new variant tag
5. keep the numerical rerun outputs in a distinct run root

Suggested naming:

- run tag: `20260418_runtimefail_v1`
- variant tag: `0p50_ldvb_slice_runtimewarmup_v1`

## Recommended next step

The best next step is:

1. let the canonical run finish
2. refresh the audit snapshot
3. freeze the final runtime-failure manifest
4. launch a dedicated crash-focused rerun using the primary stronger-init / larger-warmup contract
5. only if exDQLM still crashes, open the smaller-slice secondary arm
