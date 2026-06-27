# Q-DESN TT500 VB Hard-Cell Forecast Refinement

Date: 2026-06-27

This note documents the hard-cell, forecast-focused refinement stage launched
after the completed targeted Q-DESN TT500 VB dominance refinement. The goal is
not to promote a final profile yet; the goal is to test whether compact,
forecast-oriented Q-DESN reservoirs can close the remaining DQLM/exDQLM VB gap
in the difficult family x tau cells before any MCMC relaunch.

## Upstream Evidence

- completed targeted run tag:
  `qdesn-tt500-vb-targeted-refinement-full-20260626`
- completed targeted report root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/qdesn-tt500-vb-targeted-refinement-full-20260626/20260626-142912__git-f700322`
- completed targeted results root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/qdesn-tt500-vb-targeted-refinement-full-20260626/20260626-142912__git-f700322`
- strict targeted audit evidence:
  `observed=1080 success=1080 running=0 fail=0 strict_ready=TRUE`
- post-targeted diagnosis:
  `validation/fitforecast_v2/docs/QDESN_TT500_VB_POST_TARGETED_DIAGNOSIS_PLAN_2026-06-27.md`

The targeted screen found useful cell-specific profiles but no globally
dominant profile. The remaining bottleneck was forecast performance.

## Stage Design

- stage:
  `qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement`
- run family:
  Q-DESN TT500 VB, `rhs_ns`, `exal`
- profiles:
  36 compact profiles
- cells:
  all 9 family x tau cells, including 7 hard cells and 2 sentinel cells
- root count:
  324 roots
- workers:
  20
- rolling-origin contract:
  `Hmax=30`, `origin_stride=30`
- source contract:
  frozen period90/m90/w300 source materialization
- storage contract:
  storage-light only; scalar/path summaries, logs, manifests, lead metrics,
  rolling-origin path tables; no successful `.rds`, `.rda`, or `.RData`
  retention.

The profiles intentionally keep `m=90` and `readout_y_lags=90`. Changing those
would require a separate source-rematerialized stage because the existing frozen
source inputs are materialized for period90/m90/w300. This keeps the screen
comparable to the completed TT500 validation evidence.

## Materialized Files

- profiles:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement_profiles.csv`
- defaults:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement_defaults.yaml`
- grid:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement_grid.csv`
- materialization manifest:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement_materialization_manifest.json`
- diagnostic report:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/qdesn-tt500-vb-targeted-refinement-full-20260626/20260626-142912__git-f700322/diagnostics/qdesn_tt500_vb_hardcell_forecast_refinement/summary/qdesn_tt500_vb_hardcell_forecast_refinement.md`

Hashes at materialization:

| File | SHA-256 |
|---|---|
| profiles CSV | `1121201621a4f7198e15fdd87883cff55b704d0c40c5ec19c2b6af3aed6aa6ee` |
| defaults YAML | `ffb06f2d5ce8ea8539228bb14102afd4a3d76cfa55448b8972d9442f6d3ac483` |
| grid CSV | `295b9cb44464976ada984d4af7dd5e1b8d8109fb406fd63bbbc4529692d28083` |
| materialization manifest | `ba39b998abf126ee36de4f2a315f4c0d02688d22e70bc14018f91d442b9363f5` |

## Commands Run

Load and focused tests:

```bash
Rscript -e "pkgload::load_all('.', quiet=TRUE); cat('load_ok\n')"
Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-qdesn-tt500-vb-hardcell-forecast-refinement.R')"
Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-qdesn-tt500-vb-targeted-refinement.R')"
```

Materialization:

```bash
Rscript scripts/materialize_qdesn_tt500_vb_hardcell_forecast_refinement.R \
  --workers 20 \
  --max-profiles 36 \
  --max-p-over-n 0.50
```

Prepare-only gate:

```bash
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement_grid.csv \
  --batch full \
  --methods vb \
  --fit-sizes 500 \
  --allow-grid-subset \
  --prepare-only \
  --run-tag qdesn-tt500-vb-hardcell-forecast-refinement-prepare-20260627
```

Smoke preflight and smoke:

```bash
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement_grid.csv \
  --batch smoke \
  --methods vb \
  --fit-sizes 500 \
  --allow-grid-subset \
  --prepare-only \
  --run-tag qdesn-tt500-vb-hardcell-forecast-refinement-smoke-preflight-20260627

Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement_grid.csv \
  --batch smoke \
  --methods vb \
  --fit-sizes 500 \
  --allow-grid-subset \
  --run-tag qdesn-tt500-vb-hardcell-forecast-refinement-smoke-20260627
