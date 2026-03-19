# TRACK: Q-DESN MCMC Validation Framework

Date: 2026-03-19
Branch: `feature/qdesn-mcmc-alternative`
Status: const-`rhs_c2` wave completed and reconfirmed with `FAIL=0`; candidate defaults are frozen as `v1`; broader confirmation and healthy-only comparison runners are implemented
Purpose: define the first robust, expandable validation framework for Q-DESN
`vb` versus `mcmc` using a single toy scenario and a single-core root design
that can scale later without changing the core contract

## Latest Update (2026-03-19)

- Const `rhs_c2` targeted wave:
  - run: `rhs_const_c2_wave/20260318-182919__git-a034805__const-c2-wave`
  - phase-A winner: `B4` (`max_split_rhat=1.0286`, `winner_n_root_fail=0`)
  - phase-B reconfirm result: `PASS=2`, `WARN=0`, `FAIL=0`
  - provisional defaults promotion: `TRUE`
- Frozen defaults baseline:
  - candidate: `config/validation/qdesn_mcmc_compare_rhs_structural_reparam_constc2_candidate.yaml`
  - frozen v1: `config/validation/qdesn_mcmc_compare_rhs_structural_reparam_constc2_v1.yaml`
- Finalization bookkeeping:
  - `scripts/run_qdesn_mcmc_rhs_const_c2_wave.R` now writes
    `manifest/wave_completed.json` in addition to `wave_manifest.json`.
- YAML robustness:
  - promotion writers now sanitize YAML boolean-key coercion so reservoir
    width is persisted under `'n'` (not `'FALSE'`) in promoted defaults files.
- New move-forward runners:
  - broader RHS multichain confirmation:
    `scripts/run_qdesn_mcmc_rhs_constc2_broader_confirmation.R`
  - healthy-only VB vs MCMC comparison (runs campaign + healthy-filter summaries):
    `scripts/run_qdesn_mcmc_compare_healthy_only.R`
  - broader confirmation grid:
    `config/validation/qdesn_mcmc_multichain_rhs_broader_confirmation_grid.csv`

## Weekly Consolidated Status (Updated 2026-03-18 16:21 EDT)

This section is the canonical weekly status for the full validation program.

### Last-week milestone summary

- 2026-03-13:
  - initial Q-DESN `mcmc` integration landed;
  - inference dispatch and pipeline wiring for `vb`/`mcmc` became runnable from
    common entry points.
- 2026-03-14:
  - validation pilot and broader comparison framework landed;
  - signoff diagnostics were added;
  - tuned phase-1 validation defaults were introduced;
  - RHS-VB collapse fixes were integrated into the shared inference path.
- 2026-03-15:
  - RHS repair ladder, structural candidate promotion, and representative
    multichain confirmation flows landed;
  - targeted follow-up utilities for remaining RHS failures were added.
- 2026-03-16:
  - reparameterization gate workflow and follow-up phase scripts were added for
    transformed-parameter RHS analysis.
- 2026-03-17:
  - runtime-confound isolation wave landed;
  - phased RHS experiment matrix orchestrator and patch matrix (`E00..E13`)
    landed with tests.
- 2026-03-18:
  - failed-only repair relaunch was started from the completed matrix to rescue
    only the remaining `FAIL` roots.

### Canonical run state

- Matrix preflight:
  - `20260317-201834__git-15b388e__preflight`
  - completed as `dry_run=true` with `14` planned experiments.
- Full gated matrix:
  - `20260317-201850__git-15b388e__relaunch_full`
  - completed with `12/12` experiments;
  - phase winners:
    - phase 1: `E00`
    - phase 2: `E07`
    - phase 3: `E11`
    - phase 4: `SKIPPED_BY_TRIGGER`;
  - final winner:
    - `E11`
    - `max_split_rhat = 1.0347`
    - `min_ess_rhs = 130.76`.
- Failed-only repair relaunch (current active run):
  - `20260318-152303__git-15b388e__failed-repair`
  - targeted roots:
    - `level_shift_small | tau=0.25 | rhs`
    - `const_small | tau=0.05 | rhs`
  - live progress at this update:
    - first root started;
    - chain completions: `2/4` complete on first root;
    - second root pending.

### Current gate and decision rule

- Immediate objective:
  - eliminate remaining `FAIL` roots from the matrix carry-over set.
