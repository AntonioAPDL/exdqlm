# Frozen preprocessing v10 closeout

The compatibility replay completed on 2026-10-05 at 01:32:49 UTC. It required
ten saved-MCMC forecast replays and four selected VB reconstructions, not new
MCMC fits. All fourteen workers exited successfully. The frozen source,
materialization and final manifests verified at 224, 27 and 238 rows. All 147
numerical checks passed at tolerance 1e-6 (maximum error 6.82121e-13).
Independent reconstruction verified 56 point-score rows and 126 interval rows.
No fitted-model binary payloads remain in this run.

Evidence root (relative to this worktree):
`validation/fitforecast_v2/local_trackers/independent_qdesn_frozen_preprocessing_v10_recovery_20261004__git-054df26f`.
Audit root: `validation/fitforecast_v2/local_trackers/health_v10_complete_20261005_042307_UTC`.
The audit includes its own artifact manifest and reproducible analysis scripts.
Neither root is an article asset; both remain ignored runtime evidence.

The Gaussian exAL p=0.25 challenger improves all four point criteria in all
three paired chains. Mean forecast oracle MAE is 3.049042 versus 8.601532 for
its control, but remains above the matched-window exDQLM VB reference 1.705392.
These are not matched MCMC comparator results. The Gaussian AL p=0.05
challenger improves fit but worsens MCMC forecast MAE (3.955742 versus
3.639626) and check loss (1.325443 versus 1.268539). Retain the exAL challenger
and AL control as separate next-stage anchors.

Preserving the training input basis fixed an implementation defect, not all
forecast underperformance. Late-origin underprediction and longer-lead error
remain. Per-draw score ranges and score-of-mean-path results are distinct;
the repair did not establish calibrated uncertainty or narrower intervals.

Scientific status: COMPLETE_COMPATIBILITY_REPAIR_NO_DIRECT_ARTICLE_REPLACEMENT.
Only the integration coordinator may integrate this code. Internal fit/evaluation
windows (8501:8750 / 8751:9000) cannot replace external article tables directly.
No Article-v2, Overleaf or shared-validation publication is authorized here.

The continuation separates same-structure tau0 sensitivity from archived and
richer identity-Q designs, uses likelihood-specific internal forecast selection
and explicit exAL M0, and confirms only finite case-specific forecast gains.
It must preserve diagnostic caveats without using mixing grades as exclusion
rules. Normal VB is an initializer, not a hard MCMC eligibility gate.
