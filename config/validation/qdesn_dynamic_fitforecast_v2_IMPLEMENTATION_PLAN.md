# Q-DESN Dynamic Fit + Forecast v2 Implementation Plan

Date: 2026-05-15

Revision: v2.1

Worktree:

`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

Branch:

`validation/shared-fitforecast-v2-1.0.0`

Purpose:

Prepare the Q-DESN fit+forecast validation study for a clean, reproducible, storage-light launch on the shared exDQLM 1.0.0 dynamic fit+forecast API.

This plan supersedes the earlier rough launch-readiness list. It keeps the same safety posture, but sharpens the engineering strategy around documentation, reproducibility, compatibility, testing, and launch gates.

## Bottom Line

We should not do a broad rewrite before the validation launch.

The best launch-safe path is compatibility-first:

1. Restore/adapt the known Q-DESN pipeline entrypoint contract.
2. Keep the existing Q-DESN validation runner structure.
3. Add strict runtime, grid-filter, source-index, horizon-summary, and storage tests around it.
4. Run source generation, prepare-only, smoke, and healthcheck gates before any full compute.

A full package-native rewrite of the pipeline can be the long-term cleanup, but it is too risky to do immediately before an expensive scientific validation launch unless it exactly reproduces the old artifact contract under tests.

The objective is not merely to make the launcher run. The objective is to make the launch auditable: the same source data, model specification, prior specification, grid filters, runtime, storage policy, and failure policy must be recoverable from repository files and run manifests without relying on chat history.

## Plan V2.1 Improvements

This revision strengthens the plan in four areas:

1. Documentation:
   - establish this file as the canonical Q-DESN implementation tracker;
   - require every implementation decision to be reflected in code-adjacent documentation or manifests;
   - keep the shared exDQLM/Q-DESN tracker as the cross-chat coordination layer, not the detailed implementation source of truth.
2. Reproducibility:
   - require runtime, source hashes, selected grid rows, worker policy, storage policy, and failure policy in manifests before any smoke or full launch;
   - require prepare-only preflight outputs for every planned phase;
   - require source-window verification before any model fit.
3. Rewrite discipline:
   - prefer compatibility adapters for the pre-launch path;
   - defer package-native rewrites until artifact parity and numerical smoke parity are demonstrated;
   - forbid silent behavioral changes to Q-DESN inference, priors, storage retention, or source-window semantics.
4. Testing:
   - require non-skipping tests for pipeline entrypoints;
   - add tests for launch phase filtering, no-leakage, horizon summaries, runtime guards, and storage-light retention;
   - make smoke launch a gate after unit/contract/preflight tests, not a substitute for them.

## Why This Is The Best Path

The current Q-DESN validation code already expects a specific pipeline artifact contract:

- `models/forecast_objects.rds`
- `tables/scores_summary.csv`
- `tables/timing_summary.csv`
- `tables/timing_breakdown.csv`
- `manifest/runtime_summary.json`
- `manifest/status.txt`
- compact train/forecast path CSVs after retention handling

The current worktree contains `R/run_esn_pipeline.R`, which dispatches to:

- `scripts/pipeline_real_main.R`
- `scripts/pipeline_sim_main.R`

Those two scripts are currently absent in this worktree. Older Q-DESN worktrees contain them. That means the existing validation runner is structurally prepared, but the pipeline entrypoint layer is incomplete.

Restoring/adapting the entrypoints is safer than rewriting the full runner because:

- the existing validation and closeout functions already know how to consume the old artifact structure;
- previous Q-DESN validation evidence used that contract;
- the MCMC path is nontrivial and should not be reimplemented under launch pressure;
- tests can lock the restored entrypoints down before source generation or smoke.

## Alternatives Considered

### Option A: Broad Package-Native Rewrite Before Launch

This would replace the script-entrypoint pipeline with a cleaner package-native implementation before the validation campaign.

Decision: reject for the pre-launch path.

Reason:

- it increases the number of scientific and engineering changes made at the same time;
- it risks changing fitted quantities, retained summaries, and closeout behavior;
- it would need full artifact parity tests before it could be trusted;
- it delays the validation campaign without clearly reducing launch risk.

This remains a good post-launch cleanup direction once the fit+forecast campaign has a stable, tested artifact contract.

### Option B: Hand-Edit Grids And Launch Scripts For Each Stage

This would create separate CSVs or ad hoc shell commands for VB, MCMC TT500, and MCMC TT5000.

Decision: reject.

Reason:

- it is easy to accidentally launch the wrong subset;
- it makes reproducibility depend on command history;
- it creates unnecessary drift between Q-DESN and exDQLM validation studies.

The better path is generic runner filters plus selected-grid manifests.

### Option C: Compatibility-First With Strong Contract Tests

This restores/adapts the known Q-DESN pipeline entrypoints, keeps the existing validation runner shape, and adds strict tests and manifests around the launch path.

Decision: accept.

Reason:

- it preserves the known artifact contract;
- it minimizes scientific behavior changes before compute;
- it gives us clear tests for the exact risks we identified;
- it allows staged launch approval after source verification, prepare-only preflight, smoke, and healthcheck.

## Non-Goals Before Launch

- Do not start the full validation run.
- Do not silently replace Q-DESN inference behavior.
- Do not hand-edit phase grids as the main control mechanism.
- Do not keep full successful `.rds`, `.rda`, or `.RData` payloads by default.
- Do not treat smoke outputs as MCMC-quality evidence.
- Do not make article tables depend on full `forecast_objects.rds`.
- Do not use chat-only decisions as the source of truth for launch behavior.

## Documentation Standard

Every implementation change must be paired with one of:

- an update to this plan;
- an update to the prep README;
- a machine-readable manifest written by preflight, launch, healthcheck, or closeout;
- a test that states and verifies the contract.

Required documentation layers:

1. Canonical Q-DESN implementation tracker:
   - `config/validation/qdesn_dynamic_fitforecast_v2_IMPLEMENTATION_PLAN.md`
2. Q-DESN local prep guide:
   - `config/validation/qdesn_dynamic_fitforecast_v2_PREP_README.md`
3. Shared cross-chat coordination tracker:
   - `/data/jaguir26/local/src/QDESN_EXDQLM_SHARED_FIT_FORECAST_VALIDATION_PLAN_2026-05-15.md`
4. Generated run evidence:
   - source inventory;
   - source-window verification;
   - selected-grid manifests;
   - runtime manifests;
   - retention manifests;
   - healthcheck reports;
   - closeout notes.

Documentation acceptance:

- a new Codex chat can identify the intended source data, model specs, prior specs, grid, launch phases, runtime, and storage policy from files alone;
- the shared tracker points to the canonical Q-DESN plan rather than duplicating implementation details;
- each launch phase has a prepare-only artifact before any detached launch.

## Reproducibility Contract

Each generated run tag must be reproducible from repository files plus generated manifests.

Required manifest fields:

- repository path;
- branch;
- HEAD commit;
- clean or dirty status;
- relevant diff hash or explicit dirty-file list if dirty;
- Rscript path;
- R home;
- R version;
- `.libPaths()`;
- package library environment variables;
- defaults file path and hash;
- grid file path and hash;
- source registry path and hash;
- source IDs and per-source hashes;
- selected grid rows and row count;
- active launch phase;
- active filters;
- worker count;
- storage retention policy;
- failure policy;
- output roots;
- timestamp and host.

Reproducibility acceptance:

- rerunning a prepare-only command produces the same selected grid and same planned roots when the inputs are unchanged;
- every fitted case can be traced to a source ID and source hash;
- every article-facing summary can be regenerated from compact CSV outputs without full heavy objects.

## Rewrite And Rewiring Policy

Use three levels of change:

1. Compatibility repair:
   - restore missing entrypoints;
   - adapt paths and API calls to exDQLM 1.0.0;
   - preserve output names and artifact schemas.
2. Contract hardening:
   - add tests, manifests, and healthcheck gates;
   - make implicit assumptions explicit.
3. Deferred cleanup:
   - package-native pipeline rewrite;
   - broader refactors;
   - artifact schema simplification.

Only levels 1 and 2 are pre-launch work. Level 3 requires exact artifact parity tests before it can replace the launch path.

Pre-launch rewiring means making existing intended components connect correctly under the exDQLM 1.0.0 API: runtime guards, entrypoint scripts, CLI filters, source registries, compact summaries, healthchecks, and manifests. It should not change the scientific meaning of the Q-DESN model, priors, training window, forecast window, or table metrics unless that change is explicitly documented, tested, and approved.

Minimum parity requirements for any replacement pipeline:

- same selected source rows;
- same effective train and forecast source indices;
- same model/prior configuration values;
- same essential summary columns;
- same retention behavior;
- same healthcheck interpretation;
- same or explicitly documented numerical differences on a tiny deterministic fixture.

## Target Launch Shape

Shared data:

- `TT_total = 12000`
- `TT_warmup = 2000`
- `TT_main = 10000`
- train origin/source index `9000`
- forecast source indices `9001:10000`

Q-DESN windows:

- TT500 raw window: `8189:10000`
- TT500 effective train: `8501:9000`
- TT500 forecast: `9001:10000`
- TT5000 raw window: `3689:10000`
- TT5000 effective train: `4001:9000`
- TT5000 forecast: `9001:10000`

Launch stages:

1. Source generation and window verification.
2. Prepare-only preflight.
3. Smoke.
4. VB full.
5. MCMC TT500.
6. MCMC TT5000.

The first scientific campaign should not use an unfiltered all-at-once `full` phase.

## Model And Prior Specs For This Campaign

Q-DESN specification:

- `D: 3`
- `n: [400, 400, 400]`
- `n_tilde: [400, 400]`
- `m: 60`
- `alpha: [0.3, 0.3, 0.3]`
- `rho: [0.95, 0.95, 0.95]`
- `act_f: [tanh, tanh, tanh]`
- `act_k: [identity, identity, identity]`
- `pi_w: [0.1, 0.1, 0.1]`
- `pi_in: [1.0, 1.0, 1.0]`
- `washout: 300`
- `add_bias: yes`
- `seed: 123`

RHS prior specification:

- `tau0: 1.0e-5`
- `a_zeta: 2.0`
- `b_zeta: 1.0`
- `s2: 1`
- `shrink_intercept: no`
- `intercept_prec: 1.0e-10`
- `n_inner: 2`
- `var_floor: 1.0e-08`

These values must be present in the defaults/config files, recorded in manifests, and surfaced in closeout documentation.

## Phase 0: Repository And Runtime Baseline

Goal:

Make runtime and branch state explicit before touching launch code.

Tasks:

1. Confirm worktree, branch, HEAD, upstream, and dirty status.
2. Confirm plain `Rscript` resolves to `/data/jaguir26/local/opt/R/4.6.0/bin/Rscript`.
3. Confirm `R.home()` is `/data/jaguir26/local/opt/R/4.6.0/lib64/R`.
4. Confirm `getRversion() >= "4.6.0"`.
5. Record these checks in preflight manifests and launch metadata.

Implementation files:

- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- `scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R`
- optional helper in `R/` if shared by tests

Tests:

- `tests/testthat/test-qdesn-validation-runtime-guard.R`

Acceptance:

- Launch/preflight fails if R is older than 4.6.0.
- Launch/preflight fails if `Rscript` resolves to `/usr/bin/Rscript`.
- Metadata records `Rscript`, `R_HOME`, R version, `.libPaths()`, `R_LIBS`, `R_LIBS_USER`, and `R_LIBS_SITE`.
- Prepare-only output records branch, HEAD, upstream, dirty status, and the exact defaults/grid file hashes.

## Phase 1: Pipeline Entrypoint Contract

Goal:

Make `run_esn_pipeline_from_cfg()` runnable and tested without changing its external contract.

Chosen strategy:

Restore/adapt the known Q-DESN pipeline entrypoints as compatibility entrypoints. Keep them as the launch path unless a package-native replacement proves exact artifact parity in tests.

Why not a full rewrite now:

- It would change too many moving pieces before a compute-heavy validation.
- The MCMC path, RHS/RHS-NS controls, and artifact retention logic have many details.
- The validation runner and closeout tools already consume the entrypoint artifact contract.

Tasks:

1. Recover the latest compatible versions of:
   - `scripts/pipeline_real_main.R`
   - `scripts/pipeline_sim_main.R`
2. Record their source commit/worktree in a compatibility note.
3. Adapt only what is needed for the 1.0.0 API.
4. Add a tiny generated fixture so pipeline tests do not skip.
5. Add an entrypoint-presence test.
6. Confirm outputs include:
   - status;
   - runtime summary;
   - timing summary;
   - scores summary;
   - forecast objects before retention pruning.

Implementation files:

- `scripts/pipeline_real_main.R`
- `scripts/pipeline_sim_main.R`
- `R/run_esn_pipeline.R`
- `tests/testthat/test-pipeline-inference-validation.R`
- `tests/testthat/test-qdesn-pipeline-entrypoints.R`

Acceptance:

- Tiny sim VB smoke passes.
- Tiny real VB smoke passes.
- MCMC smoke is either tiny and passing or split into an API-level MCMC initialization test plus one explicit runtime smoke.
- `collect_pipeline_run_summary()` can read the produced artifacts.
- The restored scripts include a compatibility note naming their source worktree or source commit.
- The entrypoint tests fail if `scripts/pipeline_real_main.R` or `scripts/pipeline_sim_main.R` disappear again.

## Phase 2: Generic Grid Filtering

Goal:

Make phase launches auditable and impossible to confuse.

Chosen strategy:

Add generic filters to the runner, not hand-maintained phase grids.

New CLI filters:

- `--fit-sizes 500`
- `--fit-sizes 5000`
- optionally `--families`, `--taus`, `--priors`, `--root-ids`

Phase mapping:

- `smoke`: use defaults smoke filter.
- `vb_full`: `--methods vb`
- `mcmc_tt500`: `--methods mcmc --fit-sizes 500`
- `mcmc_tt5000`: `--methods mcmc --fit-sizes 5000`
- `full`: explicit all-at-once only, not recommended for first scientific campaign.

Implementation files:

- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- `scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R`

Tests:

- `tests/testthat/test-qdesn-dynamic-fitforecast-launcher-filters.R`

Acceptance:

- Selected-grid CSV for `mcmc_tt500` contains only `fit_size == 500`.
- Selected-grid CSV for `mcmc_tt5000` contains only `fit_size == 5000`.
- Preflight manifests record active filters.
- `full` selection is explicit and auditable, not reached accidentally through a missing filter.

## Phase 3: Source-Index And No-Leakage Contract

Goal:

Guarantee Q-DESN trains only on intended effective training rows and evaluates only on the forecast block.

Key risk:

Materialization is correct, but downstream compact path alignment depends on realized fit metadata. The real-data evaluator constructs an effective training design, and the output metadata must reflect those exact effective training rows.

Tasks:

1. Ensure the fitted object or method manifest records the realized effective train indices.
2. Add `index_alignment.csv` or `index_alignment.json` per method.
3. Include:
   - raw source start/end;
   - context row count;
   - effective train start/end;
   - forecast start/end;
   - realized train row count;
   - realized forecast row count;
   - first/last train source index;
   - first/last forecast source index;
   - pass/fail status and reason.
4. Update compact path generation to use explicit effective train indices where available.
5. Extend healthcheck to report and gate this status.

Implementation files:

- `R/qdesn_model_selection_v2.R`
- `R/qdesn_static_exdqlm_crossstudy.R`
- `R/qdesn_dynamic_exdqlm_crossstudy.R`
- `R/qdesn_mcmc_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R`

Tests:

- `tests/testthat/test-qdesn-dynamic-fitforecast-no-leakage.R`

Acceptance:

- TT500 compact train path has 500 rows and source indices `8501:9000`.
- TT5000 compact train path has 5000 rows and source indices `4001:9000`.
- Forecast compact path has 1000 rows and source indices `9001:10000`.
- Healthcheck fails on any forecast-row leakage into train.
- Any mismatch between fitted-object metadata and compact-path metadata is an explicit failure.

## Phase 4: Fit + Forecast Metric Schema

Goal:

Make table generation unambiguous and independent of full heavy objects.

Tasks:

1. Update defaults language away from fit-only semantics:
   - replace `primary_window: train`;
   - replace `holdout_role: secondary_single_point`.
2. Add explicit fit+forecast evaluation windows:
   - effective train;
   - forecast H=100;
   - forecast H=1000.
3. Preserve existing `holdout_*` columns as aliases for full H=1000 forecast where needed.
4. Add horizon-summary tables from compact forecast paths:
   - `forecast_horizon_summary.csv`;
   - H=100 rows;
   - H=1000 rows.
5. Include source-index ranges in summaries.
6. Ensure article tables can be generated from compact CSV summaries only.

Implementation files:

- `config/validation/qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml`
- `R/qdesn_static_exdqlm_crossstudy.R`
- `R/qdesn_dynamic_exdqlm_crossstudy.R`
- future article table builder scripts

Tests:

- `tests/testthat/test-qdesn-dynamic-fitforecast-horizon-summaries.R`

Acceptance:

- H=100 summary uses forecast source indices `9001:9100`.
- H=1000 summary uses forecast source indices `9001:10000`.
- Missing compact forecast path is an explicit failure/warning, not silent success.
- Article-facing summaries expose both fit capture and forecast performance with unambiguous window labels.

## Phase 5: Storage-Light Enforcement

Goal:

Avoid hundreds of GB of validation outputs.

Tasks:

1. Keep `retention_profile: analysis`.
2. Keep `save_forecast_objects: no` for successful cases.
3. Keep `save_compact_fit_paths: yes`.
4. Healthcheck reports counts and bytes for:
   - `forecast_objects.rds`;
   - `.rda`;
   - `.RData`;
   - `rhs_trace.rds`;
   - `timing_summary.rds`.
5. Make smoke prove pruning happens after compact outputs are written.
6. Retain heavy objects only for a predeclared debug subset, failures if approved, or explicit repair waves.

Implementation files:

- `R/qdesn_mcmc_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- cleanup scripts only as audited dry-run tools

