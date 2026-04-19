# Refreshed288 `vb_init_validation_fail` Investigation

Generated: `2026-04-18 23:00:00 EDT`

## Scope

This note investigates the new crash-only-rerun failure

- `vb_init_validation_fail: theta_nonfinite; post_pred_nonfinite; sfe_nonfinite`

observed in the refreshed288 runtime-failure rerun lane.

The goal is to determine whether this is:

1. a genuinely new failure created by the stronger warmup spec,
2. an over-strict validation gate, or
3. an earlier and more explicit detection of an already-broken VB initializer.

## Affected Rows

At the time of inspection, the rows showing `vb_init_validation_fail` were:

| rerun row_id | phase | family | tau | fit size | model | original canonical crash |
|---|---|---|---|---|---|---|
| `8` | `runtime_mcmc_pilot` | `gausmix` | `0.05` | `5000` | `exdqlm` | `nonfinite_chi` |
| `16` | `runtime_mcmc_full` | `gausmix` | `0.25` | `5000` | `exdqlm` | `nonfinite_chi` |

## Validation Gate

The explicit VB-init validation gate lives in:

- [LOCAL_refreshed288_run_row_20260416.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_run_row_20260416.R:139)

It checks the saved VB-init fit object for:

- finite `samp.theta`
- finite `samp.post.pred`
- finite `map.standard.forecast.errors`
- finite positive `samp.sigma`
- finite `samp.gamma` for `exdqlm`

The runtime-failure rerun currently enables all of those checks for `exdqlm` MCMC rows via:

- [LOCAL_refreshed288_helpers_20260416.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R:331)

## Main Findings

### 1. The gate is detecting a genuinely broken VB-init fit

For the failing rerun VB-init fits for rows `8` and `16`:

| object | row `8` | row `16` |
|---|---:|---:|
| `samp.theta` finite entries | `0 / 150,000,000` | `0 / 150,000,000` |
| `samp.post.pred` finite entries | `0 / 25,000,000` | `0 / 25,000,000` |
| `map.standard.forecast.errors` finite entries | `0 / 5,000` | `0 / 5,000` |
| `samp.sigma` finite entries | `5,000 / 5,000` | `5,000 / 5,000` |
| `samp.gamma` finite entries | `5,000 / 5,000` | `5,000 / 5,000` |

So this is not a false positive from a strict gate. The state-side VB-init object is fully non-finite.

### 2. This is not a new pathology introduced by the stronger rerun spec

The original canonical-run VB-init fits for source rows `8` and `16` were already broken in the same way:

| source canonical row | `samp.theta` finite | `samp.post.pred` finite | `sfe` finite | canonical convergence |
|---|---:|---:|---:|---|
| `8` | `0 / 30,000,000` | `0 / 5,000,000` | `0 / 5,000` | `max_iter` |
| `16` | `0 / 30,000,000` | `0 / 5,000,000` | `0 / 5,000` | `max_iter` |

The canonical run simply did not have an explicit VB-init validation gate, so MCMC continued and later failed as:

- `exdqlm_mcmc_uts ... chi has 5000 non-finite values`

The new rerun is catching the same upstream failure earlier.

### 3. The stronger rerun spec did not rescue the broken init

The runtime-failure rerun strengthened the exDQLM VB-init profile to:

- `max_iter = 800`
- `min_iter = 80`
- `tol = 0.01`
- `n.samp = 5000`
- `sigmagam` warmup `50`
- post-warmup damping `0.5` for `5` iterations
- `min_postwarmup_updates = 5`

See:

- [LOCAL_refreshed288_helpers_20260416.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R:349)

But the broken rows still end with:

- `converged = FALSE`
- `stop_reason = "max_iter"`
- `delta_state = NaN`
- `delta_elbo = NaN`
- `delta_sigma = 0`
- `delta_gamma = 0`

So the stronger warmup does not fix the underlying failure mode.

### 4. The failure is state-side, not sigma/gamma-side

For the broken VB-init fits:

- `gammasig.out` remains finite
- `theta.out$sC` remains finite
- `theta.out$sm` is entirely non-finite
- `theta.out$exps` and `theta.out$exps2` are entirely non-finite
- `map.standard.forecast.errors` are entirely non-finite

This means the covariance path is numerically regularized successfully, but the state-mean path is broken.

Relevant code:

- state update in [exdqlmLDVB.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmLDVB.R:378)
- output assembly in [exdqlmLDVB.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmLDVB.R:1304)

### 5. The latent `s_t` block collapses before the state path

For the canonical row-`8` VB-init fit:

| component | finite? |
|---|---|
| `sts.out$sts.sig2` | fully finite |
| `sts.out$sts.mu` | fully non-finite |
| `sts.out$E.sts` | fully non-finite |
| `sts.out$E.sts2` | fully non-finite |
| `vts.out$E.uts` | fully finite |
| `vts.out$E.inv.uts` | fully finite |

This is important because the LDVB update order is:

1. update `q(s_t)`
2. update `q(u_t)`
3. compute `ex.f` / `ex.q`
4. update `q(theta)`
5. update `q(gamma, sigma)`

