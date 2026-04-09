# REPORT: QDESN Dynamic Effective-W300 Deep-DESN Setup And Launch

Date: 2026-04-08  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the setup, validation, and launch evidence for the new full effective-w300 rerun that uses
the shared 3-layer deep-DESN architecture across every in-scope case.

## 2) Checked-In Rerun Assets

Primary inputs:

- plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_deepdesn_rerun_20260408.md`
- defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_defaults.yaml`
- grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.csv`

Wrappers:

- materializer:
  - `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.R`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation.R`
- launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation.R`

## 3) DESN Spec

Shared DESN profile used for every case:

- profile id:
  - `deep_d3_n100x3_skip100_w300_m30`
- `D = 3`
- `n = [100, 100, 100]`
- `n_tilde = [100, 100]`
- `m = 30`
- `alpha = [0.2, 0.2, 0.2]`
- `rho = [0.95, 0.95, 0.95]`
- `act_f = [tanh, tanh, tanh]`
- `act_k = [identity, identity, identity]`
- `pi_w = [0.1, 0.1, 0.1]`
- `pi_in = [1.0, 1.0, 1.0]`
- `washout = 300`

Preserved study contract:

- effective fit sizes:
  - `500`
  - `5000`
- source totals:
  - `813`
  - `5313`
- MCMC:
  - burn-in `1000`
  - kept iterations `2000`
- posterior metric draws:
  - `1000`

## 4) Setup Validation

Grid materialization:

- result:
  - pass
- written grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.csv`
- validated size:
  - `36` roots
  - `18` unique dataset cells

Full-batch preflight:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-deepdesn-preflight-20260408`
- result:
  - pass
- selected batch:
  - `full`
- selected size:
  - `36` roots
  - `144` fit rows

Live smoke snapshot before full launch:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-deepdesn-smoke-20260408`
- health snapshot time:
  - `2026-04-08 21:15:14 EDT`
- state:
  - `4/4` roots materialized
  - `4/4 RUNNING`
  - `0/4 FAIL`
- interpretation:
  - the new DESN spec cleared materialization and entered live fit execution without an early
    root-level crash

## 5) Launch

This section is updated after the committed-state full launch completes.
