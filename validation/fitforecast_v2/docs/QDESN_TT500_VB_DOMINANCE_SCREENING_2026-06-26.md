# Q-DESN TT500 VB Dominance Screening

This runbook defines the next Q-DESN-only VB screening lane for the shared
fit+forecast validation study. It does not launch AL/MCMC and does not modify
the exdqlm 1.0.0 package baseline branch.

## Goal

Find Q-DESN VB specifications that can beat the best DQLM/exDQLM VB baseline
for each TT500 family and quantile cell before any expensive replacement MCMC
run is considered.

Promotion criterion:

- family cells: `gausmix`, `laplace`, `normal`
- quantile cells: `0.05`, `0.25`, `0.50`
- fit size: `TT500`
- inference: Q-DESN `VB`, likelihood `exal`, prior `rhs_ns`
- baseline: best available DQLM/exDQLM `VB` row per family and quantile
- pass condition: every cell beats the baseline on forecast MAE, forecast
  pinball, fit RMSE, and fit pinball.

## Design

The prior TT500 Q-DESN VB screens fit the known quantile path well but forecast
poorly. The simulated DGP has `period = 90` and harmonics `1,2`, while the
earlier compact screens mostly used `m_y = 12` and no deterministic covariates.

This lane therefore uses one coherent source/materialization contract:

- `m_y = 90`
- explicit x lag set `x = 0`, so current future-known covariates are included
- `washout = 300`
- holdout/forecast block length `1000`
- source total size `500 + 1000 + 90 + 300 = 1890`
- deterministic covariates: `sin/cos(2*pi*h*source_index/90)` for `h=1,2`,
  plus centered/scaled source-index trend
- 72 compact profiles, all with p/n <= 0.50 after counting the five
  deterministic x features.

The screen is intentionally broad but bounded:

- depth/width: `(D,n) in {(1,20),(1,30),(1,50),(2,20),(2,30),(2,50)}`
- dynamics: `(alpha,rho) in {(0.05,0.60),(0.10,0.70),(0.20,0.80),(0.30,0.85)}`
- sparsity/readout variants:
  - sparse: `pi_w=0.05`, `pi_in=0.30`, `reservoir_lags=0`
  - balanced: `pi_w=0.10`, `pi_in=0.50`, `reservoir_lags=1`
  - input-rich: `pi_w=0.20`, `pi_in=0.80`, `reservoir_lags=1`

Total planned roots: `72 profiles x 9 cells = 648`.

## Generated Tracked Inputs

The orchestrator writes:

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_grid.csv`

The staged source cache is separate from earlier runs:

- `results/qdesn_mcmc_validation/dynamic_fitforecast_v2_qdesn_sources_period90_m90_w300`

## Commands

Prepare-only preflight:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_dominance_screening.R \
  --prepare-only \
  --refresh-materialized \
  --workers 20
```

Main background launch:

```bash
nohup Rscript scripts/orchestrate_qdesn_tt500_vb_dominance_screening.R \
  --workers 20 \
  > reports/qdesn_mcmc_validation/qdesn_tt500_vb_dominance_screening/manual_launch/stdout_stderr.log 2>&1 &
```

After completion, the standard screen ranking and baseline-dominance ranking
are written under the campaign report root.

## Rolling-Origin Leadfix

The first broad run completed all 648 roots but exposed an article-facing
forecast contract failure:

- run tag: `qdesn-tt500-vb-dominance-period90-broad-20260625-213402__git-f700322`
- compute status: `SUCCESS = 648`
- post-processing status: generic rank failed
- cause: no `forecast_lead_metrics.csv` files were produced
- root error: the rolling grid required final partial origin source index
  `9990`, but the pipeline generated only full 30-step origins through source
  index `9960`
- storage consequence: `forecast_objects.rds` files were retained because the
  compact export was incomplete.

The repair makes the Q-DESN pipeline generate all stride-aligned origins needed
by the rolling-origin grid, including partial tail origins. For the TT500
dominance contract this means:

- forecast block: `9001:10000`
- `Hmax = 30`
- `origin_stride = 30`
- expected rolling path rows: `1000`
- expected origin sequence: `9000, 9030, ..., 9960, 9990`
- final origin `9990` contributes only leads `1:10`.

Smoke evidence after the repair:

