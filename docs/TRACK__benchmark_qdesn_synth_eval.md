# TRACK: Benchmark Evaluation Plan for Q-DESN Synthesized Forecasts

Date: 2026-03-06
Owner: benchmark evaluation of the current Q-DESN model family
Status: implemented benchmark runner with active pilot validation; tracker now records current protocol, current RHS-collapse evidence, and the immediate low-cost debugging plan before any heavy rerun

## Frozen State: 2026-03-10

Current benchmark work is intentionally frozen at the tourism medium-route RHS
failure before any wider benchmark rerun.

Latest decisive corrected checkpoint:

- corrected run:
  - `results/benchmarks/qdesn_synth/qdesn_synth_tourism_one_step_medium_n256_rhs_refine__20260310-133219__git-39c0cf7`
- corrected log:
  - `logs/benchmarks/qdesn_synth_tourism_one_step_medium_n256_rhs_refine__20260310-133034.log`
- first corrected candidate result:
  - `medium_n256_tau100_f50`
  - warmup now correctly uses `tau = tau0`
  - still fails with `coverage_dev|pit_dev|rhs_collapse|rhs_near_bound`
  - runtime `13911.9s`

Operational rule from this freeze point:

- do **not** rerun `check`, `dev`, `monthly`, or any broader synthesis benchmark
  until the isolated quantile debug mode produces a non-collapsing shoulder fit
  on the pinned tourism series.
- the current expensive full-ladder refinement run was stopped after the first
  corrected checkpoint because the next efficient step is a single-quantile,
  single-candidate debug loop.

## Isolated Debug Mode

New isolated debug mode:

- script:
  - `scripts/benchmark_qdesn_quantile_debug_run.R`
- config:
  - `config/benchmarks/qdesn_tourism_q20_quantile_debug.yaml`

Design:

- one dataset: `tourism_monthly`
- one series: `T109`
- one stage: `validation`
- one candidate: `medium_n256_tau100_f50`
- one quantile: `q = 0.20`

Outputs:

- `tables/quantile_debug_summary.*`
- `tables/quantile_debug_collapse_summary.*`
- `tables/quantile_debug_rhs_trace.*`
- `reports/quantile_debug_report.md`
- `figures/quantile_debug_tau_trace.png`
- `figures/quantile_debug_beta_l2_trace.png`

Purpose:

- isolate the collapse at the single-quantile level;
- record the exact post-warmup tau behavior;
- avoid rerunning the full synthesis ladder while the core RHS issue is still
  unresolved.

## 0) Scope and core decision

This tracker defines how to evaluate the current Q-DESN workflow on the benchmark
datasets already ingested in this repo:

- Monash Forecasting Archive
- official M4

The model under test is **not** an individual quantile fit.

The primary forecast object is:

- `QDESN-synth(p_vec)` = the synthesized predictive distribution obtained by:
  - fitting `qdesn_fit_vb()` separately at several quantile levels `p_vec`,
  - generating posterior predictive draws for each fitted quantile model,
  - combining those draws with `exdqlm_synthesize_from_draws()`.

This means:

- individual quantile fits are intermediate components,
- the synthesized forecast is the object that should be scored, ranked, and compared,
- point metrics for M4-style comparability must be computed from the synthesized forecast summary, not from a standalone median-fit forecast.

The benchmark implementation must be careful about:

- split integrity,
- leakage control,
- provenance,
- reproducibility,
- storage scale,
- fair comparison against standard benchmark baselines.

## 1) What already exists in this repo

### 1.1 Benchmark data pipeline already available

Processed benchmark data already lives under:

- `data-processed/benchmarks/metadata/series_metadata.rds`
- `data-processed/benchmarks/splits/split_definitions.rds`
- `data-processed/benchmarks/panel/<dataset>.rds`

Supporting documentation:

- `docs/BENCHMARK_PIPELINE.md`

Current benchmark semantics already implemented:

- `source_family = "monash"` and `source_family = "m4"` are distinct.
- Monash M4 duplicates are excluded from the Monash main pool.
- official M4 train/test structure is preserved.
- Monash uses explicit tail-based train/validation/test definitions.

### 1.4 Current implementation snapshot

Benchmark-side Q-DESN evaluation is now implemented in:

- `R/benchmark_qdesn_data.R`
- `R/benchmark_qdesn_runner.R`
- `R/benchmark_qdesn_calibration.R`
- `R/benchmark_qdesn_metrics.R`
- `R/benchmark_qdesn_baselines.R`
- `R/benchmark_qdesn_results.R`
- `R/benchmark_qdesn_diagnostics.R`
- `R/benchmark_qdesn_report.R`
- `scripts/benchmark_qdesn_run.R`
- `scripts/benchmark_qdesn_report.R`

The current benchmark protocol now includes:

- dataset-level candidate selection on validation splits using synthesized CRPS;
- quantile-level candidate diagnostics, so selection can now inspect component
  quantile pinball, empirical coverage error, and PIT deviation rather than
  only the synthesized score;
- route-aware candidate families for short / medium / long fit histories;
- multi-seed Q-DESN synthesis through fixed `seed_set` pooling;
- explicit RHS-aware benchmark configs, including `beta_prior_type = "rhs"`,
  tau-aware candidate blocks, and saved RHS diagnostic tables for near-bound
  and collapse-like shrinkage behavior;
- optional internal recalibration on the fitting tail, estimated without using
  the held-out benchmark test block;
- stronger classical baselines plus M4 comparability outputs (`Naive2`, `OWA`,
  `MSIS95`);
- audit-subset diagnostics with PIT summaries, coverage summaries, and fan
  charts;
- compact machine-readable result tables and run manifests.

### 1.4.1 Current tourism shoulder status

The latest completed tourism-only shoulder tau sweep is:

- `results/benchmarks/qdesn_synth/qdesn_synth_tourism_shoulder_tau_sweep__20260309-003529__git-2eb8111`

What it established:

- increasing `tau0` from `100` to `250` or `500` mostly prevents collapse for
  the bridge-family candidates;
- this does **not** solve the blocking pathology;
- the dominant failure mode is now shoulder quantile explosion:
  - `q = 0.20` and `q = 0.80` stay numerically stable,
  - but their forecast scale and pinball loss explode by several orders of
    magnitude relative to the median reference scale;
- only one candidate in that sweep still collapsed, and it did so under
  `tau0 = 100` on the larger `n = 160`, `rho = 0.915` shape.

Operational implication:

- keep `tau0 = 100` as the default;
- use `tau0 = 250` only as a fallback branch for the larger candidate shapes
  that still collapse;
- the next step is a tourism-only scale-control family, not a wider benchmark
  rerun.

### 1.4.2 Current tourism scale-control outcome

The next tourism-only scale-control sweep is:

- `results/benchmarks/qdesn_synth/qdesn_synth_tourism_shoulder_scale_control__20260309-023624__git-2eb8111`

What it established:

- lower-drive DESN settings improve the shoulder explosion numerically, but do
  not solve it;
- all six candidates are non-collapsing shoulder-explosion failures;
- the best scale-control candidate still has shoulder/reference pinball and
  |qhat| ratios on the order of `10^6`;
- `tau0 = 250` on the larger shapes makes the shoulder explosion materially
  worse, so the scale-control family should keep `tau0 = 100` by default.

Operational implication:

