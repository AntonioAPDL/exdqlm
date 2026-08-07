# Q-DESN MCMC Dynamic-Seed Repair v1

Date: 2026-08-07
Package: exdqlm 1.0.0
Branch: `validation/qdesn-mcmc-dynamic-seedrepair-v1-1.0.0`
Worktree: `/data/jaguir26/local/src/exdqlm__wt__qdesn_mcmc_dynamic_seedrepair_v1_1p0p0`

## Decision

Run one focused MCMC discovery screen for the two Normal, quantile 0.25,
regularized-horseshoe cells whose previous high-alpha experiment was not a
valid test of reservoir dynamics:

- Q-DESN under AL;
- exQ-DESN under exAL.

The prior screen used DESN seed 123. Its realized recurrent matrix has zero
nonzero entries, and its only nonzero input weight is attached to the bias
column. Therefore `sum(Win != 0) > 0` was true while
`sum(Win[, -1] != 0) == 0`. With no observed-series input path, changing
alpha could not test how memory affects the data-driven reservoir state.

This campaign repairs that design defect. It does not reinterpret the old
negative result as evidence, broaden unrelated cells, update the article, or
start full-budget MCMC confirmation automatically.

## Frozen Authority

The exact authority is:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_trainonly_article_v1_20260805/qdesn_dqlm_500obs_trainonly_article_v1_20260805_interface.csv`

SHA-256:

`dff814fab1e920c10760645ac9e8d37dfa7f33ae2afba34ee8ed2a5509f4952a`

Shared source-registry identity:

`edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`

Both target authorities use the same structural DESN contract:

| Field | Frozen value |
|---|---:|
| `D` | 1 |
| `n_each` | 6 |
| `m` | 1 |
| parent alpha | 0.00075 |
| rho | 0.35 |
| `pi_w` | 0.0025 |
| `pi_in` | 0.05 |
| RHS `tau0` | 0.0003 |
| DESN seed | 123 |
| readout response lags | 1 |
| reservoir lags | 0 |

The implementation extracts these fields from the authoritative fit-request
provenance and checks its file hash. It does not transcribe a replacement
model specification by hand.

## Source Continuity

The DGP, source seeds, and evaluation windows are unchanged from the completed
high-alpha campaign. Materialization regenerates and hashes `dev05` through
`dev08`, then compares every Normal p=0.25 artifact hash with a checked-in
reference:

- `series_wide.csv`;
- `series_long.csv`;
- `true_quantile_grid.csv`;
- source `sim_output.rds`.

The source RDS files are frozen DGP evidence, not fitted-model payloads. The
model-run storage gate separately forbids retained `.rds`, `.rda`, and
`.RData` files.

Source roles are fixed before outcomes are read:

- `dev05`, `dev06`, `dev07`: discovery;
- `dev08`: generated and hashed sealed holdout.

The time contract is:

| Quantity | Value |
|---|---:|
| warmup | 2,000 |
| main source length | 10,000 |
| total generated length | 12,000 |
| forecast origin source index | 9,000 |
| 500-observation training target window | 8,501-9,000 |
| forecast block | 9,001-10,000 |
| maximum forecast lead | 30 |
| origin stride | 30 |

Forecasting is rolling-origin, no-refit evaluation. Observed lags are updated
as the origin advances; fitted parameters are not relearned.

## Corrected Topology Contract

The input matrix contains a first column for bias. Dynamic connectivity is
defined only by non-bias columns:

```text
dynamic_input_nnz = sum(Win[, -1] != 0)
```

Seed selection is deterministic and outcome-blind:

1. Start at frozen parent seed plus 900001.
2. Inspect only the generated sparsity mask.
3. Keep the first three seeds with `dynamic_input_nnz > 0`.
4. Never inspect fit or forecast outcomes during seed selection.

The resulting seeds are `900124`, `900126`, and `900132`.

For every selected seed, all alpha candidates share the same recurrent and
input masks. A deterministic probe trajectory must produce a distinct state
hash for every alpha value. Materialization fails if the masks change within a
seed or if alpha remains state-inert.

## Discovery Design

Only alpha varies. `D`, `n`, `m`, rho, sparsity probabilities, `tau0`, readout
lags, and all preprocessing choices stay at the exact cell authority.

Cell-specific alpha levels are:

- AL Normal p=0.25: `0.40, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 0.99`;
- exAL Normal p=0.25: `0.40, 0.50, 0.60, 0.70, 0.80, 0.85, 0.90, 0.925, 0.95, 0.975, 0.99, 0.995`.

Each target cell contains:

- one frozen-authority control using seed 123;
- one dynamic-parent control at parent alpha for each of three active seeds;
- 12 alpha candidates for each active seed.

This gives 40 profiles per cell, 80 profiles total, and 240 discovery fits over
three development sources. The sealed source is excluded from discovery.

## Randomness Contract

DESN topology seeds are explicit in the screening profile and execution grid.
MCMC seed, MCMC RNG seed, VB warm-start seed, and synthesis seed are also
explicit. Within each target-cell/source pair, every candidate and both parent
types use the same sampler seeds. The closeout reads the executed
`fit_request.json` files and fails if any observed seed differs from the grid.

This produces two complementary comparisons:

1. Candidate versus the dynamic parent with the same source, DESN seed, and
   sampler seeds.
2. Candidate versus the frozen authority with the same source and sampler
   seeds.

The first estimates the alpha effect conditional on a valid dynamic topology.
The second tests whether that effect is useful relative to the article-facing
authority rather than merely useful relative to a new seed.

## Discovery Gate

Selection is separate for AL and exAL. The target metric for both cells is
forecast true-quantile MAE over H=1000. Fit RMSE and forecast check loss are
companions.

Each candidate has nine paired observations in each comparison: three source
replicates by three dynamic reservoir seeds. Each comparison must satisfy:

- 9/9 complete pairs;
- target median ratio at most 0.98;
- companion median ratios at most 1.05;
- target 90th-percentile ratio at most 1.10;
- target improvement in at least 6/9 pairs;
- target median improvement for at least 2/3 reservoir seeds;
- target median improvement for at least 2/3 source trajectories.

A finalist must pass both comparisons. At most two finalists are retained per
cell. Diagnostic signoff remains visible but does not erase finite screening
metrics.

## Compute And Telemetry

- 20 workers, one fit per worker;
- one computational thread per worker;
- 1,000 burn-in plus 3,000 retained MCMC iterations;
- VB warm-start initialization, maximum 150 VB iterations;
- MCMC progress every 50 iterations;
- orchestration heartbeat every 30 minutes;
- 30 minutes without artifact progress triggers review, not automatic kill;
- per-fit timeout 12 hours;
- load, available memory, and available disk resource gate before discovery.

The launcher dynamically binds the campaign to 20 least-used logical CPUs and
sets BLAS/OpenMP/Rcpp thread caps to one. It requires a clean branch whose HEAD
exactly matches its configured upstream.

## Storage And Failure Policy

Terminal model roots retain scalar fit metrics, scalar rolling-origin forecast
metrics, compact summaries, seed/config manifests, logs, progress traces, and
explicit status. They do not retain posterior draws, VB initialization
objects, forecast objects, or failure-debug RDS payloads.

In-flight transient payloads are reported separately. Any binary model payload
remaining in a terminal campaign root blocks closeout. Missing specs,
nonfinite metrics, unexpected specs, seed mismatches, timeouts, and storage
violations remain explicit failures.

## Pipeline Stages

1. Verify the frozen contract.
2. Prepare-only and assert zero binary model payloads.
3. Run one tiny MCMC smoke and assert finite outputs and storage-light cleanup.
4. Wait at the resource gate if necessary.
5. Run all 240 discovery specs with 20 workers.
6. Audit completion, executed seeds, paired ratios, and storage.
7. Stop with a machine-readable decision.

No full-budget confirmation and no article promotion occur automatically.
Confirmation, if justified, uses 5,000 burn-in plus 20,000 retained iterations
and requires an explicit follow-up decision.

## Commands

Materialize:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/materialize_qdesn_mcmc_dynamic_seedrepair_v1.R \
  --workers 20
```

