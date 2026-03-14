# TRACK: Q-DESN MCMC Validation Framework

Date: 2026-03-14
Branch: `feature/qdesn-mcmc-alternative`
Status: phase-0 pilot framework implemented on this branch; the two-root pilot campaign is ready to run
Purpose: define the first robust, expandable validation framework for Q-DESN
`vb` versus `mcmc` using a single toy scenario and a single-core root design
that can scale later without changing the core contract

## 0) Goal

Build a validation framework for Q-DESN inference that is:

- rigorous enough to validate the implementation, not just run smoke tests;
- minimal enough to debug quickly in the first pilot;
- structured so the same core runner can later expand over scenarios, taus,
  seeds, and datasets without redesign;
- directly comparable across `vb` and `mcmc` because both methods run on the
  same exact root with the same data split, same reservoir seed, and same prior
  family;
- explicit about numerical health, forecast quality, and runtime.

This framework is not a benchmark framework. It is a validation framework for
algorithm correctness, stability, and controlled method comparison.

## 0.1) Implemented State On 2026-03-14

The following pieces are now implemented on this branch:

- validation defaults and pilot grid:
  - `config/validation/qdesn_mcmc_pilot_defaults.yaml`
  - `config/validation/qdesn_mcmc_pilot_grid.csv`
- package-side validation helpers in:
  - `R/qdesn_mcmc_validation.R`
- CLI wrappers in:
  - `scripts/generate_qdesn_toy_validation_case.R`
  - `scripts/run_qdesn_mcmc_validation_root.R`
  - `scripts/run_qdesn_mcmc_validation_campaign.R`
  - `scripts/collect_qdesn_mcmc_validation_reports.R`
- focused regression coverage in:
  - `tests/testthat/test-qdesn-mcmc-validation-pilot.R`

The implemented framework now:

- generates the pilot toy series under a fixed scenario/seed contract;
- runs `vb` then `mcmc` inside the same root;
- writes root manifests, method manifests, timing summaries, health summaries,
  progress traces, MCMC chain summaries, and method-comparison tables;
- creates comparison plots for series, forecast behavior, runtime, scores, and
  algorithm progress;
- collects campaign-level summaries and plots across roots.

RHS VB stabilization note:

- the shared VB RHS path was corrected after the first pilot exposed a false
  collapse mode;
- the main fixes were:
  - preserve `init_log_tau = null` through the shared inference-config merge,
    so RHS can start at `tau0` instead of being silently reset to `tau = 1`;
  - preserve `freeze_tau_iters` and `freeze_tau_warmup_iters` as separate
    controls in the shared VB path;
  - initialize the `(eta, ell)` covariance for `q(sigma, gamma)` with a tiny
    matrix, matching the stable static core, instead of a diffuse
    `diag(1e-2)`;
  - fall back from invalid delta-corrected `xi` bundles to a damped or
    point-moment bundle when the delta approximation leaves the admissible
    domain.

Operational note:

- the first no-plots pilot campaign has already completed successfully with
  `2 / 2` successful roots;
- the plots-enabled pilot rerun is the current live background execution.

## 1) Design Principles

The validation framework should follow the same strengths as the more mature
validation work on `origin/jaguir26/dqlm-conjugacy-cavi-gibbs`:

- one root-centered execution contract;
- one machine-readable grid;
- one human-readable tracker;
- one root runner that owns all compute for a case;
- one collector that merges reports into cross-root comparison tables;
- one stable artifact schema per root.

For Q-DESN, each validation root should hold everything fixed except the
inference backend:

- same toy data;
- same split;
- same quantile level;
- same reservoir profile;
- same random seed;
- same beta-prior family;
- run `vb` and `mcmc` inside the same root.

That gives a cleaner comparison than separate pipelines for each method.

## 2) Phase-0 Pilot Scope

The first validation pass should intentionally stay tiny.

### Fixed pilot grid

- toy scenarios: `1`
- taus: `1`
- priors: `2`
  - `ridge`
  - `rhs`
- methods per root: `2`
  - `vb`
  - `mcmc`
- seeds: `1`
- reservoir profiles: `1`

### Proposed default pilot values

- toy scenario:
  - `toy_sine_small`
- tau:
  - `0.25`
- seed:
  - `123`
- reservoir profile:
  - `tiny_d1_n8`

### Effective pilot size

Because both inference methods run inside the same root, the root count is:

- `1 scenario x 1 tau x 2 priors x 1 seed x 1 reservoir = 2 roots`

The fit-task count inside those roots is:

- `2 roots x 2 methods = 4 fits`

This is intentionally small enough to debug the framework itself.

## 3) Pilot Toy Scenario

