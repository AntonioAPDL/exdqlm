# Q-DESN 500-Observation MCMC High-Alpha Cellwise v1

Date: 2026-08-06
Package baseline: exdqlm 1.0.0
Branch: `validation/qdesn-mcmc-highalpha-cellwise-v1-1.0.0`
Worktree: `/data/jaguir26/local/src/exdqlm__wt__qdesn_mcmc_highalpha_cellwise_v1_1p0p0`

## Decision

Run a case-specific, topology-aware MCMC calibration around the exact current
Q-DESN AL-RHS and exQ-DESN exAL-RHS authorities. The experiment tests whether
the previously underexplored high-alpha region can improve the lower-quantile
cells that remain behind the better of DQLM and exDQLM.

This is not a global-specification search. Every family, quantile, and
likelihood cell keeps its own current authoritative `D`, `n`, `m`, readout,
RHS `tau0`, and parent reservoir specification. Winners, if any, are selected
separately by cell.

## Evidence And Diagnosis

The frozen authority is:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_trainonly_article_v1_20260805/qdesn_dqlm_500obs_trainonly_article_v1_20260805_interface.csv`

SHA-256:

`dff814fab1e920c10760645ac9e8d37dfa7f33ae2afba34ee8ed2a5509f4952a`

Its source-registry identity is:

`edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`

The implementation reads the fit request associated with each authoritative
metric source and hashes it. No DESN specification is transcribed manually.

Across the distinct Q-DESN MCMC metric-source designs, most realized
reservoirs have no recurrent edges and many have no input edges. Consequently:

- `rho` is not an estimable search axis when the realized recurrent matrix is
  zero;
- `alpha` cannot influence a zero-state reservoir when its input matrix is
  zero;
- another unconditional alpha-rho rectangle would contain computational
  duplicates rather than distinct models.

The campaign therefore classifies each parent from its realized reservoir:

1. `repair_alpha_rho`: the parent has no input path. Preserve the exact parent
   as a control, add a connectivity-only control, and apply the established
   minimal active-topology rule before varying alpha and rho.
2. `exact_alpha_only`: input is active but recurrence is zero. Preserve the
   exact topology, vary alpha, and hold rho fixed.
3. `exact_alpha_rho`: input and recurrence are active. Preserve the exact
   topology and vary both alpha and rho.

The active-topology rule is `pi_w = min(1, 4/n)` and
`pi_in = max(parent_pi_in, 2/(m+1))`. A connectivity-only arm distinguishes a
topology gain from a high-alpha gain.

## Search Design

The broad levels are:

- alpha: `0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 0.95, 0.99`;
- rho: `0.35, 0.45, 0.60, 0.75, 0.85, 0.93, 0.97, 0.99`.

For active two-axis cells, a deterministic 20-point maximin subset spans the
64-point rectangle and retains historical bridge levels. For recurrence-inert
cells, all eight alpha levels are used with parent rho fixed. Each design is
paired with two deterministic reservoir seeds. Candidate topology masks are
hashed, and the audit fails if a searched axis is inert or if alpha/rho changes
the fixed sparsity mask.

### Wave 1

Wave 1 targets the four clearest scientific gaps:

| Cell | Main gap | Search mode |
|---|---|---|
| Q-DESN AL-RHS, normal, 0.05 | fit, forecast MAE, check loss | repaired alpha-rho |
| exQ-DESN exAL-RHS, Gaussian mixture, 0.25 | fit and forecast MAE | repaired alpha-rho |
| Q-DESN AL-RHS, normal, 0.25 | forecast MAE | exact alpha-only |
| exQ-DESN exAL-RHS, normal, 0.25 | forecast MAE | exact alpha-only |

This gives 124 profiles. Three fresh discovery trajectories yield 372 MCMC
fits.

### Wave 2

The seven remaining unresolved lower-quantile cells are fully materialized as
a 756-fit universe. They are not launch-approved. Wave 2 requires evidence
that the Wave 1 mechanism transfers within at least one target cell and an
explicit follow-up decision.

Median-quantile cells are not part of this calibration target.

## Source Contract

The DGP is unchanged:

- warmup: 2,000;
- main series: 10,000;
- total generated length: 12,000;
- forecast origin: 9,000;
- effective 500-observation target window: 8,501-9,000;
- forecast block: 9,001-10,000;
- rolling maximum lead: 30;
- rolling-origin stride: 30.

`dev05`, `dev06`, and `dev07` are discovery trajectories. `dev08` is generated
and hashed during materialization but sealed from Wave 1. The source seed
contract is checked in, while source registries, slices, and file hashes are
written to the materialization evidence directory.

## Compute Contract

- exactly 20 workers;
- one model fit per worker;
- one computational thread per worker;
- dynamically select 20 currently least-used logical CPUs;
- set `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, `MKL_NUM_THREADS`,
  `VECLIB_MAXIMUM_THREADS`, `NUMEXPR_NUM_THREADS`, and
  `RCPP_PARALLEL_NUM_THREADS` to 1;
