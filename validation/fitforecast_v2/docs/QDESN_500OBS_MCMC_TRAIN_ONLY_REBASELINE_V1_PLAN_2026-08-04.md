# Q-DESN 500-Observation MCMC Train-Only Rebaseline v1

Date: 2026-08-04
Package baseline: exdqlm 1.0.0
Branch: `validation/qdesn-trainonly-transport-v1-1.0.0`
Authority affected: independent single-quantile Q-DESN fit-and-forecast validation only

## Decision

The current Q-DESN article metric envelope must be re-estimated before any further
hyperparameter screening or article promotion. The production real-data path used
the complete 1,890-row analysis block to estimate response and covariate scaling,
including the 1,000 held-out forecast rows. Because the nonlinear reservoir and
regularized-horseshoe readout are not affine invariant, this is future-response
leakage and not merely a reporting defect.

The repair is a complete, exact-design MCMC rebaseline under training-only
preprocessing. It does not alter the frozen simulation sources, forecast protocol,
DESN architecture, prior, reservoir seed, or article automatically.

## Audit Finding

The affected production paths were:

- `scripts/pipeline_real_main.R`;
- `R/qdesn_model_selection_v2.R`.

Both paths previously estimated centering and scaling before resolving and applying
the train/forecast split. The corrected implementation resolves the split first,
fits all affine transformations on the first 890 rows of the selected 1,890-row
input block, then applies those frozen transformations to the complete block.

The corrected provenance is retained in run manifests and compact campaign rows:

- scope: `train_only`;
- analysis input rows: 1--1,890;
- preprocessing fit rows: 1--890;
- corresponding source rows: 8,111--9,000;
- effective target fit window after lag/washout: 8,501--9,000;
- held-out response used for scaling: false;
- held-out covariates used for scaling: false;
- fit-row-index SHA-256: recorded in every corrected run.

## Frozen Statistical Protocol

