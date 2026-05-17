# Rolling-Origin Fit + Forecast Redesign For Q-DESN And exDQLM/DQLM

Date: 2026-05-16

Status: redesign proposal and implementation contract. This document supersedes the fixed-origin
`H=100` / `H=1000` study as the recommended article-facing validation design, but it does not delete
or rewrite historical run evidence.

Authoritative worktree at time of drafting:

`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

Authoritative branch at time of drafting:

`validation/shared-fitforecast-v2-1.0.0`

## 1. Purpose

The shared validation study must compare Q-DESN, exDQLM, and DQLM on the same simulated dynamic
source paths, the same train and forecast source indices, the same fit metrics, and the same forecast
metrics. The design must be reproducible, storage-light, failure-explicit, and usable by the
Article-Q-DESN repository without making the article repository the source of truth for validation
logic.

The previous shared fit + forecast plan used one fixed forecast origin at source index `9000` and
reported forecast metrics over the blocks `9001:9100` and `9001:10000`. That design is valid as a
fixed-origin stress test, but it is not the best primary evaluation for the dynamic models considered
here. It also risks a protocol mismatch because historical Q-DESN pipelines include rolling-origin
lattice forecasting machinery, while the exDQLM/DQLM v2 runner used a fixed-origin forecast path.

This redesign defines the primary benchmark as:

`rolling_origin_no_refit_state_update`

In words:

- Fit model parameters once using observations through the initial cutoff.
- Roll the forecast origin forward one source index at a time through the forecast block.
- Do not refit model parameters at later origins.
- At each origin, condition on observations available through that origin to update lags, states, or
  filtering quantities in the model-specific way.
- Issue forecasts for leads `1:Hmax`.
- Score a forecast only when its target source index lies inside the frozen evaluation block and the
  matching true simulated quantile is available.
- Aggregate forecast scores by lead first, then optionally across leads as a secondary summary.

Code audit note motivating the redesign:

- The current exDQLM/DQLM v2 row runner fits once and calls `exdqlmForecast()` from one origin with
  `k = forecast_horizon_max`; this is a fixed-origin forecast path, not a rolling-origin grid.
- The historical Q-DESN machinery has a `forecast_lattice.qdesn_fit()` engine that accepts many
  origins, constructs origin-specific histories and states, and can retain per-origin/per-lead draws.
- The historical Q-DESN sim pipeline then either used mixture/lattice summaries or selected rolling
  lead-1 outputs depending on `forecast.mode`. Therefore the previous v2 contract could mix different
  forecast semantics unless the protocol is redesigned and encoded explicitly.

The redesigned protocol must make the forecast semantics impossible to confuse in code, manifests,
interfaces, and Article-Q-DESN guards.

## 2. Statistical Rationale

The primary scientific question is:

> After learning model parameters up to source time `T`, how well can each model forecast the target
> quantile at leads `r = 1, ..., Hmax` as new observations arrive and update the dynamic state, but
> without refitting the model parameters?

This is different from the fixed-origin question:

> After learning up to source time `T`, how well can the model issue one autonomous `K`-step path
> without observing anything after `T`?

Both questions are valid. The rolling-origin question is recommended as the primary benchmark because:

- It produces many forecast errors per lead, not one long path from one origin.
- It matches common out-of-sample forecast evaluation practice for time series.
- It separates forecast skill by lead, which is essential for dynamic models.
- It matches how these models are likely to be used operationally: parameters are not refit at every
  time point, but observed data update states and lags as time moves forward.
- It avoids over-interpreting the end of a long autonomous path as if it were a typical operational
  short-to-medium lead forecast.

The fixed-origin autonomous path should be retained only as an optional secondary stress test.

References for the design principle:

- Tashman (2000), out-of-sample forecast evaluation and rolling-origin evaluation:
  https://ideas.repec.org/a/eee/intfor/v16y2000i4p437-450.html
- Hyndman forecast `tsCV`, rolling forecast-origin errors by horizon:
  https://pkg.robjhyndman.com/forecast/reference/tsCV.html
- Gneiting and Raftery (2007), proper scoring rules for probabilistic forecasts:
  https://www.tandfonline.com/doi/abs/10.1198/016214506000001437

## 3. Source Registry And Window Contract

The source registry remains shared and frozen across model families.

Required source design:

| Field | Value |
|---|---:|
| `TT_warmup` | `2000` |
| `TT_main` | `10000` |
| `TT_total` | `12000` |
| initial forecast origin source index | `9000` |
| forecast/evaluation block start | `9001` |
| forecast/evaluation block end | `10000` |
| forecast/evaluation block size `K` | `1000` |
| TT500 training target window | `8501:9000` |
| TT5000 training target window | `4001:9000` |
| DGP seasonal period | `90` |
| DGP harmonics | `1, 2` |

Period audit evidence:

- Frozen source bundle scenario:
  `dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`.
- Each inspected `sim_output.rds` records `info$params$period = 90`.
- Each inspected `sim_output.rds` records `info$params$harmonics = c(1, 2)`.
- Therefore the main seasonal period is `90`, and the second harmonic has period `45`.

The frozen source registry must provide, at minimum:

- source registry id
- source registry path
- source registry hash
- source path per family/tau/source cell
- source file hash per source cell
- true quantile path and hash per source cell, when stored separately
- source design fields listed above
- canonical `/data/jaguir26/local/src` paths only
- no active `/home/jaguir26/local/src` fallback paths

Both Q-DESN and exDQLM/DQLM must consume the same registry rows and must echo source identity and
hashes into all retained manifests and interface tables.

## 4. Primary Forecast Grid

Let:

- `T0 = 9000`, the initial forecast origin and final source index used for parameter fitting.
- `B_start = 9001`, the first target index in the forecast evaluation block.
- `B_end = 10000`, the final target index in the forecast evaluation block.
- `K = B_end - B_start + 1 = 1000`, the number of evaluation targets.
- `Hmax`, the maximum lead to evaluate.
- `o`, a rolling forecast origin.
- `r`, a forecast lead.
- `t = o + r`, the forecast target source index.

The valid rolling-origin scoring grid is:

```text
origins: o = T0, T0 + 1, ..., B_end - 1
leads:   r = 1, 2, ..., Hmax
target:  t = o + r
score if and only if B_start <= t <= B_end
```

Equivalently, for each lead `r`, score origins:

```text
o = T0, T0 + 1, ..., B_end - r
```

The number of scored forecasts at lead `r` is:

```text
N_r = K - r + 1
```

provided `1 <= r <= min(Hmax, K)`.

This triangular grid handles the forecast-block edge case correctly. Near the end of the block, longer
lead forecasts are issued only if their target remains inside the block. For example, at origin `9999`
only lead `1` is scoreable. At origin `9995` and `Hmax = 10`, only leads `1:5` are scoreable.

## 5. Recommended Maximum Lead

The primary rolling-origin design should not default to `Hmax = 1000`.

Because the frozen simulated DGP has period `90` and harmonics `1, 2`, the scientifically natural lead
candidates are:

| Candidate `Hmax` | Interpretation | With `S = Hmax`, approximate scored origins per lead | Recommendation |
|---:|---|---:|---|
| `10` | short-range operating forecast | about `100` | smoke/pilot or cheap sensitivity |
| `30` | medium-range forecast, one third of main period | about `33` | approved primary benchmark |
| `45` | one full second-harmonic cycle, half main period | about `22` | optional extended sensitivity |
| `90` | one full main DGP period | about `11` to `12` | optional full-period stress test |

With `S = Hmax`, increasing `Hmax` reduces the number of scored origins per lead. Therefore a full
period `Hmax = 90` is scientifically appealing but statistically thinner at each lead. The approved
primary benchmark is `Hmax = 30` with `S = 30`. This covers one third of the main DGP period and
roughly two thirds of the second-harmonic period while keeping about 33 scored origins per lead.
`Hmax = 45` and `Hmax = 90` remain optional extensions after the primary machinery is proven.

Recommended launch sequence:

| Stage | `Hmax` | Purpose |
|---|---:|---|
| smoke | `2` or `3` | verify wiring, schema, storage, state updates |
| micro pilot | `5` | verify metrics and runtime over several leads |
| primary validation | `30` | approved main rolling-origin benchmark under `S = Hmax` |
| optional extended validation | `45` | second-harmonic cycle / half main period |
| optional full-period validation | `90` | full main-period rolling-origin evaluation |
| optional fixed-origin stress test | `1000` | separate protocol, not mixed with rolling-origin primary results |

The article-facing primary tables should preserve per-lead metrics. Any lead-averaged score is a
secondary summary and must state the lead set and weights.

## 6. Origin Cadence / Stride Decision

Before relaunch, the study must predeclare the rolling-origin cadence.

Let `S` be the origin stride. The origin grid is:

```text
origins: o = T0, T0 + S, T0 + 2S, ...
keep origins with o <= B_end - 1
```

For a lead `r`, the valid scored origins are:

```text
o in {T0, T0 + S, T0 + 2S, ...} such that o + r <= B_end
```

and the number of scored origins is:

```text
N_r(S) = floor((B_end - r - T0) / S) + 1
```

when `B_end - r >= T0`; otherwise `N_r(S) = 0`.

Candidate cadences:

| Cadence | Example | Strengths | Weaknesses | Recommended use |
|---|---:|---|---|---|
| one-by-one | `S = 1` | maximal information, strongest per-lead precision, standard rolling-origin benchmark | overlapping forecast errors require dependence-aware uncertainty summaries | optional later sensitivity |
| every max lead | `S = Hmax` | cheaper, roughly non-overlapping target blocks across origins/leads | fewer origins per lead, weaker per-lead precision than `S = 1` | approved primary cadence |
| fixed calendar stride | `S = 5`, `10`, etc. | tunable compute/sample-size tradeoff | less canonical unless justified before launch | pilot or extended-lead stage |
| adaptive stride | smaller `S` for short leads, larger `S` for long leads | can control compute | harder to explain and compare | avoid for primary article-facing results |

Approved primary cadence decision:

- Use `S = Hmax` for the primary rolling-origin benchmark.
- Use the same `S` for Q-DESN, exDQLM, and DQLM.
- Record `origin_stride` in every config, manifest, status row, and interface row.
- If reporting uncertainty intervals or paired model comparisons, use dependence-aware summaries
  such as block bootstrap, moving-block bootstrap, or lead-wise paired differences with transparent
  caveats. Do not pretend the overlapping rolling-origin errors are independent.

Implications of `S = Hmax`:

- Forecast origins are spaced by non-overlapping issue blocks of size `Hmax`.
- The total scored forecast targets stays roughly the size of the forecast block, but the number of
  origins per lead decreases as `Hmax` increases.
- For `K = 1000` and approved `Hmax = 30`, most leads have about 33 scored origins.
- For `K = 1000` and optional `Hmax = 45`, most leads have about 22 scored origins.
- For `K = 1000` and `Hmax = 90`, most leads have about 11 to 12 scored origins.
- This cadence is cleaner computationally and reduces overlap, but per-lead summaries will be noisier
  than a one-by-one origin grid.

If more precise per-lead estimates are needed later, run `S = 1` as a sensitivity analysis rather than
mixing it with the primary `S = Hmax` article-facing table.

## 7. Model-Specific Forecast Semantics

### 7.1 Common Requirements

For every model family and source cell:

- Fit model parameters using only the predeclared training target window ending at `T0 = 9000`.
- Do not refit parameters during rolling-origin evaluation.
- For each origin `o`, condition only on observations and covariates available through `o`, plus
  predeclared future covariates if the model is allowed to use known future covariates.
- Do not use the true future quantile in fitting, filtering, state updates, or feature construction.
- Use the true simulated quantile only for scoring.
- Record the forecast protocol in every manifest and interface row:
  `forecast_protocol = rolling_origin_no_refit_state_update`.

### 7.2 Q-DESN

Q-DESN already has historical machinery for rolling-origin/lattice forecasting. The redesigned
implementation should reuse that idea but remove synthesis from the primary benchmark.

Important terminology:

- The primary validation targets a single quantile per source row.
- Quantile synthesis across multiple fitted quantile models is disabled.
- Telemetry/status fixtures used to test healthchecks are unrelated to quantile synthesis and do not
  produce validation metrics.

Required Q-DESN semantics:

- Fit readout/inference parameters once on the training target window.
- Use the trained reservoir/readout object for all origins.
- At origin `o`, update reservoir states and response-lag histories using observed `y` through `o`.
- Produce lead-specific forecasts for `r = 1:Hmax`.
- For a forecast path beyond lead `1`, recursively propagate model-implied future values within that
  issued forecast path unless the implementation explicitly defines a teacher-forced diagnostic.
- Retain single-quantile outputs only. Do not synthesize across multiple quantile models for the
  primary validation.
- Retain per-origin/per-lead scalar summaries or compact quantile-path summaries only, not heavy draw
  payloads.

Historical Q-DESN concepts to keep, with stricter naming:

| Historical concept | New interpretation |
|---|---|
| `forecast_lattice` | rolling-origin forecast engine |
| `origin` | forecast issue source index |
| `lead` | horizon from origin to target |
| `target_idx` | source index scored against true quantile |
| `lead_eval` | required primary per-lead scoring |
| synthesis | disabled for primary single-quantile validation |

### 7.3 exDQLM/DQLM

The exDQLM/DQLM implementation must be upgraded from one fixed-origin `k`-step forecast path to the
same rolling-origin grid used by Q-DESN.

Required exDQLM/DQLM semantics:

- Fit posterior/inference parameters once on the training target window.
- Do not rerun the full inference algorithm at each origin.
- For each origin `o`, create or recover the filtered state/lag context conditional on observations
  through `o`.
- Forecast leads `1:Hmax` from that origin.
- Score only valid targets `o + r <= 10000`.
- Record whether filtering/state propagation between `T0` and `o` used:
  - exact filtering with fixed posterior parameters,
  - posterior-draw-specific filtering,
  - deterministic plug-in filtering,
  - or an explicitly documented approximation.

This state-update detail is a first-class reproducibility field because it affects comparability.

## 8. Fit-Period Evaluation

The fit-period evaluation remains required and is separate from forecast evaluation.

For each model/source/tau/fit size:

| Fit Size | Source Target Window |
|---|---|
| TT500 | `8501:9000` |
| TT5000 | `4001:9000` |

Fit-period metrics should evaluate the model's ability to recover the simulated true quantile over the
training target window and its empirical quantile calibration against observed responses.

Required fit metrics:

- true-quantile MAE
- true-quantile RMSE
- true-quantile bias
- pinball loss at `tau`
- empirical quantile coverage, `mean(y <= qhat)`
- coverage error, `mean(y <= qhat) - tau`
- optional posterior interval width or draw dispersion if available
- runtime
- convergence/status/diagnostic fields

## 9. Forecast Metrics

The primary retained forecast table is lead-level, not block-level.

For each model/source/tau/fit size/inference method/lead:

Required forecast metrics:

- `origin_stride`
- `forecast_lead`
- `n_origins_scored`
- `origin_start_source_index`
- `origin_end_source_index`
- `target_start_source_index`
- `target_end_source_index`
- true-quantile MAE
- true-quantile RMSE
- true-quantile bias
- pinball loss at `tau`
- empirical quantile coverage, `mean(y <= qhat)`
- coverage error, `mean(y <= qhat) - tau`
- optional CRPS or draw-based score if a comparable predictive distribution is retained or streamed
- optional posterior interval width or draw dispersion
- runtime split, if available
- status and failure fields

Point summaries should be computed from the model's posterior predictive quantile estimate or posterior
median of the predicted quantile, using a definition shared across Q-DESN and exDQLM/DQLM.

## 10. Article-Facing Interface Schema

The redesigned article-facing interface should be explicit enough to prevent accidental mixing of
fixed-origin and rolling-origin results.

Required identity/provenance fields:

```text
interface_schema_version
forecast_protocol
source_registry_id
source_registry_path
source_registry_hash
source_cell_id
source_path
source_hash
true_quantile_path
true_quantile_hash
model_family
model_variant
inference_method
dynamic_family
tau
fit_size_label
effective_fit_size
package_version
validation_branch
validation_commit
run_tag
run_started_at
run_finished_at
```

Required window fields:

```text
TT_warmup
TT_main
TT_total
initial_forecast_origin_source_index
forecast_block_start_source_index
forecast_block_end_source_index
forecast_block_size
train_start_source_index
train_end_source_index
rolling_origin_start_source_index
rolling_origin_end_source_index
forecast_lead
target_start_source_index
target_end_source_index
n_origins_scored
max_lead_configured
origin_stride
```

Required fit metric fields:

```text
fit_qtrue_mae
fit_qtrue_rmse
fit_qtrue_bias
fit_pinball_mean
fit_coverage
fit_coverage_error
fit_interval_width_mean
fit_runtime_seconds
```

Required forecast metric fields:

```text
forecast_qtrue_mae
forecast_qtrue_rmse
forecast_qtrue_bias
forecast_pinball_mean
forecast_coverage
forecast_coverage_error
forecast_interval_width_mean
forecast_runtime_seconds
```

Required diagnostic/status fields:

```text
status
failure_stage
failure_reason
warning_count
diagnostic_flags
state_update_method
refit_per_origin
uses_future_observed_y_for_state
uses_true_quantile_for_training
storage_policy
artifact_manifest_path
artifact_manifest_hash
compact_path_summary_path
compact_path_summary_hash
log_path
progress_path
heartbeat_path
last_heartbeat_at
last_progress_stage
last_progress_iter
last_progress_total_iter
config_path
config_hash
```

Hard requirements:

- `forecast_protocol` must equal `rolling_origin_no_refit_state_update` for the primary article-facing
  rolling-origin tables.
- `refit_per_origin` must be `false`.
- `uses_true_quantile_for_training` must be `false`.
- `uses_future_observed_y_for_state` must be `true` only in the precise rolling-origin sense that
  observations through the current origin are available; it must never mean using observations after
  the forecast origin for a scored forecast.
- Fixed-origin stress-test outputs must use a different `forecast_protocol` value and different run tag.

## 11. Storage-Light Contract

The redesigned study keeps the storage-light policy.

Retain:

- scalar fit metrics
- scalar forecast metrics by lead
- compact path summaries for small predeclared subsets
- manifests
- configs
- logs
- status files
- source registry hashes
- artifact hashes

Do not routinely retain successful heavy payloads:

- `.rds`
- `.rda`
- `.RData`
- posterior draw arrays
- full per-origin draw lattices
- full fitted model objects

Allowed exceptions:

- tiny predeclared diagnostic subsets
- capped failure-debug payloads
- smoke-only artifacts needed to prove correctness

Every exception must be capped, named, and listed in the artifact manifest.

## 12. Failure Policy

The study must be failure-explicit.

Every source/model/tau/fit-size/inference-method unit must end in exactly one terminal status:

- `success`
- `failed_prepare`
- `failed_fit`
- `failed_state_update`
- `failed_forecast`
- `failed_metrics`
- `failed_artifact_contract`
- `skipped_by_stage_filter`
- `aborted_protocol_superseded`

Failure rows must retain enough metadata for article-side guards to exclude them deterministically.

The existing fixed-origin `H=100/H=1000` run tags should be marked:

`aborted_protocol_superseded`

They must not be consumed as final article-facing fit+forecast evidence.

## 13. Progress Logging And Health Telemetry

The rolling-origin relaunch must not contain silent long-running jobs. Progress logging is a launch
gate for both VB and MCMC.

Current audit findings:

- The current exDQLM/DQLM v2 row runner sets `verbose = FALSE` for LDVB and MCMC calls even though
  the package has progress hooks. This is not acceptable for the relaunch.
- `exdqlmMCMC()` already supports `verbose.every`, `trace.every`, and `progress_callback`.
- `exdqlmMCMC()` also honors the `EXDQLM_MCMC_PROGRESS_EVERY` environment variable.
- `exdqlmLDVB()` and the LDVB engine print progress when `verbose = TRUE`; the redesign should add or
  wrap a machine-readable VB progress callback so healthchecks do not depend only on buffered console
  text.
- Historical Q-DESN validation code writes `progress_trace.csv`, `latent_v_trace.csv`,
  `sigmagam_trace.csv`, `theta_trace.csv`, `chain_summary.csv`, and campaign progress tables after
  successful collection. The rolling-origin relaunch must also write live heartbeat/progress files
  while a row is running.

Required user-facing flags for every launcher:

```text
--verbose
--progress-every <int>
--trace-every <int>
--heartbeat-seconds <int>
--healthcheck-stale-seconds <int>
--log-level <debug|info|warn>
```

Quiet mode, if implemented, may reduce console chatter but must never disable machine-readable
progress files, heartbeat files, status files, or failure logs.

Required config fields:

```text
runtime.verbose
runtime.log_level
runtime.progress_every
runtime.trace_every
runtime.heartbeat_seconds
runtime.healthcheck_stale_seconds
runtime.progress_retention_mode
runtime.progress_retention_max_rows_per_unit
```

Recommended defaults:

| Field | Smoke | Pilot | Full VB | Full MCMC |
|---|---:|---:|---:|---:|
| `progress_every` | `1` | `5` | `50` | `50` |
| `trace_every` | `1` | `5` | `50` | `50` |
| `heartbeat_seconds` | `30` | `60` | `1800` | `1800` |
| `healthcheck_stale_seconds` | `180` | `300` | `1800` | `1800` |

Approved full-run defaults:

```text
runtime.progress_every = 50
runtime.trace_every = 50
runtime.heartbeat_seconds = 1800
runtime.healthcheck_stale_seconds = 1800
```

Interpretation:

- For MCMC, progress is recorded every 50 total iterations, including burn-in and kept draws.
- For VB, progress is recorded every 50 VB iterations when the underlying method exposes iteration
  progress. If the underlying VB engine emits progress more frequently, the validation harness may
  downsample to every 50 iterations for retained progress files.
- A heartbeat older than 30 minutes is stale for full runs.
- Smoke and pilot stages keep denser progress because they are used to test telemetry correctness.

Every running row must maintain these files:

```text
row_status.csv
row_progress.csv
row_heartbeat.json
stdout.log
stderr.log or combined.log
```

`row_progress.csv` must be append-only and machine-readable. Required columns:

```text
timestamp
run_tag
row_id
row_key
model_family
model_variant
inference_method
fit_size_label
tau
stage
substage
event
phase
current_iter
total_iter
burn_iter
burn_total
keep_iter
keep_total
vb_iter
vb_max_iter
mcmc_iter
mcmc_total_iter
forecast_origin_current
forecast_origin_total
forecast_lead_current
forecast_lead_total
percent_complete
elapsed_seconds
eta_seconds
pid
host
message
```

Fields that do not apply to a method/stage should be written as `NA`, not omitted. This keeps the
healthcheck schema stable.

`row_heartbeat.json` must be overwritten atomically at every progress event and at least every
`heartbeat_seconds` while a long stage is running. Required fields:

```text
timestamp
run_tag
row_id
row_key
status
stage
substage
inference_method
current_iter
total_iter
percent_complete
elapsed_seconds
eta_seconds
pid
host
last_progress_message
```

Healthchecks must report, at minimum:

- row status counts
- active rows
- active stage/substage per running row
- VB iteration `current/total` where applicable
- MCMC iteration `current/total`, burn/keep phase, and kept draws `current/total`
- rolling forecast progress by origin and lead where applicable
- last heartbeat timestamp and heartbeat age
- stalled rows where heartbeat age exceeds `healthcheck_stale_seconds`
- estimated completion time when enough progress data exist
- terminal failures and failure stage/reason
- storage audit status

Required implementation behavior:

- exDQLM/DQLM MCMC runners must pass `verbose = TRUE`, `trace.diagnostics = TRUE`,
  `trace.every = runtime.trace_every`, `verbose.every = runtime.progress_every`, and a
  `progress_callback` that writes `row_progress.csv` and `row_heartbeat.json`.
- exDQLM/DQLM VB runners must pass `verbose = TRUE`. The validation study should not require changes
  to the exdqlm 1.0.0 package source solely for progress telemetry. Instead, implement a
  validation-harness telemetry adapter that captures/parses existing verbose LDVB progress output and
  streams a normalized view to `row_progress.csv` and `row_heartbeat.json`. If a package-level VB
  callback is later added on a separate development branch, the harness may use it, but this is not a
  prerequisite for the rolling-origin validation redesign.
- Q-DESN VB and MCMC runners must run the pipeline with verbose output enabled and must stream
  method-level progress into the same `row_progress.csv` schema.
- Where a model fit call blocks the R row runner and cannot itself update heartbeat files, the
  launcher must start a lightweight telemetry sidecar that tails the row log, parses progress lines,
  and updates `row_progress.csv` and `row_heartbeat.json` without modifying package internals.
- The row runner must write status transitions before and after each major stage:
  `prepare`, `fit`, `state_update`, `rolling_forecast`, `metrics`, `artifacts`, `done`.
- A row interrupted by a stopped tmux/session must be classifiable by a later reconciliation command
  as `failed_interrupted` or `aborted_protocol_superseded`, with the last heartbeat preserved.
- Progress logs are part of the storage-light contract. They should be compact CSV/JSONL text and may
  be downsampled or capped, but they must not be replaced by heavy binary objects.

Progress retention policy:

- Store dense progress in smoke and pilot stages.
- Store compact progress in full stages using `progress_every`/`trace_every`.
- If progress traces become large, retain all start/done/failure events, all last `N` events per row,
  and a regular downsample of earlier events.
- Never prune the final heartbeat, terminal status row, failure row, or chain/signoff summaries.
- Never prune rows needed to reconstruct the last known stage, last known iteration, terminal status,
  or failure/interruption reason.

Progress telemetry is a hard launch gate. Full validation may not launch until fixture-based
telemetry tests prove that healthchecks can detect:

- a normally progressing VB row
- a normally progressing MCMC row
- a stalled row with an old heartbeat
- an interrupted row
- a completed row
- a failed row

These are telemetry/status fixtures only. They are not simulated validation datasets, not quantile
synthesis, and not synthetic model outputs.

## 14. Required Tests Before Relaunch

The redesign is not launch-ready until the following tests pass under R 4.6.0 or newer.

Source and registry tests:

- registry schema test
- registry hash test
- canonical path test forbidding active `/home/jaguir26/local/src` paths
- source window test for TT500 and TT5000
- forecast block test for `9001:10000`
- rolling grid test for valid `(origin, lead, target)` triples
- triangular edge-case test near target index `10000`
- origin-stride test for `S = 1`, `S = Hmax`, and at least one intermediate fixed stride

Model-independent metric tests:

- pinball loss test
- true-quantile MAE/RMSE/bias test
- coverage and coverage-error test
- lead-level aggregation test
- missing-target exclusion test
- overlap/dependence metadata test ensuring `origin_stride` and lead sample sizes are exported
- status row test for failed units

Q-DESN tests:

- no-refit rolling-origin test
- observed-lag/state update through origin test
- no future observation leakage beyond origin test
- no true quantile use in fitting test
- synthesis-disabled primary path test
- compact artifact retention test

exDQLM/DQLM tests:

- no-refit rolling-origin test
- state/filter update through origin test
- no future observation leakage beyond origin test
- fixed-origin runner is not used for primary rolling-origin protocol
- discount-factor/dimension validation test
- compact artifact retention test

Interface and artifact tests:

- shared interface schema test
- article-required guard fields test
- fixed-origin/rolling-origin mixing refusal test
- storage policy test forbidding routine successful binary payloads
- progress schema test for `row_progress.csv`
- heartbeat schema test for `row_heartbeat.json`
- healthcheck fixture-progress test for active VB and MCMC rows
- stale-heartbeat detection test
- interrupted-row reconciliation test
- no-silent-fit test requiring VB/MCMC progress flags to be enabled in launch configs
- dry-run manifest test for Q-DESN
- dry-run manifest test for exDQLM/DQLM
- smoke manifest test for both model families

## 15. Relaunch Stages

The launchers should be redesigned around these stages:

| Stage | Purpose | Compute |
|---|---|---:|
| `verify-source` | registry and hash verification only | none |
| `prepare-only` | build manifests and planned rows only | none/minimal |
| `unit-smoke` | one tiny source/model/tau/fit-size with `Hmax <= 3` | tiny |
| `micro-pilot` | a small balanced set with `Hmax = 5` | small |
| `vb-primary` | VB/inexpensive models, primary `Hmax`, primary `S` | moderate |
| `mcmc-tt500-primary` | TT500 MCMC, primary `Hmax` | large |
| `mcmc-tt5000-primary` | TT5000 MCMC, primary `Hmax` | gated |
| `extended-leads` | optional `Hmax > primary` | gated |
| `fixed-origin-stress` | optional autonomous path stress test | gated |

No full stage should launch unless:

- source verification passes
- dry-run manifests pass
- storage policy checks pass
- interface schema checks pass
- both Q-DESN and exDQLM/DQLM smoke produce successful rows
- obsolete fixed-origin run tags are listed as superseded
- origin cadence has been explicitly approved

## 16. Migration Plan From Current v2

1. Freeze the current fixed-origin v2 run state.
   - Preserve logs, run tags, manifests, health reports, and failure evidence.
   - Do not delete outputs.
   - Mark the run tags as `aborted_protocol_superseded`.
   - Do not edit old status files in place unless a separate migration script records the before/after
     hashes. Prefer an external supersession ledger.

2. Add a new protocol namespace.
   - Suggested protocol id: `rolling-origin-v3-1.0.0`.
   - Suggested branch: keep current branch or create
     `validation/rolling-origin-fitforecast-v3-1.0.0`.
   - Suggested run tag prefix:
     `qdesn-exdqlm-rolling-origin-v3`.

3. Replace the primary interface schema.
   - Move from block-level `forecast_H100` / `forecast_H1000` rows to lead-level rows.
   - Retain fit-window metrics in the same row or in a linked fit-summary table.
   - Require `forecast_protocol` in every row.

4. Implement shared rolling-grid utilities.
   - One implementation should generate the valid `(origin, lead, target)` grid for both model
     families.
   - Unit tests must cover the end-of-block triangular edge cases.
   - Unit tests must cover `origin_stride = 1`, `origin_stride = Hmax`, and a fixed intermediate
     stride.

5. Update Q-DESN runner.
   - Reuse rolling-origin forecast machinery.
   - Disable synthesis for primary validation.
   - Export lead-level metrics.
   - Confirm no refit and no future leakage beyond origin.

6. Update exDQLM/DQLM runner.
   - Replace fixed-origin forecast-only runner with rolling-origin state-update runner.
   - Document the state-update method.
   - Export the same lead-level metrics.

7. Rebuild tests and dry runs.
   - Run all source, grid, schema, artifact, storage, and dry-run tests.

8. Relaunch only after successful paired smoke.
   - Q-DESN and exDQLM/DQLM must both produce successful storage-light lead-level interface rows.

## 17. Article-Q-DESN Consumption Rules

Article-Q-DESN should refuse final validation consumption if any of the following are true:

- active path contains `/home/jaguir26/local/src`
- validation branch is an old `0.5.0` branch
- package version is below `1.0.0`
- `forecast_protocol` is missing
- `forecast_protocol` is not `rolling_origin_no_refit_state_update`
- source registry hash is missing
- source path hash is missing
- initial forecast origin/window metadata are missing
- rolling-origin/lead/target metadata are missing
- `origin_stride` is missing
- `n_origins_scored` is missing
- fixed-origin `H=100` / `H=1000` outputs are mixed into the primary table
- old fit-only outputs are mixed with new rolling-origin fit+forecast outputs
- synthesis-derived rows are presented as primary single-quantile validation rows
- status is not `success`
- artifact manifest/hash fields are missing

Article-Q-DESN may use the fixed-origin stress test only if it is explicitly labeled as a secondary
analysis and never pooled with the primary rolling-origin results.

## 18. Open Decisions Before Implementation

The following choices should be made before relaunch:

1. Primary `Hmax`.
   - Evidence: frozen source DGP period is `90` with harmonics `1, 2`.
   - Approved: use `Hmax = 30` with `S = Hmax`.
   - Optional extensions: `Hmax = 45` for the second-harmonic cycle / half-period sensitivity and
     `Hmax = 90` for the full-period stress test.

2. Primary origin stride `S`.
   - Approved: `S = Hmax`.
   - Keep `S = 1` only as a possible later sensitivity analysis.

3. Whether to retain a separate fixed-origin stress test.
   - Recommendation: yes, but only after the primary rolling-origin benchmark passes.

4. Whether fit metrics and forecast metrics live in one interface table or linked tables.
   - Recommendation: one article-facing lead-level table with repeated fit metrics, plus optional
     normalized internal tables.

5. Exact exDQLM/DQLM state-update method.
   - This must be documented before article consumption.

6. Whether lead-averaged summaries use equal lead weights or origin-count weights.
   - Recommendation: primary article tables report per-lead metrics; lead-averaged summaries are
     secondary and should default to equal weights over the declared lead set.

7. Whether uncertainty summaries are required in the first article-facing table.
   - Recommendation: start with deterministic lead-level scalar metrics and paired model differences;
     add block-bootstrap intervals only after the primary run is stable.

## 19. Readiness Checklist

Before stopping old runs:

- confirm current live process list
- record current run tags
- record current statuses
- record stop commands or natural completion decision
- mark old fixed-origin runs as superseded, not failed scientific evidence
- verify Article-Q-DESN application sessions remain alive if they are unrelated to validation

Before new smoke:

- implement rolling grid utility
- update schema
- update Q-DESN runner
- update exDQLM/DQLM runner
- update launchers
- update health checks
- update storage audit
- run all required tests
- generate dry-run manifests

Before full launch:

- paired Q-DESN and exDQLM/DQLM smoke passed
- micro-pilot passed
- storage audit passed
- interface rows contain nonzero successful rows
- progress/heartbeat healthcheck passed for VB and MCMC smoke rows
- article guard checks pass on produced interface rows
- run tags and source hashes are documented in the shared tracker
- origin cadence decision is recorded in the shared tracker

## 20. Implementation Build Stages

The redesign should be implemented as a staged build so each piece can be tested before compute
launch.

| Build stage | Scope | Required output |
|---|---|---|
| `build-01-protocol-freeze` | mark fixed-origin v2 run tags superseded; freeze source/period/cadence/Hmax decisions | protocol ledger and updated tracker |
| `build-02-rolling-grid` | shared `(origin, lead, target)` grid utility with `S = Hmax` support | tested grid table generator |
| `build-03-telemetry` | common progress/heartbeat writer, log parser, sidecar adapter, healthcheck parser | `row_progress.csv`, `row_heartbeat.json`, healthcheck summaries |
| `build-04-exdqlm-rolling-state` | exDQLM/DQLM no-refit rolling-origin state-update/forecast method | lead-level forecast rows |
| `build-05-qdesn-lead-export` | Q-DESN lead-level rolling-origin export with quantile synthesis disabled | lead-level forecast rows |
| `build-06-schema-interface` | article-facing schema and artifact manifests for lead-level rows | schema CSV and interface exporter |
| `build-07-tests` | source/grid/window/storage/schema/telemetry/healthcheck tests | passing testthat/check logs |
| `build-08-dryrun` | Q-DESN and exDQLM/DQLM dry-run manifests | zero-compute manifests |
| `build-09-smoke` | paired smoke with tiny `Hmax`, dense progress, storage audit | successful nonzero interface rows |
| `build-10-pilot` | micro-pilot with `S = Hmax` and candidate `Hmax` | runtime and health evidence |
| `build-11-primary-launch-plan` | final launch plan, core allocation, gates, stop/resume commands | human-approved launch checklist |

No build stage should overwrite old fixed-origin outputs. Supersession should be recorded in a ledger
or new status table, not by destructively editing historical artifacts in place.

## 21. Stop Record For Superseded Fixed-Origin v2

Machine timestamp used for this stop record:

`2026-05-16 20:49:45 EDT`

The active validation tmux session stopped during redesign was:

`qdesn_ff_v2_0516010027`

The corresponding validation run tag was:

`qdesn-dynamic-fitforecast-v2-vb-full-20260515-215949__git-198cff1`

The session was stopped with:

```sh
tmux kill-session -t qdesn_ff_v2_0516010027
```

Post-stop verification:

- `tmux ls` showed only the Article-Q-DESN application session
  `article_qdesn_main_latent_path_main_al_vb_n1000_m360_20260515_221729`.
- No live R worker processes remained for
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`,
  `run_qdesn_dynamic_exdqlm_crossstudy_validation.R`, `pipeline_real_main.R`, or
  `validation/fitforecast_v2/scripts`.
