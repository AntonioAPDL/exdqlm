# Paper-Family Quantile-Specific Simulation Study Plan

## Purpose

Build a corrected simulation-study dataset layer for the next validation wave.

This plan is generation-only. It does **not** launch model fits.

The dataset family should support later validation of:
- static `AL` / `exAL`
- dynamic `DQLM` / `exDQLM`
- `VB` / `MCMC`
- `ridge` / `rhs` where relevant

All datasets must satisfy the quantile-specific DGP contract:
- target quantile `tau` is aligned with the regression signal by construction
- truth objects are saved and traceable
- fit-input subsets are reproducible and explicit

## Design Matrix

### Error families
- `normal`
- `laplace`
- `gausmix`
- `loggpd`

### Target quantiles
- `0.05`
- `0.25`
- `0.50`

### Dataset families
1. static non-shrinkage benchmark
2. static shrinkage benchmark
3. dynamic non-shrinkage benchmark

## Benchmark families

### 1. Static non-shrinkage benchmark
Purpose:
- paper-faithful lower-complexity multivariate regression benchmark
- direct static `AL` vs `exAL` comparison under the paper error families

Structure:
- `p = 8`
- correlated Gaussian covariates
- covariance `Sigma_ij = 0.5^{|i-j|}`
- default coefficient vector: paper sparse signal
  - `(3, 1.5, 0, 0, 2, 0, 0, 0)`
- save one quantile-specific dataset per `(family, tau)`
- save one default fit-input subset per dataset

Output root:
- `results/function_testing_20260309_static_paper_family_qspec`

### 2. Static shrinkage benchmark
Purpose:
- coefficient-recovery study under the same four paper error families
- later compare `ridge` vs `rhs`

Structure:
- current correlated high-dimensional shrinkage design
- grouped coefficients:
  - strong
  - moderate
  - small
  - near-zero
  - zero
- save one quantile-specific dataset per `(family, tau)`
- save one default fit-input subset per dataset

Output root:
- `results/function_testing_20260309_static_shrinkage_family_qspec`

### 3. Dynamic non-shrinkage benchmark
Purpose:
- dynamic DLM validation under the same family axis
- keep the current simple small-`W_t` trend + seasonal structure, varying only the error family

Structure:
- scenario: `dlm_constV_smallW`
- same trend + harmonic seasonal state evolution as the current baseline (trend retained by default)
- long warmup before keeping the analysis segment
- store final analysis segment only as the canonical dataset
- store fit-input subsets based on the **last** `T` observations

Output root:
- `results/function_testing_20260309_dynamic_dlm_family_qspec`

## Output contract

Each generated dataset root must contain:
- `sim_output.rds`
- `run_config.rds`
- `meta.txt`
- `series_wide.csv`
- `series_long.csv`
- `true_quantile_grid.csv` where meaningful
- validation summary csv

Static roots should also contain:
- default `fit_input_subsample_tt...`

Dynamic roots should also contain:
- one or more `fit_input_lastTT...` directories
- warmup metadata

## Dynamic warmup policy

Default policy:
- simulate `TT_warmup + TT_main`
- discard the warmup segment from the canonical analysis dataset
- keep metadata recording:
  - warmup length
  - full simulated length
  - kept analysis length

Default fit-input subsets:
- last `1000`
- last `2000`
- last `5000`
if available

## Naming scheme

### Static paper family
- `results/function_testing_20260309_static_paper_family_qspec/<family>/tau_<tag>`

### Static shrinkage family
- `results/function_testing_20260309_static_shrinkage_family_qspec/<family>/tau_<tag>`

### Dynamic family
- `results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_smallW/<family>/tau_<tag>`

## Checklist
- [ ] implement static paper-family generator
- [ ] implement static shrinkage-family generator
- [ ] implement dynamic family generator with warmup and last-`T` fit-input subsets
- [ ] validate all generated datasets
- [ ] write inventory tables for all dataset families
- [ ] update the reset tracker with generated roots and status
- [ ] stop before any model reruns

## Deliverable for this phase

At the end of this phase we should have:
1. the study plan documented
2. all corrected datasets generated for the three benchmark families
3. validators run
4. a compact inventory of produced dataset roots
5. no model fits launched yet