Tests:

- extend existing retention tests in `tests/testthat/test-qdesn-dynamic-p90-steepertrend-config.R`;
- add fit+forecast-specific storage test if needed.

Acceptance:

- Successful smoke cases do not retain full successful `forecast_objects.rds`.
- Healthcheck reports heavy payload inventory and total bytes.
- Any retained heavy successful object is linked to an explicit debug or failure-retention policy.

## Phase 6: Documentation And Reproducibility Artifacts

Goal:

Make every result reproducible without relying on chat history.

Required docs/manifests:

1. This implementation plan.
2. Prep README.
3. Source registry manifest with hashes.
4. Preflight manifest.
5. Launch manifest.
6. Runtime manifest.
7. Grid selection manifest.
8. Index alignment manifest.
9. Storage retention manifest.
10. Healthcheck report.
11. Smoke closeout note.

Every run tag must record:

- repo path;
- branch;
- HEAD commit;
- dirty/clean status;
- R runtime;
- defaults path;
- grid path;
- source registry path;
- source hashes;
- selected roots;
- phase filters;
- workers;
- storage policy;
- failure policy.

Acceptance:

- A fresh Codex chat can reproduce the exact source, grid, phase, and runtime choices from files alone.
- Every generated CSV or manifest has a stable path documented in the prep README or closeout note.
- The shared tracker records cross-study agreements, while this file records Q-DESN implementation details.