- The Article-Q-DESN application process
  `application/scripts/03_fit_models.R --run_id latent_path_main_al_vb_n1000_m360_20260515_221729`
  remained live and was not stopped.

Healthcheck after stopping still reported stale Q-DESN root statuses as `RUNNING` because the old
fixed-origin launcher was terminated before writing terminal row statuses. These statuses are not
article-facing scientific results; they belong to the superseded fixed-origin v2 protocol and should
be excluded by run tag and protocol.

exDQLM/DQLM v2 healthcheck at the stop audit reported:

- `failed_interrupted = 1`
- `failed_runtime = 3`
- `pending = 68`
- storage audit `PASS`
- shared interface rows `0`

These old v2 fixed-origin outputs remain historical evidence only.

## 22. Bottom-Line Decision

The revised primary study should be a rolling-origin, no-refit, state-updating, lead-specific
fit + forecast validation benchmark. This makes the comparison across Q-DESN, exDQLM, and DQLM more
statistically meaningful, more reproducible, and less ambiguous than the fixed-origin `H=100` /
`H=1000` design.

The current fixed-origin validation should be preserved as historical evidence and marked as
superseded before any article-facing final validation outputs are produced.

## 23. Build-01 And Build-02 Implementation Evidence

Implementation timestamp:

`2026-05-16 21:39:42 EDT`

