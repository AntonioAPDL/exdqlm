# Model Selection Doc Audit

## Scope checked
- `model_selection_documentation.txt`
- QDESN/DESN entry points and pipelines
- Model selection utilities and scoring outputs
- Repo conventions for configs, outputs, and seeds

## Key repo files (authoritative mapping)
- `scripts/pipeline_run.R` (config merge + dispatch)
- `scripts/pipeline_sim_main.R`, `scripts/pipeline_real_main.R`
- `R/qdesn_vb.R` (QDESN core fit/forecast)
- `R/exal_ldvb_engine.R`, `R/exal_static_LDVB.R`
- `R/priors_beta.R`, `R/qdesn_rhs_prior.R`
- `R/exdqlm_synthesize_from_draws.R`
- `R/qdesn_model_selection.R`, `scripts/qdesn_model_selection_main.R`
- `R/model_selection_distribution_first.R`

## Main inconsistencies fixed
- **Doc implied model selection is entirely new** → aligned to existing `qdesn_model_selection()` and `model_selection_distribution_first()` implementations.
- **Parameter names/locations** → updated to match `cfg$desn` keys and seed handling.
- **Synthesis naming** → replaced generic “synthesis step” with `exdqlm_synthesize_from_draws()`.
- **Scoring source** → aligned CRPS selection to `tables/metrics_summary.csv` (scope/component/score/value).
- **Output layout** → aligned to `results/<suite>/<dataset>/runs/<run_id>/` with manifest + tables/figs/models.

## Changes applied to documentation
- Added a repo mapping section with file-level references.
- Updated split/scoring descriptions to match existing pipeline and model-selection utilities.
- Marked planned components explicitly with “planned implementation location” notes.

## Open assumptions
- Calibration penalty/constraint is still a planned extension (not currently in `qdesn_model_selection()` scoring).
- Candidate caching is not implemented; doc now marks it as planned.

