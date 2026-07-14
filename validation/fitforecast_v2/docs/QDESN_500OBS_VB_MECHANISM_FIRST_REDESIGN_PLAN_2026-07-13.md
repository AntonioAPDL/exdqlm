# Q-DESN 500-Observation VB Mechanism-First Redesign Plan

- date: 2026-07-13
- worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- scope: independent Q-DESN versus DQLM/exDQLM fit+forecast validation only
- launch status: no launch requested, no launch performed
- status: planning and diagnosis only

## Executive Decision

Do not run another broad RHS/local-parameter Q-DESN VB screen. The current
calibration history is strong evidence that we are searching the wrong surface.
The next step should change the model mechanism, not just reservoir width,
sparsity, memory, or RHS scale.

The recommended next design is a small, dry-audited,
decomposition-aware Q-DESN probe:

1. keep the frozen shared validation protocol unchanged,
2. activate `dlm_decomp_lags` through existing package support,
3. test `component_lags` and `state_resid_y` input builders,
4. use the known period-90 harmonic structure as DLM seasonal structure,
5. prove the new inputs enter the design matrix and rolling-origin forecasts,
6. only then launch a tiny VB hard-cell probe after explicit approval.

MCMC remains blocked until a current-protocol VB candidate is a per-cell winner
or a compelling near winner under the strict audit.

## Why This Plan Supersedes More RHS Screening

The current search is not merely under-sampled. The best rows from recent
screens show a stable tradeoff:

| Audit finding | Evidence | Consequence |
|---|---|---|
| zero all-primary wins | v4 through v5.1 have `n_cell_likelihood_pass = 0` | no current Q-DESN VB candidate dominates the current DQLM/exDQLM VB baseline across all primary metrics |
| plateau after v4 | median best joint-worst ratio stays near `1.05` | local variants are no longer moving the global frontier much |
| hard cells remain far away | max best joint-worst ratio remains near `1.80` | some cells need a new mechanism |
| parameter tradeoff is structural | `p_over_n_tt500`, `m`, `rho`, `alpha`, `D`, and `n_each` are positively associated with fit RMSE; `m` and `p_over_n_tt500` are negatively associated with fit check loss | bigger or more persistent reservoirs help one target while hurting another |
| solver alone is not the answer | most v5.1 frontier rows converged; only laplace tau 0.05 exAL hit the cap among frontier rows | raise VB iterations only after a better design is identified |
| current new-axis screen is launch-blocked | `newaxis = DRY_PASS_LAUNCH_BLOCKED` | profile-level seasonal metadata is not a model control unless the runner makes it active |

Key evidence files:

