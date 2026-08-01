# Q-DESN 500-Observation Cell-Specific Alpha/Rho Screen v2

## Status and ownership

- Scope: independent single-quantile Q-DESN/exQ-DESN validation only.
- Package baseline: exdqlm 1.0.0; package source is not modified by this study.
- Branch: `validation/qdesn-alpha-rho-cellwise-v2-1.0.0`.
- Worktree: `/data/jaguir26/local/src/exdqlm__wt__qdesn_alpha_rho_cellwise_v2_1p0p0`.
- Predecessor: topology mechanism run `qdesn_alpha_rho_topology_v1_20260731_190255`.
- Predecessor decision: `STOP_NO_MECHANISM_SIGNAL` after 120/120 successful roots.
- Article repository: read-only until a later full-budget frozen-source confirmation.
- Full-budget confirmation: deliberately not launched by this pipeline.

## Objective

The study asks whether case-specific leak and recurrent-radius tuning can improve
the five unresolved or sentinel Q-DESN/exQ-DESN RHS MCMC cells while preserving
fit RMSE, rolling-origin forecast MAE, and quantile check loss. It does not seek
one global DESN specification. Each likelihood-family-quantile cell is selected
independently, and separate candidates may represent fit, forecast-MAE,
check-loss, and balanced objectives.

## Evidence from v1

The v1 mechanism stage evaluated the exact parent, recurrence repair, input
repair, and full topology on three independent source trajectories and two
reservoir seeds. Its main findings were:

| Cell | Best mechanism | Fit ratio | Forecast-MAE ratio | Check-loss ratio | Disposition |
|---|---|---:|---:|---:|---|
| AL, Gaussian mixture, 0.05 | input only | 0.976 | 0.965 | 0.988 | continue |
| AL, Gaussian, 0.05 | exact parent | 1.000 | 1.000 | 1.000 | bounded safeguard |
| exAL, Gaussian mixture, 0.25 | full topology | 0.968 | 0.9505 | 0.991 | continue strongly |
| exAL, Laplace, 0.05 | exact parent | 1.000 | 1.000 | 1.000 | tune parent dynamics |
| exAL, Laplace, 0.25 | input only | 0.987 | 0.9997 | 1.000 | weak control |

The broad v1 surface was correctly blocked. It assigned full topology to every
cell even though full topology worsened four cells and helped only the exAL
Gaussian-mixture 0.25 cell.

## Structural diagnosis

The v1 topology audit establishes that several coherent parent reservoirs have
zero recurrent spectral radius. In these reservoirs, changing `rho` cannot
change the fitted model. Some parent seeds also have no nonzero input weights,
which explains why recurrence-only changes can produce exactly identical
metrics: a recurrent reservoir without input remains unforced.

The v2 design therefore follows an identifiability rule:

1. Search `alpha` only when recurrence is inert or `rho` is not identifiable
   consistently across both reservoir seeds; hold `rho` fixed in that search.
2. Search both `alpha` and `rho` only when the selected topology has active
   recurrence under both reservoir seeds.
3. Require every candidate topology to have at least one active input weight.
4. Hold depth, width, lag order, readout lags, RHS scale, and likelihood fixed at
   the current cell-specific parent.

## Cell-specific search map

| Cell | Search topology | Dimension | Points | Priority |
|---|---|---:|---:|---|
| AL, Gaussian mixture, 0.05 | input repair | alpha | 10 | primary |
| AL, Gaussian mixture, 0.05 | full topology | alpha/rho | 12 | secondary |
| AL, Gaussian, 0.05 | input repair | alpha | 10 | primary |
| AL, Gaussian, 0.05 | full topology | alpha/rho | 6 | safeguard |
| exAL, Laplace, 0.05 | exact parent topology | alpha | 10 | primary |
| exAL, Gaussian mixture, 0.25 | input repair | alpha | 10 | secondary |
| exAL, Gaussian mixture, 0.25 | full topology | alpha/rho | 12 | primary |
| exAL, Laplace, 0.25 | exact parent topology | alpha | 10 | control |
| exAL, Laplace, 0.25 | input repair | alpha | 10 | primary |

This produces 90 distinct candidate designs. The ten alpha-only values span
`0.0001` through `0.95`; if a value exactly equals the parent alpha, it is
replaced deterministically by the geometric midpoint to avoid repeating the v1
mechanism point. The twelve alpha/rho points cover the transformed boundaries
and interactions of the v1 admissible surface. The weak AL-Gaussian full-
topology safeguard uses a nested six-point subset.

## Non-repeat contract

The frozen execution index contains only profile IDs observed in completed MCMC
fit summaries for the five target cells. Materialization resolves those IDs
against the historical profile catalogs and compares complete design signatures:

- likelihood, family, and quantile;
- depth, width, reduction width, and lag order;
- alpha, rho, recurrent/input sparsity;
- washout, bias, readout/reservoir lags, RHS scale, and reservoir seed.

Materialization stops if any v2 profile exactly repeats an executed historical
profile. Merely materialized but unexecuted v1 broad points do not count as past
experiments and remain admissible. Unresolved historical profile IDs are
reported, never silently treated as resolved.

The versioned execution index was assembled from MCMC fit summaries under the
shared-fitforecast-v2 results root and the topology-v1 results root. It contains
331 distinct executed target profiles. Its SHA-256 is
`47173d4063fbdd9d96a81f2fc1afcc6199e1ca31a56376d926db89c142b7f13e`.
All 331 IDs resolve to a versioned profile catalog, and the complete-signature
comparison finds zero overlaps with v2. The materialization manifest records the
index, resolution audit, unresolved-ID table, overlap audit, and their paths.