- further blind DESN tuning is lower value than direct diagnosis;
- the next step is a lead-1 audit to separate readout-mean issues from
  predictive-scale issues on the shoulder quantiles.

### 1.4.3 Current lead-1 one-step audit outcome

The corrected, seed-consistent lead-1 audit is:

- `results/benchmarks/qdesn_synth/qdesn_synth_tourism_one_step_audit__20260309-033651__git-2eb8111`

What it established:

- the exploding bridge-family candidates are already pathological at lead `1`;
- for those candidates, the problem is both:
  - enormous posterior mean (`mu_mean`) at `q = 0.20` and `q = 0.80`, and
  - enormous predictive scale (`draw_sd`, `sigma_mean`) in the same quantiles;
- increasing `tau0` from `100` to `250` on that same bridge shape increases
  both the shoulder posterior mean magnitude and the shoulder predictive scale;
- the best scale-control candidate behaves differently:
  - `q = 0.20` and `q = 0.80` collapse to the RHS lower tau bound at lead `1`,
  - their posterior means stay around the median scale,
  - but their predictive spread is still roughly `16x` the median predictive
    spread.

Operational implication:

- the current failure modes are now split cleanly:
  - bridge family: non-collapsing but readout mean and scale both explode;
  - scale-control family: mean is controlled, but the shoulder quantile models
    collapse and still yield excessive predictive spread;
- the next modeling work should target the shoulder quantile readout fit
  directly rather than broadening the DESN search or rerunning the benchmark.

### 1.4.4 Current next-step refinement

To act on the corrected one-step audit cleanly, the next micro-stage is:

- `config/benchmarks/qdesn_synth_tourism_one_step_tau_refine.yaml`

Design:

- keep the best scale-control DESN shape fixed:
  - `n = 128`
  - `m = 36`
  - `rho = 0.90`
  - `alpha = 0.05`
  - `pi_in = 0.02`
  - `pi_w = 0.005`
  - `washout = 96`
- vary only `tau0 = 100, 150, 250`;
- use a shared `seed_group_id` so all three `tau0` variants reuse the same
  underlying reservoir seed family and are directly comparable.

Decision rule:

- if one of these variants removes shoulder collapse without reopening the
  bridge-family explosion regime, it becomes the next tourism candidate to
  validate before any wider rerun;
- if all three fail, stop DESN candidate tuning and move to direct
  shoulder-readout work.

Outcome:

- completed run:
  - `results/benchmarks/qdesn_synth/qdesn_synth_tourism_one_step_tau_refine__20260309-130308__git-2eb8111`
- all three `tau0` variants (`100`, `150`, `250`) failed in the same way:
  - no RHS collapse,
  - immediate shoulder posterior-mean explosion at lead `1`,
  - immediate shoulder predictive-scale explosion at lead `1`;
- the explosion becomes worse as `tau0` increases from `100` to `250`.

Operational conclusion:

- stop DESN-side candidate tuning for this tourism shoulder problem;
- do **not** reopen M4, `check`, `dev`, or `full`;
- the next phase is direct shoulder-readout work, because the remaining
  bottleneck is the quantile readout behavior itself rather than the broader
  DESN candidate family.

### 1.4.5 Current direct readout phase

The first readout-phase micro-stage is:

- `config/benchmarks/qdesn_synth_tourism_one_step_readout_refine.yaml`

Design:

- keep the best DESN shape fixed:
  - `n = 128`
  - `m = 36`
  - `rho = 0.90`
  - `alpha = 0.05`
  - `pi_in = 0.02`
  - `pi_w = 0.005`
  - `washout = 96`
- keep a shared `seed_group_id` across all readout variants;
- vary only the readout-side components:
  - RHS + readout scaling on
  - RHS + readout scaling off
  - ridge prior with `tau2 = 10`
  - ridge prior with `tau2 = 100`

Decision rule:

- if any readout variant materially reduces shoulder posterior mean and
  predictive scale at lead `1`, that readout family becomes the new shoulder
  candidate to validate before any wider rerun;
- if none do, the next work moves below config-level tuning and into the
  readout implementation itself.

Current result:

- completed run:
  - `results/benchmarks/qdesn_synth/qdesn_synth_tourism_one_step_readout_refine__20260309-144010__git-2eb8111`
- `readout_ridge_scale_tau10` is the first readout variant that materially
  stabilizes the shoulder quantiles at lead `1`;
- `readout_ridge_scale_tau100` is also much better than RHS, but clearly worse
  than ridge `tau2 = 10`;
- toggling `readout_scale` off under RHS makes no material difference.

Operational implication:

- the next gate is a full-ladder one-step audit of the fixed ridge candidate,
  not a wider tourism rerun yet.

### 1.2 Current Q-DESN / synthesis pipeline already available

Relevant implementation pieces:

- `R/qdesn_vb.R`
  - `qdesn_fit_vb()`
- `R/exdqlm_synthesize_from_draws.R`
  - `exdqlm_synthesize_from_draws()`
- `scripts/pipeline_real_main.R`
  - current real-data fit -> forecast -> synthesis -> diagnostics flow
- `R/model_selection_distribution_first.R`
  - split-safe pattern where several quantile fits are synthesized and scored
- `R/qdesn_model_selection_v2.R`
  - newer YAML-driven model-selection workflow with synthesized CRPS
- `R/run_esn_pipeline.R`
  - separate-process wrapper around the pipeline scripts

### 1.3 Important existing behavior to preserve

The current real-data pipeline already contains useful logic for:

- fitting one model per quantile in `p_vec`,
- synthesizing forecast draws via `exdqlm_synthesize_from_draws()`,
- CRPS scoring on synthesized draws,
- pinball summaries on synthesized quantiles,
- PIT diagnostics for per-quantile and synthesized forecasts,
- calibration / rolling-coverage summaries,
- lead-wise synthesized CRPS evaluation.

This logic should be reused where sensible.

### 1.5 New benchmark-side selection guardrails

The benchmark runner now has explicit candidate guardrails that sit alongside
the synthesized validation metric:

- keep synthesized CRPS as the primary validation score;
- compute per-quantile diagnostics from the component Q-DESN fits;
- record RHS shrinkage summaries from the fitted VB objects;
- allow validation ranking to use tie-breakers based on tail pinball,
  quantile-coverage deviation, and RHS health;
- reject candidates that show obviously bad quantile behavior or RHS collapse
  signals unless every candidate fails the guardrails, in which case the guard
  is relaxed and this is logged explicitly.

This matches the scientific intent better than selecting only on synthesized
CRPS while ignoring whether the individual quantile models are behaving
sensibly.

### 1.6 Current validation status after RHS / quantile-selection pass

Latest completed validation run:

- `results/benchmarks/qdesn_synth/qdesn_synth_dev__20260306-145436__git-2eb8111`

Key outcomes from that run:

- the benchmark now writes `quantile_model_metrics` and `rhs_diagnostics` as
  first-class result tables;
- selection is using the new quantile/RHS-aware summary layer successfully;
- for the current dev slice, both medium-route datasets selected the
  `n = 128`, `m = 24`, `washout = 48`, `tau0 = 10000`, `init_log_tau = 0`
  candidate over the smaller-`n` or smaller-`tau0` alternatives;
- no selected candidate showed RHS collapse or near-bound tau behavior;
- the benchmark still shows extreme forecast failure for the current
  `qdesn_synth` model, especially through the interior component quantiles,
  so the remaining work is model improvement rather than benchmark plumbing.