The pilot toy scenario should be simple, smooth, and interpretable while still
exercising the Q-DESN design and forecast path.

### Proposed scenario: `toy_sine_small`

Use a single synthetic series:

`y_t = 0.7 sin(2 pi t / 12) + e_t`

with

- `t = 1, ..., 96`
- `e_t ~ N(0, 0.12^2)`

Recommended split:

- `T_use = 96`
- `n_train = 78`
- `H_forecast = 18`

Why this is the recommended pilot:

- it is simple enough to debug visually;
- it contains real serial structure, unlike a purely constant series;
- it is much less pathological than an asymmetric or spiky scenario;
- it still exercises reservoir recursion, readout fitting, predictive draws,
  and forecast scoring.

### Why not start with a constant series

A near-constant series is useful later for intercept and shrinkage checks, but
it is not the best first full Q-DESN pilot because it under-exercises the
reservoir side and can make apparently good runs look trivial.

### Why `tau = 0.25`

`0.25` is a better first non-median validation point than `0.50` because:

- it still stays away from the extreme lower tail;
- it exercises quantile-specific inference more clearly than the median;
- it remains easier to stabilize than `0.05`.

Later expansion should add:

- `0.05`
- `0.50`

## 4) Fixed Reservoir Profile for the Pilot

The first pilot should freeze a single tiny DESN profile:

- `D = 1`
- `n = 8`
- `n_tilde = 0`
- `m = 4`
- `alpha = 0.2`
- `rho = 0.9`
- `washout = 4`
- `act_f = "tanh"`
- `act_k = "identity"`
- `pi_w = 0.15`
- `pi_in = 1.0`
- `add_bias = TRUE`
- DESN seed fixed at `123`

Reason:

- small enough for fast validation;
- large enough to exercise the design path;
- deterministic enough to keep `vb` versus `mcmc` comparisons clean.

## 5) Root Contract

Each root should correspond to one exact tuple:

- `scenario`
- `tau`
- `beta_prior_type`
- `seed`
- `reservoir_profile`

Inside that root, the runner should execute:

1. data generation
2. shared config build
3. `vb` fit
4. `mcmc` fit
5. score and diagnostics collection
6. within-root `vb` versus `mcmc` comparison
7. artifact writeout

This means the root is the unit of ownership, reproducibility, and comparison.

### Proposed root naming convention

For the pilot:

`scenario-toy_sine_small__tau-0p25__prior-ridge__seed-123__res-tiny_d1_n8`

and

`scenario-toy_sine_small__tau-0p25__prior-rhs__seed-123__res-tiny_d1_n8`

## 6) Proposed Artifact Schema Per Root

Every root should write the same minimal contract.

### Manifest

- `manifest/root_manifest.json`
- `manifest/root_status.txt`
- `manifest/runtime_summary.json`

### Config and data

- `config/root_config.json`
- `data/series.csv`
- `data/split_summary.csv`

### Method-specific fit outputs

- `fits/vb/fit_summary.json`
- `fits/vb/timing_summary.csv`
- `fits/vb/score_summary.csv`
- `fits/vb/health_summary.csv`
- `fits/vb/forecast_objects.rds`
- `fits/mcmc/fit_summary.json`
- `fits/mcmc/timing_summary.csv`
- `fits/mcmc/score_summary.csv`
- `fits/mcmc/health_summary.csv`
- `fits/mcmc/chain_summary.csv`
- `fits/mcmc/forecast_objects.rds`

### Root-level comparison outputs

- `tables/method_compare_summary.csv`
- `tables/method_compare_long.csv`
- `tables/root_summary.csv`

### Optional plots for the pilot

- `plots/series_overview.png`
- `plots/forecast_compare.png`
- `plots/mcmc_trace_gamma.png`
- `plots/mcmc_trace_sigma.png`
- `plots/mcmc_beta_norm.png`

The framework should not depend on plots for correctness. Plots are support
artifacts, not the primary contract.

## 7) Evaluation Dimensions

The pilot should judge success on four separate axes.

### 7.1 Execution health

Questions:

- did the root finish?
- did both methods finish?
- were all required artifacts written?

Minimum pass:

- root status is `SUCCESS`
- both method statuses are `SUCCESS`
- all required summary files exist

### 7.2 Numerical health

Questions:

- are `beta`, `sigma`, `gamma`, forecasts, and scores finite?
- are all constrained parameters inside domain?
- did either method collapse to obviously degenerate behavior?

Minimum pass:

- no non-finite stored scalar summaries
- no parameter-domain violations
- no empty draw objects
- no obviously exploded score tables

### 7.3 Forecast and fit quality

Questions:

- do both methods produce sane predictive summaries?
- are forecast scores finite and comparable?
- do forecast paths look consistent with the toy signal?