## Phase 7: Source Generation And Verification

Only after Phases 0-6 pass:

```sh
Rscript scripts/run_qdesn_dynamic_fitforecast_v2_source_refresh.R --execute
Rscript scripts/verify_qdesn_dynamic_fitforecast_v2_source_windows.R
```

Required outputs:

- shared source root;
- materialized Q-DESN source inventory;
- full Q-DESN v2 grid;
- source-window verification CSV;
- source hashes.

Acceptance:

- Every materialized row verifies PASS.
- Q-DESN and exDQLM validation chats agree on the same source IDs and hashes.

## Phase 8: Prepare-Only And Smoke

Prepare-only commands should be run before smoke for:

- smoke;
- `vb_full`;
- `mcmc_tt500`;
- `mcmc_tt5000`.

Smoke acceptance:

- correct R runtime;
- correct selected grid;
- correct source indices;
- compact train/forecast paths present;
- H=100/H=1000 summaries present;
- no retained full successful heavy objects;
- failures explicit and classifiable.

Smoke is not allowed to compensate for missing unit or contract tests. It is a final wiring test after the static/runtime/source/index/storage contracts have already passed.

## Phase 9: Full Launch

Only after smoke closeout:

1. Launch `vb_full`.
2. Healthcheck and close out.
3. Launch `mcmc_tt500`.
4. Healthcheck and close out.
5. Launch `mcmc_tt5000` with explicit approval.

