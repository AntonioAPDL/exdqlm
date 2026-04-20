# QDESN Tau050 Run-Specific Remaining-Fail Postmortem

Date: `2026-04-20`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## Outcome

The run-specific remaining-hard-fail relaunch finished with a strong recovery result:

| Surface | Success | Fail | Success rate |
|---|---:|---:|---:|
| AL latent-`v` cluster | 6 | 1 | 85.7% |
| EXAL latent-`v` cluster | 5 | 0 | 100.0% |
| EXAL ridge-precision `v1` cluster | 2 | 1 | 66.7% |
| Overall | 13 | 2 | 86.7% |

The remaining unresolved surface is now only **2 fits**, and both correspond to the **same root**:

- `root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge`
- unresolved under `AL`
- unresolved under `EXAL`

## Main Diagnostic Finding

The last two failures are **not latent-`v` crashes**. They are both **precision-matrix Cholesky failures** on the same `laplace / tau=0.50 / fit_size=5000 / ridge` root.

### AL failure

Path:

- [AL failure log](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_al_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_hard_fail_latent_v_al-20260420-030610__git-dbafa6a/20260420-030618__git-dbafa6a/roots/root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge/fits/mcmc_al/logs/pipeline_stdout.log)

Observed failure:

- burn reached at least iteration `200`
- then:
  - `Error in chol.default(Prec + 1e-10 * diag(nrow(Prec)))`
  - `the leading minor of order 554 is not positive`

Interpretation:

- this AL fit was still using the run-specific latent-`v` rescue lane without explicit precision conditioning
- it did **not** fail in the latent-`v` GIG path
- it failed after entering a numerically unstable beta-precision regime

### EXAL failure

Path:

- [EXAL failure log](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v1_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_hard_fail_exal_ridge_precision_v1-20260420-030633__git-dbafa6a/20260420-030642__git-dbafa6a/roots/root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge/fits/mcmc_exal/logs/pipeline_stdout.log)

Observed failure:

- precision-conditioned EXAL `v1` still failed almost immediately
- then:
  - `Error in chol.default(Prec + 1e-10 * diag(nrow(Prec)))`
  - `the leading minor of order 40 is not positive`

Interpretation:

- `qr_whiten + gram_ridge=1e-6 + sigma_then_gamma` was not strong enough for this root
- the failure moved earlier and remained inside the precision path
- the right next move is a **stronger EXAL precision spec**, not another latent-state warmup pass

## Why This Is A Clean Pattern

The nearby controls now separate the problem clearly:

### AL controls

The AL run-specific relaunch recovered:

- `gausmix / tau=0.25 / rhs_ns`
- `gausmix / tau=0.25 / ridge`
- `gausmix / tau=0.50 / rhs_ns`
- `laplace / tau=0.25 / rhs_ns`
- `laplace / tau=0.50 / rhs_ns`
- `normal / tau=0.50 / rhs_ns`

So the remaining AL failure is **not** “all laplace” and **not** “all tau=0.50”. It is the **ridge** version of the hardest laplace long-window root.

### EXAL controls

The EXAL precision `v1` lane recovered:

- `gausmix / tau=0.25 / ridge`
- `normal / tau=0.05 / ridge`

So the remaining EXAL ridge failure is **not** a generic ridge-conditioning failure. It is the specific `laplace / tau=0.50 / fit_size=5000 / ridge` root.

## Decision

The remaining surface should now be treated as an **exact 2-fit precision pair**, not as a broader cluster:

1. `AL / laplace / tau 0.50 / 5000 / ridge`
2. `EXAL / laplace / tau 0.50 / 5000 / ridge`

The next relaunch should stay root-specific and promote:

- **AL** to a new mild precision-conditioned retry
- **EXAL** to the stronger precision `v2` fallback that was already prepared conceptually

## Prepared Next-Wave Package

The exact next-wave package has been materialized and prepare-validated in:

- [pair map](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_map.csv)
- [AL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_grid.csv)
- [EXAL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_grid.csv)
- [AL defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_v1_defaults.yaml)
- [EXAL defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_v2_defaults.yaml)

The corresponding materializer is:

- [remaining precision-pair materializer](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_grids.R)

And the exact relaunch plan is captured in:

- [remaining precision-pair relaunch plan](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_tau050_remaining_precision_pair_relaunch_20260420.md)
