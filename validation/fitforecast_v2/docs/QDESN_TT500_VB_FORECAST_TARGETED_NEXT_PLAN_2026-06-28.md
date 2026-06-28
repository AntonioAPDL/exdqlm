# Q-DESN TT500 VB Forecast-Targeted Next Plan

Date: 2026-06-28

This note records the post-hard-cell audit and the revised plan for the next
Q-DESN TT500 VB screening stage. It is a planning and design document only. It
does not promote new article-facing outputs, does not launch MCMC, and does not
touch TT5000.

## Current Evidence

- Worktree:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- Branch:
  `validation/shared-fitforecast-v2-1.0.0`
- Current HEAD:
  `58943c4 Add Q-DESN TT500 VB dominance refinement workflow`
- Latest completed run tag:
  `qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627`
- Latest report root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement/qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627/20260627-005028__git-f700322`
- Latest results root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement/qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627/20260627-005028__git-f700322`

Strict audit after rankings:

| expected | observed | success | running | fail | lead metrics | rolling paths | storage-light | forbidden binaries | rankings | strict ready |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| 324 | 324 | 324 | 0 | 0 | 324 | 324 | 324 | 0 | generic + dominance | TRUE |

Key generated evidence:

- `audit/tables/qdesn_tt500_vb_screen_audit_summary.csv`
- `tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv`
- `tables/qdesn_tt500_vb_screen_profile_ranking.csv`
- `tables/qdesn_tt500_vb_dominance_cell_summary.csv`
- `tables/qdesn_tt500_vb_dominance_profile_ranking.csv`
- `summary/qdesn_tt500_vb_dominance_ranking.md`

## Main Finding

The hard-cell run was computationally clean but did not solve the modeling goal.

| Quantity | Value |
|---|---:|
| Profiles ranked | 36 |
| Family x tau cells | 9 |
| Global dominance-pass profiles | 0 |
| Best global profile | `tt500vb_hcell_d2_n30_a0p1_r0p7_m90_lag90_rl0_pw0p05_pin0p3` |
| Best global worst-primary ratio | 2.595746 |
| Cells beaten by best global profile on all primary metrics | 2 of 9 |

The previous targeted refinement had a better global worst-primary ratio
(`2.439980`) and also only solved 2 of 9 cells. The hard-cell run did not
improve the global promotion case.

## Cell-Level Status

The best available Q-DESN VB cell winners after the hard-cell run are:

| family | tau | best worst ratio | pass all primary metrics | diagnosis |
|---|---:|---:|---|---|
| gausmix | 0.05 | 0.958005 | yes | solved sentinel cell |
| gausmix | 0.25 | 1.115475 | no | close; forecast MAE and pinball just above baseline |
| gausmix | 0.50 | 1.137018 | no | close/moderate; forecast MAE bottleneck |
| laplace | 0.05 | 0.956549 | yes | solved sentinel cell |
| laplace | 0.25 | 1.325098 | no | forecast MAE bottleneck |
| laplace | 0.50 | 1.607590 | no | hard forecast MAE bottleneck |
| normal | 0.05 | 1.214399 | no | forecast MAE bottleneck; fit is strong |
| normal | 0.25 | 1.499720 | no | hard forecast MAE bottleneck |
| normal | 0.50 | 1.629702 | no | hard forecast MAE bottleneck |

The consistent pattern is that fit recovery is strong while rolling-origin
forecast metrics are not. The next search should therefore target forecast
mechanism and cell-specific behavior, not spend compute on global reservoir
variants or MCMC.

## Is the Previous Plan Optimal?

The previous plan was directionally right because it avoided MCMC and focused on
hard cells. It is not optimal anymore for three reasons.

First, it still evaluates profile sets globally across all family x tau cells.
The evidence now says cell-level winners are heterogeneous. A single universal
profile is not the best target for the next compute dollar.

Second, it mostly varies reservoir geometry and sparsity while holding
`m=90` and `readout_y_lags=90`. The failures are forecast-side failures, so the
next screen needs controlled readout/forecast-mechanism variants.

Third, the ranking output currently carries `D`, `n_each`, `alpha`, and `rho`
as `NA` in some profile ranking tables even though the profile ids and registries
contain those values. The metrics are usable, but the metadata should be repaired
before any article-facing or freeze workflow depends on those tables.