```

Smoke audit:

```bash
Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement/qdesn-tt500-vb-hardcell-forecast-refinement-smoke-20260627/20260627-004642__git-f700322 \
  --expected-roots 1 \
  --strict
```

Smoke ranking checks:

```bash
Rscript scripts/rank_qdesn_tt500_vb_screen.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement/qdesn-tt500-vb-hardcell-forecast-refinement-smoke-20260627/20260627-004642__git-f700322 \
  --top-n 5

Rscript scripts/rank_qdesn_tt500_vb_dominance_screen.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement/qdesn-tt500-vb-hardcell-forecast-refinement-smoke-20260627/20260627-004642__git-f700322 \
  --top-n 5
```

Full launch:

```bash
tmux new-session -d -s qdesn_hcell_20260627 \
  "cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0 && \
   /data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
     --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement_defaults.yaml \
     --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement_grid.csv \
     --batch full \
     --methods vb \
     --fit-sizes 500 \
     --allow-grid-subset \
     --run-tag qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627 \
     > reports/qdesn_mcmc_validation/qdesn_tt500_vb_hardcell_forecast_refinement_launcher/qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627.tmux.log 2>&1; \
   echo \$? > reports/qdesn_mcmc_validation/qdesn_tt500_vb_hardcell_forecast_refinement_launcher/qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627.exitcode"
```

## Gate Results

- package load:
  passed
- new hard-cell test file:
  15 passed, 0 failed
- targeted-refinement regression test:
  17 passed, 0 failed
- materialization:
  36 profiles, 324 grid rows, max `p/n=0.492`
- prepare-only:
  passed; selected 324 roots; no forbidden binary payloads
- smoke:
  passed
- smoke strict audit:
  `observed=1 success=1 running=0 fail=0 strict_ready=TRUE`
- smoke generic ranking:
  passed; wrote `qdesn_tt500_vb_screen_fit_forecast_summary.csv`,
  `qdesn_tt500_vb_screen_profile_cell_summary.csv`, and
  `qdesn_tt500_vb_screen_profile_ranking.csv`
- smoke dominance ranking:
  passed; wrote `qdesn_tt500_vb_baseline_targets.csv`,
  `qdesn_tt500_vb_dominance_cell_summary.csv`, and
  `qdesn_tt500_vb_dominance_profile_ranking.csv`
- smoke rolling-origin artifact check:
  `lead_rows=30`, `max_lead=30`, `lead_origin_end=9990`,
  `rolling_rows=1000`, `origins=34`, `origin_range=9000:9990`,
  `final_origin_rows=10`

## Live Launch State

- tmux session:
  `qdesn_hcell_20260627`
- run tag:
  `qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627`
- run stamp:
  `20260627-005028__git-f700322`
- live report root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement/qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627/20260627-005028__git-f700322`
- live results root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement/qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627/20260627-005028__git-f700322`
- launcher log:
  `reports/qdesn_mcmc_validation/qdesn_tt500_vb_hardcell_forecast_refinement_launcher/qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627.tmux.log`
- exit-code sidecar, created only after completion:
  `reports/qdesn_mcmc_validation/qdesn_tt500_vb_hardcell_forecast_refinement_launcher/qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627.exitcode`

Snapshot after launch:

| Observed roots | Success | Running | Fail | Missing status | Lead metrics | Rolling paths |
|---:|---:|---:|---:|---:|---:|---:|
| 20 | 0 | 20 | 0 | 0 | 0 | 0 |

## Follow-Up After Completion

Run the strict audit and rankings:

```bash
Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement/qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627/20260627-005028__git-f700322 \
  --expected-roots 324 \
  --strict

Rscript scripts/rank_qdesn_tt500_vb_screen.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement/qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627/20260627-005028__git-f700322 \
  --top-n 20

Rscript scripts/rank_qdesn_tt500_vb_dominance_screen.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement/qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627/20260627-005028__git-f700322 \
  --top-n 20
```

Promotion remains blocked until the full 324-root run completes, passes strict
audit, and the dominance ranking shows whether any profile is globally viable or
whether only cell-specific replacements are worth pursuing.
