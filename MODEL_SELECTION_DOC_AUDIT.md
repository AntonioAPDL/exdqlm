# Model Selection Doc Audit (v2 Prep)

## Scope checked
- `model_selection_documentation.txt`
- QDESN/DESN repo structure and existing (legacy) model-selection files

## Key updates applied
- **CalCRPS-only redesign:** Calibration now defined exclusively via CalCRPS from coverage draws.
- **Objective updated:** Constrained and weighted objectives now use CalCRPS (mean or max), no CalRMSE.
- **Planned output schemas:** Added `tables/calibration_by_tau.csv` and `tables/calibration_summary.csv` definitions.
- **Stage definitions:** Added explicit coarse/final multi-fidelity defaults.
- **Deprecation decision:** Legacy model-selection scripts are explicitly marked as deprecated for v2.
- **v2 plan:** New file locations specified (`R/qdesn_model_selection_v2.R`, `scripts/qdesn_model_selection_v2_main.R`, `R/model_selection_utils_v2.R`).

## Assumptions / open items
- CalCRPS is planned only; no repo code currently computes it.
- CRPS_synth remains sourced from `tables/metrics_summary.csv`.
- v2 implementation will ignore legacy model-selection scripts.