- Acceptable near-term state:
  - `PASS` or `WARN` is acceptable;
  - remaining `FAIL` is not acceptable.
- Next step after repair completion:
  - if both roots are `PASS/WARN`, close this repair wave and update candidate
    RHS defaults;
  - if any root stays `FAIL`, run a tightly scoped follow-up on only the
    unresolved root with one-factor kernel/warmup interventions.

### Post-repair escalation wave (const `rhs_c2`) on 2026-03-18

The failed-only continuation completed with one unresolved fail:

- `const_small | tau=0.05 | rhs`
- failure reason: `split_rhat_high` driven by `rhs_c2`.

To isolate this remaining issue without resetting broader progress, the next
wave is implemented as:

1. phase-A micro-matrix on const-only root
   - matrix config:
     - `config/validation/qdesn_mcmc_rhs_const_c2_matrix/matrix.yaml`
   - grid:
     - `config/validation/qdesn_mcmc_multichain_rhs_const_fail_grid.csv`
   - experiments:
     - `B0` control (`E07+E11` equivalent),
     - `B1`/`B2` narrowed `rhs_c2` and block widths,
     - `B3` coordinate global update,
     - `B4` long-chain stress with strong narrowing.
2. phase-B reconfirm on two roots
   - grid:
     - `config/validation/qdesn_mcmc_multichain_rhs_runtime_isolation_grid.csv`
3. provisional promotion gate
   - promote selected defaults only if reconfirm has `FAIL=0`;
   - otherwise keep defaults unchanged and escalate kernel changes.

End-to-end orchestrator:

- `scripts/run_qdesn_mcmc_rhs_const_c2_wave.R`

This preserves existing signoff thresholds and keeps all changes localized to
the unresolved `rhs_c2` geometry.

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

Current state note:

- the framework has now progressed beyond broad `vb` versus `mcmc` comparison;
- `vb` is stable enough to serve as the reference path;
- the remaining bottleneck is structural `rhs` MCMC behavior on a small
  persistent failed set;
- the current active work is the first structural repair on the transformed
  global RHS block.

Broader validation promotion note:

- the first structural RHS repair succeeded on the persistent failed set;
- it has now been promoted to a broader phase-1 toy-grid candidate profile;
- the next decision gate is:
  - broader structural candidate versus prior repaired baseline;
  - then representative RHS multichain confirmation if the broader candidate
    is strong enough.

Current promotion note:

- the broader structural candidate completed and passed the promotion gate;
- representative RHS multichain confirmation also completed and returned
  `representative_confirmation`;
- the blocked transformed global RHS update is now the working validation
  default for RHS MCMC;
- one representative failure remains:
  - `sin_asym_small | tau = 0.25 | rhs`
- the next work should therefore be targeted refinement on that remaining
  representative failure, not another broad validation redesign.

Current follow-up note:

- the targeted refinement on the remaining representative failure completed;
- `sin_asym_small | tau = 0.25 | rhs` was rescued from `FAIL` to `PASS` under
  a narrower `rhs_c2`/global-block follow-up setting;
- the next step is a small representative rerun with that `rhs_c2`
  stabilization folded in, to decide whether it should replace the current
  structural representative setting more broadly.

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
- broader comparison campaign defaults and grid:
  - `config/validation/qdesn_mcmc_compare_defaults.yaml`
  - `config/validation/qdesn_mcmc_compare_grid.csv`
- broader comparison runner:
  - `scripts/run_qdesn_mcmc_full_comparison.R`

The implemented framework now:

- generates the pilot toy series under a fixed scenario/seed contract;
- runs `vb` then `mcmc` inside the same root;
- writes root manifests, method manifests, timing summaries, health summaries,
  progress traces, MCMC chain summaries, and method-comparison tables;
- creates comparison plots for series, forecast behavior, runtime, scores, and
  algorithm progress;
- collects campaign-level summaries and plots across roots.
- collects campaign-level stage-timing, chain-diagnostic, grouped comparison,
  and markdown summary artifacts that scale past the pilot-only two-root case.

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
- the next active validation layer is the phase-1 broader toy comparison:
  - scenarios:
    - `toy_sine_small`
    - `const_small`
    - `sin_asym_small`
    - `level_shift_small`
  - taus:
    - `0.05`
    - `0.25`
    - `0.50`
  - priors:
    - `ridge`
    - `rhs`
  - seeds:
    - `123`
  - total roots:
    - `24`

