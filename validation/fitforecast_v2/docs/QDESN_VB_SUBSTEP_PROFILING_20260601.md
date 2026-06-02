# Q-DESN VB Substep Profiling

Date: 2026-06-01

## Scope

This note records a package-side promotion from the Article-Q-DESN GloFAS
efficiency pass. The promoted feature is generic opt-in timing for the shared
static Q-DESN/exAL variational readout engine. It does not promote the
GloFAS-specific latent-path algebra, paired `Y/G` row reuse, or application
future-builder shortcuts.

## Public Control

Enable profiling through the existing VB diagnostics block:

```r
vb_args <- list(
  likelihood_family = "al",
  diagnostics = list(profile_substeps = TRUE)
)
fit <- qdesn_fit_vb(y, vb_args = vb_args)
```

The same control is available through `exal_make_vb_control()` and direct
`exal_fit(..., method = "vb")` calls.

## Output Contract

When profiling is enabled, the engine writes a data frame to:

```r
fit$misc$substep_timing
```

Rows are iteration-level timings for generic readout blocks:

- `beta_update`
- `local_v_update`
- `local_s_update`
- `sigmagam_stats`
- `sigmagam_update` when the scale/asymmetry block is active
- `xi_refresh`
- `beta_presteps` when requested
- `beta_prior_update`
- `elbo_initial`
- `rhs_tau_gate`

The table also records likelihood family, chunking mode, and whether exact,
stochastic, or hybrid chunking was active. With profiling disabled, the same
field is an empty data frame and the normalized diagnostics block records
`profile_substeps = FALSE`.

## Promotion Boundary

Promoted to the shared package:

- Generic timing hooks for the static readout VB engine.
- Control propagation from `qdesn_fit_vb()` into `exal_ldvb_engine()`.
- Regression tests that profiling is opt-in and leaves fitted states unchanged.

Kept in Article-Q-DESN:

- GloFAS latent-path two-component block structure.
- Fixed historical `Y/G` row reuse.
- Application future-builder and posterior-path shortcuts.
- Article artifact hygiene and run-promotion helpers.

This boundary keeps the shared package focused on reusable Q-DESN machinery
while preserving application-specific speedups in the article workflow.

## Validation

Focused gates:

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-exal-vb-substep-profiling.R")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-exal-exact-chunking-stats.R")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-qdesn-vb-batching-modes.R")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-exal-batching-controls.R")'
```
