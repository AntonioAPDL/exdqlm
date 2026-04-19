# QDESN Tau050 Remaining-Failed MCMC V2 Postmortem

Date: 2026-04-18  
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Pushed commit at time of postmortem: `906525b`

## Scope

This note summarizes the completed `remaining_failed_mcmc_v2` rerun for the QDESN dynamic exDQLM cross-study validation on the `tau050` refreshed-main surface.

The v2 rerun targeted only the `18` fits that still failed after the first failed-only rerun. The v2 package kept the strengthened tau and sigma/gamma warmup baseline, then added direct MCMC `latent_v` warmup and sparse-update controls.

This note is intended to answer four questions:

1. How much did v2 recover?
2. Which pockets improved?
3. Which pockets still fail?
4. What does that imply for the next relaunch?

## Study Surface

The targeted v2 rerun remained on the same dynamic data surface:

- Scenario: `dlm_constV_smallW`
- Families: `gausmix`, `laplace`, `normal`
- Taus: `0.05`, `0.25`, `0.50`
- Fit sizes: mostly `5000`, with one `500`
- Priors: `ridge`, `rhs_ns`
- Likelihood lanes: `al`, `exal`
- Model stack: QDESN dynamic exDQLM MCMC

Key launcher and config surfaces:

- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml)
- [launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
- [healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)

## Runtime Cohorts

The v2 relaunch was split into four lanes:

- `remaining_failed_mcmc_al_v2_canary`
- `remaining_failed_mcmc_exal_v2_canary`
- `remaining_failed_mcmc_al_v2_residual`
- `remaining_failed_mcmc_exal_v2_residual`

Primary result roots live under:

- `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation/`

Primary implementation and launch record:

- [REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_implementation_and_launch_20260418.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_implementation_and_launch_20260418.md)

## Final Outcome

### Overall Result

| Metric | Count | Percent |
|---|---:|---:|
| Targeted fits | 18 | 100.0% |
| Successful reruns | 8 | 44.4% |
| Failed reruns | 10 | 55.6% |
| Running | 0 | 0.0% |
| Completion | 18 | 100.0% |

### By Lane

| Lane | Total | Success | Fail | Success rate |
|---|---:|---:|---:|---:|
| `al_v2_canary` | 2 | 2 | 0 | 100.0% |
| `exal_v2_canary` | 3 | 1 | 2 | 33.3% |
| `al_v2_residual` | 5 | 2 | 3 | 40.0% |
| `exal_v2_residual` | 8 | 3 | 5 | 37.5% |

### By Likelihood

| Likelihood | Success | Fail | Success rate |
|---|---:|---:|---:|
| `al` | 4 | 3 | 57.1% |
| `exal` | 4 | 7 | 36.4% |

### By Family

| Family | Success | Fail | Success rate |
|---|---:|---:|---:|
| `normal` | 4 | 1 | 80.0% |
| `gausmix` | 3 | 6 | 33.3% |
| `laplace` | 1 | 3 | 25.0% |

### By Tau

| Tau | Success | Fail | Success rate |
|---|---:|---:|---:|
| `0.05` | 1 | 1 | 50.0% |
| `0.25` | 3 | 3 | 50.0% |
| `0.50` | 4 | 6 | 40.0% |

### By Prior

| Prior | Success | Fail | Success rate |
|---|---:|---:|---:|
| `rhs_ns` | 5 | 5 | 50.0% |
| `ridge` | 3 | 5 | 37.5% |

### By Fit Size

| Effective fit size | Success | Fail | Success rate |
|---|---:|---:|---:|
| `500` | 1 | 0 | 100.0% |
| `5000` | 7 | 10 | 41.2% |

## What Improved

The v2 package did produce real recovery. It was not a no-op.

Positive signals:

- The rerun recovered `8 / 18` unresolved fits that had previously remained terminal failures.
- The cleanest pocket was `al` canary: `2 / 2` recovered.
- `normal` became the healthiest family: `4 / 5` recovered.
- The added MCMC `latent_v` warmup did help some runs survive the startup and thaw region that had previously been fragile.

The key implication is that the `latent_v` warmup direction was valid, but incomplete.

## What Did Not Improve Enough

The unresolved failures are still concentrated in a few repeat pockets:

- `gausmix` remains the hardest family.
- `tau = 0.50` remains the hardest tau level.
- `exal` remains weaker than `al`.
- Prior type is no longer the primary separator.

Most importantly, the unresolved failures are not purely startup-only anymore.

From direct log inspection, the remaining failure timings include:

- late burn failures around `3000` to `4500`
- thaw-adjacent failures around `5500`
- late keep-phase failures around `11000`, `13500`, `16000`, and `19000`

This means a broader or longer startup warmup alone is unlikely to solve the whole remaining surface.

## Failure Family

Representative failed logs still show the same core runtime signature:

- `Error: exal_mcmc_fit::latent_v returned 1 invalid draws after 12 retry batches`

Representative locations:

- [gausmix tau 0.50 rhs_ns exal fail log](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_exal_v2_canary-20260418-184639__git-c6f8955/20260418-184647__git-c6f8955/roots/root__dynamic__dlm_constV_smallW__gausmix__tau_0p50__lasttt_5000__qdesn_rhs_ns/fits/mcmc_exal/logs/pipeline_stdout.log)
- [laplace tau 0.50 ridge al fail log](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_al_v2_residual-20260418-184940__git-c6f8955/20260418-184948__git-c6f8955/roots/root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge/fits/mcmc_al/logs/pipeline_stdout.log)

Representative recovered logs:

- [gausmix tau 0.25 rhs_ns al success log](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_al_v2_canary-20260418-184633__git-c6f8955/20260418-184641__git-c6f8955/roots/root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_rhs_ns/fits/mcmc_al/logs/pipeline_stdout.log)
- [normal tau 0.05 ridge exal success log](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_exal_v2_canary-20260418-184639__git-c6f8955/20260418-184647__git-c6f8955/roots/root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_ridge/fits/mcmc_exal/logs/pipeline_stdout.log)

## Diagnostic Quality Of Recovered Fits

Recovery should not be interpreted as universally clean inference.

Example recovered fit summary:

- [gausmix tau 0.25 rhs_ns al fit summary](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_al_v2_canary-20260418-184633__git-c6f8955/20260418-184641__git-c6f8955/roots/root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_rhs_ns/fits/mcmc_al/fit_summary_row.csv)

That recovered fit is terminally successful, but still has:

- `signoff_grade = FAIL`
- `signoff_reason = high_autocorrelation; geweke_drift`

So the current state is:

- some cases are now numerically survivable
- not all of those cases are scientifically clean yet

That argues for a targeted v3 rerun rather than another broad campaign.

## Export Gap

One important reproducibility gap remains:

- the v2 health-summary schema includes `mcmc_failure_*` fields
- successful fits serialize the `latent_v` warmup fields cleanly
- failed fits still collapse to sparse terminal summaries with `missing_chain_diagnostics`

Representative failed summaries:

- [failed exal fit summary row](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_exal_v2_canary-20260418-184639__git-c6f8955/20260418-184647__git-c6f8955/roots/root__dynamic__dlm_constV_smallW__gausmix__tau_0p50__lasttt_5000__qdesn_rhs_ns/fits/mcmc_exal/fit_summary_row.csv)
- [failed exal health summary](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_exal_v2_canary-20260418-184639__git-c6f8955/20260418-184647__git-c6f8955/roots/root__dynamic__dlm_constV_smallW__gausmix__tau_0p50__lasttt_5000__qdesn_rhs_ns/fits/mcmc_exal/health_summary.csv)

This should be fixed before the next rerun, because the next relaunch needs failure payloads to survive into result summaries, not only logs.

## Main Interpretation

The v2 relaunch supports five conclusions:

1. Direct MCMC `latent_v` warmup was directionally correct.
2. The remaining failures are still the same latent-`v` invalid-draw family.
3. The unresolved failures are no longer just startup failures.
4. The next relaunch should not be another warmup-only replay over the same full unresolved surface.
5. The next relaunch should target the unresolved `10` only, split by failure pocket, and combine warmup retention with a more local kernel-side or failure-handling change.

## Immediate Recommendation

Use this postmortem as the evidence base for a `v3` relaunch with:

- exact unresolved-10 manifests
- preserved v2 warmup baseline
- failure-export fix first
- targeted canary on hardest pockets first
- secondary kernel-side arms only where justified

The corresponding next-step plan is captured in:

- [PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_relaunch_20260418.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_relaunch_20260418.md)