Failure policy:

- no silent retries;
- no automatic repair overlay in the first scientific run;
- completed-but-FAIL rows remain in tables;
- repair waves get new run tags and repair manifests.

## Minimum Test Matrix

Existing tests to keep running:

```sh
Rscript -e 'pkgload::load_all(".", quiet=FALSE)'
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-qdesn-dynamic-fitforecast-source-windows.R", reporter="summary")'
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-exdqlm-forecast-horizon-inputs.R", reporter="summary")'
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-qdesn-fit-mcmc-precision-beta-api.R", reporter="summary"); testthat::test_file("tests/testthat/test-qdesn-prior-defaults.R", reporter="summary")'
Rscript scripts/run_qdesn_dynamic_fitforecast_v2_source_refresh.R
```

New tests to add:

- `test-qdesn-validation-runtime-guard.R`
- `test-qdesn-pipeline-entrypoints.R`
- `test-pipeline-inference-validation.R` with generated fixtures that do not skip
- `test-qdesn-dynamic-fitforecast-launcher-filters.R`
- `test-qdesn-dynamic-fitforecast-no-leakage.R`
- `test-qdesn-dynamic-fitforecast-horizon-summaries.R`
- storage-light retention test for fit+forecast smoke artifacts

Required test order:

1. Runtime and package load tests.
2. Unit/contract tests for config, source windows, filters, no-leakage, horizon summaries, and storage policy.
3. Non-skipping tiny fixture tests for pipeline entrypoints.
4. Source-refresh dry run.
5. Prepare-only preflight for smoke and staged phases.
6. Approved smoke launch.
7. Healthcheck and closeout.

