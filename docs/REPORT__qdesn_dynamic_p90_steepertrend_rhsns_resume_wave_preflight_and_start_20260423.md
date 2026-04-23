# REPORT: QDESN Dynamic P90 Steepertrend RHS-NS Resume Wave Preflight And Start

Date: 2026-04-23
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

This report records the committed-state continuation wave that resumes the
interrupted full `rhs_ns` relaunch after the disk-full event.

The continuation wave is designed to:

- preserve the already-successful roots from the interrupted parent run;
- replay only the failed roots;
- launch the never-started roots; and
- keep the same normalized baseline defaults

## 2) Frozen Continuation Commit

Committed-state continuation commit:

- `ae49a50`

This commit froze:

- the interruption report;
- the unresolved-root continuation policy; and
- the checked-in unresolved-root subset grid

Supporting interruption report:

- [disk-full interruption and continuation](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_dynamic_p90_steepertrend_rhsns_full_diskfull_interruption_and_continuation_20260423.md)

## 3) Continuation Grid

Checked-in continuation grid:

- [rhs_ns resume-after-diskfull grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_rhsns_resume_after_diskfull_grid.csv)

Continuation scope:

| Metric | Value |
|---|---:|
| unresolved roots relaunched | `15` |
| replayed failed roots | `3` |
| newly started pending roots | `12` |
| preserved successful roots from interrupted parent run | `3` |

## 4) Preflight Checks Run

Focused config test passed:

```bash
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-qdesn-dynamic-p90-steepertrend-config.R", reporter = testthat::StopReporter$new())'
```

Committed-state continuation preflight passed:

```bash
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R \
  --phase rhsns_full \
  --grid config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_rhsns_resume_after_diskfull_grid.csv \
  --allow-grid-subset \
  --prepare-only \
  --run-tag qdesn-dynamic-p90-steepertrend-rhsns-resume-preflight-20260423-192200__git-ae49a50
```

Continuation preflight run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-resume-preflight-20260423-192200__git-ae49a50`

Preflight artifacts:

- [continuation preflight report root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation/qdesn-dynamic-p90-steepertrend-rhsns-resume-preflight-20260423-192200__git-ae49a50)

## 5) Continuation Wave Started

Continuation launch command:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R \
  --phase rhsns_full \
  --grid config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_rhsns_resume_after_diskfull_grid.csv \
  --allow-grid-subset \
  --run-tag qdesn-dynamic-p90-steepertrend-rhsns-resume-full-20260423-192400__git-ae49a50 \
  --tmux-session qdesn_p90_rhsns_resume
```

Continuation launch run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-resume-full-20260423-192400__git-ae49a50`

Launcher session:

- `qdesn_p90_rhsns_resume`

Launch artifacts:

- [continuation launch report root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation/qdesn-dynamic-p90-steepertrend-rhsns-resume-full-20260423-192400__git-ae49a50)
- [continuation launcher log](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation/qdesn-dynamic-p90-steepertrend-rhsns-resume-full-20260423-192400__git-ae49a50/launch/launcher_stdout.log)

## 6) Initial Health Snapshot

Initial continuation healthcheck snapshot:

- time:
  - `2026-04-23 19:19 EDT`
- selected roots:
  - `15`
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

Initial interpretation:

- the continuation wave opened cleanly
- the unresolved-root subset was accepted as a valid auditable continuation
  surface
- no hard numerical/runtime failure evidence was present at launch time

## 7) Baseline Policy Preserved

The continuation wave preserves the same baseline contract as the interrupted
full `rhs_ns` parent run:

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

## 8) Immediate Monitoring Priority

The next monitoring checkpoint should focus first on the replayed
`tau = 0.05`, `fit_size = 5000` roots, because those were the ones interrupted
by the disk-full event in the parent campaign.