Implemented stages:

| Build stage | Status | Evidence |
|---|---|---|
| `build-01-protocol-freeze` | implemented and tested | `validation/fitforecast_v2/protocol/rolling_origin_v3_protocol_freeze.csv`; `validation/fitforecast_v2/R/protocol_freeze.R`; `validation/fitforecast_v2/tests/testthat/test-protocol-freeze.R` |
| `build-02-rolling-grid` | implemented and tested | `validation/fitforecast_v2/R/rolling_grid.R`; `validation/fitforecast_v2/tests/testthat/test-rolling-grid.R` |

The active protocol ledger row records:

```text
protocol_id = rolling-origin-v3-1.0.0
protocol_role = active_protocol
run_tag = rolling-origin-v3-primary-H30-S30
new_forecast_protocol = rolling_origin_no_refit_state_update
primary_hmax = 30
primary_origin_stride = 30
initial_forecast_origin_source_index = 9000
forecast_block_start_source_index = 9001
forecast_block_end_source_index = 10000
dgp_period = 90
dgp_harmonics = 1;2
article_consumption = allowed_after_successful_dryrun_smoke_pilot
```

The same ledger records the superseded fixed-origin v2 run tags with
`article_consumption = refuse`, including the stopped Q-DESN run tag
`qdesn-dynamic-fitforecast-v2-vb-full-20260515-215949__git-198cff1`.