See:

- [exdqlmLDVB.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmLDVB.R:897)

The `s_t` update is:

- [exdqlmLDVB.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmLDVB.R:305)

The core formula is:

- `s.mu = s.sig2 * (c.invb.absgam * (y - exps) * inv.uts - c.a.invb.absgam)`

If `exps` goes bad, `s.mu` and therefore `E.sts`/`E.sts2` go bad immediately. Once that happens, `ex.f` is contaminated and the state-mean path cannot recover.

### 6. This failure class differs from `ldvb_q_t1 is NA`

The direct VB failures on rows such as `11` and `12` are hard LDVB crashes:

- `ldvb_q_t1 is NA`

The `vb_init_validation_fail` rows are different:

- LDVB returns an object
- the run goes all the way to `max_iter`
- but the returned state-side object is unusable

So this is a soft state-collapse / invalid-return-object class, not the same as the explicit `ldvb_q_t1` hard stop.

## Comparison To A Successful exDQLM MCMC VB Init

A stable canonical exDQLM MCMC row at `TT500`:

- row `4`: `dynamic::gausmix::0p05::500::default::exdqlm::mcmc`

has a fully finite VB-init object:

| object | finite entries |
|---|---:|
| `samp.theta` | `3,000,000 / 3,000,000` |
| `samp.post.pred` | `500,000 / 500,000` |
| `map.standard.forecast.errors` | `500 / 500` |
| `samp.sigma` | `1,000 / 1,000` |
| `samp.gamma` | `1,000 / 1,000` |
| `sts.out$E.sts` | fully finite |
| `vts.out$E.uts` | fully finite |

So the new validation gate is not rejecting normal exDQLM behavior. It is identifying a real pathological subset.

## Interpretation

The best interpretation is:

1. `vb_init_validation_fail` is not a new bug introduced by the new gate.
2. It is an earlier and more explicit label for a pre-existing exDQLM VB-init collapse.
3. The collapse is concentrated in the state-side / latent-`s_t` path.
4. The current stronger warmup profile changes detection timing but does not solve the underlying collapse.

In other words:

- old path: broken VB init -> MCMC starts anyway -> later `nonfinite_chi`
- new path: broken VB init -> validation gate stops immediately as `vb_init_validation_fail`

## Practical Consequences

### What the new gate is buying us

The gate is still valuable because it:

- prevents MCMC from running on a known-invalid initializer
- distinguishes exDQLM state-collapse from later MCMC instability
- sharpens the rerun taxonomy

### What it is *not* telling us

It is not evidence that the new warmup profile fixed anything. So far it has only moved failure detection earlier for this subset.

## Most Likely Root-Cause Surface

The evidence points most strongly to:

- an exDQLM LDVB state/latent-`s_t` instability on certain `gausmix`, `TT5000`, `exdqlm` rows
- with `sigma/gamma` staying numerically stable while the state means collapse

The most likely implementation surfaces to inspect next are:

- `update_sts()` in [exdqlmLDVB.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmLDVB.R:305)
- the `ex.f` / `ex.q` construction in [exdqlmLDVB.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmLDVB.R:923)
- the state update `kf_step()` / `update_theta()` path in [exdqlmLDVB.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmLDVB.R:378)

## Recommended Next Step

The next fix should not be “relax the gate.” The gate is catching a real invalid init.

The next investigation should instead:

1. instrument `update_sts()` and `ex.f/ex.q` for the failing exDQLM TT5000 rows,
2. identify the first iteration where `sts.mu` becomes non-finite,
3. determine whether that first non-finite step is caused by:
   - non-finite `exps`,
   - extreme finite `exps`,
   - unstable `c.invb.absgam` / `c.a.invb.absgam`,
   - or a numerical issue inside the positive-truncated-normal moment calculation.

That is the real root-cause path behind the new `vb_init_validation_fail` label.

## Implementation Follow-Up

The exDQLM LDVB engine is now instrumented to expose this failure path directly in future fits.

Implemented surfaces:

- [R/exdqlmLDVB.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmLDVB.R)
- [test-vb-mcmc-convergence-controls.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tests/testthat/test-vb-mcmc-convergence-controls.R)

New diagnostics now available on future `exdqlmLDVB` fits:

- `fit$diagnostics$state_path$trace`
- `fit$diagnostics$state_path$first_nonfinite`
- `fit$diagnostics$state_path$summary`

Those fields now record, iteration by iteration:

- whether `sts.sig2`, `sts.mu`, `E.sts`, `E.sts2` are finite
- whether raw and guarded `ex.q` are finite
- whether `ex.f` is finite
- whether `theta.out$exps`, `theta.out$exps2`, `theta.out$sm`, `theta.out$sC`, and standardized forecast errors are finite

And they also record:

- the first iteration where each monitored component became non-finite
- the stage where that happened (`sts`, `driver_raw`, `driver_guarded`, or `theta`)
- which component failed first overall

So the next rerun no longer has to infer collapse only from the final broken fit object. It can now say exactly when the state path first became non-finite.
