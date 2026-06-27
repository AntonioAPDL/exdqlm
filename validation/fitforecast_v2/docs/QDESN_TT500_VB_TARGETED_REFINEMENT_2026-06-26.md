# Q-DESN TT500 VB Targeted Refinement

Date: 2026-06-26

This note documents the post-dominance-screen targeted Q-DESN VB refinement for the
shared fit+forecast validation study. It is a tuning/refinement lane, not an
article-authoritative replacement result until it completes, is ranked against the
DQLM/exDQLM VB baselines, passes strict storage-light audit, and is explicitly
promoted.

## Input Screen

- completed screen run tag: `qdesn-tt500-vb-dominance-period90-broad-leadfix-20260626__git-f700322`
- completed screen report root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance/qdesn-tt500-vb-dominance-period90-broad-leadfix-20260626__git-f700322/20260626-013231__git-f700322`
- completed screen strict audit: `observed=648 success=648 running=0 fail=0 strict_ready=TRUE`
- dominance ranking result: no global profile passed all nine family x tau cells; forecast metrics were the bottleneck.

## Diagnostic Pack

Generated with:

```sh
Rscript scripts/materialize_qdesn_tt500_vb_targeted_refinement.R \
  --top-n-per-cell 3 \
  --max-profiles 120 \
  --workers 20 \
  --max-p-over-n 0.50
```

Diagnostic output root:

`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance/qdesn-tt500-vb-dominance-period90-broad-leadfix-20260626__git-f700322/20260626-013231__git-f700322/diagnostics/qdesn_tt500_vb_targeted_refinement`

Key diagnostic tables:

- `tables/qdesn_tt500_vb_dominance_cell_gap_summary.csv`
- `tables/qdesn_tt500_vb_dominance_top_profiles_per_cell.csv`
- `tables/qdesn_tt500_vb_dominance_factor_summary.csv`

## Targeted Registry

Materialized files:

- profiles: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement_profiles.csv`
- defaults: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement_defaults.yaml`
- grid: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement_grid.csv`
- materialization manifest: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement_materialization_manifest.json`

Registry summary:

- profiles: 120
- full roots: 1080
- families: `gausmix`, `laplace`, `normal`
- taus: `0.05`, `0.25`, `0.50`
- fit size: TT500
- inference: VB / EXAL / RHS-NS
- max p/n: 0.492
- smoke guard: `smoke.max_roots = 1`

## Gates Run Before Full Launch

Focused tests:

```sh
Rscript -e "pkgload::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-qdesn-tt500-vb-dominance-screening.R'); testthat::test_file('tests/testthat/test-qdesn-tt500-vb-dominance-followup.R'); testthat::test_file('tests/testthat/test-qdesn-tt500-vb-targeted-refinement.R')"
```

Result: all focused tests passed.

Full targeted prepare-only:

```sh
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement_grid.csv \
  --batch full \
  --methods vb \
  --likelihoods exal \
  --fit-sizes 500 \
  --priors rhs_ns \
  --allow-grid-subset \
  --prepare-only \
  --workers 20 \
  --scheduler load_balanced \
  --run-tag qdesn-tt500-vb-targeted-refinement-prepare-20260626
```

Result: prepare-only passed and produced zero forbidden `.rds`, `.rda`, or `.RData`
payloads.

Smoke prepare-only:

```sh
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement_grid.csv \
  --batch smoke \
  --methods vb \
  --likelihoods exal \
  --fit-sizes 500 \
  --priors rhs_ns \
  --allow-grid-subset \
  --prepare-only \
  --workers 1 \
  --scheduler sequential \
  --run-tag qdesn-tt500-vb-targeted-refinement-smoke-preflight-20260626
```

Result: selected exactly one smoke root and produced zero forbidden binary payloads.

Smoke run:

```sh
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement_grid.csv \
  --batch smoke \
  --methods vb \
  --likelihoods exal \
  --fit-sizes 500 \
  --priors rhs_ns \
  --allow-grid-subset \
  --workers 1 \
  --scheduler sequential \
  --run-tag qdesn-tt500-vb-targeted-refinement-smoke1-20260626
```

Smoke report root:

`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/qdesn-tt500-vb-targeted-refinement-smoke1-20260626/20260626-142637__git-f700322`

Smoke strict audit: `observed=1 success=1 running=0 fail=0 strict_ready=TRUE`.

## Full Launch

Launched in detached tmux:

```sh
tmux new-session -d -s qdesn_tref_20260626 \
  "cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0 && \
   Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
     --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement_defaults.yaml \
     --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement_grid.csv \
     --batch full \
     --methods vb \
     --likelihoods exal \
     --fit-sizes 500 \
     --priors rhs_ns \
     --allow-grid-subset \
     --workers 20 \
     --scheduler load_balanced \
     --run-tag qdesn-tt500-vb-targeted-refinement-full-20260626 \
     2>&1 | tee reports/qdesn_mcmc_validation/qdesn_tt500_vb_targeted_refinement_launcher/qdesn-tt500-vb-targeted-refinement-full-20260626.log"
```

Live launch:

- tmux session: `qdesn_tref_20260626`
- run tag: `qdesn-tt500-vb-targeted-refinement-full-20260626`
- report root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/qdesn-tt500-vb-targeted-refinement-full-20260626/20260626-142912__git-f700322`
- launcher log:
  `reports/qdesn_mcmc_validation/qdesn_tt500_vb_targeted_refinement_launcher/qdesn-tt500-vb-targeted-refinement-full-20260626.log`

## Health Check Commands

```sh
tmux ls | rg qdesn_tref_20260626
tail -n 80 reports/qdesn_mcmc_validation/qdesn_tt500_vb_targeted_refinement_launcher/qdesn-tt500-vb-targeted-refinement-full-20260626.log
Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/qdesn-tt500-vb-targeted-refinement-full-20260626/20260626-142912__git-f700322 \
  --expected-roots 1080
```

After completion, run ranking and strict audit before promotion:

```sh
Rscript scripts/rank_qdesn_tt500_vb_screen.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/qdesn-tt500-vb-targeted-refinement-full-20260626/20260626-142912__git-f700322 \
  --top-n 30

Rscript scripts/rank_qdesn_tt500_vb_dominance_screen.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/qdesn-tt500-vb-targeted-refinement-full-20260626/20260626-142912__git-f700322 \
  --baseline /data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv \
  --top-n 30

Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/qdesn-tt500-vb-targeted-refinement-full-20260626/20260626-142912__git-f700322 \
  --expected-roots 1080 \
  --strict \
  --require-rankings
```

## Promotion Rule

Do not use the targeted refinement outputs in Article-Q-DESN until:

1. all 1080 roots are terminal success or explicitly documented failures;
2. rolling-origin lead metrics exist for every successful root;
3. storage-light strict audit passes;
4. dominance rankings are regenerated against the current DQLM/exDQLM VB baseline;
5. a profile is explicitly frozen/promoted with a manifest.