The primary rolling grid for `Hmax = 30` and `S = 30` has these invariants:

```text
n_rows = 1000
target_source_index range = 9001:10000
unique target_source_index count = 1000
forecast_origin_source_index range = 9000:9990
forecast_lead range = 1:30
n_origins_scored for leads 1:10 = 34
n_origins_scored for leads 11:30 = 33
```

This means the primary `S = Hmax` grid partitions the 1000-point forecast block exactly once while
preserving lead-level sample sizes and correctly dropping unscoreable end-of-block targets.

Focused test evidence:

```sh
Rscript -e 'testthat::test_file("validation/fitforecast_v2/tests/testthat/test-protocol-freeze.R", reporter = "summary")'
Rscript -e 'testthat::test_file("validation/fitforecast_v2/tests/testthat/test-rolling-grid.R", reporter = "summary")'
```

Both focused suites completed with:

```text
DONE
```

Full shared harness test evidence:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e 'source("validation/fitforecast_v2/R/utils.R"); ffv2_source_all("validation/fitforecast_v2"); testthat::test_dir("validation/fitforecast_v2/tests/testthat", reporter="summary")'
```

Observed result:

```text
artifact-schema: ...
forecast-horizon-api: ...
protocol-freeze: ............
rolling-grid: ...........................
row-runner-discounts: ..
shared-interface-schema: .......
source-registry-schema: .....
source-window-contract: ...........
stage-filtering: ...........
storage-policy: ...

