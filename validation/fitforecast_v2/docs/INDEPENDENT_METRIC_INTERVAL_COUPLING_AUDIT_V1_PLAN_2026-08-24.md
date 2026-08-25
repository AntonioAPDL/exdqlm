# Independent Metric-Interval Evidence and Coupling Audit v1

Date: 2026-08-24

## Decision context

The published independent single-quantile v10 tables report posterior means and
equal-tailed 95 percent credible intervals of draw-wise fit RMSE, rolling-origin
forecast MAE, and rolling-origin forecast check loss. The completed v10 campaign
is frozen at promotion id
`qdesn_dqlm_500obs_metric_intervals_v10_20260824`. This phase does not reopen
case-specific model selection, alter any displayed center, or launch a new DESN
screen unless its predeclared audit identifies a material interval-contract
problem.

The audit found one issue that deserves explicit verification before further
calibration. Q-DESN preserves a native posterior-draw identity across rolling
origins. DQLM and exDQLM instead use the predeclared product coupling of
origin-specific latent forecast marginals. The posterior mean of either
additive rolling metric is invariant to a permutation of origin-level draws,
but its credible-interval width can depend on the cross-origin coupling. The
current v10 estimates remain valid under their documented model-specific
contracts; this phase measures sensitivity rather than presuming an error.

## Immutable authorities

1. Scientific branch baseline:
   `4790c9814855e06aa34505a9da32533e2748fdf6`.
2. v10 promotion:
   `validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_metric_intervals_v10_20260824`.
3. v10 estimator:
   `posterior_mean_draw_metric_equal_tailed_95cri_v1`.
4. Rollback authority:
   `qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821`.
5. Production run:
   `independent_metric_intervals_v1_production_20260823_225856`.

No Joint Q-DESN, PriceFM, GloFAS, application, Article-v2 main, or Overleaf
surface is in scope. The scientific lane commits and pushes only its dedicated
validation branch. Article publication, if ever warranted, remains owned by the
integration lane.

## Phase 1: portable raw evidence

The original run retained 198 compressed metric-draw files and no fitted-model
binary. The compact v10 promotion records their hashes but points to an ignored
task worktree. Before that worktree can ever be retired, build a portable
archive containing:

- all 198 `metric_draws.csv.gz` files;
- each job's interval summary, interval manifest, frozen configuration, and
  terminal status;
- staged Q-DESN source-series inputs and campaign manifests needed to identify
  the replay;
- the complete tracked v10 promotion packet;
- a relative-path file ledger with bytes and SHA-256 for every member.

The archive is stored outside Git because the raw draw payload is an evidence
artifact, not source code. Git retains the portable ledger, archive hash,
rebuild command, and verification result. The original 1.5 GiB run tree remains
untouched until the archive and exhaustive replay pass.

## Phase 2: exhaustive arithmetic replay

Read the 198 archived draw files, verify every promoted hash, pool chains by
the frozen replay id, and independently recompute all 270 source-metric rows.
The replay must match v10 for:

- posterior mean and standard deviation;
- 0.025, 0.50, and 0.975 type-8 quantiles;
- draw count and chain count;
- inference label and estimator id.

The gate is exact for counts and within a relative tolerance of `1e-11` for
floating-point summaries. Any mismatch blocks the coupling pilot and leaves
v10 frozen pending diagnosis.

## Phase 3: paired coupling pilot

The pilot uses the exact published MCMC sources for two representative cells:

1. Normal, `p=0.25`: a stable central-tail reference.
2. Gaussian mixture, `p=0.05`: the difficult lower-tail cell that motivates
   future calibration.

All metric-specific forecast sources are included, not one global
specification. Eleven replay identities and all three frozen chains yield 33
jobs. Each job keeps its exact likelihood, DESN specification, `tau0`, source
trajectory, reservoir seed, chain seed, burn-in, retained iterations, and M0
exAL transition. Only a paired secondary metric export is added.

Q-DESN alternatives:

- `native_aligned`: the current shared posterior-draw identity;
- `origin_independent_permutation`: deterministic independent permutations
  across origins, while preserving within-origin lead dependence and each
  origin's empirical marginal draw distribution exactly.

DQLM/exDQLM alternatives:

- `origin_independent`: the current product coupling;
- `common_marginal_rank`: each origin/lead's existing finite latent draws are
  sorted and matched by rank, preserving every empirical marginal exactly
  while imposing a strong common-rank dependence as a sensitivity bound.

The alternatives are diagnostic couplings, not competing posterior samplers.
The primary metric artifacts remain byte-schema compatible with v10.

## Predeclared decision gates

For each replay and forecast metric, compare the paired alternatives using the
same fitted posterior:

1. Mean invariance: relative mean shift at most `5e-10`. The permutation
   construction should preserve the finite-draw mean to rounding error.
2. Review threshold: endpoint shift above 0.10 native interval widths or width
   ratio outside `[0.90, 1.10]`.
3. Material threshold: endpoint shift above 0.25 native interval widths or
   width ratio outside `[0.80, 1.25]`.
4. Scientific threshold: any change in the winner/runner-up interval-overlap
   conclusion for either representative cell is material.
5. Replay threshold: the new primary-coupling draws must reproduce the original
   same-chain v10 summaries within `1e-10`; otherwise the pilot is not
   interpretable.

Decision outcomes:

- `RETAIN_V10_COUPLING_SENSITIVITY_PASS`: no material threshold is crossed;
  preserve v10 and add at most a concise methods clarification through the
  integration workflow.
- `V10_1_MATCHED_COUPLING_REPLAY_REQUIRED`: a material threshold is crossed;
  freeze the pilot and design a uniform all-cell replay before changing any
  table.
- `PILOT_INVALID_REPLAY_MISMATCH`: exact-source reproduction fails; diagnose
  implementation or provenance before drawing a scientific conclusion.

## Execution and storage

- Run three chains for every selected source, one numerical thread per job.
- Use an explicit CPU list that excludes cores owned by active external lanes.
- Cap concurrent workers at the number of supplied CPUs.
- Do not interrupt or inspect another lane beyond the read-only CPU ownership
  check needed to avoid contention.
- Retain compressed primary and coupling metric draws, summaries, compact
  diagnostics, configs, logs, and hashes.
- Delete no pre-existing artifact in this phase.
- Retain no `.rds`, `.rda`, or `.RData` payload after a successful job.

## Closeout and handoff

The pipeline writes a health report, paired coupling comparison, article-role
sensitivity ledger, decision JSON, storage audit, and hash manifest. If the
decision retains v10, no article table changes are authorized. If a v10.1
replay is required, this branch supplies evidence and a plan only; it does not
silently replace article assets.

After closeout, commit and push the dedicated branch, leave it clean and
synchronized, and provide a frozen integration handoff. The integration chat
decides whether any article-safe clarification should be merged.
