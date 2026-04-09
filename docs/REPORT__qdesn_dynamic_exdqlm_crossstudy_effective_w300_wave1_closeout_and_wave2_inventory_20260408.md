# REPORT: QDESN Dynamic Effective-W300 Wave 1 Closeout And Wave 2 Inventory

Date: 2026-04-08  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

Historical note:

- this report remains the correct Wave 1 closeout record
- the current branch-local state after the completed final residual wave and exact-root
  reconciliation is now:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_final_residual_closeout_and_zero_fail_reconciliation_20260408.md`

## 1) Purpose

Record the completed effective-w300 scientific fail-closure wave, promote the clearly improved
local winners into the working validation baseline, and define the exact residual scientific debt
that still needs one final targeted overnight wave.

This report supersedes the broader residual inventory in:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_fail_surface_and_repair_plan_20260408.md`

as the current branch-local source for:

- what improved,
- what still fails,
- what worked best,
- what did not help,
- and where the highest expected-value overnight compute remains.

## 2) Wave 1 Source And Outcome

Completed wave:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-fitfail-20260408-040402__git-8005f87`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-effectivew300-fitfail-20260408-040402__git-8005f87/summary/qdesn_dynamic_crossstudy_fit_fail_closure_results.md`
- stage execution table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-effectivew300-fitfail-20260408-040402__git-8005f87/tables/stage_execution_status.csv`
- local baseline map:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-effectivew300-fitfail-20260408-040402__git-8005f87/tables/local_baseline_map.csv`

Wave 1 completed:

- `6/6` stages
- `24/24` challenger profiles
- `80/80` planned root-campaigns
- `320/320` planned fit rows

Wave 1 stage-local promotions:

| Stage | Selected Local Baseline | Source Target FAIL Rows | Winner Target FAIL Rows | Read |
|---|---|---:|---:|---|
| `W1_ridge_lower_tail_short` | `N720_ridge_vb_guard192` | `6` | `0` | clean lower-tail short-horizon ridge VB repair |
| `W2_ridge_lower_tail_long` | `N740_ridge_vb_guard256` | `6` | `0` | strongest lower-tail long-horizon ridge VB repair |
| `W3_ridge_upper_tail_short` | `N750_ridge_tail_combo2200` | `7` | `0` | ridge upper-tail short pocket fully cleaned |
| `W4_ridge_upper_tail_long` | `N750_ridge_tail_combo2200` | `7` | `1` | strong but not complete ridge long upper-tail rescue |
| `W5_rhs_short_exal_drift` | `N810_rhs_short_drift2200` | `3` | `0` | short-horizon rhs exAL drift fully cleaned |
| `W6_rhs_long_exal_residual` | `N930_rhs_long_guard224_burnheavy2600` | `6` | `2` | strongest long-horizon rhs mixed exAL repair neighborhood |

## 3) Current Promoted Source State

The working validation baseline should now be treated as:

- repaired effective-w300 broad rerun baseline,
- plus the completed execution-failure relaunch overlays,
- plus the Wave 1 local baseline map above.

This is the source state that should feed the next residual-only overnight wave.

Verified promoted-state summary:

- fit rows:
  - `144`
- remaining fit FAIL rows:
  - `4`
- remaining fail-carrying roots:
  - `4`
- root execution FAILs:
  - `0`
- comparison-eligible-any:
  - `36/36`
- comparison-eligible-full:
  - `32/36`

Improvement versus the repaired effective-w300 comparison pack:

| Metric | Repaired Effective-W300 Pack | Promoted Wave 1 Source | Change |
|---|---:|---:|---:|
| Fit FAIL rows | `35` | `4` | **`-31` (`-88.6%`)** |
| Fail-carrying roots | `20` | `4` | **`-16` (`-80.0%`)** |
| Root execution FAILs | `0` | `0` | flat |
| Comparison-eligible-any roots | `34/36` | `36/36` | **`+2`** |
| Comparison-eligible-full roots | `16/36` | `32/36` | **`+16`** |

