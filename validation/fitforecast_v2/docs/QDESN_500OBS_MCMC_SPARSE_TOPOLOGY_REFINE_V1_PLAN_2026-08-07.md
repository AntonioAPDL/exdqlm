# Q-DESN 500-Observation MCMC Sparse-Topology Refinement V1

## Scientific Decision

Run one prospective, full-budget mechanism experiment for the two unresolved
independent single-quantile cells:

- Q-DESN AL-RHS, Normal innovations, `tau = 0.25`;
- Q-DESN exAL-RHS, Normal innovations, `tau = 0.25`.

Selection and any later promotion are metric-specific within each cell. There
is no global winning DESN specification. Diagnostic grades remain visible but
do not exclude a finite, provenance-valid improvement.

## Evidence And Current Authority

The completed dynamic-alpha confirmation produced 30/30 finite, contract-valid
fits and three strict article-envelope improvements. Those improvements are
frozen before this experiment in:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_trainonly_article_v2_20260807/`

The promoted interface has 72 rows and SHA-256
`d412434bb3546cb3e3c4f03d633b30d0e64125948bbe3ac55ef230c0f1c56a53`.
It changes only:

| Model/cell | Metric | Previous | Current |
|---|---|---:|---:|
| AL-RHS, Normal 0.25 | fit RMSE | 2.262304 | 2.182784 |
| AL-RHS, Normal 0.25 | forecast MAE | 2.514897 | 2.481148 |
| exAL-RHS, Normal 0.25 | forecast MAE | 2.919851 | 2.858278 |

Neither likelihood improved forecast check loss. Both cells therefore still
target H=1000 forecast MAE relative to DQLM's 2.208591.

## Diagnosis

The current winning structure has `D=1`, `n=6`, `m=1`, `pi_w=0.0025`, and
`pi_in=0.05`. Its selected reservoirs have a non-bias input edge but zero
recurrent edges. Alpha changes the state update, while rho is inert because the
recurrent matrix is zero. More alpha-only screening would repeat the same
mechanism surface.

The earlier topology repair is not reused. It raised expected connectivity to
roughly four recurrent edges per node and two input edges per node, producing
condition numbers from about 608 to 10,147 versus about 3.7 for the coherent
parents. That was a dense design change, not a controlled test of recurrence.

## Outcome-Blind Sparse Topologies

Keep `D=1`, `n=6`, `m=1`, one response lag, zero reservoir lags, and
`rhs_tau0=3e-4`. Search deterministic seeds without inspecting outcomes for:

| Class | Exact recurrent edges | `pi_w` | `pi_in` | Seeds |
|---|---:|---:|---:|---:|
| `w01` | 1 | 1/36 | 1/12 | 2 |
| `w02` | 2 | 2/36 | 1/12 | 2 |
| `w03` | 3 | 3/36 | 1/12 | 2 |

Each accepted seed must have at least one non-bias input edge and unchanged
input/recurrent masks over every alpha/rho point. The deterministic search found
six seeds after 39 candidates. The exact seeds, masks, and search audit are
materialized in the campaign config files.

## Interaction Points

The experiment uses purposeful interactions instead of another Cartesian
alpha/rho sweep.

AL points:

`(0.05,0.35)`, `(0.10,0.70)`, `(0.20,0.90)`, `(0.40,0.35)`,
`(0.60,0.70)`, `(0.80,0.90)`.

exAL points:

`(0.55,0.35)`, `(0.65,0.70)`, `(0.70,0.90)`, `(0.75,0.35)`,
`(0.80,0.70)`, `(0.85,0.90)`.

Every topology has an exact same-seed parent at `alpha=0.00075`, `rho=0.35`.
Candidates and parent share source, reservoir, MCMC seed, MCMC RNG seed, VB
warm-start seed, and synthesis seed.

## Counts And Compute

- 2 likelihood cells;
- 3 edge classes x 2 topology seeds = 6 topologies per cell;
- 6 interaction candidates plus 1 matched parent per topology;
- 2 prospective sampler replicates;
- 144 candidate fits plus 24 parent fits = 168 full fits;
- 144 exact candidate-parent comparisons;
- 5,000 burn-in plus 20,000 retained MCMC iterations;
- 200 posterior metric draws;
- 20 load-balanced worker processes;
- one compute thread per fit, with BLAS/OpenMP thread counts fixed at one.

## Frozen Source And Forecast Contract

- registry hash field: `source_registry_hash_value`;
- registry hash: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`;
- `TT_warmup=2000`, `TT_main=10000`, `TT_total=12000`;
- training target indices `8501:9000`;
- forecast origin `9000`;
- forecast block `9001:10000`;
- rolling leads `1:30`, origin stride `30`;
- no refit at forecast origins; observed lag state is updated.

## Stages And Gates

1. Regenerate the deterministic materialization and require zero tracked drift.
2. Verify package, branch, authority hash, source hashes, topology, seeds,
   windows, budget, storage, and parallelism contracts.
3. Run prepare-only and reject any model `.rds`, `.rda`, or `.RData` payload.
4. Run a 3-fit smoke covering an AL candidate-parent pair and exAL candidate.
5. Wait for load <=42, memory >=96 GiB, and disk >=250 GiB.
6. Select the 20 least-used CPUs and run 20 one-thread fits concurrently.
7. Compact progress traces to first, final, and every 50th row while preserving
   every status, heartbeat, and failure record.
8. Reject retained fitted-model binary payloads.
9. Close out 168 specs and 144 pairs, writing a status-agnostic metric envelope.
10. Leave article promotion manual and evidence-driven.

Progress is emitted every 50 MCMC iterations. The orchestration heartbeat is
written every 30 minutes; a 30-minute progress age is the stale-review
threshold. The health parser reports the runner's global iteration directly,
from 1 through 25,000.

## Failure And Recovery Policy

Nonzero runner status does not discard finite metrics. Promotion eligibility
requires exact spec identity, all five seeds, source registry and source-file
hashes, source windows, 5,000+20,000 budget, and finite metrics. Missing or
contract-invalid roots block closeout and are the only roots eligible for a
resume. Valid roots are never rerun merely because another root failed.

## Storage Policy

Keep scalar fit/forecast metrics, compact path summaries, configs, manifests,
logs, statuses, failure records, and compact progress traces. Do not retain
draws, VB warm-start objects, forecast objects, or fitted-model binary payloads.
Trace compaction is atomic and writes before/after row, byte, and hash evidence.

## Reproduction

```bash
cd /data/jaguir26/local/src/exdqlm__wt__qdesn_mcmc_sparse_topology_refine_v1_1p0p0
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/materialize_qdesn_mcmc_sparse_topology_refine_v1.R \
  --workers 20
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/verify_qdesn_mcmc_sparse_topology_refine_v1.R
bash validation/fitforecast_v2/scripts/launch_qdesn_mcmc_sparse_topology_refine_v1.sh
```

Health check:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/healthcheck_qdesn_mcmc_sparse_topology_refine_v1.R
```

## Article Boundary

This campaign is independent-Q-DESN validation only. It does not modify or
launch joint-QDESN, PriceFM, GloFAS, or application work. Closeout writes an
article-interface preview but never edits the article repository automatically.
