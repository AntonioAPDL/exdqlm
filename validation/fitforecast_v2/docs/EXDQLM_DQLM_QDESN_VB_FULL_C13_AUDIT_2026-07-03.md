# exDQLM/DQLM and Q-DESN Full c13 VB Audit

Date: 2026-07-03

## Scope

This audit evaluates the current c13 exDQLM/DQLM VB evidence after the missing-cell fit+forecast launch. It covers all 18 exDQLM/DQLM VB model/family/tau cells at fit size 500 and compares them against the current Article-facing Q-DESN VB rows and the older Article exDQLM/DQLM baseline rows.

## Inputs

- validation worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- validation branch: `validation/shared-fitforecast-v2-1.0.0`
- validation HEAD at audit generation: `10ef52920b8d77de9c01d05efd0db2939c70f4e6`
- validation HEAD subject: `Plan exDQLM DQLM VB promotion and targeted screen`
- shared interface: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/interfaces/exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv`
- Article-facing summary read-only input: `/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv`
- cleanup manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/storage/prune_c13_missing_cell_fit_handoffs_20260703.csv`
- reproducible CSV output: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/exdqlm_dqlm_qdesn_vb_full_c13_comparison_20260703.csv`

## Evidence Counts

- current c13 done/PASS cells: `18/18`
- c13 lead rows in interface: `540`
- cells where c13 improves old Article fit RMSE: `18/18`
- cells where c13 improves old Article forecast check: `14/18`
- cells where Q-DESN VB still has lower forecast check than c13: `12/18`
- cells eligible for narrow MCMC follow-up under this audit rule: `6/18`
- cells flagged for challenger screening before MCMC: `4/18`
- newly generated fit handoffs pruned: `11`
- newly generated fit handoff GiB pruned: `1.673`

## Full c13 Comparison

| Family | Tau | Model | Fit RMSE | Forecast MAE | Forecast check | Old forecast check ratio | Q-DESN forecast check ratio | Recommendation |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |
| gausmix | 0.05 | dqlm | 2.725 | 5.169 | 1.610 | 0.950 | 1.028 | promote as coherent current c13 VB baseline; no MCMC |
| gausmix | 0.05 | exdqlm | 4.615 | 9.234 | 1.895 | 1.205 | 1.209 | promote only with evidence-status flag; consider small c11/c12 challenger screen |
| gausmix | 0.25 | dqlm | 1.958 | 4.675 | 4.795 | 1.011 | 1.064 | promote as coherent current c13 VB baseline; no MCMC |
| gausmix | 0.25 | exdqlm | 1.834 | 3.976 | 4.711 | 0.994 | 1.046 | promote as coherent current c13 VB baseline; no MCMC |
| gausmix | 0.50 | dqlm | 1.598 | 1.840 | 5.541 | 0.951 | 1.018 | promote as coherent current c13 VB baseline; no MCMC |
| gausmix | 0.50 | exdqlm | 1.595 | 1.859 | 5.542 | 0.946 | 1.018 | promote as coherent current c13 VB baseline; no MCMC |
| laplace | 0.05 | dqlm | 4.591 | 3.644 | 1.868 | 0.831 | 0.994 | keep as current evidence but run targeted laplace-left-tail VB challenger screen before MCMC |
| laplace | 0.05 | exdqlm | 8.498 | 9.354 | 2.146 | 1.093 | 1.142 | keep as current evidence but run targeted laplace-left-tail VB challenger screen before MCMC |
| laplace | 0.25 | dqlm | 2.125 | 3.123 | 4.485 | 0.961 | 1.014 | promote as coherent current c13 VB baseline; no MCMC |
| laplace | 0.25 | exdqlm | 2.145 | 2.347 | 4.427 | 0.937 | 1.000 | promote as coherent current c13 VB baseline; no MCMC |
| laplace | 0.50 | dqlm | 1.569 | 1.285 | 5.078 | 0.954 | 0.964 | eligible for narrow MCMC follow-up if a matched MCMC counterpart is required |
| laplace | 0.50 | exdqlm | 1.571 | 1.285 | 5.077 | 0.954 | 0.964 | eligible for narrow MCMC follow-up if a matched MCMC counterpart is required |
| normal | 0.05 | dqlm | 2.374 | 1.445 | 1.078 | 0.885 | 0.997 | eligible for narrow MCMC follow-up if a matched MCMC counterpart is required |
| normal | 0.05 | exdqlm | 2.708 | 3.126 | 1.156 | 1.042 | 1.069 | promote only with evidence-status flag; consider small c11/c12 challenger screen |
| normal | 0.25 | dqlm | 2.404 | 2.513 | 3.371 | 0.998 | 1.025 | promote as coherent current c13 VB baseline; no MCMC |
| normal | 0.25 | exdqlm | 2.429 | 2.022 | 3.333 | 0.987 | 1.014 | eligible for narrow MCMC follow-up if a matched MCMC counterpart is required |
| normal | 0.50 | dqlm | 1.923 | 1.109 | 4.022 | 0.970 | 0.986 | eligible for narrow MCMC follow-up if a matched MCMC counterpart is required |
| normal | 0.50 | exdqlm | 1.988 | 1.125 | 4.023 | 0.958 | 0.986 | eligible for narrow MCMC follow-up if a matched MCMC counterpart is required |

## Interpretation

- The c13 specification now gives current, done/PASS VB evidence for every exDQLM/DQLM model/family/tau cell in the fit-size-500 validation table.
- c13 dramatically improves old Article fit RMSE in every exDQLM/DQLM VB cell, but it does not improve old Article forecast check in every cell.
- Q-DESN remains the stronger forecast-check row in a majority of cells, so this audit does not justify broad exDQLM/DQLM MCMC.
- Article promotion is technically possible only with an explicit evidence-status/provenance update; silently mixing old d0759413 rows with current c13 rows is no longer acceptable.
- Cells flagged for challenger screening should be explored with the predeclared small c11/c12 challenger set before any MCMC decision.

## MCMC Recommendation

Narrow MCMC may be considered only after Article-facing VB promotion/audit for: `dqlm/laplace/0.5`, `exdqlm/laplace/0.5`, `dqlm/normal/0.05`, `exdqlm/normal/0.25`, `dqlm/normal/0.5`, `exdqlm/normal/0.5`. Do not launch broad exDQLM/DQLM MCMC.

## Next Recommended Action

Build a cell-level Article promotion override for the current c13 VB evidence only after adding explicit evidence-status fields, or run the small c11/c12 challenger screen for flagged cells first. The stronger validation-first path is to run the challenger screen before changing Article tables.

## Regeneration Command

```bash
Rscript validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_qdesn_vb_full_c13.R
```