Testing acceptance:

- no launch approval based on skipped tests;
- skipped tests must be either converted to generated fixtures or explicitly classified as not relevant;
- failures must be classified as data-correctness, wiring/runtime, storage, or scientific/model-quality failures.

## Launch Approval Checklist

Do not request full launch approval until all are true:

- Runtime guard passes.
- Pipeline entrypoints pass non-skipping tests.
- Launcher filters pass tests.
- Source-window tests pass.
- No-leakage tests pass.
- Horizon-summary tests pass.
- Storage-light tests pass.
- Source generation and verification pass.
- Prepare-only preflight passes for all planned phases.
- Smoke healthcheck passes or produces only documented non-data-correctness failures.

## Risk Register

| Risk | Impact | Mitigation | Gate |
|---|---:|---|---|
| Wrong R version resolves in detached launch | high | runtime guard and manifest | Phase 0 |
| Missing pipeline entrypoints | high | restore/adapt and non-skipping tests | Phase 1 |
| MCMC TT500 and TT5000 phases select wrong rows | high | generic `--fit-sizes` filters and selected-grid tests | Phase 2 |
| Forecast rows leak into training | high | index alignment manifests and no-leakage tests | Phase 3 |
| Article tables read stale/heavy objects | medium | compact CSV schema and article dependency documentation | Phase 4 |
| Full objects consume excessive storage | high | retention policy, healthcheck heavy-payload audit | Phase 5 |
| Chat decisions are lost | medium | canonical plan, prep README, manifests, closeout notes | Phase 6 |
| Full launch starts before smoke is meaningful | high | prepare-only and smoke approval checklist | Phases 7-9 |