Conclusion: the better plan is a cell-specific forecast-targeted VB screen with
explicit metadata repair and subset-grid execution.

## Revised Decision

Use run-specific Q-DESN specifications as the primary promotion target.

Primary target:

- one frozen Q-DESN VB profile per family x tau cell;
- same source registry, same rolling-origin protocol, same scoring schema;
- each cell must beat the best DQLM/exDQLM VB baseline on forecast MAE,
  forecast pinball, fit RMSE, and fit pinball.

Secondary target:

- keep looking for a universal profile, but do not make it the blocking target.

Do not run MCMC, TT5000, or article replacement until the VB cell-specific gate
passes.

## Build Plan

### Build 01: Metadata and Ranking Hardening

Goal: make all screening/ranking tables self-describing and safe for downstream
review.

Tasks:

- repair profile-id parsing for prefixes such as `tt500vb_hcell` and
  `tt500vb_tref`;
- when available, join ranking rows back to the profile registry so `D`,
  `n_each`, `alpha`, `rho`, `m`, `readout_y_lags`, `reservoir_lags`, `pi_w`,
  `pi_in`, `dimension_p_estimate`, and `p_over_n_tt500` are never silently lost;
- add regression tests that fail if top dominance rows have missing design
  metadata;
- regenerate ranking summaries for the completed hard-cell run after the parser
  fix.

This is the first build because every later decision table depends on these
columns being reliable.

### Build 02: Cell Candidate Ledger

Goal: produce one authoritative planning row per family x tau cell.

Required columns:

- `family`, `tau`, `cell_status`, `priority`;
- current best profile id and full DESN spec;
- forecast MAE ratio, forecast pinball ratio, fit RMSE ratio, fit pinball ratio;
- primary bottleneck metric;
- source run/report path;
- recommended local search neighborhood;
- whether the cell is sentinel, near-pass, hard, or extreme-hard.

Recommended priority classes:

| priority | cells | reason |
|---|---|---|
| extreme-hard | `laplace 0.50`, `normal 0.25`, `normal 0.50` | worst ratios near 1.5-1.63 |
| hard | `laplace 0.25`, `normal 0.05` | ratio 1.21-1.33 |
| near-pass | `gausmix 0.25`, `gausmix 0.50` | ratio 1.11-1.14 |
| sentinel | `gausmix 0.05`, `laplace 0.05` | currently pass |

The ledger should be tracked under `config/validation` or written as a
deterministic report artifact with a manifest and SHA-256 hashes.

### Build 03: Cell-Specific Subset Grid

Goal: avoid the inefficient profiles-times-all-cells design.

The existing runner can already execute a grid subset with
`--allow-grid-subset`. The new materializer should create:

- a profile registry;
- a cell-profile assignment ledger;
- a grid CSV containing only approved profile x family x tau assignments;
- a manifest that records the complete canonical grid hash and the selected
  subset hash.

This is important. If we create 80 profiles and expand them across all 9 cells,
we spend 720 roots even though most profiles were designed for one or two cells.
The better design is roughly:

- 7 failing cells x 20 to 35 local profiles;
- 2 sentinel cells x 3 to 5 guard profiles;
- target size: 160 to 260 roots.

This keeps the screen fast, interpretable, and directly aligned with the
promotion target.

### Build 04: Forecast-Mechanism Profile Stage

Goal: test mechanisms that can plausibly improve rolling-origin forecast MAE.

Keep the shared protocol fixed:

- TT500 train window: `8501:9000`;
- forecast block: `9001:10000`;
- rolling origin: no refit, observed-lag state update;
- `Hmax=30`, `origin_stride=30`;
- same source registry and source hashes.

Use two source-compatible tiers.

Tier A, no new source materialization:

- use the existing period90/m90/w300 source support;
- allow `m` and `readout_y_lags` in `{30, 60, 90}`;
- keep `washout=300`;
- keep `rhs_tau0=1e-4` initially;
- restrict `p/n <= 0.50`.

Tier B, only if Tier A fails:

- materialize a separate source-support stage for longer memory such as
  `m=120`, if we decide that longer-than-period history is necessary;
- keep it separate from the existing m90 source cache so old and new evidence
  cannot be mixed.

Recommended local neighborhoods:

- gausmix 0.25/0.50: low dynamics around `(0.03,0.50)`,
  `(0.05,0.60)`, `(0.10,0.70)`; test readout lengths 30/60/90 and sparse or
  light hybrid input;
