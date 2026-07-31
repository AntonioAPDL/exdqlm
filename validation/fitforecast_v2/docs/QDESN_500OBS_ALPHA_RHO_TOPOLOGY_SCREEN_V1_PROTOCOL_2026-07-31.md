# Q-DESN 500-Observation Alpha/Rho and Topology Screen v1

## Status

- Scope: independent, single-quantile Q-DESN/exQ-DESN validation only.
- Package baseline: exdqlm 1.0.0.
- Branch: `validation/qdesn-alpha-rho-topology-v1-1.0.0`.
- Article authority: read-only during this screen.
- Full-budget confirmation: explicitly outside this launch.
- Article promotion: forbidden from raw mechanism or broad-screen output.

## Scientific objective

The current 500-observation MCMC evidence shows several case-specific Q-DESN
and exQ-DESN RHS rows with strong forecast metrics but weak fit recovery, or
strong fit recovery but weak forecast transport. The immediate question is not
whether one global DESN specification can solve every row. The question is
whether the leak (`alpha`) and recurrent-radius (`rho`) controls can improve
specific model-family-quantile cells when every other coherent parent setting
is held fixed.

The screen targets five sentinel cells:

| Likelihood | Family | Quantile | Role |
|---|---:|---:|---|
| AL | Gaussian mixture | 0.05 | hard fit gap |
| AL | Gaussian | 0.05 | hard fit and forecast gap |
| exAL | Laplace | 0.05 | hard fit gap with strong forecast |
| exAL | Gaussian mixture | 0.25 | hard fit and transport gap |
| exAL | Laplace | 0.25 | resolved negative control |

The negative control is deliberate. A mechanism that improves only already
hard cells without preserving the resolved cell is not sufficiently stable for
promotion.

## Why a naive alpha/rho grid is invalid

The coherent parent profiles have extremely sparse random reservoirs. Four of
the five parent designs use `n=4` or `n=8` with `pi_w` between 0.00075 and
0.0025. Their expected total recurrent edge count is therefore far below one.
Several also have an expected input edge count below one. If `W` is all zero,
`rho` has no effect. If `Win` is all zero, the reservoir receives no observed
signal. A broad alpha/rho grid on those draws would be numerically broad but
scientifically inert.

This protocol first identifies whether recurrence, input connectivity, or both
are missing:

1. `parent_exact`: exact parent sparsity, alpha, rho, and seed.
2. `recurrence_only`: expected recurrent indegree raised to four; input mask unchanged.
3. `input_only`: expected input indegree raised to at least two; recurrent mask unchanged.
4. `full_topology`: both repairs at the parent alpha and rho.

The broad alpha/rho screen is allowed only if these paired controls show a
credible mechanism signal.

## Broad parameter surface

The admissible alpha levels are:

`0.0001, 0.0003, 0.001, 0.003, 0.01, 0.03, 0.10, 0.25, 0.50, 0.80, 0.95`.

The admissible rho levels are:

`0.05, 0.15, 0.30, 0.50, 0.70, 0.85, 0.93, 0.97, 0.99, 0.997`.

The full Cartesian product contains 110 points per cell and is wasteful. The
frozen broad design uses 32 points:

- 8 boundary and interaction anchors;
- 24 deterministic maximin points selected after transforming log10(alpha)
  and logit(rho) to comparable unit intervals.

The transformed-space design covers slow/fast leaks, weak/near-unit recurrent
radii, and their interactions. It is deterministic and tested for uniqueness.

## Repeated-measures design

Each cell-arm result is evaluated on:

- three independently generated DGP trajectories with predeclared latent and
  observation-noise seeds;
- two reservoir seeds;
- the same raw W and Win masks for all fully repaired alpha/rho arms within a
  cell and reservoir replicate.

This gives six paired observations per cell-arm. The existing frozen article
trajectory is excluded from selection and remains reserved for later
confirmation.

Counts:

| Stage | Cells | Arms/cell | Reservoir seeds | Source replicates | MCMC specs |
|---|---:|---:|---:|---:|---:|
| Mechanism | 5 | 4 | 2 | 3 | 120 |
| Broad alpha/rho | 5 | 32 | 2 | 3 | 960 |
| Total discovery | 5 | 36 | 2 | 3 | 1080 |

