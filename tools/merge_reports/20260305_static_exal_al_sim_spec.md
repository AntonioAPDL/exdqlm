# Static exAL/AL Simulation Spec (Rich 1D MC-Quantiles)

Date: 2026-03-05  
Repo: `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp`

## Purpose

Define a static simulation that is:

1. visually informative for cloud-style quantile plots,
2. compatible with dynamic `ts_mc_quantiles` schema,
3. equipped with true quantiles computed by Monte Carlo approximation (dynamic-style truth construction).

## Dynamic lineage trace

Dynamic simulation lineage references:

- `/data/muscat_data/jaguir26/exdqlm/scripts/sim_suite_dlm.R`
- `/data/muscat_data/jaguir26/exdqlm/R/simulate_ts_mc_quantiles.R`

## Chosen static DGP

For `t = 1, ..., T`:

- Primary covariate: `x_t ~ Uniform(x_min, x_max)`
- Basis design:
  - `X_t = [1, x_t, x_t^2, sin(1.35*x_t)]`
- Predictor:
  - `mu_t = X_t^T beta`
- Observation:
  - `y_t ~ exAL(p0_gen, mu_t, sigma_true, gamma_true)`

Default values:

- `T = 5000`
- `x_min = -2.75`, `x_max = 2.75`
- `beta = (-0.55, 1.80, -0.72, 1.10)`
- `sigma_true = 2.8`
- `gamma_true = 0.42`
- `p0_gen = 0.50`
- `seed = 20260305`
- `p_grid = {0.01, 0.05, 0.10, ..., 0.95, 0.99}`
- `R_mc = 4000` (MC draws for quantile anchors)

## True quantile construction (MC approximation)

We approximate quantile anchors via Monte Carlo from standardized exAL innovations:

- Draw `eps_exAL_r ~ exAL(p0_gen, 0, sigma_true, gamma_true), r=1..R_mc`
- Draw `eps_AL_r ~ exAL(p0_gen, 0, sigma_true, 0), r=1..R_mc`
- For each `p`:
  - `q0_exAL(p) = Quantile(eps_exAL, p)`
  - `q0_AL(p) = Quantile(eps_AL, p)`
- For each `t`:
  - `Q_exAL(t,p) = mu_t + q0_exAL(p)`
  - `Q_AL(t,p) = mu_t + q0_AL(p)`

The simulation stores:

- `sim$q = Q_exAL(t,p)` (primary truth)
- `sim$extras$q_al = Q_AL(t,p)` (AL counterfactual)

## Output schema and artifacts

Output root (default):

- `results/sim_suite_static/series/static_exal_rich1d_mcq/`

Produced files:

- `sim_output.rds` with dynamic-like schema:
  - `y`, `q`, `p`, `info`, `extras`
- `series_wide.csv`
- `series_long.csv`
- `meta.txt`
- `run_config.rds`

Compatibility notes:

- Top-level schema is aligned with dynamic simulation objects (`ts_mc_quantiles`).
- `info$R_mc` and `info$quantile_truth_method` explicitly document MC truth construction.