Important nuance:

- the Wave 1 summary table reports `35 -> 3` on the strictly targeted fail rows;
- after actually promoting the selected stage winners into one merged working baseline, the true
  residual is `4` FAIL rows on `4` roots;
- that difference comes from the `W6` winner leaving one extra non-target fail on the stage guard
  set.

## 4) Exact Remaining FAIL Inventory

The current residual scientific debt is now tightly localized to four long-horizon MCMC rows:

| Family | Tau | Fit Size | Prior | Inference | Model | Signoff Reason | Root ID |
|---|---:|---:|---|---|---|---|---|
| `laplace` | `0.95` | `5000` | `ridge` | `mcmc` | `exal` | `geweke_drift` | `root__dynamic__dlm_constV_smallW__laplace__tau_0p95__lasttt_5000__qdesn_ridge` |
| `gausmix` | `0.05` | `5000` | `rhs_ns` | `mcmc` | `exal` | `missing_chain_diagnostics` | `root__dynamic__dlm_constV_smallW__gausmix__tau_0p05__lasttt_5000__qdesn_rhs_ns` |
| `gausmix` | `0.25` | `5000` | `rhs_ns` | `mcmc` | `exal` | `missing_chain_diagnostics` | `root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_rhs_ns` |
| `laplace` | `0.95` | `5000` | `rhs_ns` | `mcmc` | `al` | `geweke_drift` | `root__dynamic__dlm_constV_smallW__laplace__tau_0p95__lasttt_5000__qdesn_rhs_ns` |

Current residual pattern:

- all remaining FAIL rows are:
  - `fit_size = 5000`
  - `mcmc`
- no `vb` FAIL rows remain
- no short-horizon FAIL rows remain
- no root execution FAILs remain

## 5) What Improved

### A) The broad fail surface collapsed

Wave 1 removed the high-volume ridge VB debt and the short-horizon rhs exAL debt almost completely.
The study is no longer a broad surface-repair problem.

### B) The current source is cleaner and more comparable

The promoted source now has:

- `36/36` roots comparison-eligible-any
- `32/36` roots comparison-eligible-full

That is a major improvement over the repaired broad pack and means the next wave can focus on
scientific signoff closure rather than missing comparison coverage.

### C) Residual debt is now mechanism-specific

What remains is not a generic “the model is weak” story. It is now two very specific MCMC
residuals:

1. ridge long upper-tail `mcmc_exal` drift
2. rhs_ns long-horizon mixed MCMC residuals:
   - two `mcmc_exal` missing-diagnostics rows
   - one `mcmc_al` Geweke-drift row

## 6) Which Ideas Worked Best

### A) Promote only clear local winners

Wave 1 worked because it did not try to force one global rescue. It preserved the repaired
effective-w300 broad baseline and promoted only stage-local improvements that clearly reduced the
active fail mechanism.

### B) Ridge VB guard ladders were high-value

For the dominant ridge fail bands, stronger VB guard settings were the right tool. Once those bands
were repaired, the residual ridge problem ceased to be VB-wide and narrowed to one `mcmc_exal`
upper-tail row.

### C) rhs-only local tuning was the right way to handle the long exAL band

The rhs long residual pocket clearly responded to combined rhs-only tuning. The current best local
baseline there is `N930_rhs_long_guard224_burnheavy2600`.

### D) Keeping execution repair separate from scientific retuning was still correct

The repaired execution relaunch closed the implementation failures; Wave 1 then addressed the
scientific fail surface on top of that repaired baseline. That separation kept provenance clean.

## 7) Which Ideas Did Not Help

### A) Re-running already solved stages would now be low value

The following stage neighborhoods should now be treated as closed unless later evidence disproves
them:

- `W1_ridge_lower_tail_short`
- `W2_ridge_lower_tail_long`
- `W3_ridge_upper_tail_short`
- `W5_rhs_short_exal_drift`

