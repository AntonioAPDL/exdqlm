# Dynamic Candidate Dataset Refresh Implementation

## Summary

Implemented a new candidate dynamic dataset pipeline in the Q-DESN validation repo and used it to generate:

- a canonical period-90 steeper-trend source bundle
- canonical `lastTT500` / `lastTT5000` tail slices
- Q-DESN-specific `effTT500_totalTT813` / `effTT5000_totalTT5313` washout windows
- a flat visual audit pack for the candidate windows
- a paired `lastTT5000` versus `lastTT500` review pack for root-level visual screening

## Main code added

### Canonical helper script

- `tools/merge_reports/20260305_dynamic_dgp_model_helpers.R`

This restores a portable validation-layer helper location and provides:

- `build_dynamic_dgp_matched_model()`
- `dynamic_dgp_make_m0()`
- `simulate_dynamic_dgp_latent_path()`
- `dynamic_dgp_family_quantile_shift()`
- `simulate_dynamic_family_errors()`

### Q-DESN candidate dataset module

- `R/qdesn_dynamic_exdqlm_crossstudy_candidate_datasets.R`

This adds:

- manifest loading
- scenario state/path resolution
- canonical root generation
- canonical `lastTT` slicing
- root-level metadata and preview plot writing
- Q-DESN washout materialization handoff

### Candidate audit module

- `R/qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_audit.R`

This adds:

- audit manifest loading
- inventory assembly from canonical slices plus Q-DESN materialized windows
- flat PNG rendering
- audit metadata and summary writing

### Candidate last5000-versus-last500 audit module

- `R/qdesn_dynamic_exdqlm_crossstudy_candidate_last5000_last500_audit.R`

This adds:

- one-PNG-per-root review rendering
- side-by-side `lastTT5000` and `lastTT500` panels
- explicit highlighting of the `lastTT500` window inside the `lastTT5000` panel
- compact root-level metadata and summary writing

### Runner scripts

- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_refresh.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_audit.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_candidate_last5000_last500_audit.R`

### Manifests

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_manifest.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_candidate_materialization_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_audit_manifest.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_candidate_last5000_last500_audit_manifest.yaml`

### Focused tests

- `tests/testthat/test-qdesn-dynamic-candidate-dataset-config.R`
- `tests/testthat/test-qdesn-dynamic-candidate-dataset-audit.R`
- `tests/testthat/test-qdesn-dynamic-candidate-last5000-last500-audit.R`

## Implementation choices worth noting

### 1. Keep the canonical source and Q-DESN washout separate

The canonical roots are staged under the new candidate source root, and the Q-DESN windows are derived later by the existing materialization pipeline. This keeps the source DGP identical across worktrees while preserving the Q-DESN washout contract locally.

### 2. Use deterministic `m0` initialization

The user wanted:

- `C0 = 0.01 I`
- larger seasonal amplitude
- a small slope

Using a sampled initial state would make the slope too random relative to the intended small baseline. The implementation therefore fixes the initial state at `m0` and documents that choice explicitly in the manifest and metadata.

### 3. Preserve shared-within-family latent paths across tau

Each family gets:

- one latent path
- one raw noise draw

Tau-specific series are created by subtracting family/tau-specific quantile shifts from the same raw noise draw. This preserves the earlier study logic where `mu_t` is shared across tau within family.

### 4. Keep the Gaussian-mixture family numerically explicit

For `gausmix`, the quantile-centering shift is solved numerically from the mixture CDF with a widening root bracket. This keeps the tau-centering rule exact enough without introducing an external dependency.

## Validation run during implementation

Focused tests:

```bash
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-qdesn-dynamic-candidate-dataset-config.R", reporter = testthat::StopReporter$new())'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-qdesn-dynamic-candidate-dataset-audit.R", reporter = testthat::StopReporter$new())'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-qdesn-dynamic-candidate-last5000-last500-audit.R", reporter = testthat::StopReporter$new())'
```

Generation and audit:

```bash
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_refresh.R --prepare-only
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_refresh.R
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_audit.R
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_candidate_last5000_last500_audit.R
```

## Small bug fixes made during rollout

### Scalar tau-label bug

The first full generation pass exposed that the helper tau-label formatter was scalar-only. It was changed to a vectorized implementation so multi-tau family bundles can be named cleanly.

### Partial-matching bug on `C0`

The helper initially used `$` access for `C0`, which partially matched `C0_scale` on lists. That was corrected to exact `[[..., exact = TRUE]]` extraction so the generator cannot accidentally treat a scalar scale as a full covariance matrix.