Operational note:

- after moving benchmark configs to explicit RHS and tau-aware grids, the old
  `qdesn_synth_pilot.yaml` became substantially heavier than its name implied;
- `config/benchmarks/qdesn_synth_dev.yaml` was added as the practical
  fast-iteration profile for candidate development under the strengthened
  protocol.

### 1.7 Revised default alignment after tau review

The benchmark configs were then revised again to align with the repo-level
defaults in `config/defaults.yaml`:

- RHS beta prior now defaults to `tau0 = 0.001`, `s2 = 0.1`, and the tighter
  numerical settings used by the main config defaults;
- benchmark-side fallback defaults in `R/benchmark_qdesn_runner.R` now mirror
  those base RHS settings rather than the older large-scale values from the
  script-era pipeline;
- the benchmark search no longer uses huge `tau0` values as a model-capacity
  lever.

At the same time, the search itself was broadened where it belongs:

- much wider raw DESN spaces over `D`, `n`, `n_tilde`, `m`, `alpha`, `rho`,
  `washout`, `pi_w`, and `pi_in`;
- deterministic per-block budgets so the search is broader without becoming
  completely unbounded;
- current config counts:
  - `qdesn_synth_dev.yaml`: 6 candidates
  - `qdesn_synth_pilot.yaml`: 5 candidates
  - `qdesn_synth.yaml`: 54 candidates

Current operational status:

- the broadened, bounded-`tau0` dev run was started and remained numerically
  stable, but it did not finish within the current implementation turn because
  the broader DESN search under the corrected VB defaults is materially more
  expensive than the previous benchmark-dev profile;
- this is now a runtime-management problem, not a benchmark-correctness problem.

### 1.8 Clarification on defaults provenance

The benchmark runner is supposed to align with:

- `config/defaults.yaml`

and this file is the correct source of repo-level default behavior.

The older large-scale RHS settings

- `tau0 = 10000`
- `s2 = 10000`

appear in:

- `scripts/pipeline_real_main.R`
- `scripts/pipeline_sim_main.R`

Those script-era defaults are useful historical context, but they are **not**
the current benchmark defaults and should not be treated as the benchmark
reference settings.

### 1.9 Current bounded-default collapse evidence

The latest completed bounded-default smoke run is:

- `results/benchmarks/qdesn_synth/qdesn_synth_ultrasmoke__20260306-181154__git-2eb8111`

That run is intentionally small and not suitable for scientific claims, but it
is very useful for diagnosing RHS behavior.

Observed outcome:

- all fitted quantile models collapsed under the bounded-default RHS settings;
- `collapse_flag = TRUE` for every fitted quantile model;
- `near_bound_flag = TRUE` for every fitted quantile model;
- `tau_last` ended at the lower eta bound, approximately `2.06e-09`;
- `beta_l2_last` was effectively zero, so the readout coefficients were
  numerically collapsed.

Interpretation:

- the immediate blocking issue is not benchmark plumbing;
- the immediate blocking issue is **RHS global shrinkage collapse**;
- until collapse is avoided reliably, larger benchmark reruns are not a good
  use of compute.

### 1.10 Immediate low-cost RHS debugging plan

The next step should not be another large benchmark search.

The next step should be a staged, low-cost collapse-debug protocol that keeps
the DESN architecture mostly fixed while exploring only the RHS settings and
tau-freezing schedule.

Primary objective:

- find at least one RHS configuration that does **not** collapse on a small,
  deterministic benchmark-dev slice.

Secondary objective:

- once non-collapse is achieved, check whether the same RHS settings also make
  the tail quantile fits behave sensibly.

#### Stage A: central-quantile collapse debugging

Use only a very small central quantile grid:

- `p_vec = c(0.45, 0.50, 0.55)`

Reason:

- these fits are cheaper than tail fits,
- they should converge faster,
- they are enough to detect global RHS collapse.

Use a fixed, deterministic benchmark-dev slice:

- `tourism_monthly / T1`
- `m4_monthly / M23845`

Reason:

- both are long enough to be meaningful,
- they avoid the confounding effect of extremely short histories,
- they keep runtime low.

Use a fixed compact DESN spec at first:

- `D = 1`
- `n = 32`
- `m = 12`
- `alpha = 0.20`
- `rho = 0.90`
- `washout = 24`
- `pi_w = 0.10`
- `pi_in = 1.00`
- one fixed seed

Reason:

- the first question is whether RHS can avoid collapse at all,
- not whether a larger reservoir is already benchmark-optimal.

Run only a small RHS / tau-schedule matrix:

1. `tau0 = 0.001`, `s2 = 0.1`, `init_log_tau = null`, `freeze_tau_iters = 20`
2. `tau0 = 0.001`, `s2 = 1.0`, `init_log_tau = null`, `freeze_tau_iters = 20`
3. `tau0 = 0.001`, `s2 = 1.0`, `init_log_tau = 0.0`, `freeze_tau_iters = 50`
4. `tau0 = 1.0`, `s2 = 1.0`, `init_log_tau = 0.0`, `freeze_tau_iters = 20`
5. `tau0 = 1.0`, `s2 = 1.0`, `init_log_tau = 0.0`, `freeze_tau_iters = 50`
6. `tau0 = 10.0`, `s2 = 1.0`, `init_log_tau = log(10)`, `freeze_tau_iters = 50`

Also set:

- `freeze_tau_warmup_iters = freeze_tau_iters`

This keeps the search disciplined and directly tests the components that are
most likely to control collapse:

- prior scale,
- prior spread,
- tau initialization,
- tau freezing.

Stage-A success rule:

- `collapse_flag = FALSE` for every fitted quantile model,
- `near_bound_flag = FALSE` for every fitted quantile model,
- `tau_last` must stay materially away from the lower bound,
- `beta_l2_last` must be clearly non-zero.

Stage-A ranking rule after the hard filter:

- first: median `p = 0.50` pinball loss,
- second: mean pinball across the three central quantiles,
- third: runtime.

Latest Stage-A run:

- Run: `results/benchmarks/qdesn_synth/qdesn_rhs_debug_stageA__20260306-185930__git-2eb8111`
- Validation winner on both pinned datasets: `rhs_tau0_10_s2_1_initlogtau10_f50`
- Validation result:
  - `tourism_monthly`: non-collapsing
  - `m4_monthly`: non-collapsing on validation only
- Critical refit check:
  - the selected `m4_monthly` test refit still collapses at `p = 0.50`
  - `tau_last = 2.061257e-09`
  - `beta_l2_last = 2.790311e-16`

Current status:

- collapse is **not** solved robustly yet
- do **not** move to Stage B / Stage C / heavier benchmark runs until the
  selected-candidate refit is stable on both pinned datasets
- the run-level collapse audit now lives in:
  - `scripts/benchmark_qdesn_collapse_audit.R`
  - `reports/rhs_collapse_audit.md` inside each audited run directory

Updated Stage-A rerun under the tightened tau sweep:

- Run: `results/benchmarks/qdesn_synth/qdesn_rhs_debug_stageA__20260306-220307__git-2eb8111`
- Candidate grid:
  - `tau0 in {1, 10, 100}`
  - `s2 = 1`
  - `init_log_tau = 2.302585093`
  - `freeze_tau_iters = 50`
  - `freeze_tau_warmup_iters = 50`
  - `max_iter = 1000`
