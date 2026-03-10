# Quantile-Specific Simulation Validation Reset Tracker

## Document Control

- Status: implementation started
- Date: 2026-03-08
- Branch: `jaguir26/dqlm-conjugacy-cavi-gibbs`
- Repo: `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp`
- Purpose: replace the previous simulation-based validation campaign with a quantile-correct validation campaign in which each simulated dataset is specific to the target quantile `p0`

## Why This Reset Is Required

The previous simulation validation campaign used datasets of the form:

- static: `y_i = x_i' beta + eps_i`
- dynamic: `y_t = F_t' theta_t + eps_t`

but the noise distribution was not shifted so that the target quantile satisfied:

- `Q_{p0}(eps) = 0`

That means the previous validation truth was generally not:

- static: `Q_{p0}(y_i | x_i) = x_i' beta`
- dynamic: `Q_{p0}(y_t | F_t) = F_t' theta_t`

unless by coincidence `Q_{p0}(eps) = 0`.

So the old truth-vs-estimate comparisons are not the correct validation basis for quantile-targeted models.

## Correct Validation Principle

For every target quantile `p0`, the simulated data must be generated so that the target conditional quantile is exactly the model signal.

### Static

For a model targeting quantile `p0`, simulate:

- `y_i = x_i' beta + eps_i^*`

with:

- `eps_i^* = eps_i - Q_{p0}(eps_i)`

so that:

- `Q_{p0}(eps_i^*) = 0`
- `Q_{p0}(y_i | x_i) = x_i' beta`

### Dynamic

For a model targeting quantile `p0`, simulate:

- `y_t = F_t' theta_t + eps_t^*`

with:

- `eps_t^* = eps_t - Q_{p0}(eps_t)`

so that:

- `Q_{p0}(eps_t^*) = 0`
- `Q_{p0}(y_t | F_t) = F_t' theta_t`

### Consequence

There is no longer one shared simulation dataset across all quantiles.

Instead, there must be one simulation dataset per target quantile.

Examples:
- one dataset for `tau = 0.05`
- one dataset for `tau = 0.50`
- one dataset for `tau = 0.95`

The fit, truth, plots, and metrics for a given `tau` must use the dataset generated specifically for that same `tau`.

## Reset Scope

This reset applies to all simulation-based validation workflows involving:

- static `AL`
- static `exAL`
- dynamic `DQLM`
- dynamic `exDQLM`
- `VB`
- `MCMC`
- `ridge`
- `rhs`

This does **not** mean the algorithms are wrong.
It means the old simulation-based scientific validation outputs are not the correct target-aligned basis and should not be treated as canonical.

## Results Folders Marked Obsolete

These results are considered scientifically obsolete for quantile-targeted validation because they were built on the old non-shifted simulation basis:

- `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260304_vb_quantiles`
- `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260306_static_heteroskedastic_cosine`
- `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260306_static_heteroskedastic_skewnormal`
- `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260306_static_scale_pair_skewnormal`
- `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260306_static_simple_linear_exal_positive_gamma`
- `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260306_static_simple_linear_normal`
- `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian`
- `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/sim_suite_dlm`
- `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/sim_suite_static`

## Deletion Policy

Delete the obsolete results only after the following are confirmed:

- the scripts needed to regenerate the studies are already preserved in the repo or elsewhere safe
- any simulation inputs that still matter scientifically are preserved elsewhere if needed
- no active workflow still depends on these directories

Deletion rationale:
- frees space
- prevents accidental reuse of scientifically obsolete outputs
- reduces confusion between the old and corrected validation campaigns

## Q0 Status: Reset and Cleanup

Completed on 2026-03-08.

Deleted obsolete directories:
- `results/function_testing_20260304_vb_quantiles`
- `results/function_testing_20260306_static_heteroskedastic_cosine`
- `results/function_testing_20260306_static_heteroskedastic_skewnormal`
- `results/function_testing_20260306_static_scale_pair_skewnormal`
- `results/function_testing_20260306_static_simple_linear_exal_positive_gamma`
- `results/function_testing_20260306_static_simple_linear_normal`
- `results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian`
- `results/sim_suite_dlm`
- `results/sim_suite_static`

Reason:
- all were scientifically obsolete under the old non-quantile-centered DGP contract
- they were reproducible from scripts or superseded by the new rebuild plan

## New Validation Campaign Requirements

### Dataset-level requirements

For each target quantile `p0`:

1. define the DGP signal
   - static: `x_i' beta`
   - dynamic: `F_t' theta_t`
2. define the base noise law
3. compute `Q_{p0}(eps)`
   - closed form if available
   - Monte Carlo if needed
4. shift the noise by that quantile
5. save the resulting `p0`-specific dataset and truth objects
6. record exactly how the truth was obtained

