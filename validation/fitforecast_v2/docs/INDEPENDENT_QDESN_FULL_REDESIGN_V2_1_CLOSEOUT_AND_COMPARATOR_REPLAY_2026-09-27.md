# Independent Q-DESN redesign v2.1 closeout and comparator replay

## Scope

This plan closes the completed independent single-quantile Q-DESN redesign
without changing Article-v2, Overleaf, shared validation, or another scientific
lane. The completed 5,952-job campaign remains immutable. No Q-DESN fit is
repeated merely to repair postprocessing.

## Audited state

- All six scientific stages completed with 5,952 successes and no failures.
- The live verification contract passes all protocol, source-hash, and stage
  checks.
- Final closeout stopped only because the corrected exDQLM authority was looked
  up one directory above its tracked `scientific/` location.
- Both predeclared forecast estimators were retained for every confirmation
  draw. Mean-readout-state recursion usually improves forecast scores, but the
  original path-recursive selection remains part of the frozen evidence.
- Historical DQLM/exDQLM article scores use origin stride 30. They cannot be
  compared directly with the redesign's 971-origin stride-one lattice.

## Implementation stages

1. Repair the fixed-comparator authority path and cover it with a regression
   test.
2. Re-run verification and closeout only. Emit path-recursive winners,
   mean-readout-state winners, paired estimator comparisons, immutable hashes,
   and an explicit estimator recommendation. Do not rewrite the predeclared
   path-recursive selection.
3. Freeze a matched-comparator protocol for DQLM AL and exDQLM exAL. Preserve
   the authoritative model specification, priors, train window, package 1.1.1
   behavior, MCMC budget, chains, and seeds. Change only the forecast-origin
   lattice from stride 30 to stride 1.
4. Refit comparators only because success fit objects were deliberately pruned
   and no retained artifact can generate 971-origin posterior forecasts. Run
   the 54 comparator chains in parallel with one numerical thread per worker.
5. Export posterior metric draws, means, 95% intervals, origin/lead summaries,
   inference diagnostics, source/config hashes, and storage-light manifests.
6. Compare both Q-DESN forecast estimators with their likelihood-matched fixed
   comparator. Keep every family, quantile, and likelihood cell separate.
7. Investigate the Laplace exAL, p=0.25 Q-DESN cell separately because its
   chain disagreement is exceptional. Do not use a broad new screen as a
   substitute for diagnosing that one posterior.
8. Freeze a coordinator handoff. This branch must not merge itself into shared
   validation or publish article/Overleaf files.

## Audited implementation contract

The implementation uses
`independent_qdesn_fixed_comparator_stride1_v1`. It intentionally replays only
the fixed comparators; it does not launch another Q-DESN screen.

- **Jobs:** 54 MCMC chains: 2 comparator classes x 3 families x 3 target
  levels x 3 chains.
- **Frozen sources:** the 27 authoritative DQLM configurations from the 1.1.1
  rerun and the 27 corrected exDQLM configurations from the rolling-state
  promotion. Every source JSON is hash checked and copied into the ignored run
  root before execution.
- **Package:** the exact CRAN exdqlm 1.1.1 source tarball with SHA-256
  `3f3ed643ded7602fd62357d7f62024ca9071e0096214456650ed2de79722443e`,
  installed into a run-local R library. Workers use the installed namespace;
  they do not call `pkgload::load_all()` for this replay.
- **Invariant inference:** model identity, family, target level, design,
  priors, 5,000 burn-in iterations, 20,000 retained MCMC iterations, VB
  initialization, and chain seeds remain unchanged.
- **Deliberate protocol changes:** origin stride becomes one; only origins with
  a complete 30-step horizon are retained; each chain exports 300 evenly
  selected posterior metric draws; output/provenance paths are remapped; and
  the corrected posterior-predictive state update is declared. For reduced AL
  DQLM, gamma remains fixed and the state-update method is algebraically on the
  existing reduced path.
- **Exact lattice:** origins 9000--9970, 971 origins, leads 1--30, and 29,130
  origin-lead pairs per chain. The 29 truncated late-origin forecasts emitted
  by the legacy generic grid are explicitly excluded.
- **Separate window and horizon contracts:** the loader retains all 1,000
  observations at source indices 9001--10000 through
  `forecast_window_rows = 1000`, while `forecast_horizon_max = 30` controls
  the maximum lead from each origin. This prevents the legacy fixed-origin
  horizon field from truncating or rejecting the rolling-origin block.
- **Metric intervals:** fit oracle-path RMSE, fit oracle-path MAE, fit check
  loss, forecast oracle-path MAE, forecast oracle-path RMSE, and forecast check
  loss, each summarized over 900 pooled draws per model-family-level cell.
- **Granular outputs:** model/family/level lead profiles, origin profiles, and
  origin-by-lead summaries, plus gamma/sigma and metric-chain diagnostics.
- **Execution:** 15 process workers on 15 selected CPUs, one numerical thread
  per fit, under R 4.6.0. The pipeline refuses a dirty or divergent branch and
  enforces memory, disk, package, source-hash, dry-run, and final-completeness
  gates.
- **Storage:** fitted objects are transient and pruned after successful compact
  exports. `.rds`, `.rda`, and `.RData` files are forbidden inside the final
  run root.

The implementation is covered by exact-registry, source-equality,
configuration-invariance, full-horizon-grid, package-runtime, metric-interval,
and lane-ownership regression tests. Disposable DQLM and exDQLM smoke fits
also exercise the installed CRAN namespace, six-metric export, corrected state
recursion, and compact-object pruning.

## Result-dependent continuation

The pipeline automatically closes out the matched comparator surface and
builds an ignored four-model diagnostic PDF. It does **not** automatically
change article tables. A further Q-DESN run is justified only after this
comparison identifies a remaining gap on the matched lattice. The previously
observed Laplace exAL, `p=0.25` chain disagreement remains the first targeted
posterior investigation if it survives that comparison; it is not a reason to
repeat a broad structural screen preemptively.

## Decision rules

- No partial comparator surface is article-authoritative.
- Diagnostic labels are disclosed but are not automatic score vetoes.
- Point and interval comparisons must use the same 971 origins, horizon 30,
  source trajectories, and score definitions.
- Mean-state recursion may become the primary reporting estimator only through
  an explicit evidence-backed decision; path recursion remains a sensitivity
  result.
- Runtime fitted objects are temporary and are removed only after all compact
  summaries and hashes verify.