## 0.2) Inference Signoff Layer Added On 2026-03-14

The validation framework now distinguishes three levels of fit quality:

- execution-healthy:
  the job finished with finite values and no domain violation;
- comparison-eligible:
  the fit passed a minimum inference-health gate and may be compared with
  caution;
- convergence-certified:
  the fit passed the stricter signoff gate and is suitable as a tuned baseline.

This was added because the phase-1 comparison run completed cleanly at the
pipeline level, but that alone is not enough to justify tuning decisions.

### Current signoff policy

For `vb`, signoff uses:

- `status`, finite checks, and domain checks;
- the package convergence flag;
- tail-window stabilization of:
  - `ELBO`
  - `gamma`
  - `sigma`
  - `beta_norm`
  - and, under `rhs`, the shrinkage traces `tau`, `c2`, and `lambda_mean`

For `mcmc`, signoff uses the current single-chain diagnostics:

- kept-draw count;
- effective sample size;
- lag-1 autocorrelation;
- Geweke absolute `z`;
- first-half versus second-half standardized drift.

This is intentionally high-standard for a single-chain phase. It is strong
enough to drive tuning, but it is still not the final multi-chain certification
step. In particular:

- split-`R-hat` is not used yet because the current validation campaign is
  intentionally single-core and single-chain;
- once the main tuning pass is complete, a reduced multi-chain validation layer
  should be added before any broader default claims are finalized.

### Baseline phase-1 signoff read

Using the completed untuned phase-1 baseline campaign:

- method signoff counts:
  - `vb`: `PASS = 8`, `WARN = 7`, `FAIL = 9`
  - `mcmc`: `PASS = 1`, `WARN = 5`, `FAIL = 18`
- method comparison-eligible rates:
  - `vb`: `0.625`
  - `mcmc`: `0.250`
- pair signoff counts:
  - `PASS = 1`, `WARN = 3`, `FAIL = 20`
- pair comparison-eligible rate:
  - `0.1667`

### Main current reading

- The baseline campaign is operationally healthy.
- The baseline campaign is not yet inference-certified as a full comparison
  baseline.
- `vb` is much closer to comparison-ready than `mcmc` on this current untuned
  grid, but it still has several tail-stability warnings and failures.
- The largest immediate tuning pressure is on MCMC mixing and chain length,
  especially for:
  - `rhs`
  - lower-tail runs
  - and a subset of ridge lower-tail cases
- The strongest current `vb` tuning pressure is:
  - increase the number of certified `PASS` cases without reintroducing RHS
    collapse;
  - reduce the number of stable-but-not-certified runs where the convergence
    flag remains false.

## 0.3) Tuned Phase-1 Validation Setup Added On 2026-03-14

The next validation layer is now wired for a controlled tuned rerun:

- tuned defaults:
  - `config/validation/qdesn_mcmc_compare_tuned_defaults.yaml`
- tuned preflight grid:
  - `config/validation/qdesn_mcmc_compare_preflight_grid.csv`
- tuned runners:
  - `scripts/run_qdesn_mcmc_tuned_preflight.R`
  - `scripts/run_qdesn_mcmc_tuned_phase1.R`
- baseline-vs-tuned comparison:
  - `R/qdesn_mcmc_validation_compare.R`
  - `scripts/compare_qdesn_mcmc_validation_campaigns.R`

The validation builder now also supports prior-specific inference overrides
inside the validation defaults so the tuned phase can use different settings
for:

- `vb.ridge`
- `vb.rhs`
- `mcmc.ridge`
- `mcmc.rhs`

without changing the grid, runner, or artifact schema.

### Tuned preflight result

The 4-root tuned preflight was completed on:

- `reports/qdesn_mcmc_validation/phase1_compare_tuned/20260314-181709__git-907d9fb`

Sentinel roots:

- `level_shift_small`, `tau=0.50`, `ridge`
- `const_small`, `tau=0.05`, `ridge`
- `toy_sine_small`, `tau=0.25`, `rhs`
- `const_small`, `tau=0.05`, `rhs`

Preflight read:

- root success:
  - `4 / 4`
- method signoff counts:
  - `vb`: `PASS = 2`, `WARN = 2`, `FAIL = 0`
  - `mcmc`: `PASS = 0`, `WARN = 3`, `FAIL = 1`
