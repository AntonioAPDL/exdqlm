# Q-DESN 500-Observation MCMC Post-v4 Per-cell Redesign Plan

Date: 2026-07-27

Scope: independent Q-DESN / exQ-DESN versus DQLM / exDQLM simulation-validation study only.
This document does not update article tables and does not launch compute.

## Current Evidence

The v4 targeted MCMC screen is complete and storage-light:

`validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727/`

Key facts:

| Item | Value |
|---|---:|
| Planned roots | 75 |
| Completed roots | 75 |
| Failed roots | 0 |
| Metric-wise improvements | 7 |
| Cells with improvements | 6 |
| Unresolved cells after v4 | 15 |
| Retained heavy payloads | 0 |

The source-registry hash remains:

`edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`

## Diagnosis

The last week of MCMC calibration shows real but limited movement. The v4
screen improved a small number of Gaussian-mixture rows and one normal-median
forecast row, but every targeted Q-DESN/exQ-DESN RHS row remains outside the
1.10 external-best tolerance band on at least one metric.

The remaining problem is not a single global DESN specification. The remaining
gap is cell-specific:

| Gap class | Cells |
|---|---:|
| Fit dominated | 7 |
| Forecast dominated | 8 |
| Lower-quantile primary-goal cells | 11 |
| Median/context cells | 4 |

The critical observation is that larger depth, memory, and width did not behave
as a universal rescue. Several v4 winners were anchors or local tau0 probes,
while higher-capacity arms often became diagnostic failures or worsened the
target metric. The next design must therefore be smaller, per-cell, and anchored
in empirical MCMC evidence.

## Implemented Post-v4 Design Bundle

The post-v4 design bundle is:

`validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_postv4_percell_design_20260727/`

Materializer:

`validation/fitforecast_v2/scripts/materialize_qdesn_mcmc_postv4_percell_design_20260727.R`

The bundle mines six historical MCMC ledgers, keeps only independent
Q-DESN/exQ-DESN RHS rows, and builds a case-specific design for the 15 unresolved
cells.

Generated artifacts:

| Artifact | Role |
|---|---|
| `qdesn_tt500_mcmc_postv4_percell_design_20260727_unresolved_cell_diagnostic.csv` | one row per unresolved cell, current metrics, external-best ratios, bottleneck class |
| `qdesn_tt500_mcmc_postv4_percell_design_20260727_historical_candidate_pool.csv` | mined MCMC candidate pool |
| `qdesn_tt500_mcmc_postv4_percell_design_20260727_historical_metric_winners_by_cell.csv` | best historical candidate per cell and metric |
| `qdesn_tt500_mcmc_postv4_percell_design_20260727_historical_coherent_candidates_by_cell.csv` | most balanced historical candidates per cell |
| `qdesn_tt500_mcmc_postv4_percell_design_20260727_candidate_arm_design.csv` | six prepared arms per unresolved cell |
| `qdesn_tt500_mcmc_postv4_percell_design_20260727_launch_review_checklist.csv` | explicit gates before launch |
| `source_manifest.csv` and `file_manifest.csv` | reproducibility hashes |

## Candidate Design

Each unresolved cell receives six arms:

1. replay the historical winner for the bottleneck metric;
2. replay the most coherent historical candidate;
3. local `tau0 = 3e-7` perturbation;
4. local `tau0 = 1e-7` perturbation;
5. axis-specific breakout arm A;
6. axis-specific breakout arm B.

This is deliberately not a global search. The calibration unit is:

`model variant x family x quantile x bottleneck metric`

The current design has 90 arms total, six per unresolved cell. It is capped
below the current v4 p/n exploration gate; the largest proposed
`p_over_n_tt500` is 0.752.

## Why This Is Better Than Another Broad Launch

Another broad launch would repeat the same plateau: larger capacity, low alpha,
high rho, and tighter tau0 can help isolated cells but do not solve the whole
surface. The post-v4 design instead:

1. starts from the actual historical MCMC winners;
2. separates metric-envelope wins from coherent-candidate behavior;
3. keeps fit and forecast cells on different design paths;
4. avoids global-winner assumptions;
5. keeps all launch gates explicit.

## Launch Gate

This materialization intentionally does not create orchestrator configs and does
not launch compute. Before launching, we still need to:

1. review the 90-arm design table;
2. decide whether all 15 cells should launch or only the 11 lower-quantile
   primary-goal cells;
3. materialize run configs from the reviewed design;
4. run a one-cell smoke;
5. launch the reduced-budget MCMC screen only after explicit approval.

## Recommendation

Freeze the v4 closeout and this post-v4 design bundle. The next scientific move
should be a reviewed, per-cell MCMC launch from this design, not another broad
capacity sweep.
