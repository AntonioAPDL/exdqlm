# Broad VB Screening Plan for exDQLM/DQLM and Q-DESN RHS

Date: 2026-07-04

## Purpose

This screening round is a VB-first calibration layer before any new heavy MCMC work. It keeps the exdqlm 1.0.0 package API unchanged and explores only external validation specifications.

The scientific target is twofold:

- exDQLM/DQLM: find VB evolution specifications where exDQLM is competitive with, or better than, DQLM under the shared rolling-origin validation protocol.
- Q-DESN RHS: find family- and quantile-specific RHS DESN profiles where AL and exAL RHS are competitive with the current Q-DESN best rows.

## Shared Evaluation Contract

- package baseline: exdqlm 1.0.0
- validation branch: `validation/shared-fitforecast-v2-1.0.0`
- fit size: 500 observations
- forecast protocol: rolling origin
- maximum lead: 30
- origin stride: 30
- forecast scoring window: 1000 observations
- storage policy: scalar metrics, lead summaries, logs, manifests, status/health/telemetry only; no routine successful fit payload retention

## exDQLM/DQLM Lane

Candidate registry:

`validation/fitforecast_v2/config/exdqlm_dqlm_vb_noninferiority_screen_candidates_20260704.csv`

Orchestrator:

`validation/fitforecast_v2/scripts/orchestrate_exdqlm_dqlm_vb_noninferiority_screen.R`

Summary:

`validation/fitforecast_v2/scripts/summarize_exdqlm_dqlm_vb_noninferiority_screen.R`

The screen evaluates 25 candidate evolution specifications across all 18 DQLM/exDQLM model-family-tau cells. The full manifest contains 450 rows. Ranking is cellwise by lead-weighted rolling-origin forecast check loss, with forecast MAE and fit RMSE as tie breakers.

## Q-DESN RHS Lane

Materializer:

`scripts/materialize_qdesn_tt500_vb_rhs_optimization_screen.R`

Orchestrator:

`scripts/orchestrate_qdesn_tt500_vb_rhs_optimization_screen.R`

Materialized config:

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization_cell_assignments.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization_materialization_manifest.json`

The current materialization contains 48 profile rows, 432 selected Q-DESN roots, and both AL and exAL RHS likelihood lanes. Ranking and dominance audits run automatically after a full successful Q-DESN screen.

## Gates Before Full Launch

1. exDQLM/DQLM candidate dry-run must report 450 manifest rows and 175 sentinel rows.
2. exDQLM/DQLM prepare must write a manifest under `validation/fitforecast_v2/runs/<run_tag>/manifests/row_manifest.csv`.
3. exDQLM/DQLM smoke must run a small normal/tau=0.05 subset across DQLM and exDQLM.
4. Q-DESN RHS materialization must report 432 expected roots.
5. Q-DESN RHS prepare-only must pass.
6. Q-DESN RHS smoke must pass before the full screen is allowed.

## Gate Evidence Before Background Launch

Observed on 2026-07-04 before committing this screening layer:

- exDQLM/DQLM dry-run: 25 candidates, 450 manifest rows, 175 sentinel rows, source window verification PASS.
- exDQLM/DQLM prepare+smoke run tag: `20260704_exdqlm_dqlm_vb_noninferiority_gate_20260704`.
- exDQLM/DQLM smoke status: 4 selected rows done/PASS; exported shared interface has 120 lead rows; storage audit PASS with zero forbidden payloads.
- Q-DESN RHS materialization: 48 profiles, 432 selected roots, 432 expected Q-DESN roots.
- Q-DESN RHS prepare-only status: PASS.
- Q-DESN RHS smoke run tag: `qdesn-tt500-vb-rhs-optimization-smoke-gate-20260704`; status PASS for the smoke root across AL and exAL RHS.
- Smoke payload check: no `.rds`, `.rda`, `.RData`, or `__design.rds` files were found under the smoke output roots.

## Background Launch Shape

Use bounded worker counts while unrelated GloFAS/QVP tasks are active.

Suggested split on the current 64-core host:

- exDQLM/DQLM VB non-inferiority screen: 10 to 12 workers
- Q-DESN RHS VB optimization screen: 12 to 16 workers

This gives both screens meaningful parallelism while leaving room for existing active jobs.

## Non-Goals

- Do not launch new MCMC from this screen.
- Do not alter exdqlm 1.0.0 package internals.
- Do not promote candidates to Article-facing tables until each lane completes, passes health/storage checks, and receives a separate promotion/materialization step.