- Winner on both pinned datasets: `rhs_tau0_100_s2_1_initlogtau10_f50`
- New status on this cheap central-quantile slice:
  - selected candidate is stable on both validation and test refits
  - no collapse on the selected candidate for either pinned dataset
  - this clears the collapse gate for moving to the next debug stage

#### Stage B: tail-fit sanity check

Only after at least one Stage-A survivor exists, move to:

- `p_vec = c(0.05, 0.50, 0.95)`

Keep:

- the same benchmark-dev slice,
- the same compact DESN architecture,
- only the Stage-A survivor RHS settings.

Goal:

- confirm that the non-collapsing RHS settings also behave sensibly on the
  extreme quantile fits.

Stage-B rejection criteria:

- any renewed RHS collapse;
- extremely poor tail coverage deviation;
- obviously exploded interval widths relative to the data scale.

#### Stage C: move to the final synthesis quantile grid

Once collapse is avoided reliably on the three-quantile debug runs, move to the
final synthesis grid:

- `p_vec = seq(0.05, 0.95, by = 0.05)`

Across all stages, the benchmark fit path must stay on Laplace-Delta only.
The benchmark runner now rejects any `readout_approximation` other than
`laplace_delta`.

This is the intended long-run synthesis grid for benchmark work.

Do **not** move to this larger grid until:

- Stage A has a clear non-collapse winner;
- Stage B shows that the same RHS settings remain stable on the tail models.

#### Stage D: only then re-open DESN search

After a stable RHS setting is found, reopen the DESN candidate search.

Recommended order:

1. keep the winning RHS settings fixed;
2. compare only a few DESN candidates;
3. only after that launch the heavier route-aware benchmark configs.

This keeps the search efficient and avoids conflating:

- collapse caused by the RHS prior,
- with genuine model-capacity differences in the reservoir.

## 2) Important audit finding: do not benchmark by naively looping `pipeline_real_main.R`

`scripts/pipeline_real_main.R` is a strong reference for object structure,
diagnostics, and synthesis, but it should **not** be used unchanged as the
benchmark harness.

Reasons:

- It is a plot-heavy end-to-end script, not a scalable benchmark runner.
- In its current form it preprocesses `y_all` and `X_all` before the forecast
  split is carved out, which is not acceptable for leakage-safe benchmarking.
- Its split handling is generic and does not understand the benchmark pipeline's
  explicit Monash vs official M4 split contracts.

Benchmark implementation should therefore:

- reuse core model and synthesis functions,
- reuse the correct split-safe ideas from `model_selection_distribution_first()`
  and `model_selection_optionA()`,
- avoid shelling out to the full script once per benchmark series unless
  debugging a small audit subset.

## 3) Definition of the model under test

For benchmarking, define the main model as:

- **Name**: `qdesn_synth`
- **Core forecast object**: synthesized predictive distribution
- **Construction**:
  1. choose a quantile grid `p_vec`,
  2. fit `qdesn_fit_vb()` at each `p` in `p_vec`,
  3. generate posterior predictive draws per quantile model,
  4. call `exdqlm_synthesize_from_draws(draws_list, p = p_vec, ...)`,
  5. score the resulting synthesized distribution on the benchmark split.

Intermediate artifacts to keep for diagnostics:

- per-quantile forecast draws,
- per-quantile predictive quantiles,
- synthesized draws,
- synthesized quantiles on the evaluation grid,
- point summaries derived from synthesized draws.

Primary point forecast to report:

- synthesized median (`q50`)

Secondary point forecast to report:

- synthesized mean

Final target synthesis quantile grid:

- `p_vec = seq(0.05, 0.95, by = 0.05)`

Collapse-debug quantile grids:

- Stage A: `c(0.45, 0.50, 0.55)`
- Stage B: `c(0.05, 0.50, 0.95)`
- Stage C: `seq(0.05, 0.95, by = 0.05)`

The benchmark code must always record `p_vec` in the run manifest, and heavy
benchmark reruns should use the full `seq(0.05, 0.95, 0.05)` grid only after
RHS collapse has been debugged away on the smaller grids.

### 3.1 Current staged RHS-debug outcome

Latest completed staged debug runs:

- Stage A candidate sweep:
  - `results/benchmarks/qdesn_synth/qdesn_rhs_debug_stageA__20260306-220307__git-2eb8111`
- Stage B fixed-candidate tail check:
  - `results/benchmarks/qdesn_synth/qdesn_rhs_debug_stageB__20260306-223523__git-2eb8111`
- Stage C fixed-candidate full synthesis-grid check:
  - `results/benchmarks/qdesn_synth/qdesn_rhs_debug_stageC__20260306-224321__git-2eb8111`

Current preferred RHS debug setting:

- `tau0 = 100`
- `s2 = 1`
- `init_log_tau = 2.302585093`
- `freeze_tau_iters = 50`
- `freeze_tau_warmup_iters = 50`
- `max_iter = 1000`
- `readout_approximation = laplace_delta`

What the staged audit now shows:

- Stage A selected `rhs_tau0_100_s2_1_initlogtau10_f50` over the smaller-`tau0`
  candidates and cleared collapse on the central quantiles.
- Stage B kept the same fixed RHS setting and cleared collapse on both pinned
  datasets for the tail triplet `0.05`, `0.50`, `0.95`.
- Stage C kept the same fixed RHS setting and cleared collapse on the full
  synthesis grid `0.05:0.95 by 0.05`; there were `0/76` collapsed fits and
  `0/76` fragile fits on the pinned validation/test slice.

The important blocking nuance is that Stage C solved **collapse**, but not
**quantile quality**.

The 19-quantile Stage C audit shows a strong shoulder-quantile failure band:

- quantiles `0.20` to `0.40` produce extreme negative forecasts;
- quantiles `0.60` to `0.80` produce extreme positive forecasts;
- those fits are numerically stable under the RHS diagnostics, but they are not
  scientifically usable:
  - mean pinball on those quantiles is on the order of `1e9` to `8e9`;
  - fitted quantile means explode to approximately `6e9` to `3e10` in
    magnitude;
  - empirical coverage saturates toward `0` for the lower shoulder and `1` for
    the upper shoulder.

By contrast, the extreme tails and central triplet remain much more reasonable:

- `0.05` to `0.15`
- `0.45` to `0.55`
- `0.85` to `0.95`

Operational decision from this audit:

- RHS-collapse debugging is now sufficiently solved on the tiny debug slice.
- A full benchmark rerun should still remain paused.
- The next work should keep the preferred RHS setting fixed and improve the
  candidate quantile models so that the shoulder quantiles stop producing
  stable-but-pathological forecasts.

### 3.2 Additional full-ladder `tau0` sweep result

An additional pinned-slice sweep was then run over:

- `tau0 in {10, 20, 50, 100}`
- same fixed DESN candidate
- same full synthesis grid `0.05:0.95 by 0.05`
- same fixed settings:
  - `s2 = 1`
  - `init_log_tau = 2.302585093`
  - `freeze_tau_iters = 50`
  - `freeze_tau_warmup_iters = 50`
  - `max_iter = 1000`
  - `readout_approximation = laplace_delta`

Run directory:

- `results/benchmarks/qdesn_synth/qdesn_rhs_debug_tau_sweep__20260307-001216__git-2eb8111`

Main result:

- Lowering `tau0` does reduce the shoulder-quantile pathology dramatically.
- But it does so by reintroducing RHS collapse.

Observed pattern on validation:

- `tau0 = 100`
  - the only fully non-collapsing option on both pinned datasets
  - but still has catastrophic shoulder pathology
  - shoulder/reference pinball ratio is on the order of `4e7` to `6e7`
- `tau0 = 50`
  - shoulder pathology is much smaller
  - but it collapses on roughly half of the fitted quantiles
- `tau0 = 20`
  - also much smaller shoulder pathology than `100`
  - but still collapses on `8` to `10` quantiles depending on dataset
- `tau0 = 10`
  - similarly reduces the pathology relative to `100`
  - but remains collapse-prone

Important methodological consequence:

- The current synthesized-CRPS-based selection path picked `tau0 = 20` on both
  pinned datasets because its validation score looked better than `tau0 = 100`.
- That is not a trustworthy model choice, because the selected `tau0 = 20`
  refit collapses on test for both pinned datasets.

So the current benchmark lesson is:

- `tau0 = 100` is the only collapse-safe setting in this local sweep.
- `tau0 = 10`, `20`, and `50` show that the shoulder pathology is shrinkage
  sensitive, but none of them is viable as-is because they fail the collapse
  gate.
- Future candidate selection should treat RHS collapse / near-bound behavior as
  a hard veto rather than a soft tie-breaker.

## 4) Correct benchmark protocol

### 4.1 Unit of evaluation

The scoring unit is one time series.

For each `(dataset, series_id)`, the benchmark runner should consume:

- one row from `series_metadata`,
- one row from `split_definitions`,
- one series slice from `panel/<dataset>.rds`.

### 4.2 Monash protocol

Use the split already stored in `split_definitions`.

Default rule:

- fit candidate model(s) on `train`,
- tune on `validation`,
- refit winning spec on `train + validation`,
- evaluate once on `test`.

Do not move the test boundary.

### 4.3 official M4 protocol

The official M4 test split is sacred.

Allowed benchmark behavior:

- keep official train/test untouched,
- if tuning is needed, derive validation only inside the official training span,
- after tuning, refit on the full official training segment,
- evaluate once on the official test segment.

Recommended deterministic internal validation rule for M4:

- `selection_protocol = "m4_train_tail_val_h"`
- let `h = forecast_horizon`,
- carve the last `h` observations of the official training block as validation,
- use the earlier training prefix as the model-fitting segment for tuning,
- refit on the full official training block after selecting the spec.

This derived tuning split must be stored explicitly in results metadata.

### 4.4 Hyperparameter selection scope

Per-series hyperparameter search across all benchmark series is usually too
expensive and changes the benchmarking question.

Recommended default:

- `tuning_scope = "dataset"`

Meaning:

- choose a deterministic calibration subset of series within each dataset,
- select a shared Q-DESN configuration for that dataset using synthesized CRPS,
- then run the winning configuration across all series in that dataset.

Optional modes:

- `tuning_scope = "series"` for small pilot studies only
- `tuning_scope = "global"` for stress tests only

For a serious large benchmark, dataset-level tuning is the best default.

## 5) Recommended architecture for implementation

### 5.1 Main principle

Use a function-driven benchmark runner inside R.

Do not make the first implementation depend on launching one external
`Rscript` process per series.

### 5.2 Implemented file plan

Implemented modules:

- `R/benchmark_qdesn_data.R`
  - helpers to read benchmark metadata/panel/splits and assemble per-series bundles
- `R/benchmark_qdesn_runner.R`
  - one-series benchmark run for `qdesn_synth`, route-aware candidate selection,
    and experiment orchestration
- `R/benchmark_qdesn_calibration.R`
  - internal tail recalibration helpers for synthesized draws
- `R/benchmark_qdesn_metrics.R`
  - probabilistic and point metrics from synthesized forecasts
- `R/benchmark_qdesn_baselines.R`
  - baseline model runners and harmonized forecast summaries
- `R/benchmark_qdesn_results.R`
  - write manifests, result tables, and aggregated summaries
- `R/benchmark_qdesn_diagnostics.R`
  - audit-subset PIT, coverage, calibration, and fan-chart diagnostics
- `scripts/benchmark_qdesn_run.R`
  - main experiment entrypoint
- `scripts/benchmark_qdesn_report.R`
  - aggregate results, plots, and markdown summary

Suggested config files:

- `config/benchmarks/qdesn_synth.yaml`
- `config/benchmarks/qdesn_synth_pilot.yaml`

Suggested result root:

- `results/benchmarks/qdesn_synth/<experiment_name>/`

### 5.3 Benchmark adapter contract

The adapter layer should return a clean series bundle:

- `dataset`
- `source_family`
- `series_id`
- `y`
- `timestamp`
- `frequency_label`
- `seasonal_period`
- `forecast_horizon`
- `train_idx`
- `val_idx`
- `test_idx`
- `selection_protocol`
- `benchmark_split_protocol`

The current real-mode code already supports a plain single-series input with:

- a `y` column,
- no exogenous columns required.

So the first benchmark implementation can remain strictly univariate.

### 5.4 Model runner contract

For each series, the Q-DESN benchmark runner should:

1. receive a series bundle and effective config,
2. fit one Q-DESN per `p` in `p_vec`,
3. forecast the target horizon,
4. synthesize forecast draws,
5. compute metrics,
6. return a compact result object.

The runner should expose separate phases:

- `fit_quantile_models()`
- `forecast_quantile_models()`
- `synthesize_forecast()`
- `score_forecast()`
- `summarize_forecast()`

### 5.5 Storage policy

Full predictive draws for every series in M4 will be too large.

Default storage policy:

- store compact forecast summaries for all series,
- store full synthesized draws only for a deterministic audit subset,
- optionally store per-quantile draws for the same audit subset only.

Recommended compact outputs for all series:

- point summaries,
- selected quantiles,
- per-series metrics,
- lead-wise metrics,
- calibration summaries,
- exclusion / failure logs.

## 6) Reusing current pipeline logic correctly

### 6.1 Pieces to reuse directly

- `qdesn_fit_vb()`
- `exdqlm_synthesize_from_draws()`
- CRPS logic from `scripts/pipeline_real_main.R`
- PIT and calibration summary logic from `scripts/pipeline_real_main.R`
- split-safe selection/refit pattern from `model_selection_distribution_first()`

### 6.2 Pieces to adapt rather than reuse verbatim

- full `scripts/pipeline_real_main.R`
- `run_esn_pipeline_from_cfg()` as the default benchmark execution engine
- any preprocessing that computes scale parameters on the full series before split

### 6.3 Leakage-safe preprocessing rule

All split-dependent preprocessing must be estimated on the fitting segment only.

Examples:

- if scaling `y`, fit mean and sd on the training segment used for that fit
- if scaling exogenous `X`, fit scaling on the allowed training rows only
- if validation refits occur, refit preprocessing on `train + validation`
- never fit preprocessing on the test segment

This rule is non-negotiable.

## 7) Metrics and comparisons

### 7.1 Primary probabilistic metrics

Primary selection metric:

- mean CRPS of the synthesized forecast on the validation segment

Primary final benchmark metric:

- mean CRPS of the synthesized forecast on the test segment

Secondary probabilistic metrics:

- mean pinball loss over an evaluation grid
- empirical coverage for 80% and 95% intervals
- interval score / Winkler score
- PIT summary diagnostics for audit subsets

