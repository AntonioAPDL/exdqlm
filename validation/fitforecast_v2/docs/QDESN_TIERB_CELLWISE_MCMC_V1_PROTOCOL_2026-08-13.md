# Independent Q-DESN Tier-B Cellwise MCMC v1

## Decision

This campaign is the only justified continuation after the completed lower-tail
Tier-A campaign. It targets four previously declared but never executed
AL-RHS fit-RMSE cells. It does not reopen Tier A, recalibrate exAL, modify the
exdqlm 1.0.0 package kernel, or update the article automatically.

Frozen authority:

- validation base: `e75280ba14fcdefc8508f150623323e783f4c54a`;
- package version: `1.0.0`;
- article-facing interface: `qdesn_dqlm_500obs_trainonly_article_v6_paired_confirmation_20260811`;
- source-registry identity: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`;
- Tier-A closeout: `NO_CONFIRMED_GAIN_RETAIN_V6`;
- branch: `validation/qdesn-tierb-cellwise-mcmc-v1-1.0.0`.

The completed Tier-A campaign ran 218/218 roots successfully, including six
full-budget canonical chains. Its two canonical finalists were worse than v6:
exAL Laplace at 0.05 had mean fit-RMSE ratio 1.0266, and exAL Normal at 0.25
had mean forecast-MAE ratio 2.2122. Broad high-capacity and persistent
recurrence arms were also materially worse during development. Repeating that
surface would spend compute without a new scientific hypothesis.

## Open Cells

All four targets use Q-DESN under AL with the regularized horseshoe prior and
optimize `fit_qtrue_rmse` only.

| Cell | v6 Q-DESN | best DQLM/exDQLM | gap |
|---|---:|---:|---:|
| Laplace, 0.05 | 5.4198 | 3.6628 | 48.0% |
| Laplace, 0.25 | 2.2560 | 1.7102 | 31.9% |
| Gaussian mixture, 0.05 | 3.1536 | 2.5535 | 23.5% |
| Gaussian mixture, 0.25 | 1.8553 | 1.3813 | 34.3% |

Forecast metrics remain recorded as guard evidence but are not selection
objectives. The exact v6 metric-specific parent is included on every source.

## Candidate Contract

Each cell has eight candidates:

1. Four local profiles designed in the closed campaign but not materialized in
   any Tier-A plan: lower and upper `tau0`, longer input memory, and longer
   readout memory.
2. Two coupled profiles: lower `tau0` with longer input memory, and lower
   `tau0` with longer readout memory.
3. One local alpha/rho bridge under stronger shrinkage.
4. One shallow high-alpha sentinel under two-orders-stronger shrinkage.

The first four are admitted through a frozen configured-unrun allowlist. The
other four must have signatures absent from the complete historical config
ledger. The candidate generator rejects duplicate cell/signature pairs and any
effective readout dimension above 900. This is a local hypothesis test, not a
new broad depth/capacity search.

## Source And Evaluation Contract

- `TT_warmup = 2000`, `TT_main = 10000`, `TT_total = 12000`;
- period 90 with harmonics 1 and 2;
- training target window 8501:9000;
- forecast origin 9000 and evaluation block 9001:10000;
- rolling-origin maximum lead 30, origin stride 30, no refit per origin;
- fresh development sources `dev16`--`dev23`;
- canonical confirmation uses only the frozen article source and hashes.

The DESN/reservoir seed is paired within a target-cell panel so candidate and
parent differences are interpretable. Source, reservoir-replicate, chain, and
MCMC seeds remain separated by the existing seed contract.

## Stages And Gates

| Stage | Roots | Budget | Advancement rule |
|---|---:|---:|---|
| Smoke | 2 | 4 burn + 4 retained | both AL jobs finite and storage-clean |
| Runtime calibration | 4 | 200 + 500 | all four complete within six hours |
| Discovery | 108 | 1000 + 3000 | 8 candidates + parent, 4 cells, 3 sources |
| Replication | 16 | 1000 + 3000 | top 3 + parent, 4 cells, fresh `dev19` |
| Sealed holdout | 48 | 1000 + 3000 | top 2 + parent, 4 cells, 4 sealed sources |
| Canonical confirmation | at most 12 | 5000 + 20000 | 3 chains per eligible cell; explicit approval |

Discovery requires three paired sources. Replication rankings use all four
development sources. A sealed candidate is canonical-eligible only if mean and
median paired ratios are below one and at least three of four sealed sources
improve. Canonical promotion requires finite successful chains and both mean
and median metric values strictly below v6. The gain may be arbitrarily small.
Signoff grade is retained but is not a metric veto; implementation, provenance,
nonfinite, source-hash, and storage failures are hard vetoes.

The initial launcher stops after discovery. Replication and sealed stages use
separate verified launchers. Canonical confirmation additionally requires
`QDESN_TBCV1_CONFIRMATION_APPROVED=true`. Article publication is always manual
and belongs to the Article-Q-DESN integration lane.

## Runtime And Storage

- up to 20 workers are permitted; the default is 16 one-thread workers;
- exdqlm 1.0.0 is installed once into a fingerprinted campaign library and
  reused by all workers, avoiding concurrent per-worker native compilation;
- workers are pinned only to CPUs below the idle threshold;
- launch waits for load, memory, disk, and idle-CPU gates;
- heartbeat cadence is 1800 seconds;
- a campaign lock prevents duplicate orchestration;
- a matching successful config hash is resumable and skipped;
- status, metrics, compact lead summaries, logs, configs, and manifests remain;
- `.rds`, `.rda`, and `.RData` payloads are pruned by each worker and recorded;
- small immutable `sim_output.rds` files generated with each frozen source are
  retained as source-authority inputs required by the existing exdqlm 1.0.0
  cross-study contract; the 32 family/quantile/source roots produce 64 paired
  full/slice files (about 14 MiB), and they are not model-fit payloads;
- no posterior is recycled as a prior.

The launcher must start from a clean branch exactly synchronized with its
upstream. It never modifies or stops Joint Q-DESN, PriceFM, GloFAS, article
main, or Overleaf jobs.

## Reproducible Commands

Materialize and verify without compute:

```bash
R_SCRIPT=/data/jaguir26/local/opt/R/4.6.0/bin/Rscript
R_BIN=/data/jaguir26/local/opt/R/4.6.0/bin/R
LIB="$PWD/reports/shared_fitforecast_v2_orchestration/qdesn_tierb_cellwise_mcmc_v1_r_library"
mkdir -p "$LIB"
MAKEFLAGS=-j1 "$R_BIN" CMD INSTALL --preclean --clean --no-multiarch \
  --library="$LIB" "$PWD"