Required recorded metrics:

- pinball loss
- CRPS
- `S` score if available in the current pipeline
- train versus forecast split summaries

The pilot is not trying to prove MCMC superiority. It is trying to verify that
both methods produce sane, comparable outputs under the same controlled root.

### 7.4 Runtime and efficiency

Questions:

- what is total wall time per method?
- what are the dominant timed stages?
- how much slower is `mcmc` than `vb` on the same root?

Required recorded metrics:

- total wall seconds
- per-stage timed breakdown
- `mcmc / vb` runtime ratio

## 8) MCMC-Specific Diagnostics for the Pilot

The pilot uses one seed and should stay operationally simple. That means
multi-chain diagnostics such as `R-hat` are not required in phase 0.

Instead, the first pilot should record:

- kept draws count
- burn-in count
- thinning
- acceptance or slice-step summaries where available
- effective sample size summaries for core stored scalars where available
- lag-1 autocorrelation summaries for `gamma`, `sigma`, and a simple beta norm
- chain range and finiteness checks

The goal is not to certify asymptotic MCMC quality in the pilot. The goal is to
catch obviously broken or unusable sampler behavior.

## 9) Single-Core Execution Policy

The pilot should run with one owned core per root and thread caps set to one:

- `OMP_NUM_THREADS = 1`
- `OPENBLAS_NUM_THREADS = 1`
- `MKL_NUM_THREADS = 1`

Reason:

- timing becomes more interpretable;
- method comparisons become cleaner;
- debugging is easier;
- the campaign can scale later by running more roots, not by adding threads
  inside one root.

## 10) Proposed Implementation Layout

This section describes the planned layout only. It is not an implementation
commitment yet.

### Proposed config and manifests

- `config/validation/qdesn_mcmc_pilot_grid.csv`
- `config/validation/qdesn_mcmc_pilot_defaults.yaml`

### Proposed scripts

- `scripts/generate_qdesn_toy_validation_case.R`
- `scripts/run_qdesn_mcmc_validation_root.R`
- `scripts/run_qdesn_mcmc_validation_campaign.R`
- `scripts/collect_qdesn_mcmc_validation_reports.R`

### Proposed package helpers

- root-config resolver
- toy-scenario generator
- method-comparison summarizer
- root-summary collector

### Proposed tests

- `tests/testthat/test-qdesn-mcmc-validation-pilot.R`

## 11) Pilot Execution Order

The implementation should be built in this order:

1. toy-scenario generator
2. root manifest/config builder
3. root runner for one prior and one method
4. root runner extended to `vb -> mcmc`
5. root-level comparison writer
6. campaign grid runner
7. collector and merged summaries
8. validation tests

This order is intentional. The framework should prove one root first before it
tries to manage a campaign.

## 12) Acceptance Criteria For Phase-0 Pilot

Phase 0 should be considered complete only if all of the following are true:

1. The pilot grid runs end to end with exactly `2` completed roots.
2. Each root successfully produces both a `vb` fit and an `mcmc` fit.
3. Each root produces the required manifest, timing, score, and comparison
   outputs.
4. All recorded scores and stored scalar diagnostics are finite.
5. The root-level comparison tables clearly show:
   - method
   - prior
   - tau
   - runtime
   - score summaries
   - health flags
6. The pilot is easy to rerun from a single command without manual editing.
7. The framework is parameterized so new scenarios, taus, and seeds can be
   added through the grid rather than by changing the runner code.

## 13) Planned Expansion After Phase 0

Only after the pilot is stable should the framework expand in this order:

### Phase 1 expansion

- add taus:
  - `0.05`
  - `0.50`

### Phase 2 expansion

- add toy scenarios:
  - `const_small`
  - `sin_asym_small`
  - `level_shift_small`
  - `cos_spike_small`

### Phase 3 expansion

- add multiple seeds

### Phase 4 expansion

- add micro real-data validation roots

The framework should never need a redesign for these expansions. Only the grid
should grow.

## 14) Immediate Next Actions After Approval

If this plan is approved, the next implementation step should be:

1. create the pilot tracker/grid files;
2. implement the toy-scenario generator;
3. implement the one-root runner with fixed artifacts;
4. make the root runner execute `vb` then `mcmc` for the same root;
5. add the first collector and pilot regression test.

## 15) Open Defaults To Confirm Before Coding

These are the recommended defaults for the first implementation pass:

- scenario:
  - `toy_sine_small`
- tau:
  - `0.25`
- seed:
  - `123`
- reservoir:
  - `tiny_d1_n8`
- single-core execution:
  - `yes`
- run both methods in one root:
  - `yes`

If any of these defaults should change, the framework design still stands. Only
the pilot grid contents need to change.