- run tag: `qdesn-tt500-vb-dominance-leadfix-smoke-20260626`
- report root:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance/qdesn-tt500-vb-dominance-leadfix-smoke-20260626/20260626-012810__git-f700322`
- roots: `SUCCESS = 1`
- `forecast_rolling_origin_paths.csv`: `1000` rows
- `forecast_lead_metrics.csv`: `30` rows
- final origin source index `9990`: present with leads `1:10`
- lead counts: leads `1:10` have `34` origins, leads `11:30` have `33`
  origins
- storage-light: successful `forecast_objects.rds` was pruned
- generic rank: passed
- dominance rank: passed.

## Outputs To Inspect

- `tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv`
- `tables/qdesn_tt500_vb_screen_profile_ranking.csv`
- `tables/qdesn_tt500_vb_baseline_targets.csv`
- `tables/qdesn_tt500_vb_dominance_cell_summary.csv`
- `tables/qdesn_tt500_vb_dominance_profile_ranking.csv`
- `summary/qdesn_tt500_vb_dominance_ranking.md`
- `manifest/qdesn_tt500_vb_dominance_manifest.json`

## Post-Run Automation

The follow-up layer is staged so the live screen can finish undisturbed, then
be audited and promoted only if the evidence is complete.

Live, non-strict audit while roots are still running:

```bash
Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R \
  --results-root results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance/<run-tag>/<stamp> \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance/<run-tag>/<stamp> \
  --expected-roots 648
```

Dry-run cleanup check for successful-root RHS trace payloads:

```bash
Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R \
  --results-root results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance/<run-tag>/<stamp> \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance/<run-tag>/<stamp> \
  --expected-roots 648 \
  --prune-success-rhs-trace
```

Execute cleanup only after explicit approval:

```bash
Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R \
  --results-root results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance/<run-tag>/<stamp> \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance/<run-tag>/<stamp> \
  --expected-roots 648 \
  --prune-success-rhs-trace \
  --execute-prune
```

The cleanup only targets terminal `SUCCESS` roots under `fits/vb_exal` where a
compact RHS diagnostic summary exists. It leaves `RUNNING` and `FAIL` roots
untouched.

Terminal, strict audit after the orchestrator has ranked the screen:

```bash
Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance/<run-tag>/<stamp> \
  --expected-roots 648 \
  --strict \
  --require-rankings
```

Materialize a refinement stage from the broad dominance ranking:

```bash
Rscript scripts/materialize_qdesn_tt500_vb_dominance_followup.R \
  --stage refinement \
  --ranking reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance/<run-tag>/<stamp>/tables/qdesn_tt500_vb_dominance_profile_ranking.csv \
  --top-n 12 \
  --workers 20
```

Materialize a seed-stability stage with an alternate reservoir seed:

```bash
Rscript scripts/materialize_qdesn_tt500_vb_dominance_followup.R \
  --stage seed_stability \
  --ranking reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/<run-tag>/<stamp>/tables/qdesn_tt500_vb_dominance_profile_ranking.csv \
  --top-n 5 \
  --seed 777 \
  --workers 20
```

Freeze one profile for the later TT500 replacement candidate:

```bash
Rscript scripts/freeze_qdesn_tt500_vb_profile.R \
  --ranking reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_seed_stability/<run-tag>/<stamp>/tables/qdesn_tt500_vb_dominance_profile_ranking.csv \
  --require-dominance-pass
```

The guarded orchestrator can materialize, prepare, smoke, and optionally run a
follow-up stage. It never launches the full stage unless `--full` is supplied:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_dominance_followup.R \
  --stage refinement \
  --ranking reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance/<run-tag>/<stamp>/tables/qdesn_tt500_vb_dominance_profile_ranking.csv \
  --top-n 12 \
  --smoke \
  --workers 20
```

Add `--full` only after the prepare and smoke logs are clean and the launch is
explicitly approved.

## Guardrails

- This is a screening lane, not an article-facing final table.
- Do not promote a Q-DESN replacement TT500 result unless the dominance ranking
  and follow-up confirmation pass.
- For storage-light screening, `forecast_objects.rds` and successful-root
  `rhs_trace.rds` payloads are not article-facing artifacts. The scalar/compact
  CSV diagnostics are authoritative.
- Do not launch TT5000 or MCMC from this lane.
- Do not mix this period-90 source cache with older `m_y=12` caches.