- pair signoff counts:
  - `WARN = 3`
  - `FAIL = 1`
- pair comparison-eligible rate:
  - `0.75`

Interpretation:

- the tuned ridge settings are strong enough to promote;
- the central RHS sentinel is now comparison-eligible;
- the hardest remaining failure is still the lower-tail RHS case
  `const_small | tau = 0.05 | rhs`, where tuned MCMC still fails the current
  signoff gate on chain drift;
- despite that remaining hard case, the tuned phase is strong enough to justify
  launching the full 24-root tuned campaign, because it is materially better
  than the untuned baseline on the sentinel set.

## 0.4) Full Tuned Phase-1 Result And Phase-2 Targets Added On 2026-03-14

The full tuned campaign completed on:

- `reports/qdesn_mcmc_validation/phase1_compare_tuned/20260314-183449__git-1ec79ff`

The baseline-vs-tuned comparison is recorded at:

- `reports/qdesn_mcmc_validation/phase1_compare_tuned_compare/20260314-183449__vs-baseline-b39220b`

### Full tuned outcome

- root success:
  - `24 / 24`
- execution failures:
  - `0`
- pair comparison-eligible groups:
  - baseline: `4`
  - tuned: `19`
- pair signoff-pass groups:
  - baseline: `1`
  - tuned: `3`
- pair eligibility gains:
  - `15 / 24`

### Main read from tuned-vs-baseline

- `vb.ridge` is stable enough to keep as-is for the next pass.
- `mcmc.ridge` improved enough that it should also remain stable for the next
  pass; only one ridge case still fails signoff and it is the lower-tail
  `level_shift_small` stress case.
- `vb.rhs` no longer shows collapse on this grid and now has:
  - `PASS = 6`
  - `WARN = 6`
  - `FAIL = 0`
  Most remaining RHS-VB warnings are `vb_converged_false` with stable tails,
  not numerical pathologies.
- `mcmc.rhs` is the dominant remaining tuning target. Under the tuned phase-1
  defaults it has:
  - `PASS = 0`
  - `WARN = 8`
  - `FAIL = 4`
  and the failure modes are now concentrated in:
  - `geweke_drift`
  - `half_chain_drift`
  rather than low ESS or obvious chain sticking.

### Why the next tuning should target RHS MCMC specifically

The tuned phase-1 run already moved RHS MCMC from broad ineligibility to broad
usability:

- all RHS MCMC fits executed successfully;
- `8 / 12` RHS MCMC roots are now comparison-eligible;
- the remaining failures are on a small subset of harder roots:
  - `const_small | tau = 0.25 | rhs`
  - `level_shift_small | tau = 0.05 | rhs`
  - `level_shift_small | tau = 0.25 | rhs`
  - `sin_asym_small | tau = 0.25 | rhs`

That pattern says the next pass should not change the ridge settings broadly.
It should focus on reducing post-burn drift in `mcmc.rhs`.

### Phase-2 default tuning targets

The next validation defaults are stored in:

- `config/validation/qdesn_mcmc_compare_phase2_defaults.yaml`

They intentionally keep the ridge and VB settings effectively stable while
making one targeted move on `mcmc.rhs`.

Keep stable:

- `vb.ridge`
  - `max_iter = 35`
  - `min_iter_elbo = 10`
  - `n_samp_xi = 64`
- `mcmc.ridge`
  - `n_burn = 300`
  - `n_mcmc = 600`
  - `width_gamma = 0.6`
  - `max_steps_out = 40`
  - `max_shrink = 150`
- `vb.rhs`
  - `max_iter = 60`
  - `min_iter_elbo = 12`
  - `n_samp_xi = 128`
  - `freeze_tau_iters = 10`
  - `freeze_tau_warmup_iters = 10`
  - `tau_local_tol = 5e-4`
  - `min_tau_updates = 2`

Targeted phase-2 change for `mcmc.rhs`:

- `n_burn = 800`
- `n_mcmc = 1600`
- `progress_every = 200`
- `width_gamma = 0.55`
- `width_rhs_lambda = 0.25`
- `width_rhs_tau = 0.15`
- `width_rhs_c2 = 0.25`
- `max_steps_out = 60`
- `max_shrink = 250`

Rationale:

- ESS is no longer the main blocker, so the next change needs more burn-in and
  more kept draws to stabilize half-chain and Geweke diagnostics.