## Definition Of Ready For Full Launch

The Q-DESN fit+forecast validation is ready for full launch only when:

- all launch-blocking implementation phases are complete;
- all required tests pass without launch-relevant skips;
- source generation and verification are complete;
- prepare-only preflight has been run for smoke, `vb_full`, `mcmc_tt500`, and `mcmc_tt5000`;
- smoke has run and been healthchecked;
- storage-light behavior is proven on smoke artifacts;
- failures are classified and documented;
- the user approves the staged launch sequence.

## Immediate Next Implementation Order

1. Add runtime guard and manifest fields.
2. Restore/adapt pipeline entrypoint scripts with compatibility notes.
3. Add non-skipping entrypoint fixture tests.
4. Add generic `--fit-sizes` runner filter and launcher phase tests.
5. Add no-leakage index manifest and tests.
6. Add H=100/H=1000 horizon-summary outputs and tests.
7. Add/extend storage-light retention healthcheck tests.
8. Update prep README and shared tracker links.
9. Run the full test matrix.
10. Request approval for source generation and smoke.

## Implementation Status 2026-05-15

Implemented:

- runtime guard and reproducibility helpers;
- git/runtime/file-hash metadata in preflight manifests;
- compatibility pipeline entrypoints restored from commit `c232d457463e007d473a3fe9b2469e70c3a1ab2a`;
- generic dynamic-grid filters and explicit `mcmc_tt500` / `mcmc_tt5000` fit-size phase plans;
- compact train/forecast path index-alignment manifests;
- forecast horizon summaries for H=100 and H=1000;
- storage-light pruning gate that requires compact output and index-alignment readiness;
- healthcheck reporting for index alignment, horizon summaries, retained heavy artifacts, disk, and memory;
- focused unit/contract tests for the above.

