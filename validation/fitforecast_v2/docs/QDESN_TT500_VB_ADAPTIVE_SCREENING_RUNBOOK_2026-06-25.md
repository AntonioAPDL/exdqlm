# Q-DESN TT500 VB Adaptive Screening Runbook

Date: 2026-06-25

Worktree:
`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

Branch:
`validation/shared-fitforecast-v2-1.0.0`

This runbook records the implemented adaptive screening ladder used before any
replacement Q-DESN TT500 validation launch. These screens are tuning evidence
only. They must not be promoted directly to Article-Q-DESN final validation
tables.

## Implemented Artifacts

Ranking implementation:

- `R/qdesn_fitforecast_screening.R`
- `scripts/rank_qdesn_tt500_vb_screen.R`

Stage materialization:

- `scripts/materialize_qdesn_tt500_vb_screen_stage.R`
- `scripts/orchestrate_qdesn_tt500_vb_adaptive_screening.R`

Checked-in stage configs:

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_confirm_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_confirm_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_confirm_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_broad_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_broad_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_broad_grid.csv`

Tests:

- `tests/testthat/test-qdesn-tt500-vb-adaptive-screening.R`
- `tests/testthat/test-qdesn-dynamic-fitforecast-vb-screening-config.R`

## Median Scout Ranking

Input run:

`reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_tt500_vb_screen/qdesn-tt500-vb-screen-median-scout-200draw-20260625-045828__git-437dc73-dirty/20260625-045959__git-437dc73`

Ranking outputs:

- `tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv`
- `tables/qdesn_tt500_vb_screen_profile_cell_summary.csv`
- `tables/qdesn_tt500_vb_screen_profile_ranking.csv`
- `summary/qdesn_tt500_vb_screen_profile_ranking.md`
- `manifest/qdesn_tt500_vb_screen_profile_ranking_manifest.json`

Important audit result:

- `189/189` median-scout fits have complete lead metrics.
- Campaign-level `forecast_*` scalar columns are all missing for this scout,
  so ranking uses each fit's `forecast_lead_metrics.csv`.
- The median scout collapses from `63` tau0-tagged rows to `21` unique profile
  bases.

## Adaptive Ladder

Stage 1: all-quantile confirmation.

- Profiles: `10`.
- Families: `gausmix`, `laplace`, `normal`.
- Quantiles: `0.05`, `0.25`, `0.50`.
- Fits: `90`.
- Purpose: confirm the strongest median-scout profiles and family guards across
  every validation quantile.

Stage 2: broad compact screen.

- Profiles: `55`.
- Families: `gausmix`, `laplace`, `normal`.
- Quantiles: `0.05`, `0.50`.
- Fits: `330`.
- Purpose: search a wider compact-DESN region without reintroducing the inert
  tau0 triplicates.

Stage 3: seed-stability check.

- Generated from a completed ranking table with
  `scripts/materialize_qdesn_tt500_vb_screen_stage.R --stage stability`.
- Purpose: rerun the top few profiles with an alternate reservoir seed before
  freezing a final TT500 replacement spec.

## Launch Policy

Use the sequential orchestrator with 20 workers:

```sh
Rscript scripts/orchestrate_qdesn_tt500_vb_adaptive_screening.R \
  --workers 20
```

The orchestrator runs confirmation first, ranks it, then runs the broad screen
and ranks it. It writes logs and a manifest under:

`reports/qdesn_mcmc_validation/qdesn_tt500_vb_adaptive_screening/<orchestrator_tag>/`

This uses one 20-worker screen at a time. It does not launch any MCMC or final
TT500 replacement validation.

## Tests Run

Focused adaptive-screening tests:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-qdesn-tt500-vb-adaptive-screening.R", reporter="summary")'
```

Result: passed.

Original screening config tests:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-qdesn-dynamic-fitforecast-vb-screening-config.R", reporter="summary")'
```

Result: passed.

Prepare-only preflights:

- Confirmation top-10:
  `qdesn-tt500-vb-confirm-top10-prep-20260625-174049__git-437dc73`.
- Broad compact:
  `qdesn-tt500-vb-broad-prep-20260625-174049__git-437dc73`.

Both preflights passed with `workers=20`.

Confirmation execution:

- Run tag:
  `qdesn-tt500-vb-confirm-top10-20260625-174340__git-437dc73`.
- Report root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_confirm/qdesn-tt500-vb-confirm-top10-20260625-174340__git-437dc73/20260625-174352__git-437dc73`.
- Results root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_confirm/qdesn-tt500-vb-confirm-top10-20260625-174340__git-437dc73/20260625-174352__git-437dc73`.
- Status:
  `90/90` roots `SUCCESS`.
- Lead metrics:
  `90/90` `forecast_lead_metrics.csv` files present.
- Ranking:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_confirm/qdesn-tt500-vb-confirm-top10-20260625-174340__git-437dc73/20260625-174352__git-437dc73/tables/qdesn_tt500_vb_screen_profile_ranking.csv`.
- Confirmation leader:
  `tt500vb_d2_n30_a0p3_r0p85`, followed by
  `tt500vb_d1_n50_a0p3_r0p85`.

Broad execution:

- Run tag:
  `qdesn-tt500-vb-broad-20260625-181834__git-437dc73-dirty`.
- Tmux session:
  `qdesn_tt500_vb_broad_0625_181834`.
- Planned campaign report root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_broad/qdesn-tt500-vb-broad-20260625-181834__git-437dc73-dirty`.
- Planned campaign results root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_broad/qdesn-tt500-vb-broad-20260625-181834__git-437dc73-dirty`.
- Launch artifacts:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_broad/qdesn-tt500-vb-broad-20260625-181834__git-437dc73-dirty/manual_launch/`.
- Initial health:
  session live, campaign manifest written under
  `20260625-181857__git-437dc73`, and 20 worker roots started.

## Decision Gate Before Replacement TT500

Do not relaunch final TT500 replacement until:

1. Confirmation and broad screens finish with explicit success/failure status.
2. Both screens have complete lead-level rolling-origin metrics.
3. Rankings are generated from lead metrics, not campaign-level missing
   `forecast_*` fields.
4. Top profiles are checked for family/quantile robustness.
5. A seed-stability check is run for the final short list.
6. The final spec is frozen in a versioned config.
7. Article-facing schema/storage/stale-path audits pass.
8. The user explicitly approves the replacement validation launch.