- Narrower RHS slice widths target the remaining drift in:
  - `rhs_tau`
  - `rhs_c2`
  - and, secondarily, `rhs_lambda`
- `width_gamma` is only reduced slightly because the core chain diagnostics are
  materially healthier than the RHS-specific diagnostics.
- `progress_every = 200` reduces console overhead in the longer RHS runs
  without changing the inference target.

### Quality suggestions before running phase-2

- Keep the grid unchanged so phase-1 tuned vs phase-2 remains a clean
  comparison.
- Run a new 4-root RHS-heavy preflight before the next full 24-root campaign.
- Keep signoff thresholds fixed for the next pass. Changing the thresholds now
  would confound the tuning read.
- Do not thin the chains by default. The current issue is certification of
  mixing and stationarity, not storage pressure.
- After the next single-chain pass, run a small multichain confirmation on the
  hardest RHS roots to add `R-hat` before promoting any RHS-MCMC setting as a
  broader default.

## 0.5) RHS MCMC Repair Sub-Tracker Added On 2026-03-14

The current bottleneck is no longer the broad validation framework. It is the
hard-root repair path for `rhs` MCMC.

That work now has its own focused tracker:

- `docs/TRACK__qdesn_rhs_mcmc_repair_plan.md`

and its own machine-readable experiment matrix:

- `config/validation/qdesn_rhs_mcmc_repair_matrix.csv`

with the current executable support files:

- `config/validation/qdesn_rhs_primary_hard_grid.csv`
- `config/validation/qdesn_rhs_mcmc_repair_profiles.yaml`
- `R/qdesn_rhs_mcmc_repair.R`
- `scripts/run_qdesn_rhs_mcmc_repair_experiment.R`

Use those files for:

- the long-run diagnosis;
- the initialization-only study;
- the short `tau`-warmup study;
- the RHS slice-width study;
- and the structural fallback options such as reparameterization, blocked
  updates, alternate hyperparameter updates, and alternate RHS kernels.

## 0.6) RHS Repair Candidate Promotion Added On 2026-03-14

The hard-root RHS repair sequence completed on:

- `reports/qdesn_mcmc_validation/rhs_mcmc_repair_sequence/20260314-222329__git-0817936`

That sequence selected the current broader-validation candidate settings for
`rhs` MCMC:

- VB warm start:
  - `vb_rhs_stronger_tau40`
- MCMC tau warmup:
  - `freeze_tau_burnin_iters = 50`

Those settings are now promoted into a dedicated broader-validation defaults
file:

- `config/validation/qdesn_mcmc_compare_rhs_repair_defaults.yaml`

with dedicated wrappers:

- `scripts/run_qdesn_mcmc_rhs_repair_phase1.R`
- `scripts/compare_qdesn_mcmc_rhs_repair_phase1.R`

Purpose of this promotion step:

- keep the broader phase-1 toy grid fixed;
- keep signoff thresholds fixed;
- change only the repaired RHS-MCMC controls;
- compare the repaired candidate against the current tuned phase-1 baseline
  before any wider claims are made.

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

## 16) Added On 2026-03-15: Live Monitor And Multichain Follow-up

The repaired broader phase-1 campaign now has an automated follow-up layer:

- 10-minute live monitor:
  - `scripts/monitor_qdesn_mcmc_rhs_repair_phase1.R`
- automatic broader-run decision:
  - `R/qdesn_mcmc_followup.R`
- multichain follow-up runner:
  - `scripts/run_qdesn_mcmc_multichain_followup.R`
- representative multichain grid:
  - `config/validation/qdesn_mcmc_multichain_representative_grid.csv`

The current automation path is:

1. monitor the repaired broader phase-1 rerun every 10 minutes;
2. once complete, compare it against the tuned phase-1 baseline;
3. decide whether the next step should be:
   - representative multichain confirmation; or
   - targeted RHS-failure multichain triage;
4. launch that follow-up automatically.

The decision rule is intentionally conservative:

- use representative multichain confirmation only if the repaired candidate is
  at least as good as the tuned baseline on the main RHS eligibility/failure
  metrics while not materially regressing ridge;
- otherwise, isolate the persistent failed RHS roots first.

The multichain layer is reduced-scope by design. It is meant to answer whether
the remaining single-chain `WARN/FAIL` patterns are real stationarity problems
or artifacts of a single-chain signoff gate before we move to structural RHS
sampler changes.

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
