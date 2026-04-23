# REPORT: QDESN Dynamic P90 Steepertrend RHS-NS Full Disk-Full Interruption And Continuation

Date: 2026-04-23
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

This report documents the abrupt interruption of the full `rhs_ns` relaunch,
records the resolved versus unresolved roots, and defines the clean recovery
path so the campaign can continue from where it stopped instead of restarting
blindly.

## 2) Interrupted Run

Interrupted run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-full-20260423-143900__git-20c5e35`

Initial launch report:

- [full launch preflight and start](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_dynamic_p90_steepertrend_rhsns_full_launch_preflight_and_start_20260423.md)

Interrupted campaign roots:

- [report root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation/qdesn-dynamic-p90-steepertrend-rhsns-full-20260423-143900__git-20c5e35/20260423-143922__git-20c5e35)
- [results root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation/qdesn-dynamic-p90-steepertrend-rhsns-full-20260423-143900__git-20c5e35/20260423-143922__git-20c5e35)

## 3) Interruption Context

User-observed environment event:

- disk filled during the live run
- additional disk space was freed afterward

Current disk state after cleanup:

- repository filesystem has substantial free space again

Observed launcher-level failure evidence:

- `3 nodes produced errors; first error: cannot open the connection`
- warning while handling the failure:
  - unable to open `pipeline_stdout.log`

Interpretation:

- the interruption is consistent with an abrupt storage / I/O exhaustion event
  during the live run
- the current evidence does **not** point to a clean model-level numerical
  breakdown in the already-completed fits

## 4) Reconciled Run State

Reconciliation artifact:

- [campaign reconciliation note](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation/qdesn-dynamic-p90-steepertrend-rhsns-full-20260423-143900__git-20c5e35/20260423-143922__git-20c5e35/campaign_metadata_reconcile.md)

Machine-generated root status table:

- [resume root status table](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation/qdesn-dynamic-p90-steepertrend-rhsns-full-20260423-143900__git-20c5e35/20260423-143922__git-20c5e35/tables/campaign_resume_root_status.csv)

Resolved counts:

| Status | Count |
|---|---:|
| `SUCCESS` | `3` |
| `FAIL` | `3` |
| `PENDING` | `12` |

Successful roots retained:

- `gausmix`, `tau = 0.05`, `fit_size = 500`
- `laplace`, `tau = 0.05`, `fit_size = 500`
- `normal`, `tau = 0.05`, `fit_size = 500`

Failed roots requiring rerun:

- `gausmix`, `tau = 0.05`, `fit_size = 5000`
- `laplace`, `tau = 0.05`, `fit_size = 5000`
- `normal`, `tau = 0.05`, `fit_size = 5000`

Never-started pending roots:

- all remaining `tau = 0.25` and `tau = 0.50` rows for:
  - `normal`
  - `laplace`
  - `gausmix`
  - both `500` and `5000`

## 5) Continuation Decision

The correct recovery path is:

1. preserve the interrupted run as an audit artifact
2. keep the `3` successful roots
3. relaunch only the unresolved `15` roots
4. keep the same normalized baseline defaults
5. start the continuation wave from a fresh committed-state run tag

This avoids:

- discarding successful completed work
- conflating the disk event with the model behavior
- rerunning already-good roots unnecessarily

## 6) Continuation Grid

Checked-in unresolved-root subset grid:

- [rhs_ns resume-after-diskfull grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_rhsns_resume_after_diskfull_grid.csv)

Continuation-grid scope:

| Metric | Value |
|---|---:|
| unresolved roots | `15` |
| failed roots to replay | `3` |
| pending roots to start | `12` |
| already-successful roots excluded | `3` |

## 7) Continuation Policy

The continuation wave must preserve the same baseline contract:

- `LDVB` for VB
- `slice` for MCMC
- `init_from_vb = TRUE`
- automatic `rhs_ns` tau warmup with `50L`
- light exAL `(sigma, gamma)` warmup
- `vb.max_iter = 300`
- `vb.min_iter_elbo = 80`
- `vb.n_samp_xi = 1000`
- `mcmc.n_burn = 5000`
- `mcmc.n_mcmc = 20000`
- `mcmc.thin = 1`
- `posterior_metric_draws = 20000`
- `vb_sampling_nd_draws = 20000`
- `vb_synthesis_n_samp = 20000`
- `washout = 300`

Still excluded:

- theta freeze rescue
- latent-state rescue
- latent `v` / latent `s` rescue
- precision rescue
- row-local overrides

## 8) Immediate Next Action

The correct next step is:

1. run a committed-state preflight on the `15`-root continuation grid
2. if preflight passes, launch the continuation wave
3. monitor the replayed `tau = 0.05`, `fit_size = 5000` roots first
4. only after continuation completes, reconcile the interrupted and resumed
   runs into one combined campaign view
