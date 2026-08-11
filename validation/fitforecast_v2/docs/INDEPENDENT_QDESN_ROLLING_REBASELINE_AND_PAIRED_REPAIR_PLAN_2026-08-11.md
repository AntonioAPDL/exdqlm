# Independent Q-DESN Rolling Rebaseline and Paired Repair Plan

Date: 2026-08-11

## Scope

This document covers only the independent single-quantile Q-DESN/exQ-DESN and
DQLM/exDQLM fit-and-forecast validation study. It does not authorize changes to
joint-QDESN, PriceFM, GloFAS, or other article/application pipelines.

The immediate objective is to correct the forecast metric contract, identify
the remaining exQ-DESN MCMC gaps using comparable rolling-origin evidence, and
prepare a paired calibration campaign in which candidate designs share both
the simulated source and the reservoir realization.

## Audit Conclusion

The prior article-facing interface mixed two forecast summaries:

- the intended rolling-origin aggregate over targets 9001:10000, leads 1:30,
  and origin stride 30; and
- a scalar horizon summary that did not represent that rolling aggregate.

The raw rolling paths exist and pass the protocol for all 72 Q-DESN forecast
metric roles in the current 72-row interface. Re-derivation found 71 values
that differ from the displayed scalar value. Therefore the existing interface
must not be overwritten automatically, and no new calibration should use its
Q-DESN forecast columns as optimization targets.

The targeted confirmation run also exposed a failure-explicitness defect. Its
six fits completed, but every retention manifest reported:

```text
Q-DESN rolling lead grid could not be mapped to staged source rows.
```

The staged source had reset `t` to local row numbers without retaining the
global source index. The compact exporter swallowed that error, allowing a fit
to appear successful without required rolling artifacts. The source window now
retains both local `t` and global `source_index`, and a required rolling export
failure now fails the job after preserving compact diagnostic metadata.

A second design defect affected candidate comparisons. The earlier development
screen derived the reservoir seed from candidate and source identifiers. Thus
changing the simulated source or candidate also changed the reservoir. A
candidate difference could not be attributed solely to its DESN specification.
The repaired opt-in seed contract derives the reservoir seed from target cell
and `reservoir_seed_id`; source, candidate, and chain seeds remain distinct.

## Frozen Protocol

| Item | Contract |
|---|---|
| Package | exdqlm 1.0.0 |
| MCMC exAL method | `M0_v_collapsed_support_logit` |
| Registry hash | `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275` |
| Training source window | 8501:9000 |
| Forecast source window | 9001:10000 |
| Maximum lead | 30 |
| Origin stride | 30 |
| Refit at each origin | no |
| Required rolling rows | 1000 |
| Required lead rows | 30 |
| Routine binary retention | forbidden |
| Automatic article promotion | forbidden |

## Rebaseline Evidence

Audit root:

```text
reports/shared_fitforecast_v2_orchestration/qdesn_article_rolling_rebaseline_v1_20260811
```

Key outputs:

- `rolling_metric_contract_manifest.json`
- `rolling_metric_contract_audit.csv`
- `qdesn_rederived_rolling_metrics.csv`
- `provisional_rolling_rebaseline_interface.csv`
- `qdesn_comparator_metric_gap_ledger.csv`
- `qdesn_comparator_cell_priority_ledger.csv`

The provisional interface is marked
`PROVISIONAL_NOT_ARTICLE_AUTHORITY`, sets
`article_consumption_allowed=FALSE`, and leaves the promoted interface
unchanged. The audit decision is `BLOCK_AUTOMATIC_ARTICLE_REBASELINE`: this is
an intentional manual-promotion gate, not missing evidence. There are zero
unresolved rows.

Using a 5 percent closeness tolerance, four MCMC Q-DESN/exQ-DESN cells already
win or are close on all three displayed metrics. Fourteen have at least one
remaining gap. The exQ-DESN MCMC cells selected for paired repair are:

| Cell | Primary corrected gap | Current | Comparator | Gap |
|---|---|---:|---:|---:|
| Laplace, p=0.05 | fit RMSE | 6.4090 | 3.6628 (DQLM) | 75.0% |
| Normal, p=0.50 | forecast MAE | 1.9707 | 1.1615 (DQLM) | 69.7% |
| Gaussian mixture, p=0.25 | forecast MAE | 3.3965 | 2.4874 (DQLM) | 36.5% |
| Gaussian mixture, p=0.50 | forecast MAE | 2.5623 | 1.9321 (DQLM) | 32.6% |
| Gaussian mixture, p=0.05 | fit RMSE | 3.3538 | 2.5535 (exDQLM) | 31.3% |
| Normal, p=0.05 | fit RMSE | 2.1493 | 1.9351 (exDQLM) | 11.1% |
| Normal, p=0.25 | forecast MAE | 2.4146 | 2.2086 (DQLM) | 9.3% |

This target set happens to contain the same seven family/quantile cells as the
earlier structural screen, but their forecast values and interpretation are
now corrected.

## Paired Repair Design

The next campaign is a transfer audit, not another unstructured broad screen.
For each target cell it compares:

1. the current authoritative per-cell anchor specification; and
2. the prior structural screen finalist.

Both designs are run on each of three development sources (`dev09`, `dev10`,
`dev11`) and two reservoir realizations (`r01`, `r02`). Within a
target/source/reservoir block the source latent seed, source noise seed, and
reservoir seed are identical across the two designs. MCMC and VB warm-start
seeds remain design- and chain-specific.

This yields 42 paired blocks and 84 calibration jobs. The calibration budget is
200 burn-in plus 500 retained iterations per job. This budget is for ranking
transfer behavior only; it is not article-confirmation evidence. A winner must
show a paired improvement across sources and reservoirs before receiving a
full-budget canonical-source confirmation.

All three article metrics are evaluated in every paired block: fit RMSE,
rolling-origin forecast MAE, and rolling-origin forecast check loss. Selection
is metric-specific. A finalist metric advances when all six paired blocks are
present, its mean and median paired deltas are strictly below zero, and it wins
at least four of six blocks. There is no minimum effect-size threshold: every
finite paired-consistent gain, however small, is retained for canonical
confirmation. This does not turn calibration evidence into article evidence.

No sealed source is used during calibration. `dev12` remains reserved for a
later gate and is not materialized into the calibration plan.

## Implementation

Tracked contract:

```text
config/validation/qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_paired_rolling_repair_v1.json
```

Tracked scripts:

```text
validation/fitforecast_v2/scripts/audit_qdesn_article_rolling_metric_contract_v1.R
validation/fitforecast_v2/scripts/materialize_independent_exal_m0_paired_rolling_repair_v1.R
validation/fitforecast_v2/scripts/verify_independent_exal_m0_paired_rolling_repair_v1.R
validation/fitforecast_v2/scripts/healthcheck_independent_exal_m0_paired_rolling_repair_v1.R
validation/fitforecast_v2/scripts/closeout_independent_exal_m0_paired_rolling_repair_v1.R
validation/fitforecast_v2/scripts/launch_independent_exal_m0_paired_rolling_repair_v1.sh
```

Materialization root:

```text
reports/shared_fitforecast_v2_orchestration/independent_exal_m0_paired_rolling_repair_v1_materialization
```

Materialization result:

```text
targets=7
smoke_jobs=2
calibration_jobs=84
paired_groups=42
launch_state=PREPARED_NOT_APPROVED_NOT_LAUNCHED
```

Both smoke and calibration static verification pass. The calibration launcher
also refuses to run without `QDESN_PAIRED_REPAIR_APPROVAL=YES` and enforces a
20-worker maximum. It additionally requires a clean synchronized branch,
holds a campaign lock, waits for load/memory/disk/idle-core gates, pins the
worker pool to 20 currently idle cores, forces one thread per fit, writes a
30-minute resource heartbeat and health snapshot, and supports same-tag resume
without repeating matching successful jobs.

## Smoke Evidence

Run tag:

```text
ind-exal-m0-paired-rolling-repair-v1-smoke-20260811_023024
```

The smoke compares the Normal p=0.25 anchor and prior finalist on `dev09` and
reservoir `r01`, using one core per job. Both jobs pass. Each has 1000 rolling
rows, 30 lead rows, finite rolling MAE/check loss, a passing retention
manifest, and zero retained binary payloads. The result root is approximately
2.9 MB.