DONE
Ran 4/4 deferred expressions
```

Next implementation stage:

`build-03-telemetry`.

## 24. Build-03 Telemetry Implementation Evidence

Implementation timestamp:

`2026-05-16 21:54:51 EDT`

Implemented stage:

| Build stage | Status | Evidence |
|---|---|---|
| `build-03-telemetry` | implemented and tested | `validation/fitforecast_v2/R/telemetry.R`; `validation/fitforecast_v2/tests/testthat/test-telemetry.R` |

Build-03 added the shared validation-harness telemetry layer without modifying the exdqlm 1.0.0
package algorithms. The implementation provides:

- stable `row_progress.csv` schema via `ffv2_required_progress_columns()`
- stable `row_heartbeat.json` schema via `ffv2_required_heartbeat_fields()`
- append-only progress writer and atomic heartbeat writer
- exDQLM/DQLM MCMC `progress_callback` adapter
- verbose LDVB/DQLM log parser for `LDVB start`, `LDVB progress`, and `LDVB done` lines
- optional validation-harness sidecar that tails row logs and writes normalized VB progress/heartbeat
  rows without changing package internals
- healthcheck telemetry summary with `progressing`, `stalled`, `interrupted`, `completed`, and
  `failed` row states
- launcher/runtime flags:
  `--verbose`, `--quiet`, `--progress-every`, `--trace-every`, `--heartbeat-seconds`,
  `--healthcheck-stale-seconds`, `--log-level`, and `--telemetry-sidecar-poll-seconds`

The exDQLM/DQLM manifest now records:

```text
row_progress_path
row_heartbeat_path
```

The exDQLM/DQLM runtime defaults now record the approved full-run cadence:

```text
runtime.progress_every = 50
runtime.trace_every = 50
runtime.heartbeat_seconds = 1800
runtime.healthcheck_stale_seconds = 1800
```

Smoke rows retain denser telemetry:

```text
smoke.runtime.progress_every = 1
smoke.runtime.trace_every = 1
smoke.runtime.heartbeat_seconds = 30
smoke.runtime.healthcheck_stale_seconds = 180
```

Focused telemetry test evidence:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e 'source("validation/fitforecast_v2/R/utils.R"); ffv2_source_all("validation/fitforecast_v2"); testthat::test_file("validation/fitforecast_v2/tests/testthat/test-telemetry.R", reporter="summary")'
```