Verified:

```sh
Rscript -e 'pkgload::load_all(".", quiet=FALSE)'
Rscript -e 'pkgload::load_all(".", quiet=TRUE); files <- c("tests/testthat/test-qdesn-validation-runtime-guard.R", "tests/testthat/test-qdesn-dynamic-fitforecast-launcher-filters.R", "tests/testthat/test-qdesn-pipeline-entrypoints.R", "tests/testthat/test-pipeline-inference-validation.R", "tests/testthat/test-qdesn-dynamic-fitforecast-source-windows.R", "tests/testthat/test-exdqlm-forecast-horizon-inputs.R", "tests/testthat/test-qdesn-dynamic-fitforecast-no-leakage.R", "tests/testthat/test-qdesn-dynamic-fitforecast-horizon-summaries.R", "tests/testthat/test-qdesn-dynamic-fitforecast-storage-light.R", "tests/testthat/test-qdesn-fit-mcmc-precision-beta-api.R", "tests/testthat/test-qdesn-prior-defaults.R"); for (f in files) testthat::test_file(f, reporter="summary")'
Rscript scripts/run_qdesn_dynamic_fitforecast_v2_source_refresh.R
Rscript scripts/run_qdesn_dynamic_fitforecast_v2_source_refresh.R --execute
Rscript scripts/verify_qdesn_dynamic_fitforecast_v2_source_windows.R
Rscript -e 'pkgload::load_all(".", quiet=TRUE); for (f in c("scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R", "scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R", "scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R", "scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R", "scripts/healthcheck_qdesn_dynamic_fitforecast_v2_validation.R", "scripts/run_qdesn_dynamic_fitforecast_v2_source_refresh.R", "scripts/verify_qdesn_dynamic_fitforecast_v2_source_windows.R", "scripts/pipeline_sim_main.R", "scripts/pipeline_real_main.R")) parse(file = f); cat("script_parse_ok\n")'
```

Source and prepare-only evidence generated:

- shared source root: `/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`
- Q-DESN materialized source root: `results/qdesn_mcmc_validation/dynamic_fitforecast_v2_qdesn_sources`
- source-window verification: `config/validation/qdesn_dynamic_fitforecast_v2_source_window_verification.csv`
- full Q-DESN v2 grid: `config/validation/qdesn_dynamic_fitforecast_v2_full_grid.csv`
- source-window verification status: 18 PASS / 0 FAIL
- Q-DESN v2 grid shape: 36 roots = 3 families x 3 taus x 2 fit sizes x 2 priors
- Q-DESN v2 grid SHA-256 in latest preflight manifests: `371e9e843a76d6a0a45b94014c361d37fa6131465f0f71071c98429ce587b4c7`
- model-fit expansion at launch time: 2 likelihoods x selected inference methods per root

Prepare-only preflight run tags:

| Phase | Run tag | Selected roots | Selected cells | Methods | Fit sizes |
|---|---:|---:|---:|---|---|
| smoke | `qdesn-dynamic-exdqlm-crossstudy-smoke-20260515-051821__git-1417a82` | 2 | 2 | `vb,mcmc` | `500,5000` |
| `vb_full` | `qdesn-dynamic-exdqlm-crossstudy-full-20260515-051826__git-1417a82` | 36 | 18 | `vb` | `500,5000` |
| `mcmc_tt500` | `qdesn-dynamic-exdqlm-crossstudy-full-20260515-051831__git-1417a82` | 18 | 9 | `mcmc` | `500` |
| `mcmc_tt5000` | `qdesn-dynamic-exdqlm-crossstudy-full-20260515-051836__git-1417a82` | 18 | 9 | `mcmc` | `5000` |

Still not run:

- no detached smoke launch;
- no full scientific validation launch.

Rationale:

- unit and contract tests now verify the launch-prep contracts quickly and reproducibly;
- source generation and prepare-only preflights verify the data/window/grid/runtime contracts without fitting models;
- actual model fitting remains an explicit smoke/launch decision because even tiny compatibility-entrypoint fits can take nontrivial wall time.

Next gate:

Run the detached smoke only after explicit approval:

```sh
Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase smoke
Rscript scripts/healthcheck_qdesn_dynamic_fitforecast_v2_validation.R
```