- source warmup length: 2,000;
- main source length: 10,000;
- total source length: 12,000;
- forecast origin source index: 9,000;
- effective 500-observation fit window: 8,501--9,000;
- forecast block: 9,001--10,000;
- reported forecast windows: H=100 and H=1,000;
- rolling-origin maximum lead: 30;
- rolling-origin stride: 30;
- refit per origin: false;
- inference: MCMC;
- burn-in: 5,000 iterations;
- retained sampling iterations: 20,000;
- metric draws: 200;
- source-registry identity:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`.

## Exact Rebaseline Scope

The 18 current Q-DESN model/family/quantile rows contain 54 metric slots: fit
RMSE, H=1,000 forecast MAE, and H=1,000 forecast check loss. Metric-wise article
promotion means those slots currently draw from 37 distinct historical designs.

All 37 designs are rerun. For each design, the materializer recovers the exact
effective `fit_request.json` and freezes:

- model variant and likelihood;
- family and quantile;
- depth, layer width, lag order, alpha, rho, sparsity, and washout;
- readout lags and regularized-horseshoe `tau0`;
- effective reservoir seed;
- historical run tag, request path, request hash, and candidate identity.

The reservoir seed is preserved so that the corrected run isolates preprocessing.
Fresh deterministic seeds are assigned to MCMC, MCMC RNG, VB warm start, and
forecast synthesis. This avoids reusing a sampler stream while preserving the
historical reservoir realization.

## Execution Architecture

The lifecycle is strictly staged:

1. Verify package version, generated contracts, historical fit requests, frozen
   sources, staged sources, paths, windows, and hashes.
2. Generate a prepare-only manifest for all 37 exact specs.
3. Run a two-root executable smoke containing one AL and one exAL root selected
   from the highest-dimensional designs.
4. Audit smoke metrics, H=100/H=1,000 horizons, train-only provenance, source
   identity, seed wiring, budget, and storage.
5. Wait for the resource gate.
6. Run the 37 corrected roots with 20 one-thread workers.
7. Enforce zero run-local `.rds`, `.rda`, or `.RData` payloads.
8. Produce a failure-explicit closeout and corrected metric envelope.

The full stage requires `FULL_TRAINONLY_REBASELINE_APPROVED=1` and a clean,
committed worktree. It never updates the article automatically.

## Resource Policy

The host audit found 64 logical cores, 503 GiB RAM, and more than 500 GiB free
under `/data`. Twenty workers provide two scheduling waves for 37 roots while
leaving substantial capacity for unrelated active work. Every root is forced to
one BLAS/OpenMP thread. The resource gate requires:

- load average no greater than `nproc - workers - 8` unless overridden;
- at least 128 GiB available memory;
- at least 100 GiB available disk.

The orchestrator writes a heartbeat every 30 minutes. A root with an active
process but no file/log progress for 30 minutes is flagged as stale for diagnosis;
the monitor does not kill it automatically. Each fit has a seven-day hard timeout.

## Storage Policy

Retained successful evidence is limited to scalar metrics, compact fit and forecast
paths, progress traces, logs, configs, manifests, statuses, and hashes. The run
does not retain posterior draws, VB initialization objects, forecast objects, or
failure payloads. Frozen source objects outside the run root are inputs and are
not duplicated or deleted.

## Closeout and Promotion Rules

The closeout is status-aware but metric promotion is not gated on a diagnostic
PASS label. A result may supply metrics when all of the following hold:

- every required scalar metric is finite;
- train-only preprocessing provenance matches exactly;
- source registry and source windows match exactly;
- sampler budget and seed contract match exactly;
- no run-local binary payload exists.

Diagnostic status and signoff grade remain visible in every comparison row.

No article update is allowed unless all 37 exact designs are present and
protocol-eligible and the corrected envelope covers all 18 cells. Even then,
article promotion requires a separate manual scientific review against DQLM and
exDQLM. The legacy Q-DESN metric values are retained only as historical comparison
evidence after this repair.

## Evidence Files

Configuration prefix:

`config/validation/qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1`

Key scripts:

- `validation/fitforecast_v2/scripts/materialize_qdesn_train_only_rebaseline_v1.R`;
- `validation/fitforecast_v2/scripts/verify_qdesn_train_only_rebaseline_contract.R`;
- `validation/fitforecast_v2/scripts/verify_qdesn_train_only_rebaseline_smoke.R`;
- `validation/fitforecast_v2/scripts/healthcheck_qdesn_train_only_rebaseline_v1.R`;
- `validation/fitforecast_v2/scripts/closeout_qdesn_train_only_rebaseline_v1.R`;
- `validation/fitforecast_v2/scripts/run_qdesn_train_only_rebaseline_v1_pipeline.sh`;
- `validation/fitforecast_v2/scripts/launch_qdesn_train_only_rebaseline_v1.sh`.

## Implemented Gate Evidence

The implementation was validated under R 4.6.0 before the full launch was
authorized:

- generated contract verification: PASS, 16/16 checks;
- exact historical target set: 37/37 unique designs from 54 article metric slots;
- staged source-file audit: 36/36 files hash-matched;
- prepare-only run tag: `qdesn-trainonly-v1-prepare-manual-20260804`;
- prepare-only manifest: 37/37 requested specifications, 20 workers;
- executable smoke run tag: `qdesn-trainonly-v1-smoke-manual-20260804`;
- smoke execution: 2/2 roots completed with finite fit, H=100, and H=1,000
  metrics;
- smoke preprocessing audit: 2/2 roots used `train_only`, rows 1--890,
  fit-row-index SHA-256
  `13d7864c93516d44bc53752def311efa2b2c244c934e17a27509188744feb24e`,
  with no held-out response or covariate use;
- smoke source, seed, budget, and horizon contracts: 2/2 PASS;
- smoke binary-payload audit: zero `.rds`, `.rda`, or `.RData` files;
- focused preprocessing tests: 32 expectations PASS;
- focused rebaseline-contract tests: 76 expectations PASS;
- R parser, shell parser, whitespace, and orchestration self-test: PASS;
- orchestration self-test run ID:
  `qdesn-trainonly-v1-selftest-20260804`, using 20 workers, maximum launch
  load 36, and 30-minute heartbeat/stale intervals.

The complete legacy package test directory is not a release gate for this scoped
repair because it contains pre-existing failures that reproduce unchanged at the
clean shared branch baseline, including `test-benchmark-qdesn.R` failing on an
unresolved `.` helper and tests that depend on pruned historical run artifacts.
Those failures were not modified or masked. The two new focused test files and
the executable protocol gates above are the scoped acceptance tests for this
rebaseline.

Runtime evidence for an orchestrated launch is written beneath
`reports/shared_fitforecast_v2_orchestration/<RUN_ID>/`. In particular,
`run_tags.env`, `stage_status.csv`, `heartbeat.csv`, stage logs, storage audits,
and `closeout/rebaseline_gate.json` provide the complete launch-to-closeout
record without committing generated results.

## Safe Commands

Read-only contract verification:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/verify_qdesn_train_only_rebaseline_contract.R
```

Health check:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/healthcheck_qdesn_train_only_rebaseline_v1.R
```

Approved background launch:

```bash
FULL_TRAINONLY_REBASELINE_APPROVED=1 \
  validation/fitforecast_v2/scripts/launch_qdesn_train_only_rebaseline_v1.sh \
  /data/jaguir26/local/src/exdqlm__wt__qdesn_trainonly_transport_v1_1p0p0 20