Observed result:

```text
telemetry: .............................

DONE
```

Full shared harness test evidence after telemetry wiring:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e 'source("validation/fitforecast_v2/R/utils.R"); ffv2_source_all("validation/fitforecast_v2"); testthat::test_dir("validation/fitforecast_v2/tests/testthat", reporter="summary")'
```

Observed result:

```text
artifact-schema: ...
forecast-horizon-api: ...
protocol-freeze: ............
rolling-grid: ...........................
row-runner-discounts: ..
shared-interface-schema: .......
source-registry-schema: .....
source-window-contract: ...........
stage-filtering: ...........
storage-policy: ...
telemetry: .............................

DONE
Ran 4/4 deferred expressions
```

Next implementation stage:

`build-04-exdqlm-rolling-state`.

## 25. Build-04 exDQLM/DQLM Rolling-State Implementation Evidence

Implementation timestamp:

`2026-05-16 22:05:04 EDT`

Implemented stage:

| Build stage | Status | Evidence |
|---|---|---|
| `build-04-exdqlm-rolling-state` | implemented and tested | `validation/fitforecast_v2/R/exdqlm_rolling_state.R`; `validation/fitforecast_v2/tests/testthat/test-exdqlm-rolling-state.R` |

Feasibility audit result:

- The exdqlm 1.0.0 package already exposes `exdqlmForecast()`, which forecasts from the filtered
  state stored in `m1$theta.out$fm` and `m1$theta.out$fC`.
- The package does not expose a stable public API that performs exact posterior-draw-specific
  filtering of new held-out observations after fitting.
- Therefore build-04 implements the predeclared documented approximation class:

```text
state_update_method = deterministic_plugin_filter_train_median_latent_moments
refit_per_origin = false
forecast_protocol = rolling_origin_no_refit_state_update
```

This method keeps fitted posterior/inference parameters fixed, extends only the filtered dynamic state
through observations available up to each rolling origin, and then delegates the k-step forecast from
that origin to the existing package function `exdqlmForecast()`.

Implementation details:

- For each origin, the harness clones the fitted exDQLM/DQLM object.
- It extends `m1$y`, `m1$model$FF`, `m1$model$GG`, `m1$theta.out$fm`, and `m1$theta.out$fC` through
  observed forecast-block values available at that origin.
- It does not rerun `exdqlmLDVB()` or `exdqlmMCMC()` after the initial fit.
- It does not modify package algorithm files such as `R/exdqlmForecast.R`, `R/exdqlmLDVB.R`, or
  `R/exdqlmMCMC.R`.
- It uses the current package forecast API unchanged by calling `exdqlmForecast()` at each rolling
  origin with `start.t = length(fit_origin$y)`.
- Future pseudo-observation moments are fixed using train-window median fitted latent moments:
  `vts.out` for DQLM, and `vts.out` / `sts.out` plus `gammasig.out` for exDQLM.
- The forecast summary is now lead-level and includes:
  `forecast_origin_source_index`, `forecast_lead`, `target_source_index`, `origin_stride`,
  `max_lead_configured`, `n_origins_for_lead`, `state_update_method`, and `refit_per_origin`.

The exDQLM/DQLM default config now records:

```text
source.forecast_protocol = rolling_origin_no_refit_state_update
source.rolling_hmax = 30
source.origin_stride = 30
```

The source registry and row manifest now propagate:

```text
forecast_protocol
state_update_method
refit_per_origin
max_lead_configured
origin_stride
forecast_lead_metrics_path
```

The shared interface schema now includes:

```text
forecast_protocol
state_update_method
refit_per_origin
forecast_lead_metrics_path
```

Focused rolling-state test evidence:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e 'source("validation/fitforecast_v2/R/utils.R"); ffv2_source_all("validation/fitforecast_v2"); testthat::test_file("validation/fitforecast_v2/tests/testthat/test-exdqlm-rolling-state.R", reporter="summary")'
```