### Reporting requirements

For every fit/report:

1. the fit must point to the quantile-specific dataset used
2. plots must show only the truth corresponding to that dataset
3. metric summaries must never pool different quantile-specific DGPs as if they came from the same data-generating truth
4. run roots and file naming must encode the target quantile and DGP family clearly

## Campaign Structure To Rebuild

### Static campaigns to rebuild

1. simple Gaussian linear DGP, quantile-specific
2. simple exAL-generated DGP, quantile-specific
3. homoskedastic skew-normal DGP, quantile-specific
4. heteroskedastic skew-normal DGP, quantile-specific
5. shrinkage benchmark DGP, quantile-specific
   - compare `ridge` vs `rhs`
   - include many covariates
   - include strong, small, near-zero, and exact-zero coefficients

### Dynamic campaigns to rebuild

1. baseline dynamic Gaussian / shifted-noise DGP, quantile-specific
2. dynamic skew-normal or other asymmetric DGP, quantile-specific
3. dynamic shrinkage/regularization studies only if still scientifically needed after the baseline dynamic reruns

## Model Grid To Refit

### Static

For each static quantile-specific dataset:

- `AL` via `VB`
- `AL` via `MCMC`
- `exAL` via `VB`
- `exAL` via `MCMC`
- if regularization study:
  - `AL + ridge`
  - `AL + rhs`
  - `exAL + ridge`
  - `exAL + rhs`
  - each under both `VB` and `MCMC` where appropriate

### Dynamic

For each dynamic quantile-specific dataset:

- `DQLM` via `VB`
- `DQLM` via `MCMC`
- `exDQLM` via `VB`
- `exDQLM` via `MCMC`

## Execution Strategy

### High-level execution rules

1. generate datasets first, quantile by quantile
2. validate dataset schemas and truth objects before fitting
3. launch fits in background sessions
4. keep one clear status file per job
5. do not live-monitor aggressively; rely on status/log checkpoints
6. postprocess only after all jobs for a campaign finish

### Background orchestration approach

Use separate `tmux` sessions grouped by campaign, for example:

- static simple campaign
- static skew-normal homoskedastic campaign
- static skew-normal heteroskedastic campaign
- static shrinkage campaign
- dynamic baseline campaign
- dynamic asymmetric campaign

Each session should write:
- run root
- config file
- status table
- log file
- final summary table

## Phase Plan

| Phase | Goal | Output |
|---|---|---|
| `Q0` | Freeze the reset rationale and obsolete-result list | this tracker |
| `Q1` | Inventory old scripts and reusable sim generators/reporters | script map and reuse decisions |
| `Q2` | Implement quantile-specific static generators | static `p0`-specific datasets + truth |
| `Q3` | Implement quantile-specific dynamic generators | dynamic `p0`-specific datasets + truth |
| `Q4` | Implement schema/truth validators | validator outputs for every generated dataset |
| `Q5` | Adapt fitting pipelines to consume quantile-specific datasets cleanly | background fit launchers and status files |
| `Q6` | Launch and complete static reruns | static run roots + plots + tables |
| `Q7` | Launch and complete dynamic reruns | dynamic run roots + plots + tables |
| `Q8` | Produce final integrated review of all corrected campaigns | consolidated summary tables and interpretation |

## Q2/Q3 Generation Launch Status

Launched on 2026-03-09.

Dataset-generation-only campaigns now exist for:
- static paper-family qspec datasets
- static shrinkage-family qspec datasets
- dynamic family qspec datasets

These launchers generate and validate datasets only. They do not launch model fits.

Launcher scripts:
- `tools/merge_reports/20260309_run_static_paper_family_qspec_campaign.sh`
- `tools/merge_reports/20260309_run_static_shrinkage_family_qspec_campaign.sh`
- `tools/merge_reports/20260309_run_dynamic_family_qspec_campaign.sh`

Study plan of record:
- `tools/merge_reports/20260309_paper_family_qspec_study_plan.md`

## Q1 Script Inventory And Reuse Decisions

### Reusable with quantile-specific path/schema updates only

Pipelines:
- `tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R`
- `tools/merge_reports/20260305_vb_then_mcmc_pipeline.R`

## Q1.5 DGP Comparison Against Yan-Kottas / bqrgal

Comparison note:
- [20260309_paper_vs_qspec_dgp_audit.md](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260309_paper_vs_qspec_dgp_audit.md)

Main conclusion:
- the current quantile-specific centering principle is conceptually correct and
  is consistent with the paper-side generators
- the main discrepancies are benchmark-design differences, not the basic
  quantile shift itself