- frontier:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_current_baseline_frontier.csv`
- run trend:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_current_baseline_run_trend.csv`
- v5.1 blockers:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_v51_by_likelihood_blockers.csv`
- v5.1 parameter correlations:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_v51_parameter_correlations.csv`
- materialization audit:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/materialization_audit/tables/qdesn_tt500_vb_break_surface_materialization_audit.csv`

## Current Failure Map

Hard cells requiring a new mechanism:

| Family | Tau | Likelihood | Main blocker(s) | Best current joint-worst ratio |
|---|---:|---|---|---:|
| laplace | 0.05 | exAL | fit RMSE, fit check | 1.759805 |
| normal | 0.05 | exAL | fit RMSE, forecast MAE | 1.723917 |
| gausmix | 0.05 | exAL | fit RMSE | 1.616767 |
| normal | 0.05 | AL | fit RMSE, forecast MAE | 1.558946 |
| normal | 0.50 | AL | forecast MAE, forecast check | 1.550843 |
| normal | 0.50 | exAL | forecast MAE, forecast check | 1.439108 |
| laplace | 0.05 | AL | fit RMSE, forecast MAE, forecast check | 1.387678 |
| gausmix | 0.05 | AL | fit RMSE | 1.173839 |

Near cells suitable for a later bridge-only cleanup:

- gausmix tau 0.25 AL/exAL
- gausmix tau 0.50 AL/exAL
- laplace tau 0.25 AL/exAL
- laplace tau 0.50 AL/exAL
- normal tau 0.25 AL/exAL

The hard cells are not homogeneous. The plan should not use one global
candidate family:

- lower-tail cells mainly need fit-RMSE relief without losing check loss;
- normal tau 0.50 mainly needs forecast recovery;
- laplace tau 0.05 exAL may need solver confirmation, but only after a better
  structure is found.

## Runner and Model-Support Audit

The current validation runner can express two different classes of designs.

### What recent RHS screens already used

Recent defaults include:

- `pipeline.readout.input_mode: raw_y_lags`
- `pipeline.decomposition.enabled: no`
- `lags.m_y: 90`
- `lags.m_x: 0`
- `lags.x: 0`
- `deterministic_features.enabled: yes`
- `deterministic_features.period: 90`
- `deterministic_features.harmonics: [1, 2]`
- `deterministic_features.include_trend: yes`

Therefore, merely saying "add period-90 sine/cosine features" is not a strong
new plan. Stage-global period-90 features were already part of many recent
configs as deterministic source columns. The problem is that these screens
still used raw-y-lag reservoir/readout geometry and kept the DLM decomposition
path disabled.

### What is genuinely different and already supported

The package already supports decomposition-aware Q-DESN inputs:

- `pipeline.readout.input_mode: dlm_decomp_lags`
- `pipeline.decomposition.enabled: yes`
- DLM components: `trend`, `seasonal`, `regression`, `transfer`, `residual`
- seasonal period and harmonics
- input builders:
  - `component_lags`
  - `state_resid_y`
- forecast residual recursion:
  - `sampled_path`
  - `deterministic_plugin`
- optional exogenous regression/transfer blocks through `x_cols`

Relevant code paths:

- `R/qdesn_static_exdqlm_crossstudy.R`
  - `qdesn_static_crossstudy_build_pipeline_cfg()`
  - passes staged `x_cols` into the pipeline config
- `R/qdesn_model_selection_v2.R`
  - `ms_prepare_real_bundle()`
  - validates and loads `columns$x`
  - constructs real-data readout designs using `X_use`
- `R/qdesn_vb.R`
  - `qdesn_fit_vb()`
  - supports `input_mode = "dlm_decomp_lags"`
- `R/qdesn_dlm_decomposition.R`
  - implements `component_lags` and `state_resid_y`
- tests:
  - `tests/testthat/test-qdesn-dlm-phase2-integration.R`
  - `tests/testthat/test-qdesn-dlm-state-resid-y-builder.R`

This means the next design can be implemented without modifying the exdqlm
1.0.0 package baseline in a risky way. The work should be configuration,
materialization, and audit-first.

## Revised Scientific Strategy

### Lane A: Mechanism-First Hard-Cell Probe

Primary target: the 8 hard cells.

Mechanism families:

| Mechanism | Purpose | Candidate settings |
|---|---|---|
| DLM component lags | give the reservoir trend/seasonal/residual structure directly | `input_mode = dlm_decomp_lags`, `input_builder = component_lags`, components `trend`, `seasonal`, `residual`, period `90`, harmonics `[1,2]` and optionally `[1,2,3]` |
| state-residual-y inputs | reduce raw-lag burden while preserving filtered state and residual memory | `input_builder = state_resid_y`, small state/residual/y lags, no large raw history |
| deterministic plugin recursion | test whether forecast degradation comes from residual path propagation | compare `sampled_path` versus `deterministic_plugin` on normal tau 0.50 forecast-block cells |
| xreg-aware state-residual inputs | test whether staged period features help only when carried through DLM xreg structure | `state_resid_y.include_xreg = true`, `xreg_source = regression/transfer`, compact `xreg_lags` |
| low-capacity DESN with structured inputs | avoid reintroducing the fit-RMSE penalty from large reservoirs | keep `D = 1`, small `n_each`, low `p_over_n_tt500`, and only refine reservoir parameters after input mode moves the frontier |

This lane is the first priority because it breaks the exhausted tradeoff
surface.

### Lane B: Near-Cell Bridge Cleanup

Primary target: the 10 near cells.

This is still valid, but it is not the first scientific priority. It should be
used only after the hard-cell mechanism probe is designed, or if we explicitly
want quick cleanup of cells already within roughly five percent of the current
baseline.

### Lane C: Solver Confirmation

Primary target: only candidates that are already competitive.

Use higher VB iteration caps or tighter tolerance only for rows that have
already moved the frontier. Do not use solver settings as a broad exploratory
axis.

## Build Plan Before Any Launch

### build-01-evidence-freeze

Recompute and freeze:

- current-baseline frontier,
- run trend,
- v5.1 blockers,
- v5.1 parameter correlations,
- current materialization audit.

Output should be a compact manifest with:

- evidence file paths,
- SHA-256 hashes,
- branch and commit,
- timestamp,
- no-launch statement.

### build-02-decomp-profile-materializer

Create a materializer for hard-cell Q-DESN VB decomposition probes.

Required outputs:

- defaults YAML per mechanism bundle,
- profiles CSV,
- cell assignments CSV,
- grid CSV,
- materialization manifest JSON.

Required hard gates:

- active methods: VB only,
- hard cells only by default,
- explicit `family`, `tau`, and `likelihood_target`,
- exact source registry identity and hash,
- active protocol unchanged: source window, forecast block, `Hmax = 30`,
  `origin_stride = 30`,
- no MCMC,
- no Article, PriceFM, GloFAS, or joint-QVP paths.

### build-03-active-mechanism-audit

This is the most important new gate.

Before launching any fit, prove for each materialized bundle:

- staged `observed.csv` has the intended deterministic columns,
- pipeline config has the intended `columns$x`,
- pipeline readout mode is `dlm_decomp_lags` when requested,
- `decomposition.enabled` is true for mechanism bundles,
- expected components, period, harmonics, input builder, and residual recursion
  are present in `fit_request.json` or dry equivalent,
- a tiny no-fit design audit confirms that the intended decomposition input
  width is nonzero,
- a design-only or micro-design check confirms `fit$X` changes relative to the
  raw-y-lag control,
- forecast design metadata confirms future deterministic features are available
  at rolling-origin target/source indices,
- no forbidden heavy binary payloads are produced in dry paths.

Do not launch if this audit cannot prove the mechanism is active.

### build-04-likelihood-target-enforcement

The materialized `likelihood_target` field must be executable, not merely
metadata. Use one of these low-risk options:

1. separate AL and exAL grids, or
2. launcher preflight that refuses to run profiles under non-target likelihoods.

This prevents doubled compute and ambiguous per-cell interpretation.

### build-05-tiny-hard-cell-probe-after-approval

Only after builds 01 through 04 pass and after explicit approval.

Suggested first cells:

- gausmix tau 0.05 exAL,
- laplace tau 0.05 exAL,
- normal tau 0.50 AL,
- normal tau 0.05 exAL.

Suggested scale:

- 3 to 5 mechanism bundles,
- 4 to 8 low-capacity DESN profiles per cell-likelihood-bundle,
- VB only,
- storage-light only.

Primary success criteria:

- hard-cell joint-worst ratio moves materially downward,
- fit RMSE improves without check-loss collapse,
- normal tau 0.50 forecast MAE/check improves under rolling-origin scoring,
- no new catastrophic cells,
- strict current-baseline audit can identify a winner or near winner.

### build-06-controlled-expansion

Expand only the mechanism that moves the frontier. Do not expand all axes.

Examples:

- if `state_resid_y` helps lower-tail fit RMSE, refine state/residual/y lag
  balance for lower-tail cells only;
- if `deterministic_plugin` helps normal tau 0.50 forecasts, refine that
  recursion only for forecast-block cells;
- if `[1,2,3]` harmonics help but `[1,2]` does not, refine harmonic selection
  rather than reservoir size;
- if no decomposition mechanism helps, stop and reassess Q-DESN model class or
  objective alignment before further compute.

### build-07-MCMC-handoff

MCMC remains blocked until a per-cell VB candidate passes strict audit. Handoff
must include:

- exact profile row,
- exact decomposition bundle,
- exact likelihood target,
- branch and commit,
- source registry hash,
- fit window and rolling-origin metadata,
- VB evidence table,
- storage-light manifest.

## Proposed Candidate Bundle Families

The first implementation should materialize names, not run them.

| Bundle ID | Input mode | Builder | Components | Period/harmonics | Residual recursion | Purpose |
|---|---|---|---|---|---|---|
| `raw_period90_control` | `raw_y_lags` | none | none | staged period90 h1/h2/trend as current control | current control | prove comparability to recent RHS screens |
| `decomp_component_p90_h12` | `dlm_decomp_lags` | `component_lags` | trend, seasonal, residual | 90 / 1,2 | sampled_path | DLM-structured reservoir inputs |
| `decomp_component_p90_h123` | `dlm_decomp_lags` | `component_lags` | trend, seasonal, residual | 90 / 1,2,3 | sampled_path | test whether missing harmonic structure is the bottleneck |
| `decomp_state_resid_y_p90_h12` | `dlm_decomp_lags` | `state_resid_y` | trend, seasonal, residual | 90 / 1,2 | sampled_path | compact latent-state/residual/y memory |
| `decomp_state_resid_y_plugin_p90_h12` | `dlm_decomp_lags` | `state_resid_y` | trend, seasonal, residual | 90 / 1,2 | deterministic_plugin | targeted normal tau 0.50 forecast recovery |
| `decomp_state_resid_y_xreg_p90_h12` | `dlm_decomp_lags` | `state_resid_y` | trend, seasonal, regression/transfer, residual | 90 / 1,2 | sampled_path | test whether deterministic xreg needs to enter through DLM structure |

Initial reservoir profiles should stay conservative:

- `D = 1`,
- small `n_each`,
- small to moderate `alpha`,
- moderate `rho`,
- low `pi_w` and `pi_in`,
- low `p_over_n_tt500`,
- RHS scale from current best near profiles,
- only a few seeds for mechanism confirmation.

This intentionally avoids returning to the old width/memory tradeoff surface.

## What Must Not Happen

- Do not launch the existing `newaxis` bundle as-is.
- Do not run another broad RHS-only local screen.
- Do not treat `seasonal_feature_mode` as active unless an audit proves it.
- Do not update article tables from this planning work.
- Do not promote any candidate to MCMC without current-protocol VB evidence.
- Do not touch Article, PriceFM, GloFAS, or joint-QVP files or jobs.

## Next Safe Implementation Tasks

No launch commands are authorized by this document.

The next safe implementation tasks are:

1. create a decomp-profile materializer,
2. create an active-mechanism audit,
3. add tests proving:
   - raw control remains raw,
   - decomposition bundles activate `dlm_decomp_lags`,
   - `fit$X` or design metadata changes from raw control,
   - forecast metadata carries the same feature/decomposition contract,
   - likelihood-target enforcement works,
   - no forbidden heavy artifacts are produced in dry paths,
4. run dry-only checks,
5. stop for launch approval.

The first possible model run, after those gates, should be a tiny hard-cell VB
probe. It should not be a full screen.

## Implementation Ledger

Updated 2026-07-13 after explicit launch approval in the validation/DQLM chat.

The implementation follows the mechanism-first plan but launches a bounded
targeted VB screen, not a full validation study and not MCMC. The screen is
restricted to the 8 hard family/tau/likelihood cells listed above, 6 mechanism
bundles, and 4 conservative reservoir profiles per hard cell per bundle. The
resulting launch has 192 exact VB target specifications.

### Implemented Scripts

- materializer:
  `scripts/materialize_qdesn_tt500_vb_mechanism_first_redesign.R`
- materialization audit:
  `scripts/audit_qdesn_tt500_vb_mechanism_first_materialization.R`
- staged orchestrator:
  `scripts/orchestrate_qdesn_tt500_vb_mechanism_first_redesign.R`
- test file:
  `tests/testthat/test-qdesn-tt500-vb-mechanism-first-redesign.R`

### Materialized Config Contract

- bundle index:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_mechanism_first_bundle_index.csv`
- bundle index manifest:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_mechanism_first_bundle_index_manifest.json`
- per-bundle config families:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_mechanism_first_<bundle>_{defaults,grid,profiles,cell_assignments,target_spec_ids,materialization_manifest}.*`