### 7.2 Point metrics for benchmark comparability

Compute point metrics from the synthesized median by default.

Required point metrics:

- MAE
- RMSE
- MASE
- sMAPE

For M4 comparability, add when implemented carefully:

- OWA

`OWA` should only be reported after the Naive2 reference is implemented and
validated correctly.

### 7.3 Aggregation rules

Do not report only one giant pooled average.

Required aggregation order:

1. compute metrics per series
2. aggregate within dataset
3. aggregate within source family
4. optionally report an overall summary

Required summary types:

- macro average across series within each dataset
- macro average across datasets within each source family

Optional supplementary summaries:

- micro average weighted by number of series
- lead-wise averages by dataset

Monash and official M4 must always be reported separately before any combined
summary is shown.

## 8) Baseline comparisons

There does not appear to be a ready-made benchmark baseline stack in the repo.

So the benchmark implementation should add a controlled baseline layer.

### 8.1 Minimum required baselines

- `naive`
- `seasonal_naive` when `seasonal_period > 1`
- `drift`

These are implemented.

### 8.2 Stronger classical baselines

- `ETS`
- `AutoARIMA`
- `Theta` or `AutoTheta`

These are implemented through the benchmark baseline layer.

### 8.3 Probabilistic baseline note

Because `qdesn_synth` is probabilistic, a benchmark with only point baselines is
not enough.

Recommended probabilistic baseline options:

- residual-bootstrap `seasonal_naive`
- residual-bootstrap `ETS`

These can be phase-2 work if needed, but the tracker should keep them visible.

## 9) Result artifacts to produce

### 9.1 Required machine-readable outputs

- `tables/series_metrics.csv`
  - one row per series x model
- `tables/lead_metrics.csv`
  - one row per series x lead x model
- `tables/series_status.csv`
  - success / exclusion / failure with reasons
- `tables/model_selection_summary.csv`
  - winning config per dataset or per series, depending on tuning scope
- `tables/forecast_summary.csv`
  - compact forecast summaries for all evaluated series
- `manifest/run_config.yaml`
  - effective benchmark experiment config
- `manifest/provenance.json`
  - code version, seed, benchmark artifact paths, dataset filter, timestamps

### 9.2 Optional heavy artifacts

- `artifacts/audit_subset/<dataset>/<series_id>/synth_draws.rds`
- `artifacts/audit_subset/<dataset>/<series_id>/quantile_fit_summary.rds`
- `artifacts/audit_subset/<dataset>/<series_id>/plots/...`

### 9.3 Human-readable outputs

- `reports/benchmark_qdesn_summary.md`
- `reports/benchmark_qdesn_figures.md`

## 10) Validation and testing requirements

### 10.1 Required correctness checks

- benchmark split boundaries are respected exactly
- no observations after the training boundary influence fitting-time preprocessing
- Monash uses stored test boundaries
- official M4 test is untouched
- synthesized forecast horizon length equals benchmark horizon
- per-quantile forecast matrices align with `p_vec`
- all stored metrics reconcile with stored forecasts

### 10.2 Required tests

- unit test: one benchmark series bundle is assembled correctly
- unit test: Monash split extraction matches `split_definitions`
- unit test: M4 internal validation split stays inside official train
- unit test: synthesized forecast has expected shape `h x n_samp`
- unit test: point summaries derived from synthesized draws are consistent
- integration smoke test: one Monash series end-to-end
- integration smoke test: one M4 series end-to-end
- regression test: no leakage in preprocessing statistics

## 11) Recommended implementation order

### Phase 1: core correctness

1. Benchmark series adapter implemented.
2. Leakage-safe single-series `qdesn_synth` runner implemented.
3. Monash and official M4 split handling implemented.
4. Compact metrics and result tables implemented.
5. Tiny pilot subset validated.

### Phase 2: tuning and scaling

1. Dataset-level model selection with synthesized CRPS implemented.
2. Deterministic validation-subset selection per dataset implemented.
3. Parallel execution and run manifests implemented.
4. Compact forecast summary storage for larger benchmark runs implemented.

### Phase 3: comparisons and reporting

1. Classical baselines implemented.
2. M4-style point benchmark summaries implemented.
3. Compact report and comparison tables implemented.
4. Audit-subset diagnostic plots and PIT/calibration summaries implemented.

## 12) Non-negotiable benchmark rules

- The synthesized forecast is the main forecast under evaluation.
- Official M4 test is never touched during tuning.
- Monash M4 duplicates stay excluded from the Monash main pool.
- No split leakage through preprocessing, feature construction, or selection.
- All exclusions must be logged with explicit reasons.
- All results must preserve provenance to benchmark dataset, split policy, and model config.

## 13) Concrete checklist / tracker

### 13.1 Already available

- [x] Canonical benchmark data pipeline for Monash + official M4
- [x] Explicit benchmark split tables
- [x] `qdesn_fit_vb()` for per-quantile fitting
- [x] `exdqlm_synthesize_from_draws()` for synthesized predictive forecasts
- [x] Existing synthesized CRPS scoring logic
- [x] Existing PIT / calibration / lead-evaluation logic to adapt
- [x] Existing split-safe selection/refit precedent in `model_selection_distribution_first()`

### 13.2 Must implement next

- [x] Add benchmark-side Q-DESN config file(s)
- [x] Add benchmark series adapter functions
- [x] Add leakage-safe preprocessing inside benchmark runner
- [x] Add single-series `qdesn_synth` benchmark runner
- [x] Add Monash split execution path
- [x] Add official M4 execution path with internal train-only validation option
- [x] Add dataset-level model selection based on synthesized CRPS
- [x] Add compact result schemas and manifests
- [x] Add benchmark baseline models
- [x] Add benchmark comparison report
- [x] Add unit and smoke tests

### 13.3 Current protocol upgrades now in place

- [x] Flexible YAML-driven candidate grid with deterministic block structure
- [x] Route-aware candidate families for short / medium / long histories
- [x] Multi-seed Q-DESN candidate evaluation through `seed_set`
- [x] Internal recalibration candidates (`none`, `bias`, `affine`)
- [x] M4 comparability outputs with `Naive2`, `OWA`, and `MSIS95`
- [x] Audit diagnostics with PIT, coverage, calibration bins, and fan charts
- [x] Default active benchmark RHS setup locked to `tau0 = 100`, `s2 = 1`, `init_log_tau = 2.302585093`, `freeze_tau_iters = 50`, `freeze_tau_warmup_iters = 50`, `max_iter = 1000`
- [x] Active candidate selection now hard-vetoes `rhs_collapse`, `rhs_near_bound`, shoulder pinball explosion, and shoulder scale explosion
- [x] If all candidates are vetoed, selection now fails loudly with a guard-veto summary instead of silently relaxing to an unsafe winner
- [x] Added a reusable stage runner at `scripts/benchmark_qdesn_sequence.sh` to execute `check -> report -> dev -> report`
- [x] Converted `qdesn_synth_check.yaml` into a practical gate profile by keeping the hard-veto policy and full quantile ladder but lowering only the compute budget (`max_iter = 250`, smaller draw budgets)
- [x] Selection-failure runs now persist partial diagnostics (`model_selection_summary`, `model_selection_detail`, `quantile_model_metrics`, `rhs_diagnostics`) and write `failure_state.{json,yaml,txt}` before stopping
- [x] Added a dedicated full-budget pinned-slice candidate-family debug profile at `config/benchmarks/qdesn_synth_candidate_debug.yaml`
- [x] Added candidate-level selection checkpoint writes (`selection_checkpoint__*`) so prescreen runs flush summary/detail/quantile/RHS tables after each candidate
- [x] Added batched tourism prescreen configs at `config/benchmarks/qdesn_synth_prescreen_tourism_batch1.yaml`, `config/benchmarks/qdesn_synth_prescreen_tourism_batch2.yaml`, and `config/benchmarks/qdesn_synth_prescreen_tourism_batch3.yaml`
- [x] Added a narrower tourism-only shoulder-debug profile at `config/benchmarks/qdesn_synth_tourism_shoulder_debug.yaml`
  - Uses only `p = {0.20, 0.50, 0.80}`
  - Keeps `rhs_collapse` and `rhs_near_bound` as hard vetoes
  - Relaxes only PIT / coverage and moderate shoulder thresholds to avoid discarding near-miss candidates too early
  - Searches the collapse/explosion boundary instead of broadening the grid further
