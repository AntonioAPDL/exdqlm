# exDQLM/DQLM VB Targeted Screen Completion

Date: 2026-07-03

## Scope

This note closes the validation-side implementation of the exDQLM/DQLM VB promotion and targeted-screen plan for the fit-size-500 rolling-origin simulation study. It is scoped to the shared validation worktree and does not modify Article, GloFAS, PriceFM, or other active project work.

## Worktree

- worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- run tag: `20260702_exdqlm_dqlm_vb_c0_discount_screen`
- shared interface: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/interfaces/exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv`
- source registry paths remain canonical `/data/jaguir26/local/src` paths.

## Commands Run

Completed the c13 missing-cell launch:

```bash
ids="14,30,46,62,142,158,174,190,206,222,254"
EXDQLM_FFV2_LAUNCH_APPROVED=true Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv \
  --phase vb_full \
  --validation-stage all \
  --row-ids "$ids" \
  --workers 6
```

Completed the c11/c12 challenger launch for predeclared flagged cells:

```bash
ids="28,29,108,109,124,125,220,221"
EXDQLM_FFV2_LAUNCH_APPROVED=true Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv \
  --phase vb_full \
  --validation-stage all \
  --row-ids "$ids" \
  --workers 6
```

Regenerated the c13-only audit:

```bash
Rscript validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_qdesn_vb_full_c13.R
```

Generated the current-best audit:

```bash
Rscript validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_qdesn_vb_current_best.R
```

Post-cleanup healthcheck:

```bash
Rscript validation/fitforecast_v2/scripts/healthcheck_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv
```

## Launch Results

| Stage | Rows | Result |
| --- | ---: | --- |
| c13 missing-cell fit+forecast | 11 | all `done/PASS` |
| c11/c12 challenger fit+forecast | 7 newly launched plus 1 previously complete row | all checked rows `done/PASS` |
| current-best selector | 18 cells | c13 selected for all 18 model/family/tau cells |

The c11/c12 challenger screen did not improve the selected lead-weighted rolling-origin forecast check loss over c13 in any of the audited cells. Therefore the validation-side current-best exDQLM/DQLM VB evidence is the complete c13 grid.

## Healthcheck Evidence

Post-challenger, post-prune healthcheck:

- status counts: `done=39`, `fit_done=88`, `pending=161`
- health gates: `PASS=127`
- telemetry states: `completed=39`, `fit_done=88`, `pending=161`
- storage: `PASS`
- storage audit files/bytes: `1893` / `3470817530`
- forbidden payloads: `0`
- shared interface rows: `1258`
- shared interface path: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/interfaces/exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv`

## Storage Cleanup

Only regenerable successful fit-object handoffs from this validation task were pruned after their compact fit summaries, forecast summaries, forecast lead metrics, status files, logs, and manifests existed.

| Cleanup manifest | Rows | GiB recorded |
| --- | ---: | ---: |
| `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/storage/prune_c13_missing_cell_fit_handoffs_20260703.csv` | 11 | 1.673 |
| `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/storage/prune_c11_c12_challenger_fit_handoffs_20260703.csv` | 7 | 1.086 |
| Total | 18 | 2.759 |

No source code, configs, manifests, compact summaries, logs, promoted docs, or final interface rows were deleted.

## Audit Outputs

- c13-only audit doc: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/EXDQLM_DQLM_QDESN_VB_FULL_C13_AUDIT_2026-07-03.md`
- c13-only audit CSV: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/exdqlm_dqlm_qdesn_vb_full_c13_comparison_20260703.csv`
- current-best audit doc: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/EXDQLM_DQLM_QDESN_VB_CURRENT_BEST_AUDIT_2026-07-03.md`
- current-best audit CSV: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/exdqlm_dqlm_qdesn_vb_current_best_comparison_20260703.csv`

## Decision

The complete c13 VB grid is the validation-side current-best exDQLM/DQLM VB evidence for the fit-size-500 rolling-origin simulation comparison. Article-facing refreshes should not mix old exDQLM/DQLM rows with these new c13 rows unless the table explicitly labels evidence status and provenance.

Broad exDQLM/DQLM MCMC is not recommended from this audit. Narrow MCMC can be considered only for the cells marked eligible in the current-best audit, and only after the Article-facing VB refresh is stable.

## Next Safe Steps

1. Refresh Article-facing validation tables from `exdqlm_dqlm_qdesn_vb_current_best_comparison_20260703.csv`.
2. Keep the old exDQLM/DQLM VB rows available only as historical comparators.
3. Decide whether narrow matched MCMC is worth running for the eligible cells listed in the current-best audit.
4. Do not launch broad exDQLM/DQLM MCMC from this evidence.