Observed result:

```text
exdqlm-rolling-state: ........................

DONE
```

Full shared harness test evidence:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e 'source("validation/fitforecast_v2/R/utils.R"); ffv2_source_all("validation/fitforecast_v2"); testthat::test_dir("validation/fitforecast_v2/tests/testthat", reporter="summary")'
```

Observed result:

```text
artifact-schema: ...
exdqlm-rolling-state: ........................
forecast-horizon-api: ...
protocol-freeze: ............
rolling-grid: ...........................
row-runner-discounts: ..
shared-interface-schema: .......
source-registry-schema: .....
source-window-contract: ...........
stage-filtering: ...........
storage-policy: ...
telemetry: .............................

DONE
Ran 4/4 deferred expressions
```

Dry-run/source registry evidence:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript validation/fitforecast_v2/scripts/prepare_exdqlm_dynamic_fitforecast_v2_validation.R --dry-run
```

Observed result:

```text
source_rows: 18
manifest_rows: 72
source_window_status: PASS 18
phase_counts: mcmc_tt500=18, mcmc_tt5000=18, vb_full=36
smoke_rows: 2
```

Registry protocol check:

```text
rolling_origin_no_refit_state_update 30 30
```

Remaining caveat:

This build does not claim exact posterior-draw-specific filtering of held-out observations. It claims
deterministic plug-in filtering with fixed fitted posterior summaries, explicitly identified by
`state_update_method`. If exact draw-specific filtering becomes scientifically required, that should
be a separate package-level API addition on a future branch, not an unlabelled change to this
validation harness.

