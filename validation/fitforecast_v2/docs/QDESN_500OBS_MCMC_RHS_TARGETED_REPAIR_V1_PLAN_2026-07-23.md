# Q-DESN 500-Observation MCMC RHS Targeted Repair v1

Date: 2026-07-23

Worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

Branch: `validation/shared-fitforecast-v2-1.0.0`

## Purpose

This stage is a targeted full-MCMC repair for independent single-quantile Q-DESN and exQ-DESN RHS cells whose current article-facing MCMC evidence is either missing a clean current-protocol exAL row, has a median forecast gap, or leaves a tail AL gap.

The goal is not to replace the full validation protocol. The goal is to generate MCMC evidence for a scientifically focused, diversified set of DESN specifications so that any promotion to article tables is based on MCMC behavior rather than assuming VB rankings transfer to MCMC.

## Current Evidence That Motivates This Stage

The current-best MCMC evidence was materialized at:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_mcmc_current_best_20260723`

Key diagnostic facts:

- Q-DESN/exQ-DESN RHS is competitive for several 0.05 and 0.25 cells.
- Median cells remain weak relative to DQLM/exDQLM, especially normal and laplace.
- Current-protocol exAL is missing clean rows for gausmix 0.25 and normal 0.25.
- Previous very large D/n/m/rho expansions frequently had poor MCMC signoff or high runtime.
- Compact D=1 designs have the best observed MCMC cleanliness; exAL failures are mainly high autocorrelation and half-chain drift.

## Target Cell-Likelihoods

This stage targets ten gaps:

| Family | tau | Likelihood | Reason |
|---|---:|---|---|
| gausmix | 0.05 | exAL | current-protocol refresh of legacy clean fallback |
| gausmix | 0.25 | exAL | missing clean current-protocol exAL |
| gausmix | 0.50 | AL | median forecast gap |
| gausmix | 0.50 | exAL | median forecast gap / current-protocol refresh |
| laplace | 0.50 | AL | median forecast gap |
| laplace | 0.50 | exAL | median forecast gap / current-protocol refresh |
| normal | 0.05 | AL | tail AL gap |
| normal | 0.25 | exAL | missing clean current-protocol exAL |
| normal | 0.50 | AL | median forecast gap |
| normal | 0.50 | exAL | median forecast gap / current-protocol refresh |

## v1b Repair and Expanded Arm Design

The first full v1 attempt was stopped after an explicit failure audit. The tag
`qdesn-tt500-mcmc-rhsrepair-v1-full-20260723__git-cad213a` is diagnostic only
and must not be consumed: default JSON precision wrote `rhs_tau0 = 3e-05` as
`0`, triggering the package-side `RHS_NS hypers$tau0 must be > 0` guard.

The repaired v1b stage keeps the original anchors and the original seven
expansion arms, patches JSON writing to preserve small numeric values, adds an
explicit RHS tau0 post-override guard, and expands the DESN arm catalog into
new depth/width/memory regions that had not been covered in the first MCMC
repair launch.

Each target gets thirteen full-MCMC arms:

| Arm | Purpose |
|---|---|
| `a_current_anchor` | Preserve the best/current compact anchor or the most informative failed compact profile for that cell. |
| `b_d1_mem12` | Medium-memory shallow stability check. |
| `c_d1_mem36_lowtau` | Wider shallow low-tau memory expansion. |
| `d_d1_mem90_highrho` | Long-memory, low-alpha, high-rho persistence challenge. |
| `e_d2_mem24` | Bounded depth-two medium-memory expansion. |
| `f_d2_mem60_lowtau` | Depth-two longer-memory low-tau expansion. |
| `g_d2_mem90_highrho` | Depth-two long-memory, high-rho challenge. |
| `h_d3_mem45_wide_lowtau` | Depth-three width/memory expansion inside the p/n gate. |
| `i_d3_mem90_sparse_highrho` | Depth-three full-memory sparse high-rho persistence. |
| `j_d4_mem60_sparse_stack` | Depth-four medium-memory sparse stack. |
| `k_d2_mem36_dense_input` | Depth-two wider dense-input bridge. |
| `l_d1_mem75_ultrasparse` | Wide shallow long-memory ultra-sparse high-rho probe. |
| `m_d4_mem90_deep_guard` | Depth-four full-memory guarded capacity expansion. |

This gives 130 selected roots/specs. Each root is run for exactly one target likelihood via `execution$allowed_fit_spec_ids`, avoiding accidental AL+exAL duplication.

## Source Contract

The stage uses the frozen source materialization:

`results/qdesn_mcmc_validation/dynamic_fitforecast_v2_qdesn_sources_period90_m90_w300`

Contract:

- scenario: `dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`
- families: `gausmix`, `laplace`, `normal`
- taus: `0.05`, `0.25`, `0.50`
- fit size: `500`
- forecast horizon: `1000`
- max readout lag/memory in this stage: `90`

The stage intentionally does not test m > 90. Doing so would require a separate source-registry extension and should not be mixed into this current-protocol repair run.

## Execution Contract

Full MCMC:

- `n_burn = 5000`
- `n_mcmc = 20000`
- `thin = 1`
- `progress_every = 50`
- `init_from_vb = TRUE`
- `require_init_from_vb = TRUE`
- one core/thread per root
- load-balanced root scheduler

Storage policy:

- keep scalar fit metrics
- keep scalar rolling-origin forecast metrics
- keep compact fit path summaries
- keep logs, configs, manifests, status
- do not retain successful heavy draw or forecast objects
- do not promote until strict audit passes

## Files

Materializer:

`scripts/materialize_qdesn_tt500_mcmc_rhs_targeted_repair_v1.R`

Orchestrator:

`scripts/orchestrate_qdesn_tt500_mcmc_rhs_targeted_repair_v1.R`

Historical v1 generated config files:

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1_cell_assignments.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1_target_spec_ids.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1_materialization_manifest.json`

Repaired v1b generated config files:

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1b_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1b_cell_assignments.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1b_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1b_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1b_target_spec_ids.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1b_materialization_manifest.json`

## Launch Sequence

Use materialize, prepare, smoke, then detached full launch:

```bash
Rscript scripts/orchestrate_qdesn_tt500_mcmc_rhs_targeted_repair_v1.R --stage-file qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1b --workers 16 --prepare-only
Rscript scripts/orchestrate_qdesn_tt500_mcmc_rhs_targeted_repair_v1.R --stage-file qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1b --workers 16 --skip-materialize --skip-prepare --smoke
Rscript scripts/orchestrate_qdesn_tt500_mcmc_rhs_targeted_repair_v1.R --stage-file qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1b --workers 16 --skip-materialize --skip-prepare --skip-smoke --full --launch-approved --run-tag qdesn-tt500-mcmc-rhsrepair-v1b-full-20260723 --tmux-session qdesn_tt500_mcmc_rhsrepair_v1b_20260723
```

The recommended default is 16 workers while unrelated active jobs are running. If the machine is otherwise clear, 20 to 24 workers is supported by the stage.

## Promotion Rule

This stage is not article-facing by launch. Promotion requires:

1. completion or explicit closeout of all 130 v1b target specs;
2. strict success/failure/status audit;
3. storage-heavy artifact audit;
4. comparison against current-best DQLM/exDQLM and Q-DESN/exQ-DESN MCMC tables;
5. explicit promotion manifest before any article table update.
