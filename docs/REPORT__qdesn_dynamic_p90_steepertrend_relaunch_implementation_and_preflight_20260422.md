# REPORT: QDESN Dynamic P90 Steepertrend Relaunch Implementation And Preflight

Date: 2026-04-22
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

This report records the implementation and preflight state of the new
Q-DESN dynamic relaunch campaign built on the promoted period-90 steeper-trend
dataset surface.

The goal of this campaign is to validate:

- the promoted dynamic dataset surface;
- the normalized shared warmup/default layer; and
- the current Q-DESN dynamic launch stack

without rewriting the historical tau050 relaunch assets in place.

## 2) Promoted Dataset Surface

Promoted scenario:

- `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`

Canonical source roots:

- [candidate roots](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v1)

Active dataset manifest:

- [active dataset selection](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_active_dataset_selection.yaml)

Review packs:

- [full candidate audit](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_dataset_audit_local/qdesn-dynamic-exdqlm-crossstudy-candidate-datasetaudit-20260422-035737__git-a4ecc81)
- [last5000 vs last500 audit](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_last5000_last500_audit_local/qdesn-dynamic-candidate-last5000-last500-audit-20260422-035753__git-a4ecc81)

## 3) Relaunch Assets Created

New relaunch defaults and grids:

- [defaults manifest](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_defaults.yaml)
- [full grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_full_grid.csv)
- [smoke grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_smoke_grid.csv)
- [ridge full grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_ridge_full_grid.csv)
- [rhs_ns full grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_rhsns_full_grid.csv)
- [mcmc ridge tt500 grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_ridge_tt500_grid.csv)
- [mcmc ridge tt5000 grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_ridge_tt5000_grid.csv)
- [mcmc rhs_ns tt500 grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_rhsns_tt500_grid.csv)
- [mcmc rhs_ns tt5000 grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_rhsns_tt5000_grid.csv)

New relaunch scripts:

- [materialize grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_grid.R)
- [run wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/run_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R)
- [launch wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R)
- [healthcheck wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R)

Focused test:

- [config test](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-p90-steepertrend-config.R)

## 4) Frozen Baseline Contract

First execution prior:

- `ridge`

Second expansion prior:

- `rhs_ns`

Shared long-budget contract:

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

Important interpretation:

- the relaunch is configured to use the full retained MCMC posterior sample
  budget in downstream metrics
- the VB draw layers are also pinned to the same `20000`-draw scale so the
  downstream posterior summaries are normalized across inference engines

Shared baseline inference policy:

- `LDVB` for VB
- `slice` for MCMC
- `init_from_vb = TRUE`
- no rescue overlay in the baseline
- no `rw`
- no `laplace_rw`

Shared baseline warmup policy:

- automatic tau warmup for `rhs` / `rhs_ns` with `50L`
- light exAL VB `(sigma, gamma)` warmup
- light exAL MCMC `(sigma, gamma)` warmup

What remains out of baseline:

- theta freeze rescue
- latent-state rescue
- latent `v` / latent `s` rescue
- precision rescue
- row-local overrides

## 5) Exact Dataset Semantics

Canonical study geometry:

- `9` full roots
- `18` unique dataset cells
- one prior surface = `72` fits
- both prior surfaces = `144` fits

Exact Q-DESN staged totals:

- `813`
- `5313`

Effective fit sizes:

- `500`
- `5000`

These staged totals are intentional and must not be simplified away because
they preserve:

- `holdout_n = 1`
- `lag_max = 12`
- `washout = 300`

## 6) Preflight Results

Focused config test passed:

```bash
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-qdesn-dynamic-p90-steepertrend-config.R", reporter = testthat::StopReporter$new())'
```

Grid materialization passed:

```bash
Rscript scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_grid.R
```

Prepare-only preflights passed:

```bash
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R --phase smoke --prepare-only
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R --phase ridge_full --prepare-only
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R --phase full --prepare-only
```

Preflight run tags:

- `qdesn-dynamic-p90-steepertrend-smoke-20260422-043104__git-a4ecc81`
- `qdesn-dynamic-p90-steepertrend-ridge-full-20260422-043104__git-a4ecc81`
- `qdesn-dynamic-p90-steepertrend-full-20260422-043104__git-a4ecc81`

Resolved preflight summaries:

- smoke input grid:
  - `6` roots
  - `6` unique dataset cells
  - `ridge` only
  - note: the generic smoke batch selects one canonical root for execution from
    this checked-in smoke grid
- ridge baseline:
  - `18` selected roots
  - `18` unique dataset cells
  - `ridge` only
  - `4` fits per root
  - total planned fits: `72`
- full comparison surface:
  - `36` selected roots
  - `18` unique dataset cells
  - priors: `ridge`, `rhs_ns`
  - `4` fits per root
  - total planned fits: `144`

Verified source-total sizes in the materialized grids:

- `813`
- `5313`

## 7) Important Implementation Note

The phase-aware run wrapper was adjusted so subset preflights no longer inherit
generic `full` run tags. Default run tags are now phase-specific, for example:

- `qdesn-dynamic-p90-steepertrend-ridge-full-...`

This keeps smoke, first-prior baseline, and full dual-prior preparation easy to
distinguish in both report and results roots.

## 8) Current Read

The relaunch assets are now prepared and preflighted.

The next correct execution order is:

1. commit the staged relaunch assets
2. run committed-state smoke execution
3. if smoke is healthy, launch the `72`-fit `ridge` baseline
4. only after that decide whether to open the second `72`-fit `rhs_ns`
   expansion
