# exdqlm 0.5.0

## New
- Posterior predictive **synthesis** across multiple quantile-specific models:
  - `exdqlm_synthesize_from_draws()` implements isotonic adjustment on anchor quantiles, distributional alignment, piecewise-linear blending, and optional monotone rearrangement to produce a single coherent predictive distribution per time point.
- Diagnostic utilities/recipes (in vignette/examples) for checking quantile crossing, anchor fit, and global monotonicity.

## Changes
- Minor internal cleanups and docs to surface the synthesis workflow alongside `exdqlmLDVB`.

## Notes
- No breaking API changes. Optional C++ backends remain opt-in via `options()`.
