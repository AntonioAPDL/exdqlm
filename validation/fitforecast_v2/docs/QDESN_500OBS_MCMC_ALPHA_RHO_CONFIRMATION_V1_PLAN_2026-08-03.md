# Q-DESN Alpha/Rho Full-Budget Confirmation V1

Date: 2026-08-03

Lane: independent single-quantile Q-DESN/exQ-DESN validation

Package baseline: exdqlm 1.0.0

Article authority: `Article-Q-DESN---Version-2` (read-only until closeout)

## Decision

The alpha/rho seed-repair campaign completed all 48 planned roots and prepared
two objective-specific candidates for full-budget confirmation. The correct next
step is an eight-root paired experiment, not another broad screen and not a
global-specification search.

The experiment contains:

- two family/quantile cells;
- one candidate and its exact parent per cell;
- two frozen reservoir realizations per candidate/parent pair;
- one 5,000-burn plus 20,000-retained MCMC chain per explicit root;
- identical source, reservoir, and sampler seeds within each candidate/parent
  pair.

Generic multiseed expansion is disabled because the package's generic expansion
derives new reservoir seeds from root identities. That behavior is appropriate
for broad replication but would invalidate this paired confirmation. No package
inference function is changed.

## Evidence Base

The completed repair evidence is:

```text
reports/shared_fitforecast_v2_orchestration/
  qdesn_alpha_rho_seedrepair_v1_20260801_192732/audit/
```

Its gate is `FULL_BUDGET_HANDOFF_PREPARED`, with 48/48 complete roots, 48/48
seed-contract passes, zero missing or unexpected specs, and zero retained binary
payloads. The handoff is:

```text
validation/fitforecast_v2/docs/
  qdesn_500obs_mcmc_alpha_rho_seedrepair_v1_full_budget_handoff_20260801.csv
```

## Exact Cells And Designs

| Cell | Role | D | n | m | alpha | rho | pi_w | pi_in | tau0 | Reservoir seeds |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Gaussian mixture, p=0.25, exAL-RHS | candidate | 1 | 4 | 2 | 1e-4 | 0.997 | 1.0 | 2/3 | 3e-4 | 42083, 942084 |
| Gaussian mixture, p=0.25, exAL-RHS | exact parent | 1 | 4 | 2 | 1e-3 | 0.45 | 0.0025 | 0.05 | 3e-4 | paired |
| Laplace, p=0.05, exAL-RHS | candidate | 1 | 30 | 15 | 1e-4 | 0.45 | 0.03 | 0.30 | 1e-4 | 123, 900124 |
| Laplace, p=0.05, exAL-RHS | exact parent | 1 | 30 | 15 | 0.02 | 0.45 | 0.03 | 0.30 | 1e-4 | paired |

Each pair also shares `mcmc_seed`, `mcmc_rng_seed`, `vb_warm_start_seed`, and
`synthesis_seed`. The two reservoir realizations remain distinct.

## Source Contract

Registry identity field:

```text
source_registry_hash_value
```

Expected value:

```text
edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275
```

The materializer snapshots the two selected registry rows and verifies every
canonical source file and every staged fit/forecast source file by SHA-256.

| Quantity | Frozen value |
|---|---:|
| Warmup length | 2,000 |
| Main source length | 10,000 |
| Total source length | 12,000 |
| Training indices | 8501:9000 |
| Forecast origin | 9000 |
| Forecast block | 9001:10000 |
| Maximum lead | 30 |
| Origin stride | 30 |
| Refit at each origin | no |

Forecasting uses the existing rolling-origin, no-refit state-update contract.

## Execution Contract

The staged lifecycle is:

1. prepare-only validation of all eight full roots;
2. four-root executable smoke using both cells, candidate and parent, reservoir
   replicate 1;
3. smoke seed/hash/storage audit;
4. load, memory, and disk gate;
5. eight one-core full MCMC workers;
6. source, seed, metric, diagnostic, and storage closeout;
7. manual article review only when a metric improves the current envelope.

Telemetry uses MCMC progress every 50 iterations and an orchestration heartbeat
every 1,800 seconds. Each full root has 5,000 burn-in iterations and 20,000
retained iterations. The pipeline's safety timeout is seven days per fit; it is
not a scientific stopping rule.

## Scientific Gates

For Gaussian mixture at p=0.25, the primary gate is median candidate/parent
forecast-MAE ratio at most 0.95. Median fit and check-loss ratios must each be at
most 1.05, and no individual metric ratio may exceed 1.20.

For Laplace at p=0.05, the primary gate is median candidate/parent fit-RMSE ratio
at most 0.98. Median forecast-MAE and check-loss ratios must each be at most 1.05,
and no individual metric ratio may exceed 1.20.

Diagnostic status and signoff grades are reported but do not silently suppress
finite metric evidence. Article promotion is metric-specific: a candidate metric
must improve the current exQ-DESN value, both companion metrics must remain
within 5% of their current values, and all seed/source contracts must pass.

## Storage Policy

Routine successful or failed confirmation outputs must not retain `.rds`,
`.rda`, or `.RData` payloads. The retained record is limited to metrics, compact
paths, requests, manifests, logs, telemetry, status files, and hashes. Frozen
source `sim_output.rds` files under the shared source registry are inputs and are
not campaign result payloads.

## Reproducible Commands

Materialize and test:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/materialize_qdesn_alpha_rho_confirmation_v1.R \
  --workers 8

/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e \
  "testthat::test_file('tests/testthat/test-qdesn-alpha-rho-confirmation-v1.R')"
```

Orchestration self-test:

```bash
FULL_CONFIRMATION_APPROVED=1 PIPELINE_SELF_TEST=1 \
  validation/fitforecast_v2/scripts/run_qdesn_alpha_rho_confirmation_v1_pipeline.sh \
  "$(git rev-parse --show-toplevel)" 8 qdesn_alpha_rho_confirmation_v1_selftest
```

Launch after a clean, pushed commit:

```bash
FULL_CONFIRMATION_APPROVED=1 \
  validation/fitforecast_v2/scripts/launch_qdesn_alpha_rho_confirmation_v1.sh \
  "$(git rev-parse --show-toplevel)" 8
```

Health check:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/healthcheck_qdesn_alpha_rho_confirmation_v1.R
```

## Rollback And Stop Rules

All new roots use a new stage and run tag. Existing evidence is never replaced.
A failed prepare or smoke blocks the full stage. An interrupted full stage is
resumed only for absent roots after auditing requests and hashes; completed roots
are not rerun blindly. No reset, stash, overwrite, or destructive cleanup is
needed.

If neither cell transfers under this confirmation, local alpha/rho screening is
closed. The next scientific direction is a predeclared architecture, readout,
or shrinkage redesign rather than another nearby alpha/rho grid.