Most important benchmark differences identified:
- paper focuses on lower-tail targets `0.05, 0.25, 0.50`
- paper uses correlated 8-dimensional Gaussian designs
- paper evaluates multiple error families: normal, Laplace, Gaussian mixture,
  and log-GPD
- paper aggregates over replicated train/test splits
- several earlier local qspec runs here addressed different scientific regimes
  (one-covariate, skew-normal, heteroskedastic, shrinkage-specific)

Operational implication:
- do not replace the qspec centering rule
- instead, revise the remaining generator families so the benchmark design
  matches the intended scientific question before launching the full rerun grid
- `tools/merge_reports/20260305_static_postprocess_from_existing_fits.R`
- `tools/merge_reports/20260305_postprocess_from_existing_fits.R`
- `tools/merge_reports/20260305_static_vb_mcmc_report.R`

Reason:
- these already consume explicit `sim_path` and `run_config`
- postprocess/report layers already key most truth extraction from `run_cfg$taus`
- the main change needed is to stop constructing one run over `c(0.05,0.50,0.95)` from a single dataset

### Reusable as generator templates but requiring redesign to one-dataset-per-tau outputs

Static generators:
- `tools/merge_reports/20260306_generate_static_simple_linear_normal.R`
- `tools/merge_reports/20260308_generate_static_homoskedastic_shrinkage_gaussian.R`
- `tools/merge_reports/20260306_generate_static_simple_linear_exal_positive.R`
- `tools/merge_reports/20260306_static_heteroskedastic_cosine_plot.R`
- `tools/merge_reports/20260306_generate_static_scale_pair_from_hetero_source.R`

Reason:
- all of these currently emit `sim_output$q` and truth grids for many taus at once
- under the corrected design, they must emit one `tau`-specific dataset, one truth object, and one fit-input bundle per run

### Reusable analysis/report templates after the reruns exist

Static analysis helpers:
- `tools/merge_reports/20260308_static_shrinkage_compare_report.R`
- `tools/merge_reports/20260306_simple_normal_mcmc_triplet_compare.R`

Reason:
- these can be adapted after the new quantile-specific runs exist
- they should not be treated as first-step generator infrastructure

### Current hard-wiring that must be removed in Q5

Static pipeline hard-wiring:
- `p_vec <- c(0.05, 0.50, 0.95)` in `20260305_static_vb_then_mcmc_pipeline.R`
- default `sim_path` points to deleted old results roots

Dynamic pipeline hard-wiring:
- `p_vec <- c(0.05, 0.50, 0.95)` in `20260305_vb_then_mcmc_pipeline.R`
- default `sim_path` points to deleted old results roots
- dynamic run root naming still assumes one campaign spans all taus from one dataset

### Dynamic generator contract to preserve

The dynamic pipeline currently reconstructs the model with:
- `build_dgp_matched_model(sim$info$params, TT)`

So the new dynamic quantile-specific generators must preserve at least:
- `sim$info$params$period`
- `sim$info$params$m0`
- `sim$info$params$C0`
- `sim$y`
- `sim$p` as length-1 target tau
- `sim$q` as the matching tau-specific truth trajectory
- any additional extras needed by downstream plotting or matched-model reconstruction

### Implementation decision after Q1

Least-disruptive redesign:
- one run consumes one quantile-specific `sim_output.rds`
- `run_cfg$taus` becomes length 1 for that run
- fit/postprocess/report code stays mostly unchanged
- generator and pipeline entry points are the main rewrite points

## Checklist

### `Q0` Reset and cleanup
- [x] Confirm the obsolete result directories can be deleted safely.
- [x] Delete the obsolete result directories.
- [x] Record exactly what was deleted and why.

### `Q1` Script inventory
- [x] Inventory current simulation-generation scripts.
- [x] Classify which scripts are reusable after the quantile-shift correction.
- [x] Identify which report/postprocess scripts need only path/schema changes versus full redesign.

### `Q2` Static quantile-specific generators
- [ ] Implement shared quantile-specific static helper functions.
- [ ] Implement quantile-specific simple Gaussian static generator.
- [ ] Implement quantile-specific exAL-generated static generator.
- [ ] Implement quantile-specific homoskedastic skew-normal static generator.
- [ ] Implement quantile-specific heteroskedastic skew-normal static generator.
- [ ] Implement quantile-specific shrinkage benchmark static generator.
- [ ] Record whether each noise quantile was closed form or Monte Carlo.

### `Q3` Dynamic quantile-specific generators
- [ ] Implement shared quantile-specific dynamic helper functions.
- [ ] Implement quantile-specific baseline dynamic generator.
- [ ] Implement quantile-specific asymmetric dynamic generator.
- [ ] Save quantile-specific truth trajectories per `tau`.