### B) Weak W6 neighborhoods should not be repeated

From the completed W6 stage:

- `N920_rhs_long_guard192_narrow2400` was clearly weak and should not be rerun
- `N940_rhs_long_guard224_diag2600` rotated the fail surface without clearly improving it

### C) Pure ridge VB reruns are no longer the right tool for the remaining ridge debt

The only remaining ridge row is now `mcmc_exal` drift. Re-running pure VB-only ridge profiles would
spend compute on a mechanism that the current promoted baseline has already mostly solved.

## 8) Highest-Expected-Value Directions

### A) Ridge Long Upper-Tail MCMC Finalization

Why:

- only one ridge row remains,
- it sits on the `W4` guard set,
- and the current best local baseline is already `N750`.

Best next move:

- do not reopen weak ridge VB-only ladders;
- stay in the `N750` neighborhood and vary only the ridge MCMC depth / softness around the
  surviving `laplace tau=0.95` drift row.

### B) RHS Long-Horizon MCMC Finalization

Why:

- the residual rhs debt is now only three MCMC rows on the `W6` long-horizon guard set;
- `N930` is already the best working local baseline there;
- the remaining rows split into:
  - two `mcmc_exal` missing-diagnostics rows,
  - one `mcmc_al` Geweke-drift row.

Best next move:

- preserve the current rhs VB guard unless there is a clear reason to strengthen it;
- search only around the `N930` neighborhood with:
  - deeper chains,
  - slightly narrower transformed-block geometry,
  - slightly longer tau-freeze warmup,
  - one stronger VB guard hedge only as a controlled sidecar.

## 9) Recommended Wave 2 Program

Recommended overnight scope:

| Stage | Roots In Scope | Target FAIL Rows | Current Working Local Baseline | Compute Stance |
|---|---:|---:|---|---|
| `R1_ridge_upper_tail_long_final` | `3` | `1` | `N750_ridge_tail_combo2200` | ridge combo profiles only |
| `R2_rhs_long_mcmc_residual_final` | `5` | `3` | `N930_rhs_long_guard224_burnheavy2600` | rhs long MCMC profiles only |

Program rules:

- no reopening of closed short-horizon bands
- no reruns of weak `N920`
- no broad global retuning
- no new execution-repair work
- only local profiles built around the current promoted stage winners

## 10) Recommendation

Promote the completed Wave 1 local baselines into the working validation source now, update the
trackers to treat the promoted source as current, and run one final residual-only overnight wave
that spends compute only on the four remaining long-horizon MCMC FAIL rows and their small guard
sets.

## 11) Prepare-Only Validation

Validated from prepare-only:

- preflight run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162510__git-537a3cb`
- preflight markdown:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162510__git-537a3cb/launch/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_preflight.md`

Preflight confirmed:

- source mode:
  - `prior_fitfail_wave`
- source run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-fitfail-20260408-040402__git-8005f87`
- source state:
  - `144` fit rows
  - `4` FAIL rows
  - `4` fail-carrying roots
  - `36` comparison-eligible-any roots
  - `32` comparison-eligible-full roots
- staged plan:
  - `R1` root count `3`, target FAIL rows `1`, challenger profiles `5`
  - `R2` root count `5`, target FAIL rows `3`, challenger profiles `5`

## 12) Live Wave 2 Launch

Launched from committed state:

- launch commit:
  - `5ed0d19`
- live run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162642__git-5ed0d19`
- tmux session:
  - `qdesn_dynxff_0408_162642`
- launcher session metadata:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162642__git-5ed0d19/launch/launcher_session.json`
- launcher log:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162642__git-5ed0d19/launch/launcher_stdout.log`

Healthcheck snapshot immediately after launch:

- runner state:
  - `RUNNING`
- current stage:
  - `R1_ridge_upper_tail_long_final`
- current profile:
  - `R810_ridge_combo192_soft2600`
- launcher session live:
  - `TRUE`
