# Q-DESN 500-Observation MCMC Metric-Gap v3 Tau0 Repair

## Scope

This repair belongs only to the independent Q-DESN/exQ-DESN fit-and-forecast
validation workflow on branch `validation/shared-fitforecast-v2-1.0.0`. It does
not modify the exdqlm 1.0.0 baseline branch, statistical model kernels, article
files, application workflows, or unrelated running jobs.

The source campaign is retained as immutable diagnostic evidence:

- stage: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3`
- run tag: `qdesn-tt500-mcmc-metricgap-v3-full-20260726__git-fa5dca4`
- campaign stamp: `20260726-193528__git-fa5dca4`
- attempted roots: 80
- metric-complete successful roots: 55
- pre-fit execution failures: 25

The 55 successful roots are never recomputed or overwritten. The repair stage
contains exactly the 25 failed roots:

`qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_tau0_repair`

## Root Cause

The source grids, target-spec table, fit-request manifests, and root manifests
all retained `rhs_tau0 = 3e-5`. The value was corrupted only when
`run_esn_pipeline_from_cfg()` serialized the nested configuration into
`EXDQLM_CFG_JSON` with jsonlite's default numeric precision:

```r
jsonlite::toJSON(list(tau0 = 3e-5), auto_unbox = TRUE)
```

produces `{"tau0":0}`. Every one of the 25 failed child logs therefore ended
before model fitting with:

```text
Error: RHS_NS hypers$tau0 must be > 0.
```

This is a deterministic transport failure, not evidence against the 25
statistical designs.

## Repair

`R/run_esn_pipeline.R` now serializes `EXDQLM_CFG_JSON` with `digits = NA`.
The existing child-process entrypoint test passes a nested
`inference$vb$priors$beta$rhs_ns$tau0 = 3e-5` configuration to a real child R
process, reads the child's received JSON, and requires exact numeric recovery.

The repair materializer derives its target set from the frozen source target
table and completed campaign progress table. It refuses to write outputs unless:

1. the source target and progress tables each contain 80 roots;
2. the source campaign has exactly 55 successes and 25 failures;
3. the 25 failed roots are exactly the 25 targets with `rhs_tau0 = 3e-5`;
4. the repair set does not overlap any successful source root;
5. the repair grid, profiles, assignments, roots, and spec IDs remain one-to-one.

No statistical specification, source input, source hash, seed, likelihood,
fit window, forecast window, or MCMC budget changes.

The repair keeps the full frozen 80-profile catalog as canonical deterministic
seed context. Execution remains restricted to the 25 repair spec IDs. Removing
the other 55 profiles from the catalog would renumber deterministic seeds and
would therefore no longer be an exact repair of the failed statistical specs.

## Frozen Protocol

- effective fit size: 500 observations
- fit source indices: `8501:9000`
- forecast origin source index: `9000`
- forecast source indices: `9001:10000`
- rolling-origin forecast horizon: `Hmax = 30`
- MCMC screening budget: 2,000 burn-in + 8,000 retained iterations
- VB warm start: required
- workers: one computational thread per root
- progress cadence: every 50 MCMC iterations
- storage policy: scalar metrics, compact paths, logs, statuses, and manifests;
  no routine retained `.rds`, `.rda`, or `.RData` payloads

## Generated Contracts

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_tau0_repair_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_tau0_repair_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_tau0_repair_cell_assignments.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_tau0_repair_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_tau0_repair_target_spec_ids.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_tau0_repair_materialization_manifest.json`

The materialization manifest hashes every source and generated contract.

## Staged Commands

Materialize and prepare only:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  scripts/orchestrate_qdesn_tt500_mcmc_metricgap_v3_tau0_repair.R \
  --prepare-only --workers 8
```

Run one real `rhs_tau0 = 3e-5` smoke:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  scripts/orchestrate_qdesn_tt500_mcmc_metricgap_v3_tau0_repair.R \
  --skip-materialize --skip-prepare --smoke --workers 1
```

The detached full repair requires both explicit gates:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  scripts/orchestrate_qdesn_tt500_mcmc_metricgap_v3_tau0_repair.R \
  --skip-materialize --skip-prepare --skip-smoke \
  --full --launch-approved --workers <idle-worker-count>
```

## Combined Closeout

After all 25 repair roots complete successfully,
`scripts/closeout_qdesn_tt500_mcmc_metricgap_v3.R` combines the 55 original
metric-complete roots with the 25 repaired roots. It requires one unique
metric-complete row for all 80 frozen targets and writes:

- an all-candidate ledger;
- an execution/replacement audit;
- per-cell rankings and Pareto candidates;
- metric-wise gains;
- per-cell full-confirmation handoff;
- unresolved-cell table;
- source/file hash manifests;
- storage audit and decision summary.

Selection is specific to each family, quantile, and likelihood. There is no
global DESN specification winner. A reduced-budget candidate enters the
full-confirmation handoff only when its targeted metric improves by at least
0.5% and no fit RMSE, H=1000 forecast MAE, or H=1000 forecast check loss
regresses by more than 1% from the frozen metric envelope.

The closeout does not update the article and does not launch the 5,000 burn-in +
20,000 iteration confirmation stage. Both remain separately gated.

## Gate Results

- runtime: R 4.6.0
- package: exdqlm 1.0.0
- focused precision/repair tests: PASS
- shared rolling-origin, source-window, horizon, interface, filtering, storage,
  runtime, progress, and inference contract tests: PASS
- canonical repair grid audit: PASS, 25 supplied rows are an exact subset of
  the 720-row canonical grid recovered with the frozen 80-profile seed context
- prepare-only tag:
  `qdesn-tt500-mcmc-metricgap-v3-tau0-repair-prepare-20260726-214206__git-fa5dca4`
- prepare-only selected atomic specs: 25
- real smoke tag:
  `qdesn-tt500-mcmc-metricgap-v3-tau0-repair-smoke-20260726-214254__git-fa5dca4`
- real smoke campaign stamp: `20260726-214309__git-fa5dca4`
- real smoke result: 1/1 root SUCCESS, 1/1 fit summary, fit path present,
  rolling-origin forecast metrics present
- smoke `rhs_tau0`: `3e-5` in both `fit_request.json` root specification and
  child pipeline configuration
- prepare/smoke forbidden binary payload count: 0
- article files changed: none

The earlier prepare attempt under orchestration tag
`qdesn-tt500-mcmc-metricgap-v3-tau0-repair-orch-20260726-213952__git-fa5dca4`
stopped before compute. It correctly detected that a 25-row profile catalog
renumbered deterministic seeds. That attempt is diagnostic and non-consumable.
The materializer was corrected to preserve the full 80-profile seed context,
after which prepare-only and smoke passed.

Status after local gates: `READY_TO_COMMIT_AND_LAUNCH_25_SPEC_REPAIR`.

Remaining detached-launch gates:

1. validation-only code/config changes are committed and pushed;
2. currently unused cores are selected without disturbing unrelated jobs;
3. the detached command uses a new run tag and results/report roots;
4. combined closeout waits for all 25 repair roots and does not launch full
   confirmation automatically.