Each bundle is VB-only, uses the frozen 500-observation rolling-origin protocol,
uses `rhs_ns`, and writes one exact target likelihood per root through
`allowed_fit_spec_ids` and runner `--spec-ids`.

### Dry Gates Completed

- materialization:
  `Rscript scripts/materialize_qdesn_tt500_vb_mechanism_first_redesign.R --workers 20`
- dry audit:
  `Rscript scripts/audit_qdesn_tt500_vb_mechanism_first_materialization.R`
- prepare-only:
  `Rscript scripts/orchestrate_qdesn_tt500_vb_mechanism_first_redesign.R --prepare-only --skip-materialize --skip-audit --workers 20`
- focused tests:
  `Rscript -e 'testthat::test_file("tests/testthat/test-qdesn-tt500-vb-mechanism-first-redesign.R")'`

Dry audit evidence:

- summary:
  `reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_mechanism_first_20260713/materialization_audit/summary/qdesn_tt500_vb_mechanism_first_materialization_audit.md`
- table:
  `reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_mechanism_first_20260713/materialization_audit/tables/qdesn_tt500_vb_mechanism_first_materialization_audit.csv`

Prepare-only evidence:

- orchestrator manifest:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_mechanism_first/qdesn-vb-mechanism-first-orchestrator-20260713-182826__git-a845b34/manifest/mechanism_first_orchestrator_manifest.json`

Storage-light dry check found no `.rds`, `.rda`, `.RData`, or `__design.rds`
payloads in the mechanism-first config/preflight area.

### Launch Policy

The background launch is allowed only from a clean committed validation branch.
The staged command is:

```bash
tmux new-session -d -s ffv2_qdesn_vb_mechanism_first_20260713 \
  'cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0 && \
   Rscript scripts/orchestrate_qdesn_tt500_vb_mechanism_first_redesign.R \
     --full --launch-approved --skip-materialize --skip-audit \
     --workers 20 \
     --orchestrator-tag qdesn-vb-mechanism-first-orchestrator-20260713-main__git-<commit> \
     > reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_mechanism_first/qdesn-vb-mechanism-first-orchestrator-20260713-main__git-<commit>/mechanism_first_full.stdout.log 2>&1'