The smoke values are implementation evidence only: 2.7467 for the anchor and
2.5451 for the prior finalist. Four burn-in and four retained iterations are
not sufficient for scientific selection.

## Promotion Gates

The following sequence is mandatory:

1. Re-run the rolling rebaseline and require zero unresolved evidence rows.
2. Re-materialize and require static verification for all 84 jobs.
3. Require the paired smoke to pass exactly as above.
4. Obtain explicit approval before launching calibration.
5. Rank each of the three metrics within each cell using paired
   source/reservoir contrasts; do not select a global specification. A metric
   advances only when all six paired blocks are present, its mean and median
   paired deltas are below zero, and it wins at least four of six blocks.
6. Require a consistent metric improvement relative to the current per-cell
   anchor. The minimum accepted gain is zero, so every strict improvement is
   retained. Diagnostic flags remain visible but do not replace metric
   evidence.
7. Run only selected per-cell winners at full budget on the canonical article
   source with multiple chains.
8. Promote only metrics that improve the existing value and pass the rolling
   evidence contract. Preserve the old value otherwise.
9. Rebuild the interface and article tables only after an explicit manual
   promotion decision.

## Commands

Rebuild and verify without compute:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/audit_qdesn_article_rolling_metric_contract_v1.R \
  --output-root reports/shared_fitforecast_v2_orchestration/qdesn_article_rolling_rebaseline_v1_20260811

/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/materialize_independent_exal_m0_paired_rolling_repair_v1.R

/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/verify_independent_exal_m0_paired_rolling_repair_v1.R \
  --plan calibration_plan.csv
```

The next compute command is intentionally gated and must not be run without
explicit approval:

```bash
QDESN_PAIRED_REPAIR_APPROVAL=YES \
  bash validation/fitforecast_v2/scripts/launch_independent_exal_m0_paired_rolling_repair_v1.sh \
  --mode calibration --workers 20
```

During an approved run, the compact health table is regenerated with:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/healthcheck_independent_exal_m0_paired_rolling_repair_v1.R \
  --mode calibration --run-tag RUN_TAG
```

After all jobs and rolling artifacts verify, the launcher automatically writes
paired contrasts, a 21-row cell-by-metric selection ledger, a backward-compatible
seven-row primary-objective ledger, and deduplicated confirmation profiles. It
does not launch canonical confirmation or update the article.

The approved overnight calibration tag is:

```text
ind-exal-m0-paired-rolling-repair-v1-calibration-20260811_overnight_v1
```

The unattended run ends after paired closeout. This is the scientifically safe
automation boundary because the number and identity of full-budget candidates
are data-dependent. Canonical 5,000-burn/20,000-retained confirmation remains a
separate explicit launch after reviewing the paired ledger.

## Current Decision

The implementation, smoke contract, and overnight orchestration are ready. The
84-job calibration campaign has explicit user approval for the fixed overnight
tag above. The article-facing interface remains unchanged by this campaign;
only later canonical full-budget results can replace article metrics.

## Authoritative Rolling-Metric Promotion

The reviewed protocol correction is materialized separately from the paired
calibration campaign. The promotion builder pins the v4 interface, its manifest
and source ledger, and the complete rolling-contract audit. It replaces only
Q-DESN forecast MAE and forecast check loss with values rederived from verified
lead-level rolling-origin paths; no model, candidate, fit metric, or comparator
is reselected.

The promotion freezes all inherited compact metric sources and compresses each
unique raw rolling-origin CSV into the immutable bundle. It retains no `.rds`,
`.rda`, or `.RData` payload. The paired 84-job calibration remains explicitly
`PREPARED_NOT_APPROVED_NOT_LAUNCHED` and is not needed to publish the corrected
current evidence.

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/promote_qdesn_article_rolling_rebaseline_v1.R

/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/verify_qdesn_article_rolling_rebaseline_v1_promotion.R
```

The authoritative promotion identifier is
`qdesn_dqlm_500obs_trainonly_article_v5_rolling_rebaseline_20260811`.
