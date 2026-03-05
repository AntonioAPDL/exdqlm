# Static exAL/AL Simulation Spec (S1)

Date: 2026-03-05  
Repo: `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp`

## Purpose

Create a static (non-state-space) simulation dataset aligned with the dynamic `ts_mc_quantiles` output schema so the same downstream reporting style can be reused for static AL/exAL VB vs MCMC campaigns.

## Dynamic lineage trace

The dynamic dataset used in current campaigns (`results/sim_suite_dlm/series/dlm_constV_smallW/sim_output.rds`) carries provenance in `meta.txt` pointing to:

- `/data/muscat_data/jaguir26/exdqlm/scripts/sim_suite_dlm.R`
- `/data/muscat_data/jaguir26/exdqlm/R/simulate_ts_mc_quantiles.R`

These source files are not present in this repo checkout (`exdqlm__wt__0.3.0-cpp`) but are available in sibling repo `exdqlm` and were used as lineage reference for schema/format compatibility.

## Competing DGP options considered

1. Option A (chosen, conservative-default for discrimination): exAL DGP with mild skew (`gamma != 0`), plus AL counterfactual quantile curves saved as reference.  
2. Option B: pure AL DGP (`gamma = 0`) where AL/exAL are expected to be closer.

Chosen default: Option A, with moderate skewness to make AL vs exAL comparison informative without extreme tails.

## Chosen static DGP

For `t = 1, ..., T`:

- Covariates:
  - `x1_t = sin(2*pi*t/period)`
  - `x2_t = cos(2*pi*t/period)`
  - `x3_t = (t - mean(t)) / sd(t)`
  - `X_t = [1, x1_t, x2_t, x3_t]`
- Linear predictor:
  - `mu_t = X_t^T beta`
- Observation:
  - `y_t ~ exAL(p0_gen, mu_t, sigma_true, gamma_true)`

Constants (default):

- `T = 5000`
- `period = 50`
- `beta = (0.0, 2.0, -1.4, 0.6)`
- `sigma_true = 3.0`
- `gamma_true = 0.35`
- `p0_gen = 0.50`
- `seed = 20260305`
- `p_grid = {0.01, 0.05, 0.10, ..., 0.95, 0.99}`

True quantiles (exact, via package `qexal`):

- exAL truth: `Q_exAL(t,p) = qexal(p, p0_gen, mu_t, sigma_true, gamma_true)`
- AL counterfactual: `Q_AL(t,p) = qexal(p, p0_gen, mu_t, sigma_true, 0)`

## Output schema and artifacts

Output root:

- `results/sim_suite_static/series/static_exal_mildskew/`

Produced files:

- `sim_output.rds` with dynamic-like schema:
  - `y`: numeric length `T`
  - `q`: matrix `T x K` (exAL true quantiles)
  - `p`: numeric length `K`
  - `info`: `scenario`, `params`, `burnin`, `R_mc`, `seed`, `lineage`
  - `extras`: `mu`, `X`, `beta`, `sigma_true`, `gamma_true`, `p0_gen`, `q_al`
- `series_wide.csv`
- `series_long.csv`
- `meta.txt`
- `run_config.rds`

Compatibility notes:

- `sim_output.rds` keeps top-level fields (`y`, `q`, `p`, `info`, `extras`) consistent with dynamic simulation objects.
- `q` stores exAL truth; AL counterfactual quantiles are in `extras$q_al`.
