# REPORT: QDESN Dynamic P90 Steepertrend RHS-NS Full Launch Preflight And Start

Date: 2026-04-23
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

This report records the clean transition from the completed `rhs_ns` smoke gate
to the committed-state full `rhs_ns` launch on the promoted `p90`
steeper-trend dynamic surface.

The goal of this step is to make sure the second-prior expansion is:

- documented;
- preflighted from committed state;
- launched from a frozen clean commit; and
- easy to monitor and reproduce afterward

## 2) Frozen Commit And Decision Context

Committed-state decision commit:

- `20c5e35`

This commit froze:

- the completed `rhs_ns` smoke result;
- the interpretation that the smoke gate was free of hard numerical/runtime
  failure; and
- the decision to proceed to the full `rhs_ns` `72`-fit expansion without
  promoting rescue overlays into the baseline

Supporting decision report:

- [rhs_ns smoke completion and full-launch decision](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_dynamic_p90_steepertrend_rhsns_smoke_completion_and_full_launch_decision_20260423.md)

## 3) Preflight Checks Run

Focused config test passed:

```bash
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-qdesn-dynamic-p90-steepertrend-config.R", reporter = testthat::StopReporter$new())'
```

Committed-state `rhsns_full` preflight passed:

```bash
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R \
  --phase rhsns_full \
  --prepare-only \
  --run-tag qdesn-dynamic-p90-steepertrend-rhsns-full-preflight-20260423-143700__git-20c5e35
```

Preflight run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-full-preflight-20260423-143700__git-20c5e35`

Preflight artifacts:

- [preflight report root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation/qdesn-dynamic-p90-steepertrend-rhsns-full-preflight-20260423-143700__git-20c5e35)

## 4) Full Launch Started

Full launch command:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R \
  --phase rhsns_full \
  --run-tag qdesn-dynamic-p90-steepertrend-rhsns-full-20260423-143900__git-20c5e35 \
  --tmux-session qdesn_p90_rhsns_full
```

Full launch run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-full-20260423-143900__git-20c5e35`

Launcher session:

- `qdesn_p90_rhsns_full`

Launch artifacts:

- [full launch report root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation/qdesn-dynamic-p90-steepertrend-rhsns-full-20260423-143900__git-20c5e35)
- [launcher log](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation/qdesn-dynamic-p90-steepertrend-rhsns-full-20260423-143900__git-20c5e35/launch/launcher_stdout.log)

## 5) Initial Health Snapshot

Initial live healthcheck snapshot:

- time:
  - `2026-04-23 14:39 EDT`
- selected roots:
  - `18`
- materialized roots:
  - `0`
- successful roots:
  - `0`
- running roots:
  - `0` in summaries yet
- failed roots:
  - `0`
- campaign completed manifest:
  - `FALSE`
- launcher session live:
  - `TRUE`

Initial launcher evidence:

- workers started successfully
- no launch-time error files were present
- no hard numerical/runtime failure evidence was present at launch time

## 6) Baseline Policy Preserved

The full `rhs_ns` launch keeps the same normalized baseline contract used in
the relaunch program:

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

Still excluded from baseline:

- theta freeze rescue
- latent-state rescue
- latent `v` / latent `s` rescue
- precision rescue
- row-local overrides

## 7) Immediate Monitoring Priorities

The next monitoring checkpoints should confirm:

1. first materialized roots appear cleanly
2. first completed fits remain free of hard numerical/runtime failure
3. the early `rhs_ns` fit-quality mix remains interpretable enough to decide
   whether the baseline policy can continue unchanged
