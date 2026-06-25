# Q-DESN TT500 VB Screening Plan

Date: 2026-06-25

This is a tuning screen for the Q-DESN side of the shared fit+forecast v2 validation. It is not an article-facing final result table.

## Purpose

The completed TT500 validation showed that the previous Q-DESN profile was much slower than the DQLM/exDQLM baselines and had poor fit/forecast accuracy. Before relaunching any final validation run, the Q-DESN specification should be screened with compact reservoirs and shorter VB budgets while holding the shared source registry and rolling-origin evaluation contract fixed.

## Fixed Validation Contract

- Package baseline: exdqlm 1.0.0 worktree.
- Shared source root: `/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources`.
- Scenario: `dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`.
- Fit size: TT500 only.
- Forecast protocol: rolling-origin, no refit, observed-lag state update.
- Maximum lead: 30.
- Origin stride: 30.
- Forecast block: source indices 9001:10000.
- TT500 target training window: source indices 8501:9000.
- Q-DESN synthesis outputs are not used for ranking; the screen ranks single-quantile fit/forecast metrics.

## Screening Scope

Frozen profile registry:

`config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_screen_profiles.csv`

Screen defaults:

`config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_screen_defaults.yaml`

Checked-in grid target:

`config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_screen_grid.csv`

Primary median scout:

- Families: `gausmix`, `laplace`, `normal`.
- Tau: `0.50`.
- Method: `vb`.
- Likelihood: `exal`.
- Prior: `rhs_ns`.
- Profiles: 63 compact DESN/RHS combinations.
- Total selected roots/fits: 189.
- Workers: 20.

The full screening grid represented by the defaults has 9 dataset cells times 63 profiles = 567 roots. Launch filters select the median scout first.

## DESN Profile Grid

The registry crosses:

- Depth/width profiles: `(D,n) = (1,30), (1,50), (1,70), (2,30), (2,50), (2,70), (3,30)`.
- Alpha/rho pairs: `(0.10,0.70)`, `(0.30,0.85)`, `(0.60,0.95)`.
- RHS-NS global scale `tau0`: `1e-5`, `1e-4`, `1e-3`.

Design constraints:

- `m = 12`.
- `readout_y_lags = 12`.
- `reservoir_lags = 0`.
- `washout = 300`, preserving the TT500 materialized source contract.
- Primary gate: `p_over_n_tt500 <= 0.50`.
- Largest primary profile: estimated `p = 223`, `p/n = 0.446`.

## Runtime Budget

- VB `max_iter = 150`.
- VB `min_iter_elbo = 40`.
- VB `n_samp_xi = 500`.
- VB `progress_every = 50`.
- Posterior metric draws: 200.
- VB sampling draws: 200.
- Synthesis draw budget: 200, retained only as required by the existing compact rolling lead export path.
- MCMC is disabled for this screen.

## Storage Contract

The screen preserves the validation storage-light policy:

- Keep scalar fit metrics.
- Keep scalar rolling-origin lead metrics.
- Keep compact paths required by lead-level summaries.
- Keep logs, configs, manifests, status, and failure rows.
- Do not retain routine successful forecast object payloads.
- Do not produce article-facing final tables from this tuning screen.

## Commands

Focused tests:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-qdesn-dynamic-fitforecast-vb-screening-config.R", reporter="summary")'
```

Prepare-only median scout:

```sh
RUN_TAG="qdesn-tt500-vb-screen-median-scout-20260625__git-$(git rev-parse --short HEAD)"
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_screen_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_screen_grid.csv \
  --batch full \
  --methods vb \
  --likelihoods exal \
  --fit-sizes 500 \
  --taus 0.5 \
  --priors rhs_ns \
  --allow-grid-subset \
  --refresh-grid \
  --prepare-only \
  --workers 20 \
  --scheduler load_balanced \
  --run-tag "${RUN_TAG}"
```

Background launch after prepare-only passes:

```sh
RUN_TAG="qdesn-tt500-vb-screen-median-scout-20260625__git-$(git rev-parse --short HEAD)"
mkdir -p "reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_tt500_vb_screen/${RUN_TAG}/manual_launch"
nohup Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_screen_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_screen_grid.csv \
  --batch full \
  --methods vb \
  --likelihoods exal \
  --fit-sizes 500 \
  --taus 0.5 \
  --priors rhs_ns \
  --allow-grid-subset \
  --refresh-grid \
  --workers 20 \
  --scheduler load_balanced \
  --run-tag "${RUN_TAG}" \
  > "reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_tt500_vb_screen/${RUN_TAG}/manual_launch/stdout_stderr.log" 2>&1 &
printf '%s\n' "$!" > "reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_tt500_vb_screen/${RUN_TAG}/manual_launch/pid.txt"
```

## Decision Rule After Screen

Do not promote screen rows directly to the article. After the median scout finishes:

1. Rank by fit quantile recovery and rolling-origin forecast metrics.
2. Check VB health, runtime, and failure patterns by family.
3. Pick a small short list of profiles, not more than 10 to 15, for all-quantile confirmation.
4. Only after confirmation should any Q-DESN MCMC or final article-facing validation relaunch be planned.