### `Q4` Validators
- [ ] Add static dataset validator.
- [ ] Add dynamic dataset validator.
- [ ] Add a validator that checks empirically that the generated target quantile is centered at zero in the shifted noise.

### `Q5` Fitting pipeline adaptation
- [ ] Make static fit pipelines explicitly consume one dataset per target quantile.
- [ ] Make dynamic fit pipelines explicitly consume one dataset per target quantile.
- [ ] Ensure fit metadata stores dataset path, `tau`, and truth source.
- [ ] Ensure plotting/report scripts use the matching quantile-specific dataset only.

### `Q6` Static reruns
- [ ] Static simple Gaussian campaign rerun.
- [ ] Static exAL-generated campaign rerun.
- [ ] Static homoskedastic skew-normal campaign rerun.
- [ ] Static heteroskedastic skew-normal campaign rerun.
- [ ] Static shrinkage campaign rerun (`ridge` vs `rhs`).

### `Q7` Dynamic reruns
- [ ] Dynamic baseline campaign rerun.
- [ ] Dynamic asymmetric campaign rerun.
- [ ] Dynamic reporting/postprocess regenerated from corrected quantile-specific datasets.

### `Q8` Final review
- [ ] Build a corrected summary table for all static campaigns.
- [ ] Build a corrected summary table for all dynamic campaigns.
- [ ] Compare `AL` vs `exAL` and `DQLM` vs `exDQLM` again under the corrected quantile-specific DGPs.
- [ ] Compare `VB` vs `MCMC` again under the corrected quantile-specific DGPs.
- [ ] Compare `ridge` vs `rhs` again under the corrected shrinkage DGPs.
- [ ] Write the final corrected scientific summary.

## Canonical Naming Convention For The New Campaigns

Every quantile-specific run should encode:

- DGP family
- static vs dynamic
- target `tau`
- fit budget
- prior type if relevant
- inference type if relevant

Example patterns:
- `function_testing_YYYYMMDD_static_skewnormal_tau0p05_shiftedq`
- `function_testing_YYYYMMDD_dynamic_baseline_tau0p95_shiftedq`
- `..._shrink_rhs_tau0p50_shiftedq`

## Final Principle For All Future Simulation Validation

No simulation-based validation result should be accepted unless:

1. the dataset is specific to the target quantile being estimated
2. the shifted noise was constructed so that `Q_{p0}(eps^*) = 0`
3. the truth object stored with the run corresponds exactly to that same `p0`-specific DGP

That is the new validation contract for this branch.

## 2026-03-08 Progress Update

- `Q2` partial: quantile-specific static generators implemented for:
  - simple Gaussian linear model
  - high-dimensional Gaussian shrinkage model
- `Q4` partial: static quantile-specific validator implemented in `tools/merge_reports/20260308_validate_quantile_specific_static_sim.R`.
- `Q5` partial: static fit pipeline now honors single-tau simulation bundles via `sim$p` length 1 or explicit `EXDQLM_STATIC_PIPELINE_TAU(S)`.
- Static single-tau smoke completed end-to-end:
  - run root: `results/sim_suite_static/qspec_smoke_tau0p05`
  - tau: `0.05`
  - fit stage: complete
  - postprocess: complete
  - report: complete
  - validator coverage check on source sim: empirical coverage `0.044` vs target `0.05` (delta `-0.006`).
- Main design confirmation: static fit/postprocess/report stack does not require multi-tau datasets; one-tau run roots work with current reporting after pipeline entry-point fixes.

- `Q3` partial: quantile-specific dynamic DLM generator implemented in `tools/merge_reports/20260308_generate_dynamic_dlm_quantile_specific.R` for `dlm_constV_smallW`, `dlm_constV_bigW`, and `dlm_ar1V`.
- `Q4` partial: dynamic quantile-specific validator implemented in `tools/merge_reports/20260308_validate_quantile_specific_dynamic_sim.R`.
- `Q5` partial: dynamic fit pipeline now honors single-tau simulation bundles via `sim$p` length 1 or explicit `EXDQLM_DYNAMIC_PIPELINE_TAU(S)`.
- Dynamic single-tau smoke completed end-to-end:
  - sim root: `results/sim_suite_dlm_qspec/series/dlm_constV_smallW/tau_0p05`
  - fit root: `results/sim_suite_dlm/qspec_smoke_tau0p05`
  - tau: `0.05`
  - fit stage: complete
  - postprocess: complete
  - validator coverage check on source sim: empirical coverage `0.054` vs target `0.05` (delta `0.004`).
- Main design confirmation: dynamic fit/postprocess stack also works with one-tau simulation bundles; the remaining rebuild work is now scenario coverage and campaign orchestration, not core pipeline compatibility.
