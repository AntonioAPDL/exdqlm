# exDQLM/DQLM VB Promotion and Targeted Screen Plan

Date: 2026-07-03

Worktree:
`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

Branch:
`validation/shared-fitforecast-v2-1.0.0`

Planning HEAD:
`1077465c62ab67908ece707b36395b5d7edb111e`

## Purpose

Decide the safest and most efficient next step after the exDQLM/DQLM VB
forecast-confirmation run, while keeping the Q-DESN plus exDQLM/DQLM
fit+forecast validation reproducible, storage-light, and article-facing only
when evidence is complete enough for the claim being made.

The main decision is not "launch MCMC now". The current evidence says:

1. some exDQLM/DQLM VB rows are much better than the old Article-facing baseline;
2. the improvement is confirmed for only seven model/family/tau cells;
3. Q-DESN remains stronger or essentially tied in several forecast metrics;
4. laplace left-tail remains diagnostically fragile;
5. broad exDQLM/DQLM MCMC would be premature.

## Evidence Audited

Validation repo state:

```text
branch: validation/shared-fitforecast-v2-1.0.0
upstream: origin/validation/shared-fitforecast-v2-1.0.0
latest pushed commit: 1077465 Add VB overlap audit for exDQLM DQLM confirmation
status before this plan: clean
```

Primary run root:

```text
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen
```

Healthcheck evidence:

```text
status_counts: done 21, fit_done 91, pending 176
health_gates: PASS 112
telemetry_states: completed 21, fit_done 91, pending 176
storage: PASS, 1693 files, 3453835817 bytes, forbidden_payloads 0
shared_interface_rows: 721
```

Tracked overlap audit:

```text
validation/fitforecast_v2/docs/EXDQLM_DQLM_QDESN_VB_OVERLAP_AUDIT_2026-07-03.md
validation/fitforecast_v2/docs/exdqlm_dqlm_qdesn_vb_overlap_comparison_20260703.csv
validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_qdesn_vb_overlap.R
```

Article-facing read-only input checked:

```text
/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv
/data/jaguir26/local/src/Article-Q-DESN/application/config/shared_validation_tt500_final_fitforecast.yaml
/data/jaguir26/local/src/Article-Q-DESN/application/scripts/31_build_shared_validation_tt500_final_tables.R
/data/jaguir26/local/src/Article-Q-DESN/application/scripts/32_audit_shared_validation_tt500_vb_competitiveness.R
```

Important Article repo caveat:

```text
/data/jaguir26/local/src/Article-Q-DESN
branch: application-ensemble-likelihood-redesign
state: dirty with unrelated Article/GloFAS/joint-QVP work
action here: read-only audit only; do not touch those unrelated files
```

## Diagnosis

### What improved

The confirmed exDQLM/DQLM VB winners all use:

```text
c13_trend100_season1_df0995s099
trend_C0_scale = 100
seasonal_C0_scale = 1
df_value = 0.995,0.99
dim_df = 2,4
```

Confirmed overlap cells:

| Model | Family | Tau | Candidate | Fit RMSE | Forecast MAE | Forecast check |
| --- | --- | ---: | --- | ---: | ---: | ---: |
| DQLM | gausmix | 0.50 | `c13_trend100_season1_df0995s099` | 1.598 | 1.840 | 5.541 |
| exDQLM | gausmix | 0.50 | `c13_trend100_season1_df0995s099` | 1.595 | 1.859 | 5.542 |
| DQLM | laplace | 0.05 | `c13_trend100_season1_df0995s099` | 4.591 | 3.644 | 1.868 |
| exDQLM | laplace | 0.05 | `c13_trend100_season1_df0995s099` | 8.498 | 9.354 | 2.146 |
| DQLM | normal | 0.25 | `c13_trend100_season1_df0995s099` | 2.404 | 2.513 | 3.371 |
| DQLM | normal | 0.50 | `c13_trend100_season1_df0995s099` | 1.923 | 1.109 | 4.022 |
| exDQLM | normal | 0.50 | `c13_trend100_season1_df0995s099` | 1.988 | 1.125 | 4.023 |

The old Article exDQLM/DQLM rows were all exported from:

```text
validation_commit: d075941313186b15853e94c2a2cad7d0fec410d8
article_interface_ids: exdqlm_dqlm
```

In the seven overlap cells, the confirmed c13 rows reduce old Article fit RMSE
by roughly 70% to 95%. Forecast check improves in six of seven overlap rows;
the exception is exDQLM laplace tau 0.05, which worsens relative to the old
Article row and remains a diagnostic weak point.

### What is still incomplete

The confirmation run does not cover 11 of the 18 exDQLM/DQLM VB cells in the
Article summary:

| Model | Family | Tau | Current Article fit RMSE | Current Article forecast MAE | Current Article forecast check |
| --- | --- | ---: | ---: | ---: | ---: |
| DQLM | gausmix | 0.05 | 37.172 | 9.151 | 1.695 |
| exDQLM | gausmix | 0.05 | 35.754 | 5.410 | 1.572 |
| DQLM | gausmix | 0.25 | 32.273 | 3.696 | 4.745 |
| exDQLM | gausmix | 0.25 | 31.720 | 3.705 | 4.741 |
| DQLM | laplace | 0.25 | 23.703 | 4.494 | 4.669 |
| exDQLM | laplace | 0.25 | 22.606 | 5.136 | 4.725 |
| DQLM | laplace | 0.50 | 24.200 | 2.831 | 5.322 |
| exDQLM | laplace | 0.50 | 23.785 | 2.812 | 5.320 |
| DQLM | normal | 0.05 | 28.652 | 7.007 | 1.218 |
| exDQLM | normal | 0.05 | 26.881 | 3.387 | 1.109 |
| exDQLM | normal | 0.25 | 25.724 | 2.420 | 3.378 |

Those rows are still stale relative to the calibrated c13 evidence. Promoting
only the seven confirmed rows is useful for transparency, but it would leave an
uneven table: some exDQLM/DQLM rows would be current c13 confirmations while
others would remain old d0759413 baselines.

### Why broad MCMC is not optimal now

Broad MCMC would spend the largest compute budget before the VB baseline is
settled. That is backwards for this study.

The current evidence supports at most narrow MCMC consideration for:

```text
dqlm / normal / tau = 0.50
exdqlm / normal / tau = 0.50
```

Those two cells are the only overlap rows that pass the conservative narrow
MCMC rule in the tracked audit. Even there, the action should wait until the
VB table is made internally coherent across all exDQLM/DQLM cells.

### Why a targeted c13-first VB run is optimal

The missing-cell problem has a low-cost first answer: run the same c13 candidate
that won every confirmed overlap cell, but only in the 11 missing cells.

This requires no new branch, no new source registry, and no new architecture.
It reuses the existing manifest and row configs. The launcher can target exact
row IDs and run `--validation-stage all`, so each pending c13 row will fit,
forecast, write scalar summaries, and prune transient fit handoffs on success.

The exact c13 missing-cell row IDs are:

```text
14,30,46,62,142,158,174,190,206,222,254
```

They map to:

| Row ID | Model | Family | Tau |
| ---: | --- | --- | ---: |
| 14 | DQLM | gausmix | 0.05 |
| 30 | exDQLM | gausmix | 0.05 |
| 46 | DQLM | gausmix | 0.25 |
| 62 | exDQLM | gausmix | 0.25 |
| 142 | DQLM | laplace | 0.25 |
| 158 | exDQLM | laplace | 0.25 |
| 174 | DQLM | laplace | 0.50 |
| 190 | exDQLM | laplace | 0.50 |
| 206 | DQLM | normal | 0.05 |
| 222 | exDQLM | normal | 0.05 |
| 254 | exDQLM | normal | 0.25 |

This is the next compute action I recommend before any Article table promotion
that claims an updated exDQLM/DQLM VB baseline.

## Recommended Plan

### Step 1: Freeze the current overlap audit as evidence

Status: done.

The overlap audit is tracked and pushed at commit `1077465`. It documents what
is confirmed now and which cells remain unconfirmed. Do not overwrite it.

### Step 2: Run a dry-run for c13 missing-cell fit+forecast

Command:

```bash
ids="14,30,46,62,142,158,174,190,206,222,254"

Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv \
  --phase vb_full \
  --validation-stage all \
  --row-ids "$ids" \
  --workers 6 \
  --dry-run
