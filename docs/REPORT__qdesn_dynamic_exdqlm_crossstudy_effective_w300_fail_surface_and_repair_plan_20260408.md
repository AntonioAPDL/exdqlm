# REPORT: QDESN Dynamic Effective-W300 Remaining Fail Surface And Repair Directions

Date: 2026-04-08  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Summarize the current post-repair effective-w300 validation state after:

- the broad posterior-draw rerun completed,
- the implementation / numerical execution-failure pocket was repaired,
- the `6` failed roots were rerun successfully, and
- the repaired source was reconciled into the authoritative effective-w300 comparison pack.

This report is the branch-local decision record for the next overnight scientific fail-closure wave.

## 2) Current Authoritative Source State

Authoritative repaired comparison pack:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/summary/qdesn_dynamic_main_comparison_analysis.md`
- fail inventory:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/tables/authoritative_fail_inventory.csv`
- 144-row case table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/tables/authoritative_fit_case_table_readable.csv`

Rolled state:

- fit rows:
  - `144`
- fit signoff:
  - `40 PASS`
  - `69 WARN`
  - `35 FAIL`
- root execution:
  - `36/36 SUCCESS`
  - `0/36` root-status FAILs
- root readiness:
  - `34/36` comparison-eligible-any
  - `16/36` comparison-eligible-full

Interpretation:

- execution-failure debt is closed,
- remaining debt is purely scientific signoff debt,
- the repaired effective-w300 source is stable enough to support a targeted scientific closure wave.

## 3) What Improved

Operationally:

- the original broad effective-w300 rerun ended with `6/36` root execution failures;
- the failed-root relaunch recovered all `6/6` of those roots to `SUCCESS`;
- the repaired pack now has `144/144` fit rows available for analysis instead of `120/144`.

Scientifically:

- the comparison-analysis layer is now complete under the stronger effective-w300 / posterior-draw
  contract;
- the remaining scientific fail surface is sharply localized:
  - `35` fit FAIL rows,
  - `20` fail-carrying roots,
  - no broad execution instability elsewhere.

Methodologically:

- the new effective-w300 contract is working as intended:
  - effective post-washout sizes `500` and `5000`,
  - shared MCMC depth `1000/2000`,
  - posterior metric draw count `1000`,
  - train-path `q_true` and quantile-calibration metrics written consistently.

## 4) What Still Fails

Remaining scientific fail surface:

- `35` FAIL rows
- `20` fail-carrying roots

By primary mechanism:

| Mechanism bucket | Rows | Roots | Interpretation |
|---|---:|---:|---|
| `ridge / vb / al+exal` tail instability | `24` | `12` | dominant remaining debt; same root often fails for both `al` and `exal` under ridge VB |
| `rhs_ns / mcmc / exal` drift | `6` | `6` | localized MCMC geometry/depth issue |
| `rhs_ns / vb / exal` rhs tail instability | `3` | `3` | localized VB stabilization issue on long-horizon mid-quantile roots |
| `ridge / mcmc / exal` drift | `2` | `2` | confined to ridge upper-tail `laplace` roots and naturally coupled to the ridge upper-tail stages |

By signoff reason:

| Signoff reason | Rows |
|---|---:|
| `vb_converged_false; elbo_tail_unstable; core_parameter_tail_unstable` | `17` |
| `vb_converged_false; core_parameter_tail_unstable` | `7` |
| `half_chain_drift` | `5` |
| `geweke_drift` | `3` |
| `rhs_parameter_tail_unstable` | `3` |

By family / tau / fit size:

| Family | Tau | Fit Size | FAIL Rows | FAIL Roots |
|---|---:|---:|---:|---:|
| `laplace` | `0.95` | `5000` | `4` | `2` |
| `gausmix` | `0.05` | `5000` | `3` | `2` |
| `gausmix` | `0.95` | `500` | `3` | `2` |
| `normal` | `0.05` | `500` | `3` | `2` |
| `laplace` | `0.95` | `500` | `3` | `1` |
| `gausmix` | `0.05` | `500` | `2` | `1` |
| `gausmix` | `0.95` | `5000` | `2` | `1` |
| `laplace` | `0.05` | `500` | `2` | `1` |
| `laplace` | `0.05` | `5000` | `2` | `1` |
| `laplace` | `0.25` | `5000` | `2` | `1` |
| `normal` | `0.05` | `5000` | `2` | `1` |
| `normal` | `0.95` | `500` | `2` | `1` |
| `normal` | `0.95` | `5000` | `2` | `1` |
| `gausmix` | `0.25` | `5000` | `1` | `1` |
| `laplace` | `0.25` | `500` | `1` | `1` |
| `normal` | `0.25` | `5000` | `1` | `1` |

## 5) Which Ideas Worked Best

Most effective completed work:

1. **Repair execution bugs separately from scientific tuning.**
   - The repaired failed-root relaunch proved that the `6` original execution failures were not a
     tuning problem and should not have been mixed into scientific signoff retuning.
2. **Keep the broad effective-w300 baseline stable, then overlay only defensible local repairs.**
   - This preserved provenance and kept the repaired main-comparison pack reproducible.
3. **Use posterior-draw metrics and the stronger washout/effective-size contract as the new source
   truth.**
   - The comparison pack now measures the scientifically relevant contract rather than the earlier
     zero-fail legacy surface.
4. **Read the fail surface by mechanism, not just by family.**
   - The current fail inventory is far more cleanly explained by:
     - ridge VB tail instability,
     - rhs_ns exAL MCMC drift,
     - rhs_ns exAL VB tail instability,
     than by one generic family-wide story.

## 6) Which Ideas Did Not Help Or Are Low Value Now

Low-value directions from the current evidence:

1. **Another blind broad rerun.**
   - The fail surface is already localized to `20` roots; rerunning the full healthy surface would
     spend most compute on rows that are already `PASS` or `WARN`.
2. **A single generic rescue profile for every remaining fail.**
   - The fail inventory splits naturally into ridge-VB and rhs_ns-exAL mechanisms that want
     different interventions.
3. **Global MCMC retuning on `al` branches.**
   - The remaining fail rows are concentrated in `exal` plus ridge-VB; `mcmc_al` is not the active
     debt driver.
4. **Reopening the closed execution-failure repair loop.**
   - The execution bug was repaired and the `6/6` rerun confirmed it.

## 7) Highest-Expected-Value Directions

### A) Ridge VB Tail Stabilization

Why:

- `24/35` remaining FAIL rows sit here;
- both `al` and `exal` fail together on the same ridge roots;
- the reason strings are dominated by VB convergence/tail instability rather than geometry drift.

Best next move:

- run a stage-local ridge VB guard ladder:
  - longer ELBO minimum,
  - larger VB Monte Carlo budget,
  - stronger guard profiles for long horizons,
  - no unnecessary rhs retuning in these stages.

### B) Ridge Upper-Tail Combo Rescue

Why:

- the ridge upper-tail pocket also contains the only `ridge / mcmc / exal` drift rows.

Best next move:

- keep the ridge VB guard escalation,
- add a small number of ridge-only softer/deeper MCMC combo candidates for the upper-tail stages
  only.

### C) RHS_NS exAL Drift Rescue

Why:

- `rhs_ns / mcmc / exal` contributes `6` FAIL rows across `6` roots;
- reasons are classic chain drift diagnostics rather than broad breakdown.

Best next move:

- use rhs-only deeper/narrower MCMC schedules on the short-horizon drift stage,
- do not globally retune VB where it is already healthy.

### D) RHS_NS Long-Horizon Mixed exAL Rescue

Why:

- long-horizon rhs exAL fail rows combine:
  - `mcmc_exal` drift,
  - `vb_exal` rhs tail instability.

Best next move:

- use combined rhs-only profiles:
  - stronger rhs VB guard,
  - deeper/narrower rhs MCMC schedules,
  - leave ridge and healthy `al` branches at baseline.

## 8) Recommended Overnight Program

| Stage | Roots | Source FAIL Rows | Mechanism | Compute stance |
|---|---:|---:|---|---|
| `W1_ridge_lower_tail_short` | `3` | `6` | ridge VB lower-tail short | ridge VB only |
| `W2_ridge_lower_tail_long` | `3` | `6` | ridge VB lower-tail long | ridge VB only |
| `W3_ridge_upper_tail_short` | `3` | `7` | ridge VB + small ridge MCMC upper-tail short | ridge VB plus ridge MCMC combo |
| `W4_ridge_upper_tail_long` | `3` | `7` | ridge VB + small ridge MCMC upper-tail long | ridge VB plus ridge MCMC combo |
| `W5_rhs_short_exal_drift` | `3` | `3` | rhs short-horizon mcmc_exal drift | rhs MCMC only |
| `W6_rhs_long_exal_residual` | `5` | `6` | rhs long-horizon mixed vb_exal + mcmc_exal | rhs VB + rhs MCMC combo |

Program principles:

- no reruns of the already healthy broad surface,
- no generic all-model rescue profiles,
- no reopening of fixed execution failures,
- only stage-local changes tied to the observed signoff mechanism.

## 9) Recommendation

Proceed with a targeted **effective-w300 scientific fail-closure wave** that:

1. starts from the repaired broad effective-w300 source,
2. overlays the `6` repaired execution-failure roots automatically,
3. spends overnight compute only on the `20` fail-carrying roots,
4. uses stage-local ridge-VB or rhs-only profiles as appropriate,
5. promotes only clear local winners after the wave completes.

## 10) Prepare-Only Validation

Validated from prepare-only:

- preflight run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-fitfail-20260408-040208__git-75b9913`
- preflight markdown:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-effectivew300-fitfail-20260408-040208__git-75b9913/launch/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_preflight.md`

Verified source state:

- `144` fit rows
- `35` FAIL rows
- `20` fail-carrying roots
- `0` root execution FAILs
- `34` comparison-eligible-any roots
- `16` comparison-eligible-full roots

Verified stage sizes:

| Stage | Roots | Source FAIL Rows | Profiles |
|---|---:|---:|---:|
| `W1_ridge_lower_tail_short` | `3` | `6` | `4` |
| `W2_ridge_lower_tail_long` | `3` | `6` | `4` |
| `W3_ridge_upper_tail_short` | `3` | `7` | `4` |
| `W4_ridge_upper_tail_long` | `3` | `7` | `4` |
| `W5_rhs_short_exal_drift` | `3` | `3` | `4` |
| `W6_rhs_long_exal_residual` | `5` | `6` | `4` |

Planned overnight campaign size:

- stages:
  - `6`
- stage-profile evaluations:
  - `24`
- planned root-campaigns:
  - `80`

Interpretation:

- the repaired source overlay is wired correctly,
- the stage selectors hit the intended fail surface exactly,
- the overnight program is broad enough to be informative while still local to the remaining
  scientific debt.
