# Q-DESN 500-Observation MCMC RHS Repair v1c Status-Agnostic Closeout

Status: completed closeout and prepared next targeted follow-up. No new
screening launch was started by this closeout.

## Evidence Bundle

- Promotion id: `qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_closeout_20260725`
- Promotion root:
  `validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_closeout_20260725`
- Source run tag:
  `qdesn-tt500-mcmc-rhsrepair-v1c-full-20260724-194917__git-79931ca`
- Campaign stamp: `20260724-195157__git-79931ca`
- Source registry hash:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Validation commit at materialization: `79931ca0eb2c15dfe8afdf35f15a7af3fe35344e`

## Requested Policy

This closeout implements the requested relaxed diagnostic policy:

- Signoff status is retained as metadata.
- Signoff status is not used as a hard exclusion for metric-promotion evidence.
- The registered objective is still the primary current-best selector:
  `fit_qtrue_rmse + forecast_qtrue_rmse_H1000 + forecast_check_loss_H1000`.
- A broader metric-promotion table also records rows that improve at least one
  registered metric even if the registered objective does not improve.

This means a row can be promoted as useful metric evidence even when its
diagnostic signoff is `FAIL`. Those rows should still be described as
diagnostic-risk rows if they are used downstream.

## Health Summary

| Quantity | Value |
|---|---:|
| v1c roots | 110 |
| successful roots | 110 |
| PASS rows | 0 |
| WARN rows | 57 |
| FAIL rows | 53 |
| same-variant cells checked | 10 |
| metric promotions | 5 |
| objective promotions | 3 |
| all-primary promotions | 0 |
| new same-variant winners from v1c | 3 |
| new global cell winners from v1c | 0 |
| retained heavy/binary artifacts | 0 |

## Status-Agnostic Metric Promotions

| Family | Tau | Model | v1c candidate | Signoff | Class | Objective delta | Fit RMSE delta | Forecast MAE delta | Forecast check delta |
|---|---:|---|---|---|---|---:|---:|---:|---:|
| gausmix | 0.05 | Q-DESN exAL RHS | `mcrv1c_gm005x_a_current_anchor` | FAIL | objective improved | -0.107 | +0.017 | -0.069 | -0.002 |
| gausmix | 0.25 | Q-DESN exAL RHS | `mcrv1c_gm025x_a_current_anchor` | FAIL | metric-only improved | +0.020 | +0.057 | -0.059 | -0.008 |
| laplace | 0.50 | Q-DESN AL RHS | `mcrv1c_lp050a_b_d1_mem12_tau1e4_confirm` | WARN | objective improved | -0.228 | +0.452 | -0.679 | -0.122 |
| laplace | 0.50 | Q-DESN exAL RHS | `mcrv1c_lp050x_b_d1_mem12_tau1e4_confirm` | WARN | objective improved | -0.793 | +0.423 | -1.143 | -0.189 |
| normal | 0.50 | Q-DESN AL RHS | `mcrv1c_nm050a_a_current_anchor` | WARN | metric-only improved | +0.188 | +0.492 | -0.367 | -0.062 |

Interpretation:

- The useful v1c signal is mostly forecast-side improvement.
- None of the v1c rows improved all primary metrics at once.
- Fit RMSE usually worsened for promoted metric rows, so a future run should not
  blindly expand capacity. The tradeoff is forecast gain versus fit degradation.
- The status-agnostic same-variant objective winners from v1c are:
  gausmix 0.05 exAL, laplace 0.50 AL, and laplace 0.50 exAL.
- No v1c row becomes a new global family/tau winner against the full
  DQLM/exDQLM/Q-DESN candidate inventory.

## Resulting Status-Agnostic Table Diagnosis

The resulting global family/tau winners remain the previous rows, not v1c rows.
This is important: v1c improves selected Q-DESN model-variant rows, but it does
not yet change the global winner table.

The largest remaining gaps are mostly forecast-MAE gaps. The follow-up plan is
therefore not another broad high-capacity sweep. The next screen should be
cell-specific:

- Use multiseed or longer-chain confirmation first when the metric winner has
  signoff `FAIL`.
- Use forecast-MAE-oriented memory/rho variations when the blocker is forecast
  rather than fit.
- Use compact fit-RMSE-oriented variants only for cells where fit remains the
  dominant blocker.
- Keep each family/tau/model variant separate; do not force one shared DESN
  specification.

Prepared follow-up table:

`validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_closeout_20260725/qdesn_tt500_mcmc_rhsrepair_v1c_targeted_followup_plan_20260725.csv`

The prepared plan has 15 follow-up rows:

- 8 forecast-MAE-oriented rows,
- 4 MCMC mixing-confirmation rows,
- 3 fit-RMSE-oriented compact RHS rows.

All are marked `not_launched_prepared_only`.

## Reproducibility Checks

Commands run:

```bash
Rscript validation/fitforecast_v2/scripts/materialize_qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_closeout.R
Rscript -e "testthat::test_file('validation/fitforecast_v2/tests/testthat/test-qdesn-mcmc-rhsrepair-v1c-status-agnostic-closeout.R', reporter='summary')"
Rscript -e "testthat::test_file('validation/fitforecast_v2/tests/testthat/test-qdesn-mcmc-rhsrepair-v1c-materialization.R', reporter='summary')"
Rscript -e "pkgload::load_all('.', quiet=TRUE); cat('load_all ok\n')"
```

All commands passed after regenerating the tolerance-aware status-agnostic
selection.

## Next Decision

If the goal is to update a model-variant table, use the metric-promotion and
same-variant winner files from this bundle, with the diagnostic status disclosed.

If the goal is to change the global comparison table, v1c is not enough yet:
the next step should be the prepared targeted follow-up, starting with the
`FAIL` metric winners and the largest forecast-MAE gaps.
