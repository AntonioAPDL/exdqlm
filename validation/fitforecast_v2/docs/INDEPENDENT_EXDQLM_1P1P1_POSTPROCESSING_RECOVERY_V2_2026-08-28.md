# Independent exDQLM 1.1.1 postprocessing recovery v2

## Scope and decision

The scoped compatibility campaign
`independent_exdqlm_1p1p1_scoped_v1_20260828_032641` completed all 36
scientific jobs: nine structured-VB fits and 27 three-chain MCMC fits. No model
fit requires replay. The top-level pipeline status is `FAIL` only because the
optional diagnostic renderer attempted to aggregate path files before adding
the family and quantile metadata stored in the job audit.

Recovery is therefore limited to deterministic closeout and diagnostic
postprocessing. It must not execute a validation worker, rewrite the original
pipeline status, alter Article-v2, merge shared validation, or publish
Overleaf. Recovery and freezing both refuse to run unless the dedicated branch
is clean and exactly synchronized with its upstream, and the supplied state
root belongs to this worktree's orchestration directory.

## Audit findings

Two independent reporting defects require correction.

1. Forecast and fit path summaries contain source-index and error columns but
   do not repeat family, quantile, replay, or chain metadata. The first
   diagnostic script added only `chain_id`, so the origin aggregation failed.
2. The original candidate interface placed posterior draw-wise metric means in
   the top-level fields used by the point-estimate article tables. Like-for-like
   fixed-path point estimates were relegated to `compatibility_point_*`
   columns. The file also retained source fields from the superseded authority.
   Integrating it would silently change the table estimator and misstate
   provenance.

The original `pipeline.status`, original closeout handoff, and original
candidate remain immutable evidence. Recovery writes only to `closeout_v2`,
`diagnostics/exdqlm_1p1p1_scoped_v2`, and
`postprocessing_recovery_v2` beneath the frozen state root.

## Estimator-separated contracts

### Point candidate

`candidate_point_interface_exdqlm_only_replacement.csv` is a 72-row copy of
the current point authority with exactly 18 exDQLM rows refreshed. Its three
headline metric fields use fixed-path metrics, averaged over three chains for
MCMC and taken from the single deterministic VB fit for VB. The estimator ID
is `fixed_path_point_metric_chain_mean_v1`.

Every exDQLM metric source points to the frozen
`source_point_metric_summary.csv`. Package, execution commit, closeout commit,
chain count, status, and diagnostic grade are explicit. No posterior metric
mean may enter a point-table field.

### Interval candidate

`candidate_interval_roles_exdqlm_only_replacement.csv` starts from the complete
216-role v11.1 interval authority and replaces exactly 54 exDQLM roles. It uses
posterior draw-wise metric means with equal-tailed 95% intervals under
`posterior_mean_draw_metric_equal_tailed_95cri_v1`.

The 162 DQLM and Q-DESN roles must remain field-for-field invariant. Their
invariance is recorded in `non_exdqlm_interval_invariance_ledger.csv`. Point and
interval candidates are separate integration inputs and cannot be substituted
for one another.

## Scientific interpretation

The 1.1.1 refresh confirms the previous forecast conclusions. The material
changes are concentrated in fit RMSE. MCMC forecast-MAE and check-loss changes
are small, while the Gaussian-mixture `p=0.25` scale-skewness block remains a
parameter-level mixing challenge despite stable score summaries.

Integration may replace the complete exDQLM compatibility block if exdqlm
1.1.1 becomes the article validation runtime. It must not cherry-pick favorable
cells or describe the refresh as a material forecast improvement. Diagnostic
warnings remain visible but do not exclude finite metrics.

## Recovery procedure

From the clean dedicated branch and pinned task-local R library:

```bash
Rscript validation/fitforecast_v2/scripts/recover_independent_exdqlm_1p1p1_scoped_postprocessing_v2.R \
  --repo-root "$PWD" \
  --state-root reports/shared_fitforecast_v2_orchestration/independent_exdqlm_1p1p1_scoped_v1_20260828_032641
```

The recovery script verifies the 36 terminal jobs, runs closeout v2, rebuilds
five diagnostic PDFs plus one combined ignored packet, records the original
failure hashes, and emits `integration_handoff_v2.json`. It records zero
scientific jobs reexecuted. The diagnostic renderer is explicitly wired to the
new estimator-separated `closeout_v2` evidence rather than the preserved
original closeout.

After recovery passes, freeze the compact integration packet:

```bash
Rscript validation/fitforecast_v2/scripts/freeze_independent_exdqlm_1p1p1_scoped_integration_v2.R \
  --repo-root "$PWD" \
  --state-root reports/shared_fitforecast_v2_orchestration/independent_exdqlm_1p1p1_scoped_v1_20260828_032641

Rscript validation/fitforecast_v2/scripts/verify_independent_exdqlm_1p1p1_scoped_integration_v2.R \
  --repo-root "$PWD"
```

The tracked promotion packet contains compact metrics, candidates, manifests,
hashes, diagnostics, winner-change ledgers, and environment evidence. Raw draws
and diagnostic PDFs remain ignored but are hash-addressed from the handoff.
Fitted-model `.rds`, `.rda`, and `.RData` payloads remain forbidden.

## Integration boundary

This lane commits and pushes only
`validation/independent-qdesn-exdqlm-1.1.1-rerun-20260827`. The Article Q-DESN
integration coordinator alone may merge the packet, regenerate article tables
and interval figures, compile the manuscripts, and publish the article-only
Overleaf snapshot.