## Frozen fit and forecast protocol

- `TT_warmup = 2000`
- `TT_main = 10000`
- `TT_total = 12000`
- training source indices: `8501:9000`
- forecast origin source index: `9000`
- forecast source indices: `9001:10000`
- rolling-origin forecast, no refit
- maximum lead: 30
- origin stride: 30
- fit metric: true-quantile RMSE on the effective training window
- forecast metrics: true-quantile MAE and check loss over the H=1000 rolling-origin summary

The source generator, seeds, file hashes, materialized windows, and source
registry are retained. The original shared v2 registry is neither edited nor
replaced.

## Discovery and confirmation budgets

Discovery uses MCMC because historical VB rank is not assumed to predict MCMC
rank:

- VB initialization: at most 150 iterations;
- MCMC burn-in: 1000;
- retained MCMC iterations: 3000;
- thinning: 1;
- progress output: every 50 iterations;
- posterior metric draws: 100.

Discovery output can nominate candidates only. A nominated per-cell candidate
must later run with the established full confirmation budget of 5000 burn-in
and 20000 retained iterations on the frozen article-protocol source.

## Automatic mechanism gate

The broad stage starts only when:

1. at least 90% of the 120 expected mechanism specs have all three finite metrics;
2. at least two hard cells show a paired median improvement of at least 5% in
   one metric under a topology repair;
3. the same repair does not worsen the worst paired median metric by more than 25%;
4. full topology is either directly helpful in a hard cell or is non-catastrophic
   across the hard cells.

Failure to pass is a scientific stop, not a software failure. The pipeline
records `STOP_NO_MECHANISM_SIGNAL` and does not spend the broad-screen compute.

## Broad candidate gate

Candidates are ranked separately within each model-family-quantile cell. No
global winner is computed. An arm can be nominated for full confirmation only
when:

- at least four of six paired evaluations are complete;
- every median metric ratio to the exact parent is at most 1.05;
- at least one median metric improves by 2% or more;
- the worst 90th-percentile paired ratio is at most 1.25.

At most three arms per cell are retained for later confirmation.

## Storage and failure policy

The screen retains scalar fit metrics, scalar H=1000 rolling-origin metrics,
compact paths, manifests, statuses, progress traces, and logs. It does not keep
successful model, draw, VB-initialization, forecast-object, `.rds`, `.rda`, or
`.RData` payloads. Source `.rds` objects are small required inputs and are
separately classified in the source registry.

Every stage writes an explicit status row and a 30-minute heartbeat. The
orchestrator waits for load, available-memory, and available-disk gates before
starting a heavy stage. It never kills or modifies unrelated jobs.

The latest campaign can be inspected without changing run state:

```bash
Rscript validation/fitforecast_v2/scripts/healthcheck_qdesn_alpha_rho_topology_v1.R
```

Pass `--run-id qdesn_alpha_rho_topology_v1_YYYYMMDD_HHMMSS` to inspect an
older launch explicitly. The health checker reports the active phase, tmux
state, completed and remaining roots, fit/forecast artifact counts, progress
age, and any forbidden binary payloads.

## Reproducible sequence

1. Materialize deterministic sources, profiles, grids, topology audit, and spec IDs.
2. Run package and campaign tests under R 4.6.0.
3. Run prepare-only manifests for both phases.
4. Run a tiny mechanism smoke and enforce the binary-payload policy.
5. Run the 120-spec mechanism stage.
6. Audit paired metrics and evaluate `GO_BROAD`.
7. If allowed, run a tiny broad smoke and the 960-spec broad stage.
8. Produce per-cell candidate lists; do not launch full confirmation automatically.

## Stop conditions

The pipeline stops before broad compute for incomplete mechanism evidence,
insufficient topology signal, source-window mismatch, source-hash mismatch,
unexpected binary payload retention, package-version mismatch, or any failed
smoke. Full-budget confirmation and article promotion always require a separate
decision after reviewing the broad audit.
