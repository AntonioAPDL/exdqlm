# Selected-source forecast-prefix reconstruction

## Objective and frozen comparison

Recover forecast-capable posterior evidence for the existing independent
article Figures 1 and 2. The investigator authorized the refits after confirming
there is no backup. Refit the 44 already-selected metric-specific source
identities, three chains each (132 chains), without screening, new priors,
new likelihoods, data changes, longer chains, or holdout-based reselection.

The existing article summaries remain the baseline. New samples need not be
bitwise identical to the removed original samples. Every full-window draw and
mean difference is reported against the baseline at tolerance `1e-6`; differences
are evidence, not a reason to discard an unfavorable chain or selectively refit.
No article file, integration branch, shared authority, or Overleaf is modified.

## Resource audit and launch

Muscat provides 32 physical cores / 64 logical CPUs. PRICEFM has a 30-worker
allocation on logical CPUs 0-29 and remains untouched. This lane is limited to
15 single-threaded workers on CPUs 32-46. These are separate logical slots,
not 15 additional physical cores. Thread caps are set before R startup, with
OpenMP dynamic threads disabled. Available memory at audit was about 474 GiB;
free data disk was about 346 GiB. Each new task is held if available RAM falls
below 64 GiB or free disk below 80 GiB. Existing tasks finish; no other jobs are
stopped, reprioritized, or reassigned.

Start one full-budget chain for each class: DQLM, exDQLM, Q-DESN AL-RHS,
Q-DESN exAL-RHS. These are four of the 132 tasks, not additional fits. Open
the remaining queue only after all four complete with finite, aligned exports,
retained posterior evidence, valid manifests, and successful within-run score
reconstruction. MCMC diagnostic grades are disclosed, not score-exclusion
rules. On an implementation failure, stop new scheduling, drain active tasks,
retain all evidence, and report the failure instead of silently retrying.

## Historical runtime isolation

Most selected sources used the frozen validation package labeled 1.0.0:
`c72e19f345da88fc1a8175ed30bdde328eab88be`. The Gaussian AL p=0.05 source
used `d6bc4c5e47a922ea0255f3ad8d73e58f374827a0`. Corrected exDQLM rows use
the preserved CRAN 1.1.1 installed runtime with the rolling-state helpers frozen
at `7ace6618` (the materialized contract records its full SHA). Its CRAN source
tarball SHA-256 is
`3f3ed643ded7602fd62357d7f62024ca9071e0096214456650ed2de79722443e`.

The global installation (currently 1.1.2) is not changed or used as a silent
replacement. Source snapshots, private library files, configs, data inputs,
and worker code are hashed. Package version, loaded path, source SHA, session
information, RNG kind, and thread settings are recorded per task. Only
lane-owned historical snapshots may be compiled. Historical worktrees and
their runtime artifacts remain read-only.

## Scientific identity and scoring

Preserve training indices 8501:9000, forecast targets 9001:10000, the original
34 rolling origins with stride 30 and leads up to 30, and the original seeds,
warm starts, sampling budget, scaling, reservoir realization, and readout.
Teacher forcing observes values only through each origin; within-origin
forecast horizons do not use actual future responses or oracle quantiles.
exAL Q-DESN retains explicit M0; corrected exDQLM retains `collapsed_slice`
and its corrected predictive-moment state filter. DQLM retains its historical
AL inference controls. No likelihood or dependence convention is harmonized
for the cosmetic purpose of narrowing intervals.

Use native Q-DESN conditional quantile draws with shared posterior readout
indices across origins. DQLM/exDQLM retain their historical latent `ff/fQ`
Gaussian product-coupled metric draws, not response-predictive observations.
The original response and metric-draw budgets and forecast seeds are retained.

Generate one full joint forecast per chain. Score the first 300, first 500,
and full 1,000 targets using the same draws. The 500 cutoff includes only
20 leads from its last origin. Retain cumulative draw sums and counts at these
cutoffs and all complete-origin boundaries. Native Q-DESN full metric draws
must agree with the independently reconstructed prefix scores within `1e-6`.
Ordinary sources retain 4,000 metric draws per chain and type-8 intervals;
Gaussian AL p=0.05 retains 1,000 per chain and type-7 pooled intervals.

## Protected outputs and review

Retain every selected-source fitted posterior, joint conditional-quantile
forecast matrix, original target/observation vectors, draw IDs, scaling/design
context, native source config, environment, compact prefix draws, and hashes.
Hash-deduplicated copies of the original input data, configs, target paths, and
baseline metric draws are protected inside the new run as well. Capsules link
their backup manifest, so later cleanup of an old worktree cannot erase the
inputs needed to rebuild features around the retained posterior without fitting.
Outputs have `automatic_pruning_allowed = FALSE`. They remain ignored by Git;
do not use legacy fit-and-prune orchestration. A small JSON capsule links to
the protected fitted payload without duplicating it. No blanket legacy cleanup
is part of this launch.

Completed posterior and forecast evidence allows arbitrary later cutoff
rescoring without fitting or forecasting. All three chains are required for a
source summary. Preserve metric-specific source mappings rather than replacing
them with a newly chosen global winner. The resulting eight-page ignored PDF
shows published full-window Figures 1/2, reconstructed full-window versions,
first-500 versions, and first-300 versions, using matched panel axes and the
existing article style. Original and reconstructed realizations are explicitly
distinguished. There is no automatic publication or promotion.

## Commands

Run from the dedicated reconstruction worktree with R 4.6.0:

```bash
Rscript validation/fitforecast_v2/scripts/run_forecast_prefix_reconstruction_v1.R \
  --mode prepare --output validation/fitforecast_v2/local_trackers/PREFIX_RUN

Rscript validation/fitforecast_v2/scripts/run_forecast_prefix_reconstruction_v1.R \
  --mode controller --output validation/fitforecast_v2/local_trackers/PREFIX_RUN \
  --workers 15 --cpus 32,33,34,35,36,37,38,39,40,41,42,43,44,45,46

Rscript validation/fitforecast_v2/scripts/run_forecast_prefix_reconstruction_v1.R \
  --mode health --output validation/fitforecast_v2/local_trackers/PREFIX_RUN
```

Commit and push only the dedicated scientific lane branch. Launch its
controller in a detached tmux session, then verify live workers and logs.
The integration coordinator owns any subsequent publication decision.

## Preflight verification

All 132 source and input contracts were verified before production preparation.
Both historical Q-DESN source snapshots compile/load under R 4.6.0, and the
private installed package verifies as CRAN exdqlm 1.1.1 with `collapsed_slice`
first in the default proposal list. Reduced-budget runtime smokes exercised
all four model classes, posterior retention, 34 origins, and prefix scoring.
Two compatibility problems were caught and corrected before full-budget
launch: the old harness lacked the newer diagnostics exporter, and its state
helper expected the unexported `make_df_mat` symbol exposed by pkgload.
Diagnostics are now exported independently, and the installed namespace's
identical helper is bound inside the isolated worker process. The retained
dynamic smoke posteriors were reused to validate forecasting without refitting.
No historical source files or package algorithms were modified.

The focused recovery and reconstruction suites contain 85 passing expectations.
The eight-page renderer was tested with labeled synthetic layout fixtures;
that fixture is not a scientific results packet. Production figures are emitted
only after all 132 full-budget tasks complete. Smoke artifacts, layout fixtures,
and production payloads remain ignored, separately tagged, and unpromoted.