export R_LIBS_USER="$LIB${R_LIBS_USER:+:$R_LIBS_USER}"
OUT=reports/shared_fitforecast_v2_orchestration/qdesn_tierb_cellwise_mcmc_v1_materialization
$R_SCRIPT validation/fitforecast_v2/scripts/materialize_qdesn_tierb_cellwise_mcmc_v1.R \
  --output-root "$OUT"
QDESN_TBCV1_MATERIALIZATION_ROOT="$PWD/$OUT" \
  $R_SCRIPT -e 'library(exdqlm); testthat::test_file("validation/fitforecast_v2/tests/testthat/test-qdesn-tierb-cellwise-mcmc-v1.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'
$R_SCRIPT validation/fitforecast_v2/scripts/verify_qdesn_tierb_cellwise_mcmc_v1.R \
  --repo-root "$PWD" --materialization-root "$OUT" --stage static
```

Start the resumable resource-gated discovery campaign:

```bash
WORKERS=16 validation/fitforecast_v2/scripts/launch_qdesn_tierb_cellwise_mcmc_v1.sh "$PWD"
```

Use the printed `RUN_ID` and `RUN_TAG` for every later stage. Never invent a
new tag when resuming.

## Publication Boundary

The v6 article interface remains authoritative until canonical confirmation
closes. If a strict canonical gain is confirmed, this lane produces a frozen
promotion bundle and integration handoff. It does not merge or push article
main, `overleaf/article-snapshot`, or direct Overleaf `main`.