- MCMC discovery budget: 1,000 burn-in plus 3,000 retained iterations;
- VB initialization is retained, with at most 150 VB iterations;
- MCMC progress is emitted every 50 iterations;
- orchestration heartbeat is emitted every 30 minutes;
- 30 minutes without a live artifact update is a review threshold, not an
  automatic kill condition;
- per-fit timeout: 12 hours.

The pipeline stages are contract verification, prepare-only, one tiny smoke,
resource gate, Wave 1 full screen, storage audit, and closeout. It never starts
Wave 2 or a full-budget confirmation.

## Storage And Failure Policy

Successful model roots retain scalar fit metrics, scalar rolling-forecast
metrics, compact path summaries, progress traces, logs, manifests, and status
records. They do not retain draws, VB initialization objects, forecast objects,
or failure RDS payloads. The pipeline fails its storage gate if a model run root
contains `.rds`, `.rda`, or `.RData`.

Finite metrics are never hidden merely because a diagnostic signoff is WARN or
FAIL. Status and signoff remain explicit evidence columns. Missing outputs,
timeouts, nonfinite metrics, and unexpected heavy payloads remain failures.

## Selection Gate

Every candidate is paired against the exact parent on the same fresh source
trajectory and reservoir seed. A discovery candidate requires:

- at least five of six complete pairs;
- every targeted median metric ratio at most 0.98;
- every companion median metric ratio at most 1.05;
- worst targeted q90 ratio at most 1.10.

At most two candidates per cell are handed to confirmation. There is no global
winner and no averaging across family/quantile cells.

Screening evidence cannot update the article. Article promotion requires a
separate 5,000 burn-in plus 20,000 retained confirmation on the frozen article
source and the sealed holdout, followed by a reproducible closeout comparison.

## Reproducible Commands

Materialize:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/materialize_qdesn_mcmc_highalpha_cellwise_v1.R \
  --workers 20
```

Verify:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/verify_qdesn_mcmc_highalpha_cellwise_v1.R
```

Launch after the branch is clean and pushed:

```bash
bash validation/fitforecast_v2/scripts/launch_qdesn_mcmc_highalpha_cellwise_v1.sh
```

Health check:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/healthcheck_qdesn_mcmc_highalpha_cellwise_v1.R
```

## Rollback And Safety

All work is isolated in a new branch and worktree. Existing validation results,
article repositories, and unrelated running jobs are not modified. No reset,
stash, overwrite, or destructive cleanup is part of this campaign. Aborting a
run requires stopping only its recorded tmux session; completed scalar evidence
remains auditable, and reruns can target only missing specification IDs.

## Prelaunch Evidence

The 2026-08-06 implementation gate produced the following frozen evidence:

- authoritative article-interface SHA-256:
  `dff814fab1e920c10760645ac9e8d37dfa7f33ae2afba34ee8ed2a5509f4952a`;
- shared source identity:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`;
- discovery registry SHA-256:
  `b0a66ce329b9e0462a6f35d2fc3e7fde99df536cf228ff76f33b28aa880f5ec1`;
- sealed-holdout registry SHA-256:
  `4e9f794ddd43780d7e935f5b6aa38e27662b6e05f5e2e3fc5784a10b57607f60`;
- materialized Wave 1: 124 profiles, 372 model fits, four target cells;
- staged but launch-gated Wave 2 universe: 252 profiles, 756 model fits,
  seven target cells.

Verification passed every campaign invariant, including package version 1.0.0,
authority hashes, source windows, train-only parent provenance, one thread per
worker, exactly 20 workers, finite budgets, active search axes, storage-light
retention, and the Wave 2/full-confirmation gates. The dedicated campaign test
file passed 69 of 69 expectations. The complete shared fit-and-forecast test
directory also passed, including source registry, source-window, forecast-
horizon, artifact-schema, storage-policy, stage-filtering, telemetry, rolling-
grid, and shared-interface tests.

A package-wide `testthat::test_local()` check still reports pre-existing
benchmark and historical-path failures. The same benchmark failures were
reproduced in the untouched base worktree, so they are recorded as baseline
package debt rather than changes introduced by this campaign. No legacy test
output is included in this branch.

Prepare-only tag `qdesn-hacv1-prelaunch-prepare-20260806` completed without
creating an `.rds`, `.rda`, or `.RData` payload. Smoke tag
`qdesn-hacv1-prelaunch-smoke-20260806` completed one intended model root with
finite fit metrics, H=100 and H=1000 rolling-origin summaries, and zero heavy
payloads. Running the closeout auditor against that intentionally incomplete
smoke returned `BLOCK_INCOMPLETE` with 1 of 372 specifications complete and 371
missing. This confirms that partial evidence cannot be promoted or trigger a
later wave.

The first detached launch attempt,
`qdesn_mcmc_highalpha_cellwise_v1_20260806_205718`, was rejected during CPU
selection before contract verification, preparation, smoke, or model fitting.
GNU `nproc` honored the already-applied `OMP_NUM_THREADS=1` cap and exposed only
CPU 0 to the selector. The selector now reads `_NPROCESSORS_ONLN` through
`getconf`, while the one-thread caps remain in force for every model process.
This aborted run ID is invalid evidence and must never be consumed.