Next implementation stage:

`build-05-qdesn-lead-export`.

## 26. Build-05 Q-DESN Lead Export Implementation Evidence

Implementation timestamp:

`2026-05-16 22:20:38 EDT`

Implemented stage:

| Build stage | Status | Evidence |
|---|---|---|
| `build-05-qdesn-lead-export` | implemented and tested | `R/qdesn_mcmc_validation.R`; `scripts/pipeline_real_main.R`; `tests/testthat/test-qdesn-dynamic-fitforecast-lead-export.R` |

Design decision:

- The primary Q-DESN forecast export uses `forecast_lattice.qdesn_fit()` per-origin `mu_by_origin`
  draws.
- The Q-DESN mixture output (`forecast_full$mix`) is not used as the primary lead-level validation
  estimate.
- Quantile synthesis remains disabled for the primary single-quantile validation path.
- The point forecast used for true-quantile recovery is the median of the per-origin `mu_by_origin`
  draw row at each `(origin, lead)`.
- The retained row fields match the exDQLM/DQLM rolling-origin convention:
  `forecast_origin_source_index`, `forecast_lead`, `target_source_index`, `origin_stride`,
  `max_lead_configured`, `n_origins_for_lead`, `state_update_method`, and `refit_per_origin`.

Active Q-DESN config now records:

```text
metrics.rolling_origin.enabled = true
metrics.rolling_origin.require_lead_export = true
metrics.rolling_origin.max_lead_configured = 30
metrics.rolling_origin.origin_stride = 30
pipeline.forecast.horizon = 30
pipeline.forecast.origin_stride = 30
pipeline.forecast.primary_lead_export = true
pipeline.outputs.keep_draws = true
```

Storage-light handling:

- `forecast_objects.rds` may transiently contain per-origin draws so the retention hook can write
  compact lead-level CSV artifacts.
- Successful `forecast_objects.rds` remains pruned after compact fit paths, compatibility horizon
  summaries, rolling-origin path rows, and rolling lead metrics are written.
- The output retention manifest now records:
  `forecast_rolling_origin_path`, `forecast_rolling_origin_rows`,
  `forecast_lead_metrics_path`, `forecast_lead_metrics_rows`, and
  `forecast_rolling_origin_status`.

Q-DESN config/launcher dry-run evidence:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase smoke --dry-run
```

Observed result:

```text
phase: smoke
batch: smoke
dry_run: TRUE
run_tag: qdesn-dynamic-fitforecast-v2-smoke-20260516-222038__git-fe05baf
branch: validation/shared-fitforecast-v2-1.0.0
Rscript: /data/jaguir26/local/opt/R/4.6.0/bin/Rscript
QDESN_FFV2_LAUNCH_APPROVED: FALSE
QDESN_FFV2_TT5000_APPROVED: FALSE
```

Focused Q-DESN lead-export test evidence:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-qdesn-dynamic-fitforecast-lead-export.R", reporter="summary")'
```

Observed result:

```text
qdesn-dynamic-fitforecast-lead-export: ......................

DONE
```

Adjacent Q-DESN fit+forecast test evidence:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e 'pkgload::load_all(".", quiet=TRUE); files <- c("test-qdesn-dynamic-fitforecast-horizon-summaries.R", "test-qdesn-dynamic-fitforecast-storage-light.R", "test-qdesn-dynamic-fitforecast-no-leakage.R", "test-qdesn-dynamic-fitforecast-interface-schema.R", "test-qdesn-dynamic-fitforecast-launcher-filters.R", "test-qdesn-dynamic-fitforecast-source-windows.R"); for (f in files) testthat::test_file(file.path("tests/testthat", f), reporter="summary")'
```

Observed result:

```text
qdesn-dynamic-fitforecast-horizon-summaries: ........
qdesn-dynamic-fitforecast-storage-light: ......
qdesn-dynamic-fitforecast-no-leakage: .......
qdesn-dynamic-fitforecast-interface-schema: ...
qdesn-dynamic-fitforecast-launcher-filters: ................................
qdesn-dynamic-fitforecast-source-windows: .....................

DONE
```

Full shared harness test evidence after build-05:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e 'source("validation/fitforecast_v2/R/utils.R"); ffv2_source_all("validation/fitforecast_v2"); testthat::test_dir("validation/fitforecast_v2/tests/testthat", reporter="summary")'
```

Observed result:

```text
artifact-schema: ...
exdqlm-rolling-state: ........................
forecast-horizon-api: ...
protocol-freeze: ............
rolling-grid: ...........................
row-runner-discounts: ..
shared-interface-schema: .......
source-registry-schema: .....
source-window-contract: ...........
stage-filtering: ...........
storage-policy: ...
telemetry: .............................

DONE
Ran 4/4 deferred expressions
```

Script parse evidence:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e 'parse("scripts/pipeline_real_main.R"); parse("scripts/export_qdesn_dynamic_fitforecast_v2_shared_interface.R"); parse("R/qdesn_mcmc_validation.R"); parse("R/qdesn_static_exdqlm_crossstudy.R"); cat("parse_ok\n")'
```

Observed result:

```text
parse_ok
```

Remaining caveat:

The Q-DESN primary export still relies on the current `forecast_lattice.qdesn_fit()` machinery. It
does not refit per origin and does not perform multi-quantile synthesis. The real-mode pipeline now
honors `forecast.origin_stride` for the retained full-horizon lattice, while the separate lead-1
path remains available only for backward-compatible compact holdout summaries.

Next implementation stage:

`build-06-schema-interface`.
