# Model Selection Doc Audit (v2 Prep)

## Scope checked
- `model_selection_documentation.txt`
- QDESN/DESN repo structure and existing (legacy) model-selection files

## Key updates applied
- **CalCRPS-only redesign:** Calibration now defined exclusively via CalCRPS from coverage draws.
- **Clarified draw semantics:** $r$ denotes a joint draw across the evaluation lattice; per-time independence is an approximation.
- **Empirical CalCRPS formula:** Added a minimal formula for CRPS of coverage draws.
- **Coarse search defaults updated:** Ranges aligned to current repo regimes (larger $n$ and $m$).
- **Planned output schemas:** Added `tables/calibration_by_tau.csv` and `tables/calibration_summary.csv` with minimal identifiers.
- **Operational stage defaults:** Coarse/final stages now specify seeds, quantile grids, leads, origins policy, and draw counts.
- **Legacy scripts deprecated:** v2 will ignore legacy model-selection scripts; new file locations are specified.
- **Reuse conventions:** v2 should reuse existing pipeline/manifest/output conventions.

## Assumptions / open items
- CalCRPS is planned only; no repo code currently computes it.
- CRPS_synth remains sourced from `tables/metrics_summary.csv`.
- v2 implementation will ignore legacy model-selection scripts.