- [x] Added a direct-fit tourism shoulder trace audit at `scripts/benchmark_qdesn_shoulder_audit.R` with config `config/benchmarks/qdesn_synth_tourism_shoulder_trace_audit.yaml`
  - Runs representative collapse / explosion candidates on pinned series `T109`
  - Saves full per-quantile RHS traces, leadwise quantile paths, and a compact report
- [x] Added the next bridge-family config at `config/benchmarks/qdesn_synth_tourism_shoulder_followup.yaml`
  - Keeps `tau0 = 100`
  - Narrows to the empirical boundary between collapse and shoulder explosion (`m = 34/36`, `rho = 0.91/0.915`, `alpha = 0.05-0.07`, `pi_in = 0.05-0.06`, `pi_w = 0.005-0.01`, `n = 128/160`)
- [x] Added a tourism bridge-family `tau0` escalation sweep at `config/benchmarks/qdesn_synth_tourism_shoulder_tau_sweep.yaml`
  - Tests the same bridge family under `tau0 = 100`, `250`, and `500`
  - Keeps `init_log_tau = 2.302585093`, `s2 = 1`, and the same tau-freeze policy
  - Purpose: check whether larger `tau0` removes remaining shoulder collapses without merely converting them into non-collapsing explosions
- [x] Added the pinned-series M4 prescreen config at `config/benchmarks/qdesn_synth_prescreen_m4_batch1.yaml`
- [x] Wired the prescreen batches into `scripts/benchmark_qdesn_sequence.sh` and `scripts/benchmark_qdesn_prescreen_tourism.sh`
- [x] Pinned BLAS/OpenMP thread counts to `1` inside `scripts/benchmark_qdesn_sequence.sh` for cleaner prescreen runtime behavior
- [x] Seed-group override support so readout/prior variants can share the same reservoir seed family during one-step audits
- [x] One-step readout refinement isolated the first viable shoulder candidate: `readout_ridge_scale_tau10`
- [x] Tourism one-step full-ladder gate passed materially better than earlier shoulder runs
  - Run: `results/benchmarks/qdesn_synth/qdesn_synth_tourism_one_step_ridge_full_ladder__20260309-145243__git-2eb8111`
  - `19` quantiles from `0.05` to `0.95`
  - `0` collapse and `0` near-bound fits
  - shoulder/median `|qhat|` ratio `1.33`
  - shoulder/median `|mu|` ratio `1.22`
  - shoulder/median draw-SD ratio `1.39`
- [x] Added the pinned-series M4 one-step full-ladder gate at `config/benchmarks/qdesn_synth_m4_one_step_ridge_full_ladder.yaml`
- [x] Pinned M4 one-step full-ladder gate also passed on the same ridge-readout candidate
  - Run: `results/benchmarks/qdesn_synth/qdesn_synth_m4_one_step_ridge_full_ladder__20260309-145746__git-2eb8111`
  - `19` quantiles from `0.05` to `0.95`
  - `0` collapse and `0` near-bound fits
  - shoulder/median `|qhat|` ratio `1.001`
  - shoulder/median `|mu|` ratio `1.002`
  - shoulder/median draw-SD ratio `1.163`
- [x] Added the fixed-candidate benchmark gate at `config/benchmarks/qdesn_synth_check_ridge.yaml`
  - Tourism validation pin: `T109`
  - M4 validation pin: `M23845`
  - Evaluation pins: `T1` and `M6336`
  - Same ridge readout candidate used on both datasets before reopening broader benchmark stages
- [x] Fixed-candidate benchmark gate exposed the next route-design issue
  - Run: `results/benchmarks/qdesn_synth/qdesn_synth_check_ridge__20260309-150258__git-2eb8111`
  - `tourism_monthly / T1`: end-to-end `qdesn_synth` ran successfully
  - `m4_monthly / M6336`: `qdesn_synth` failed immediately with `subscript out of bounds`
  - Root cause is geometric applicability, not collapse: `n_train = 60` while the promoted medium-history candidate uses `washout = 96`
  - This means the next phase is short-history route design, not broader benchmark promotion
- [x] Added the pinned short-history M4 one-step audit at `config/benchmarks/qdesn_synth_m4_short_one_step_ridge.yaml`
  - Targets `m4_monthly / M6336` directly on `stage: test`
  - Uses the same ridge readout family but with short-history DESN shapes
- [x] Short-history M4 one-step audit found the first viable short-route candidate
  - Run: `results/benchmarks/qdesn_synth/qdesn_synth_m4_short_one_step_ridge__20260309-151000__git-2eb8111`
  - Best candidate: `short_ridge_compact_n32_m12_w18`
  - `0` collapse and `0` near-bound fits
  - shoulder/median `|qhat|` ratio `1.15`
  - shoulder/median `|mu|` ratio `1.17`
  - shoulder/median draw-SD ratio `1.51`
- [x] Added the routed benchmark gate at `config/benchmarks/qdesn_synth_check_ridge_routed.yaml`
  - Medium/long route uses `check_ridge_medium_tau10`
  - Short route uses `check_ridge_short_tau10`
  - Same benchmark pins as the earlier fixed-candidate check
- [x] Routed benchmark gate passed end to end
  - Run: `results/benchmarks/qdesn_synth/qdesn_synth_check_ridge_routed__20260309-151602__git-2eb8111`
  - `tourism_monthly / T1` ran with the medium ridge route
  - `m4_monthly / M6336` ran with the short ridge route
  - `qdesn_synth` now completed successfully on both benchmark datasets
  - M4 check result is strong on the pinned short series: `OWA = 0.2835`
- [x] Added the next routed dev config at `config/benchmarks/qdesn_synth_dev_ridge_routed.yaml`
  - Short route checked on `tourism_monthly / T146` and `m4_monthly / M6336`
  - Medium route checked on `tourism_monthly / T109` and `m4_monthly / M23845`
  - This is the next phase before reopening any larger benchmark pool
- [x] Routed dev stage passed end to end
  - Run: `results/benchmarks/qdesn_synth/qdesn_synth_dev_ridge_routed__20260309-152253__git-2eb8111`
  - `qdesn_synth` completed successfully on all four pinned route/dataset cases
  - Tourism aggregate over short+medium pins: CRPS `166.72`
  - M4 aggregate over short+medium pins: CRPS `1177.41`, OWA `0.4260`
  - The short/medium routed family is now benchmark-viable at the pinned dev scale