```

## Stop Conditions

Stop before full compute if any source hash, generated-file hash, historical
request hash, split/window check, train-only invariance test, smoke metric, smoke
provenance check, storage check, or resource gate fails. Do not fall back to the
legacy Q-DESN article metrics and do not begin another scalar screening campaign
until this corrected rebaseline is closed out.

## Full-Run Closeout (2026-08-05)

The approved run completed without a computational failure:

- run ID: `qdesn_trainonly_rebaseline_v1_20260804_214636__git-ae1b2db`;
- full run tag: `qdesn-trainonly-v1-full-20260804_214636__git-ae1b2db`;
- 37/37 requested roots completed 5,000 burn-in plus 20,000 retained MCMC
  iterations;
- 37/37 roots have finite required metrics and satisfy the preprocessing,
  source, budget, and seed contracts;
- operational status: 37 `SUCCESS`;
- diagnostic signoff: 12 `PASS`, 18 `WARN`, and 7 `FAIL`;
- run-local binary payloads: zero.

The first automatic closeout reported
`INCOMPLETE_CORRECTED_REBASELINE_NO_ARTICLE_UPDATE` because it looked for the
source-registry hash at the root of `fit_request.json`. The frozen request stores
that field under `study_contract$source_registry_hash_value`. This was a
closeout-parser defect, not a source or model-run failure. The parser now reads
the canonical nested field, rejects missing hashes explicitly, and records both
launch and closeout Git provenance. The superseding gate is:

`validation/fitforecast_v2/promotions/qdesn_500obs_mcmc_trainonly_rebaseline_v1_closeout_20260805/rebaseline_gate.json`

Its decision is
`CORRECTED_REBASELINE_COMPLETE_MANUAL_ARTICLE_REVIEW_REQUIRED`, with 37/37
protocol-eligible roots and 18/18 corrected model/family/quantile envelope rows.
The healthcheck selects this newest matching gate and reports
`COMPLETED_CLOSED_OUT`; the immutable stage log continues to retain the original
superseded decision as historical evidence.
The launch commit was `ae1b2dbec3119df314faa69ecdf59fb74abfb4f3`.
Twenty root manifests record that commit and 17 record `52b6100`; the only
intervening changes were the train-only healthcheck and its focused test, with no
change to model, preprocessing, source, configuration, or sampler code.

The compact closeout promotion retains the execution audit, legacy comparison,
corrected metric envelope, source hashes, file manifest, storage audit, and gate.
The full report and result trees occupy approximately 86 MiB and 253 MiB,
respectively, and contain no `.rds`, `.rda`, or `.RData` files.

## Scientific Review and Article Hold

Against the pre-repair Q-DESN RHS MCMC rows currently displayed by article
remote `main` at `a3faa0c9cd43cb91ffac1f68c84353028acb6e27`, the corrected envelope improves
13/18 fit-RMSE cells, 14/18 H=1,000 forecast-MAE cells, and 16/18 H=1,000
forecast-check-loss cells. Against the best displayed DQLM or exDQLM MCMC value
within each family and quantile, the corrected envelope wins 9/18 fit-RMSE,
10/18 forecast-MAE, and 9/18 forecast-check-loss comparisons. Median corrected
ratios to the best dynamic-linear comparator are 1.117, 0.944, and 0.999,
respectively.

These results justify retaining the corrected MCMC evidence, but they do not yet
justify rewriting the article table. All displayed Q-DESN VB rows and the
displayed ridge rows were promoted from commits that predate the train-only
repair and their promotion interfaces contain no train-only preprocessing
provenance. Updating only RHS MCMC would therefore mix corrected and legacy
preprocessing contracts in one table.

The next safe sequence is:

1. Treat this 224 KiB closeout directory as the authoritative corrected RHS MCMC
   evidence bundle; do not use the superseded automatic gate.
2. Materialize and run an exact-design, train-only VB rebaseline for the 18
   displayed Q-DESN/exQ-DESN RHS cells. This is a protocol correction, not a new
   hyperparameter screen.
3. Either remove Q-DESN ridge rows from the article comparison or rebaseline them
   under the same train-only contract. Do not retain legacy ridge metrics in a
   corrected table.
4. Rebuild the article-facing summary only after all displayed Q-DESN rows share
   the frozen source, rolling-origin, and train-only preprocessing contracts.
5. After that corrected table is frozen, restrict further MCMC calibration to
   the remaining scientific gaps: lower-tail fit recovery, Normal AL at
   `tau=0.05`, Gaussian-mixture exAL at `tau=0.25`, and the mixed Normal
   `tau=0.25` forecast cells. Do not spend additional compute on median forecast
   tuning unless the article objective changes.

No article file was changed during this closeout. The authoritative article
worktree was dirty and had diverged from `origin/main`, so article integration
must occur in a clean, synchronized article-safe context after the corrected VB
and ridge decision gates are resolved.
