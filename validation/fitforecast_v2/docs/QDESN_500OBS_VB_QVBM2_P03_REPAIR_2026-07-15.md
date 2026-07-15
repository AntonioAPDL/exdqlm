# Q-DESN qvbm2 p03 Safe-Floor Repair

- generated_at: `2026-07-14 20:47:55.364904`
- worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- stage_prefix: `qvbm2p3`
- source_prefix: `qvbm2`
- safe_rhs_tau0: `0.0001`
- index: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qvbm2p3_bundle_index.csv`
- index_manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qvbm2p3_bundle_index_manifest.json`

## Purpose

The original qvbm2 p03 roots all failed with `RHS_NS hypers$tau0 must be > 0.` The p03 structural profile was the strong-shrink check-loss guard, so this repair reruns only that mechanism with a stable lower-bound RHS scale.

## Policy

- Original qvbm2 p03 roots remain untouched and refused.
- This repair uses new profile IDs, new root IDs, new results roots, and new run tags.
- The repair is diagnostic only until closeout and explicit promotion.
- No Article-Q-DESN tables should consume this repair directly.

## Launch

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_mechanism_first_redesign.R --stage-prefix qvbm2p3 --short-path-mode --skip-materialize --skip-audit --workers 16 --full --launch-approved
```

## Materialized Bundles

 bundle_code n_target_specs
         c12              8
        c123              8
                                                                                                 defaults_path
  /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qvbm2p3_c12_defaults.yaml
 /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qvbm2p3_c123_defaults.yaml
                                                                                                grid_path
  /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qvbm2p3_c12_grid.csv
 /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qvbm2p3_c123_grid.csv