Verify:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/verify_qdesn_mcmc_dynamic_seedrepair_v1.R
```

Launch after tests and push:

```bash
bash validation/fitforecast_v2/scripts/launch_qdesn_mcmc_dynamic_seedrepair_v1.sh
```

Health check:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/healthcheck_qdesn_mcmc_dynamic_seedrepair_v1.R
```

## Safety

This campaign is isolated in its own branch and worktree. It does not modify
the package 1.0.0 baseline, the article repository, prior result directories,
or unrelated active jobs. It does not reset, stash, overwrite, or clean other
worktrees. An interrupted run can be resumed from missing specification IDs;
completed scalar evidence remains intact.

## Execution Record

### Prelaunch evidence

Materialization produced 80 profiles and 240 discovery specs. A repeated
materialization generated identical hashes for all 18 tracked contract files.
Key SHA-256 values are:

| Artifact | SHA-256 |
|---|---|
| materialization manifest | `30a32da27afcf86c062fb9c2ea7a4de53916fe3635dbe85c2fa8eba946ac9655` |
| discovery defaults | `b610ab2e041e0870f0d2847148e0829f2b1a77ce942f9a307511046e58d9edf6` |
| discovery grid | `61a87e1fce4115f376a91a53fa3b7b4a7783669bc501cb3adecdcda0879de1b0` |
| target spec IDs | `854d3f455c5f32e69f609b70e4983d9addcc7587f0d6302c59d1f976639cfa09` |
| profile registry | `3680c0df9b8b826eec8151a2ad4b0e798080846f5168f877241beb5a18e5ede9` |
| topology audit | `0ad8a5c386d36cc1de4da206c32daaea6c7455e143418aba61e23f39cbb39c8b` |
| source continuity audit | `dd117e2d761b6abfe0894ad7c75f35e575b5f064c86912e7194b504bd9af8749` |

The verifier passed 32/32 campaign checks. The dedicated campaign test file
passed all expectations, and all 38 shared fit-and-forecast test files passed
under R 4.6.0. `pkgload::load_all()` also succeeded. The broader package suite
completed with pre-existing benchmark failures and warnings tied to optional
packages and absent historical run directories; no package source file differs
from implementation parent `823c6d6`.

Prepare-only tag `qdesn-dsr1-manual-prepare-20260807` wrote manifests without
creating a model result root or binary model payload. Dynamic smoke tag
`qdesn-dsr1-dynamic-smoke-20260807` completed one AL candidate using DESN seed
`900124`, alpha `0.40`, MCMC seeds `910101` and `920101`, VB warm-start seed
`930101`, and synthesis seed `940101`. It produced finite fit RMSE and finite
H=100/H=1000 forecast summaries, then retained zero `.rds`, `.rda`, or
`.RData` model payloads.

Running the strict closeout against that intentionally partial smoke returned
`BLOCK_INCOMPLETE` with 1/240 complete specs and no finalists. This confirms
that partial evidence cannot trigger confirmation or article promotion.

The full discovery launch and final closeout are pending the clean, pushed
launch commit. Until closeout passes, no result from this campaign is
authoritative or article-facing.