- [x] Added a broader monthly routed benchmark config at `config/benchmarks/qdesn_synth_monthly_ridge_routed.yaml`
  - Monthly-only on purpose: `tourism_monthly`, `cif_2016_monthly`, `m4_monthly`
  - Explicit deterministic pins cover short, medium, and long where available
  - Uses the routed ridge family validated in the previous `check` and `dev` phases
- [x] Broader monthly routed benchmark completed end to end
  - Run: `results/benchmarks/qdesn_synth/qdesn_synth_monthly_ridge_routed__20260309-153816__git-2eb8111`
  - `qdesn_synth` completed on all 12 pinned monthly series across tourism, CIF 2016, and M4
  - Route coverage:
    - tourism: short + medium
    - CIF 2016: short + medium
    - M4 monthly: short + medium + long
  - Aggregate results:
    - `tourism_monthly`: CRPS `1558.41`
    - `cif_2016_monthly`: CRPS `1888532.06`
    - `m4_monthly`: CRPS `473.75`, OWA `1.0738`
  - Main new risk is no longer collapse or route applicability; it is forecast sharpness / calibration on broader monthly slices
- [x] Calibration-focused monthly reruns completed and were worse than the uncalibrated baseline
  - Bias run: `results/benchmarks/qdesn_synth/qdesn_synth_monthly_ridge_bias__20260309-162248__git-2eb8111`
  - Affine run: `results/benchmarks/qdesn_synth/qdesn_synth_monthly_ridge_affine__20260309-171539__git-2eb8111`
  - Outcome:
    - `tourism_monthly`: `none` beat both `bias` and `affine`
    - `m4_monthly`: `none` beat both `bias` and `affine` on CRPS and OWA
    - `cif_2016_monthly`: `bias` and `affine` both degraded sharply and failed on medium-route series
  - Current conclusion: keep `calibration.mode = none` for the routed ridge family
- [x] Re-pointed the forward routed benchmark path back to RHS
  - User preference and modeling intent are explicit: routed benchmark configs should not default to ridge
  - Added forward-path RHS configs:
    - `config/benchmarks/qdesn_synth_check_rhs_routed.yaml`
    - `config/benchmarks/qdesn_synth_dev_rhs_routed.yaml`
    - `config/benchmarks/qdesn_synth_monthly_rhs_routed.yaml`
  - These keep the routed DESN geometry from the benchmark-safe family, but switch the readout prior back to `rhs`
  - Active RHS controls in the new routed configs:
    - `tau0 = 100`
    - `s2 = 1`
    - `init_log_tau = 2.302585093`
    - `freeze_tau_iters = 50`
    - `freeze_tau_warmup_iters = 50`
    - `calibration.mode = none`
  - `scripts/benchmark_qdesn_sequence.sh` now treats these RHS-routed configs as the forward `check`, `dev`, and `monthly` path
  - Ridge configs remain in the repo only as archived comparison baselines, not as the default modeling direction
- [x] Expanded the forward RHS-routed candidate family so the prior is used in a meaningfully larger coefficient regime
  - Medium/long route now includes both `n = 128` and `n = 256` RHS candidates
  - Short route now includes both `n = 32` and `n = 64` RHS candidates
  - The intention is explicit: benchmark-side RHS evaluation should not be judged only on tiny readout geometries that make aggressive shrinkage less informative
- [x] First widened RHS gate landed and showed the next refinement target clearly
  - Run: `results/benchmarks/qdesn_synth/qdesn_synth_check_rhs_routed__20260309-190233__git-39c0cf7`
  - `tourism_monthly` medium route failed before the gate could proceed to M4
  - `n = 256` dramatically improved raw validation CRPS relative to `n = 128`, but still failed because the shoulder/interior band collapsed under RHS
  - Next step is a targeted `n = 256` medium-route RHS refinement, varying `tau0` plus tau freeze/warmup
- [x] Added targeted tourism medium-route RHS refinement config
  - Config: `config/benchmarks/qdesn_synth_tourism_one_step_medium_n256_rhs_refine.yaml`
  - Fixed geometry: `n = 256`, `m = 36`, `rho = 0.90`, `alpha = 0.05`, `pi_in = 0.02`, `pi_w = 0.005`, `washout = 96`
  - Variations:
    - `tau0 = 100, 150, 250`
    - higher freeze/warmup at `100` and `150` iterations for the stronger `tau0` settings
  - Goal: reduce or eliminate shoulder/interior collapse without returning to scale explosion

### 13.4 Audit risks to watch

- [ ] Confirm no future information enters reservoir/state construction during benchmark forecasting
- [ ] Confirm scaling is fit only on allowed training data
- [ ] Confirm long-horizon forecast generation respects benchmark horizon exactly
- [ ] Confirm large M4 runs do not store impractically large draw artifacts
- [ ] Confirm per-dataset tuning subsets are deterministic and recorded

### 13.5 Remaining research-facing work

- [ ] Add richer same-series model comparison plots for audit subsets
- [ ] Freeze the final publishable candidate family after broader runs
- [ ] Decide whether final claims are dataset-level tuned or frequency-level tuned
- [ ] Run the uncapped research protocol on a longer compute budget
- [ ] Review whether additional distributional recalibration layers are justified

## 14) Suggested end-state commands

Target user-facing workflow:

```bash
Rscript --vanilla scripts/benchmark_qdesn_run.R --config config/benchmarks/qdesn_synth_pilot.yaml
Rscript --vanilla scripts/benchmark_qdesn_run.R --config config/benchmarks/qdesn_synth.yaml
Rscript --vanilla scripts/benchmark_qdesn_report.R --run_dir results/benchmarks/qdesn_synth/<experiment_name>
```

The first config should be a small pilot to validate correctness.
The second is the uncapped research protocol and should be run on a longer
compute budget than the pilot.

## 15) Bottom line

The repo now has the benchmark evaluation layer needed to study the current
Q-DESN approach carefully.

The main work left is now split into two branches:

- benchmark promotion of the first viable ridge-readout candidate, and
- route-aware promotion of the short/medium ridge family into broader benchmark runs, and
- if that candidate fails on M4 or wider validation, direct readout-side
  model work rather than more broad DESN/RHS searching.

The current next gate is:

- run `config/benchmarks/qdesn_synth_m4_one_step_ridge_full_ladder.yaml`
- if M4 also stays non-collapsing and well-scaled, reopen a fixed-candidate benchmark gate via `config/benchmarks/qdesn_synth_check_ridge.yaml`
- if M4 fails badly, stop benchmark expansion and keep iterating at the
  readout gate

The current next gate is now:

- promote the routed ridge family beyond the pinned dev set
- either by building `qdesn_synth_full_ridge_routed.yaml` or by replacing the
  current broad `qdesn_synth.yaml` candidate family with the routed ridge
  family before a longer benchmark run

Calibration is no longer the next tuning lever for this family. The evidence
now points back to improving the core routed readout/forecast family itself if
broader monthly performance is still insufficient.

The remaining broader work is no longer infrastructure. It is research protocol
hardening:

- enriching and freezing the final candidate family,
- running broader benchmarks on a larger compute budget,
- and improving the synthesized forecast where the benchmark now shows clear
  weaknesses.
