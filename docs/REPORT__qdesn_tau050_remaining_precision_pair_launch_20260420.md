# QDESN Tau050 Remaining Precision-Pair Launch

Date: `2026-04-20`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## Launch Summary

The final remaining precision-pair relaunch is now live. It targets only the last two unresolved roots from the run-specific remaining-hard-fail wave:

1. `AL / laplace / tau 0.50 / fit_size 5000 / ridge`
2. `EXAL / laplace / tau 0.50 / fit_size 5000 / ridge`

Both phases were launched from clean commit:

- `0ba1df3`

## Live Phases

| Phase | Lane | Spec | Run tag | tmux |
|---|---|---|---|---|
| `remaining_precision_pair_al_v1` | `AL` | tau + theta + latent-`v` rescue + `qr_whiten` + `gram_ridge=1e-6` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_pair_al_v1-20260420-170808__git-0ba1df3` | `qdesn_dynx_0420_170808` |
| `remaining_precision_pair_exal_v2` | `EXAL` | tau + theta + latent-`v` rescue + `qr_whiten` + `gram_ridge=1e-4` + `gamma_sigma_gamma` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_pair_exal_v2-20260420-170835__git-0ba1df3` | `qdesn_dynx_0420_170836` |

## Operational Note

The first EXAL launch attempt at `17:08:08 EDT` failed before detach because the detached `tmux` session timestamp collided with the AL launch. No scientific compute was lost. The EXAL phase was immediately relaunched with a fresh timestamp and is now live under:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_pair_exal_v2-20260420-170835__git-0ba1df3`

## Initial Health Snapshot

Snapshot time: approximately `2026-04-20 17:08:48 EDT`

| Phase | Selected | Materialized | Running | Success | Fail | Started % |
|---|---:|---:|---:|---:|---:|---:|
| `remaining_precision_pair_al_v1` | 1 | 1 | 1 | 0 | 0 | 100.0% |
| `remaining_precision_pair_exal_v2` | 1 | 1 | 1 | 0 | 0 | 100.0% |
| Overall | 2 | 2 | 2 | 0 | 0 | 100.0% |

## Evidence Paths

- [AL launch metadata](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_v1_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_pair_al_v1-20260420-170808__git-0ba1df3/launch/launcher_session.json)
- [EXAL launch metadata](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_v2_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_pair_exal_v2-20260420-170835__git-0ba1df3/launch/launcher_session.json)

## Read

The final wave is fully isolated, fully reproducible, and now running exactly where the evidence says the remaining problem lives: the precision-Cholesky failure on the single `laplace / tau 0.50 / fit_size 5000 / ridge` root, under both `AL` and `EXAL`.