- laplace 0.25/0.50: high dynamics around `(0.20,0.80)`,
  `(0.30,0.85)`, `(0.40,0.90)`; keep sparse/no reservoir-lag as default;
- normal 0.05/0.25/0.50: test both low and moderate dynamics, with special
  attention to lower readout dimensions because fit is good and forecast MAE is
  poor;
- sentinel cells: rerun only a tiny guard set to ensure the new stage does not
  destroy already solved behavior.

The search should prefer:

- `D in {1,2}`;
- `n_each in {20,30,40,50}`;
- sparse/no-lag readout as the default;
- one light hybrid variant per hard cell;
- minimal input-rich/reservoir-lag variants unless a cell-level winner already
  used them.

### Build 05: Tests and Preflight Gates

Required tests before full screening:

- profile parser supports all active prefixes;
- ranking metadata is not missing for top rows;
- cell ledger has exactly 9 cells and correct priority labels;
- subset grid is a valid subset of the canonical grid;
- subset grid does not expand every profile across every cell;
- source paths remain canonical `/data/jaguir26/local/src` paths;
- rolling-origin lead export still has 30 lead rows and 1000 rolling path rows;
- prepare-only creates no forbidden successful binary payloads;
- storage-light audit passes for smoke.

### Build 06: Launch Sequence

Use the same conservative staged pattern:

```bash
Rscript scripts/materialize_qdesn_tt500_vb_forecast_targeted_screen.R \
  --report-root <hardcell-report-root> \
  --workers 20 \
  --max-p-over-n 0.50

Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_grid.csv \
  --batch full \
  --methods vb \
  --fit-sizes 500 \
  --allow-grid-subset \
  --prepare-only \
  --run-tag qdesn-tt500-vb-forecast-targeted-prepare-YYYYMMDD

Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_grid.csv \
  --batch smoke \
  --methods vb \
  --fit-sizes 500 \
  --allow-grid-subset \
  --run-tag qdesn-tt500-vb-forecast-targeted-smoke-YYYYMMDD
```

Launch full only after prepare and smoke pass:

```bash
tmux new-session -d -s qdesn_vb_forecast_targeted_YYYYMMDD \
  "cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0 && \
   /data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
     --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_defaults.yaml \
     --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_grid.csv \
     --batch full \
     --methods vb \
     --fit-sizes 500 \
     --allow-grid-subset \
     --workers 20 \
     --run-tag qdesn-tt500-vb-forecast-targeted-full-YYYYMMDD \
     > reports/qdesn_mcmc_validation/qdesn_tt500_vb_forecast_targeted_launcher/qdesn-tt500-vb-forecast-targeted-full-YYYYMMDD.tmux.log 2>&1; \
   echo \$? > reports/qdesn_mcmc_validation/qdesn_tt500_vb_forecast_targeted_launcher/qdesn-tt500-vb-forecast-targeted-full-YYYYMMDD.exitcode"
```

### Build 07: Post-Run Audit and Promotion Gate

After completion:

```bash
Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R \
  --report-root <forecast-targeted-report-root> \
  --expected-roots <selected-root-count> \
  --strict \
  --require-rankings

Rscript scripts/rank_qdesn_tt500_vb_screen.R \
  --report-root <forecast-targeted-report-root> \
  --top-n 20

Rscript scripts/rank_qdesn_tt500_vb_dominance_screen.R \
  --report-root <forecast-targeted-report-root> \
  --top-n 20
```

Promotion gate:

- every family x tau cell has at least one Q-DESN VB candidate with all four
  primary ratios below 1.0;
- no cell has missing lead metrics or rolling-origin paths;
- no successful root retains routine `.rds`, `.rda`, or `.RData` payloads;
- selected profiles have complete design metadata and hashes;
- Article-Q-DESN continues to treat this as non-authoritative until an explicit
  freeze/signoff artifact is created.

Optional stronger confirmation gate before MCMC:

- rerun the selected per-cell winners with one alternate reservoir seed;
- require forecast MAE and forecast pinball to remain below baseline, preferably
  with a small margin rather than a numerical tie.

## Why This Is the Better Plan