## Frozen source and forecast contract

- `TT_warmup = 2000`
- `TT_main = 10000`
- `TT_total = 12000`
- effective training source indices: `8501:9000`
- forecast origin source index: `9000`
- forecast source indices: `9001:10000`
- rolling-origin forecasts without refitting
- maximum lead: 30
- origin stride: 30
- fit metric: true-quantile RMSE over the effective training window
- forecast metrics: true-quantile MAE and check loss over the H=1000 window

The three deterministic v1 development trajectories are reused byte-for-byte.
Their registry SHA-256 must be
`07e5f3b11cccd01c5c69ba8ff4794d4d28f583b9c5e8aba8b9dbc953fe862444`.
The article trajectory remains excluded from discovery.

## Adaptive execution

### Coarse stage

All 90 candidates use reservoir replicate 1 on three development sources:

`90 candidates x 3 sources = 270 MCMC roots`.

Each candidate is paired to the v1 exact parent on the same source and reservoir
seed. A candidate may advance when all three metrics are complete, its worst
median ratio is at most 1.05, its worst 90th-percentile ratio is at most 1.25,
and at least one median metric improves by at least 2%.

Within each cell, the audit separately selects the best guarded candidate for:

- fit RMSE;
- forecast MAE;
- forecast check loss;
- balanced worst-metric ratio.

Duplicate objective winners are collapsed. At most four candidates per cell
advance; there is no global winner.

### Refinement stage

Selected candidates use reservoir replicate 2 on the same three development
sources. The dynamic upper bound is:

`5 cells x 4 candidates x 3 sources = 60 MCMC roots`.

Coarse and refinement metrics are then combined into six paired evaluations per
candidate. A full-confirmation nomination requires at least five complete
pairs, a worst median ratio at most 1.03, a worst 90th-percentile ratio at most
1.25, and at least one median improvement of 2%.

### Confirmation boundary

The pipeline stops after refinement and writes a candidate handoff. It never
launches the 5000-burn-in/20000-retained frozen-source confirmation, edits the
article, or promotes a table value automatically.

## Computational and storage policy

- discovery burn-in: 1000 iterations;
- retained discovery MCMC: 3000 iterations;
- thinning: 1;
- VB initialization: required, maximum 150 iterations;
- MCMC progress cadence: 50 iterations;
- heartbeat cadence: 30 minutes;
- one thread per root;
- default parallel roots: 8;
- resource gate: current load plus workers leaves four logical cores free;
- minimum available memory: 180 GB;
- minimum available disk: 300 GB.

Retained artifacts are scalar metrics, compact fit/forecast paths, statuses,
progress traces, logs, configuration, hashes, and manifests. Successful or
failed campaign roots must not retain `.rds`, `.rda`, or `.RData` payloads.
Unexpected binary output fails the stage before the next gate.

## Failure and rollback policy

- Every stage writes `STARTED`, `COMPLETED`, gate, failure, and storage rows.
- A detached tmux session owns only this v2 pipeline.
- The scheduler waits for resources and never stops unrelated jobs.
- Coarse failure cannot trigger refinement.
- Empty candidate selection is a scientific stop, not a software failure.
- All v1 files and outputs remain immutable.
- No reset, stash, overwrite, or destructive cleanup is part of the workflow.
- A failed stage is resumed using a new run tag and an explicit subset manifest;
  completed evidence is retained for diagnosis.

## Prelaunch verification

The implementation was checked under R 4.6.0 before detached launch:

- package load and package version 1.0.0: pass;
- topology-v1 and cellwise-v2 focused tests: pass;
- protocol, source-registry, source-window, rolling-grid, forecast-horizon,
  artifact-schema, storage-policy, stage-filtering, shared-interface, telemetry,
  Q-DESN source-window, horizon-summary, interface, launcher-filter, and
  storage-light tests: pass;
- orchestration self-test: pass at eight workers;
- prepare-only run `qdesn-arv2-prelaunch-prepare-20260801_005958`: 270 selected
  roots, no forbidden binary payloads;
- smoke run `qdesn-arv2-prelaunch-smoke-20260801_010130`: one successful MCMC
  root with fit and H=1000 forecast summaries, no forbidden binary payloads;
- smoke audit: correctly returned `BLOCK_INCOMPLETE` with 1/270 complete roots
  and did not generate or launch a refinement stage.

The two prelaunch tags are test evidence only and must not be used for candidate
selection or article promotion. The detached pipeline creates fresh run tags tied
to the clean, pushed launch commit.

## Reproducible commands

Materialize and verify:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/materialize_qdesn_alpha_rho_cellwise_v2.R \
  --workers 8
```

Focused tests:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e \
  "testthat::test_file('tests/testthat/test-qdesn-alpha-rho-cellwise-v2.R')"
```

Detached launch, after the branch is clean and exactly pushed:

```bash
bash validation/fitforecast_v2/scripts/launch_qdesn_alpha_rho_cellwise_v2.sh \
  /data/jaguir26/local/src/exdqlm__wt__qdesn_alpha_rho_cellwise_v2_1p0p0 8
```

Health check:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/healthcheck_qdesn_alpha_rho_cellwise_v2.R
```
