# Run Summary: dlm_constV_smallW (LDVB + synthesis)

- run_start: 2026-02-25 16:44:08 PST
- run_end: 2026-02-25 16:46:52 PST
- output_root: `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/sim_suite_dlm/series/dlm_constV_smallW_workcopy_20260225/fig_esn_quantile_repro`
- method: `exdqlmLDVB`
- p_fit: 0.05, 0.5, 0.95
- split: train=1:4000, forecast=4001:5000

## Key checks
- synthesis anchors monotone: TRUE
- synthesized draws finite: TRUE
- DGP code files present in this branch: FALSE

## Key metrics
- synthesis mean |coverage error| (train): 0.0251
- synthesis mean |coverage error| (forecast): 0.0267
- synthesis mean RMSE vs true quantiles (train): 0.7552
- synthesis mean RMSE vs true quantiles (forecast): 0.6404
- synthesis mean CRPS (train): 1.7477
- synthesis mean CRPS (forecast): 1.6870
- best anchor-model mean CRPS (train): 1.8012
- best anchor-model mean CRPS (forecast): 1.7488

## Notes / limitations
- Train/forecast diagnostics are reported on fixed index slices (1:4000 vs 4001:5000) from the same LDVB-fit draw matrices.
- In this branch, `scripts/sim_suite_dlm.R` and `R/simulate_ts_mc_quantiles.R` are not present; DGP confirmation used `sim_output.rds` + `meta.txt`.

## Artifacts
- tables/: integrity checks, fit summaries, comparison metrics, diagnostics
- figs/: train/forecast quantile comparison and calibration diagnostics
- models/: per-quantile LDVB fits and synthesis objects
- manifest/: tracker progress, config, and run manifest