```

Article updates, MCMC promotion, and any new full validation launch remain
blocked until this VB screen completes and a strict current-protocol audit shows
per-cell evidence strong enough to promote.

## Short-Path Repair Ledger

Updated 2026-07-14 after the first approved full launch aborted in the
validation/DQLM chat.

The original mechanism-first launch is diagnostic only. It successfully prepared
all six bundles, then started the raw period-90 control bundle, but the full run
aborted when several `root_id` path components became too long for the
filesystem. The observed failure was `File name too long` while writing
per-root manifest files such as `manifest/root_status.txt` and
`manifest/root_error.txt`. The partial outputs from that launch must not be
treated as authoritative current-protocol screening evidence.

The repaired launch keeps the same scientific design and target cells, but
shortens only operational identifiers and campaign roots:

- stage prefix: `qvbm1`;
- bundle codes: `raw`, `c12`, `c123`, `sr`, `srp`, `srx`;
- config index: `config/validation/qvbm1_bundle_index.csv`;
- campaign roots: `results/qvbm1/<bundle_code>` and
  `reports/qvbm1/<bundle_code>`;
- orchestrator root: `reports/qvbm1/orch/<orchestrator_tag>`;
- compact profile IDs: `m1<bundle_code>_c<cell>_p<profile>`;
- compact run tags: `m1<bundle_code><mode>_<timestamp>_<git>`.

The short-path materialization and audit add hard gates for:

- maximum profile ID length;
- maximum root ID component length;
- projected maximum filesystem component length for root status files;
- projected maximum absolute path length;
- canonical `/data/jaguir26/local/src` paths;
- storage-light dry paths with no routine `.rds`, `.rda`, `.RData`, or
  `__design.rds` payloads.

The repaired preflight sequence is:

```bash
Rscript scripts/materialize_qdesn_tt500_vb_mechanism_first_redesign.R \
  --stage-prefix qvbm1 --short-path-mode --workers 20