This plan is more efficient because it stops spending roots on irrelevant
profile-cell combinations. It is more statistically honest because it matches the
observed heterogeneity across family and quantile cells. It is more reproducible
because every selected root is tied to a cell-profile assignment ledger and
source hash. It is safer because the promotion gate stays at the VB level until
the forecast bottleneck is actually fixed.

## Explicit Non-Goals

- No TT5000 launch.
- No MCMC launch.
- No Article-Q-DESN final-table promotion.
- No modification of the exdqlm 1.0.0 package baseline branch.
- No deletion, reset, stash, or overwrite of completed evidence.

## Immediate Next Safe Command Checklist

1. Implement parser/ranking metadata repair. Done.
2. Add tests for active profile prefixes and non-missing ranking metadata. Done.
3. Materialize the forecast-targeted cell ledger and subset grid. Done.
4. Run prepare-only. Done.
5. Run one-root smoke. Done after retention repair.
6. Launch the 208-root VB full screen only after the above gates pass. Cleared after
   commit/push of this implementation.

## Implementation Evidence: 2026-06-28

Implemented in worktree:

`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

Materialized config bundle:

- profiles: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_profiles.csv`
- cell assignments: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_cell_assignments.csv`
- defaults: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_defaults.yaml`
- selected grid: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_grid.csv`
- manifest: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_materialization_manifest.json`

Materialization results:

- unique profiles: 73
- selected cell-profile assignments / executable roots: 208
- canonical profile-by-cell roots: 657
- selected family x tau root counts:
  - gausmix: tau 0.05 = 4, tau 0.25 = 24, tau 0.50 = 24
  - laplace: tau 0.05 = 4, tau 0.25 = 28, tau 0.50 = 32
  - normal: tau 0.05 = 28, tau 0.25 = 32, tau 0.50 = 32
- cell status counts: sentinel = 2, near_pass = 2, hard = 2, extreme_hard = 3

Commands run:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-qdesn-tt500-vb-forecast-targeted-screen.R')"
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-qdesn-tt500-vb-hardcell-forecast-refinement.R')"
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-qdesn-tt500-vb-dominance-screening.R')"
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-qdesn-tt500-vb-targeted-refinement.R')"
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-qdesn-dynamic-fitforecast-storage-light.R')"
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-qdesn-dynamic-fitforecast-lead-export.R')"
```

All focused tests above passed.

Materialization:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/materialize_qdesn_tt500_vb_forecast_targeted_screen.R \
  --workers 20 \
  --max-p-over-n 0.50
```

Prepare-only:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted_grid.csv \
  --batch full \
  --methods vb \
  --fit-sizes 500 \
  --allow-grid-subset \
  --prepare-only \
  --run-tag qdesn-tt500-vb-forecast-targeted-prepare-20260628
```

Prepare-only passed and wrote:

- preflight manifest: `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted/qdesn-tt500-vb-forecast-targeted-prepare-20260628/launch/qdesn_dynamic_exdqlm_crossstudy_preflight_manifest.json`
- selected grid evidence: `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted/qdesn-tt500-vb-forecast-targeted-prepare-20260628/launch/selected_grid_full.csv`

Smoke gate:

- invalid/aborted-for-promotion smoke tag: `qdesn-tt500-vb-forecast-targeted-smoke-20260628`
  - model succeeded, but strict storage-light audit failed because `forecast_objects.rds` remained.
  - Do not consume this tag.
- valid smoke tag: `qdesn-tt500-vb-forecast-targeted-smoke2-20260628`
  - report root: `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted/qdesn-tt500-vb-forecast-targeted-smoke2-20260628/20260628-095952__git-58943c4`
  - results root: `results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted/qdesn-tt500-vb-forecast-targeted-smoke2-20260628/20260628-095952__git-58943c4`
  - strict audit: observed = 1, success = 1, running = 0, fail = 0, strict_ready = TRUE
  - rolling-origin rows = 1000
  - lead metric rows = 30
  - forbidden binary payloads after retention = 0
  - retention manifest confirms `forecast_objects_pruned = true`, `forecast_objects_exists_after = false`, and `rolling_origin_ready_for_pruning = true`.

Retention repair:

- `storage_light_screening` pruning now treats complete rolling-origin path/lead
  exports as a valid pruning gate even when the legacy split alignment status is
  `FAIL`.
- This matches the current rolling-origin benchmark contract, where the lead-level
  forecast exports are the forecast truth for this lane.