```

Expected dry-run:

- `selected_rows: 11`
- all rows have candidate `c13_trend100_season1_df0995s099`
- all rows are currently `pending`
- commands use `--validation-stage 'all'`

Observed planning dry-run:

```text
selected_rows: 11
row_ids: 14,30,46,62,142,158,174,190,206,222,254
validation_stage: all
dry_run: TRUE
```

The printed dry-run commands target only the 11 expected row config files:
`row_0014`, `row_0030`, `row_0046`, `row_0062`, `row_0142`,
`row_0158`, `row_0174`, `row_0190`, `row_0206`, `row_0222`, and
`row_0254`.

### Step 3: Launch c13 missing-cell VB confirmation only after dry-run passes

Command:

```bash
ids="14,30,46,62,142,158,174,190,206,222,254"

EXDQLM_FFV2_LAUNCH_APPROVED=true Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv \
  --phase vb_full \
  --validation-stage all \
  --row-ids "$ids" \
  --workers 6
```

Use `6` workers first. These are VB runs, but each row still builds dynamic
state summaries and forecasts. Six workers should keep the run efficient while
avoiding avoidable memory and I/O pressure.

Do not use `--force`.

### Step 4: Healthcheck and summarize

Command:

```bash
Rscript validation/fitforecast_v2/scripts/healthcheck_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv
```

Expected after success:

- additional `done` rows: 11
- no new `failed_runtime` rows
- health gates remain PASS for completed rows
- storage audit remains PASS
- forbidden binary payloads remain 0
- shared interface includes all 11 new c13 rows with fit and forecast metrics

### Step 5: Re-run the overlap audit and extend it to full VB coverage

The current audit compares only confirmed overlap rows. After c13 missing-cell
completion, add a second audit output:

```text
validation/fitforecast_v2/docs/exdqlm_dqlm_qdesn_vb_full_c13_comparison_YYYYMMDD.csv
validation/fitforecast_v2/docs/EXDQLM_DQLM_QDESN_VB_FULL_C13_AUDIT_YYYYMMDD.md
```

That audit should answer:

- Do all 18 exDQLM/DQLM VB cells now have current c13 evidence?
- Which c13 rows beat old Article exDQLM/DQLM baselines?
- Which c13 rows are competitive with Q-DESN by fit RMSE, forecast MAE, and
  forecast check?
- Which cells still require candidate expansion?
- Is laplace left-tail still weak after c13?

### Step 6: Promote only if the full c13 audit clears promotion gates

Promotion gates:

- row status `done`
- health gate `PASS`
- storage audit `PASS`
- no forbidden binary payloads
- source registry hash unchanged:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- fit size 500 only
- rolling-origin protocol unchanged:
  `max_lead_configured = 30`, `origin_stride = 30`
- Article summary rows identify the new validation commit/run evidence
- stale rows from `d0759413` are not silently mixed with current rows without
  an explicit `evidence_status` or `article_interface_ids` distinction

Recommended Article integration design:

- add an exDQLM/DQLM override block in
  `/data/jaguir26/local/src/Article-Q-DESN/application/config/shared_validation_tt500_final_fitforecast.yaml`;
- point it to a tracked validation-side promotion/audit CSV or to the run
  interface with exact row-level replacement keys;
- require hashes for every consumed CSV;
- update `application/scripts/31_build_shared_validation_tt500_final_tables.R`
  only if necessary to support exDQLM/DQLM cell-level overrides symmetrically
  with the existing Q-DESN override machinery;
- update `application/scripts/32_audit_shared_validation_tt500_vb_competitiveness.R`
  so it can report evidence status rather than treating old and current
  exDQLM/DQLM rows as equally fresh.

Do not patch final Article table CSVs by hand.

### Step 7: If c13 fails cells, run a small challenger screen

Only expand candidates for cells where c13 is still weak. The predeclared
low-cost challenger set is:

```text
c11_trend100_season1_df0995
c12_trend100_season10_df0995
c13_trend100_season1_df0995s099
```

Exact row IDs for c11/c12/c13 in the 11 missing cells:

```text
12,13,14,28,29,30,44,45,46,60,61,62,140,141,142,156,157,158,172,173,174,188,189,190,204,205,206,220,221,222,252,253,254
```

This challenger set is intentionally small. It tests whether the persistent
trend discount alone is enough, whether extra seasonal prior flexibility helps,
or whether c13 remains the best balance. Do not re-run all 16 candidates unless
the small challenger set fails.

### Step 8: Defer MCMC until the VB baseline is coherent

MCMC decision rule:

- no broad MCMC until all exDQLM/DQLM VB cells have either current c13 evidence
  or an explicit unresolved-cell label;
- narrow MCMC may be considered only for cells where VB is competitive against
  Q-DESN and the Article needs a matched MCMC counterpart;
- current narrow candidates are only:
  `dqlm/normal/0.50` and `exdqlm/normal/0.50`;
- laplace left-tail should receive VB calibration first, not MCMC.

## Decision Matrix

| Option | Verdict | Reason |
| --- | --- | --- |
| Promote seven confirmed rows immediately | Defer | Useful evidence, but creates mixed fresh/stale exDQLM/DQLM VB table unless evidence status is explicit. |
| Run c13 in 11 missing cells | Recommended next compute | Uses the winning confirmed candidate, exact row targeting, and existing staged launcher. |
| Run c11/c12/c13 challengers in 11 missing cells | Conditional fallback | Good small expansion if c13 does not clear the full-cell audit. |
| Re-run all 16 candidates in all 18 cells | Not now | Wasteful; c13 already dominates confirmed overlap cells. |
| Launch broad exDQLM/DQLM MCMC | Reject | VB baseline is not complete/coherent yet. |
| Launch narrow normal-median MCMC now | Defer | Plausible later, but wait until c13 missing-cell audit is complete. |
| Modify the exdqlm 1.0.0 package branch | Reject | Existing harness can run the needed work without changing package code. |

## Reproducibility Commands

Current healthcheck:

```bash
Rscript validation/fitforecast_v2/scripts/healthcheck_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv
```

Current overlap audit regeneration:

```bash
Rscript validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_qdesn_vb_overlap.R
```

Current Article read-only competitiveness check:

```bash
Rscript /data/jaguir26/local/src/Article-Q-DESN/application/scripts/32_audit_shared_validation_tt500_vb_competitiveness.R \
  --input-csv /data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv \
  --out-csv /tmp/qdesn_validation_tt500_vb_competitiveness_audit.csv
```

## Final Recommendation

The optimal next move is:

1. dry-run the 11 missing-cell c13 rows;
2. launch those 11 rows if the dry-run selects exactly the expected rows;
3. healthcheck and storage-audit the run;
4. generate a full c13-versus-Q-DESN audit across all 18 exDQLM/DQLM VB cells;
5. only then decide whether to promote exDQLM/DQLM VB rows into Article-facing
   tables;
6. defer MCMC except possibly narrow normal-median follow-up after the full VB
   audit.

This path is the best balance of rigor, speed, and reproducibility. It avoids
premature MCMC, avoids table-level evidence mixing, and uses the existing
failure-explicit shared validation harness.