Rscript scripts/audit_qdesn_tt500_vb_mechanism_first_materialization.R \
  --stage-prefix qvbm1 --short-path-mode

Rscript -e 'testthat::test_file("tests/testthat/test-qdesn-tt500-vb-mechanism-first-redesign.R")'

Rscript scripts/orchestrate_qdesn_tt500_vb_mechanism_first_redesign.R \
  --stage-prefix qvbm1 --short-path-mode \
  --prepare-only --skip-materialize --skip-audit --workers 20
```

The repaired background launch, after the validation branch is clean and
pushed, is:

```bash
tmux new-session -d -s ffv2_qvbm1_20260714 \
  'cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0 && \
   Rscript scripts/orchestrate_qdesn_tt500_vb_mechanism_first_redesign.R \
     --stage-prefix qvbm1 --short-path-mode \
     --full --launch-approved --skip-materialize --skip-audit \
     --workers 20 \
     --orchestrator-tag qvbm1_20260714_main__git-<commit> \
     > reports/qvbm1/orch/qvbm1_20260714_main__git-<commit>/qvbm1_full.stdout.log 2>&1'
```

This remains a VB screening launch only. It does not update article-facing
tables, does not promote MCMC candidates, and does not replace any
authoritative validation table until the completed outputs pass the strict
post-run ranking and storage-light audits.
