# TRACK: Q-DESN RHS MCMC Repair Plan

Date: 2026-03-14
Branch: `feature/qdesn-mcmc-alternative`
Status: experiment-design tracker with execution assets implemented
Purpose: isolate why `RHS MCMC` still fails inference signoff on a subset of
hard toy roots, and define an organized experiment ladder that can tell us
whether the issue is:

- short runs / insufficient burn-in;
- weak initialization;
- unstable early `tau` motion;
- poor slice-width settings;
- hard posterior geometry for the current sampler;
- or a deeper need for structural sampler changes.

This tracker is intentionally narrower than the general Q-DESN validation plan.
It is focused on repairing the `rhs` MCMC readout and deciding what class of
solution should be expanded.

## 0.1) Implemented Execution Assets

The following repair assets are now implemented on this branch:

- repair matrix:
  - `config/validation/qdesn_rhs_mcmc_repair_matrix.csv`
- repair root-set grid:
  - `config/validation/qdesn_rhs_primary_hard_grid.csv`
- repair profile library:
  - `config/validation/qdesn_rhs_mcmc_repair_profiles.yaml`
- package-side resolver:
  - `R/qdesn_rhs_mcmc_repair.R`
- CLI runner:
  - `scripts/run_qdesn_rhs_mcmc_repair_experiment.R`
- focused regression coverage:
  - `tests/testthat/test-qdesn-rhs-mcmc-repair.R`

The implemented resolver does three things:

- selects an experiment by `experiment_id` or `run_order`;
- materializes the exact validation defaults for that experiment while keeping
  the broader validation stack unchanged;
- rejects non-executable placeholder stages such as:
  - multichain stubs;
  - `best_from_B` profile dependencies;
  - and design-only rows in stage `E`.

This means stages `A` and `B` are directly executable now, while later stages
remain deliberately blocked until the earlier evidence determines the correct
branch to expand.

Current execution entry point:

```bash
Rscript scripts/run_qdesn_rhs_mcmc_repair_experiment.R --experiment-id A1_current_long --no-plots
```

## 0) Main Current Question

We need to answer:

> Is the remaining `rhs` MCMC issue mainly a run-length / warmup problem,
> or is the current sampler itself too inefficient for the hard RHS geometry?

This question matters because it changes the entire next move:

- if longer runs and better warmup solve the problem, then the kernel may be
  acceptable and the next work is tuning defaults;
- if they do not, then we should stop over-tuning runtime knobs and move to
  deeper sampler changes.

## 1) Current State

### 1.1 What is already healthy

- `vb.ridge`
  - operationally healthy and mostly certification-ready
- `vb.rhs`
  - collapse no longer appears on the current toy grid
  - remaining issues are mostly certification warnings such as
    `vb_converged_false`, not gross numerical breakdown
- `mcmc.ridge`
  - mostly usable on the current toy validation grid
- validation / reporting framework
  - working end to end
  - baseline, tuned, and comparison artifacts are now stable

### 1.2 What is still the bottleneck

- `mcmc.rhs`

Under the tuned phase-1 comparison:

- `PASS = 0`
- `WARN = 8`
- `FAIL = 4`

The remaining hard roots were:

- `const_small | tau = 0.25 | rhs`
- `level_shift_small | tau = 0.05 | rhs`
- `level_shift_small | tau = 0.25 | rhs`
- `sin_asym_small | tau = 0.25 | rhs`

### 1.3 What the failing diagnostics mean

The current failures are MCMC-side diagnostics:

- `geweke_drift`
- `half_chain_drift`

This means:

- the chain is often running and returning finite values;
- ESS is not the dominant failure mode anymore;
- the remaining issue is mostly lack of stationary-looking behavior over the
  kept samples.

That does **not** automatically mean the implementation is wrong.
It means the current chain is not yet convincing enough on the hard roots.

## 2) Main Working Hypotheses

We should proceed with explicit hypotheses rather than one giant tuning pass.

### H1) The problem is mostly weak initialization

If a stronger `init_from_vb` warm start fixes the hard roots, then:

- the current MCMC kernel may be acceptable;
- the starting state is the main issue;
- the next work is better warm-start defaults, not a new kernel.

### H2) The problem is mostly early global-shrinkage instability

If a short `tau` freeze during early MCMC burn-in improves the hard roots, then:

- early movement of `tau` is destabilizing the chain;
- a short warmup freeze is a realistic targeted fix.

Important:

- a realistic `tau` freeze warmup should be short;
- default candidate range should be around:
  - `0`
  - `10`
  - `20`
  - `50`

Large freezes such as `200+` are useful as stress tests only.

### H3) The current kernel is too slow for the hard RHS geometry

If only very long burn-in and very long kept runs help, then:

- the chain may be valid but inefficient;
- the default budgets are too short for this geometry;
- runtime-cost versus stability becomes the main tradeoff.

### H4) The current RHS sampler structure is the deeper problem

If even long runs, better init, and short `tau` warmup do not solve the hard
roots, then the issue is probably deeper:

- strong posterior dependence across `tau`, `lambda`, and `c2`;
- poor coordinate system for exploration;
- poor block structure in the sampler;
- or a kernel mismatch for the RHS block.

## 3) Current Evidence

### 3.1 Evidence that `init_from_vb` matters

In the current focused RHS work:

- stronger `vb` warm start already improved some hard roots before adding a
  serious MCMC `tau` freeze;
- specifically, `sin_asym_small | tau = 0.25 | rhs` improved from `FAIL` to
  `WARN` under the stronger warm-start-only case.

Interpretation:

- initialization clearly matters;
- it is not the whole story because `const_small | tau = 0.25 | rhs` still
  fails under warm-start-only.

### 3.2 Evidence that early `tau` handling matters

In the current short running sweep:

- `const_small | tau = 0.25 | rhs` improved from `FAIL` to `WARN` when moving
  from the stronger warm-start-only case to a `tau`-freeze case.

Interpretation:

- early `tau` motion is plausibly part of the failure mechanism;
- but we still need a realistic short-freeze study, not only very large
  freeze lengths.

### 3.3 Evidence against “ESS is the whole problem”

The tuned phase-1 and phase-2 diagnostics show:

- several failing RHS roots already have acceptable core ESS;
- the dominant failures are drift diagnostics, not just low ESS.

Interpretation:

- simply keeping more post-burn draws is unlikely to be a complete fix;
- the chain may still be moving too much across the kept window.

## 4) What We Are Trying To Decide

The main decision tree is:

1. Are stronger initialization and short `tau` warmup enough?
2. If not, are longer runs enough?
3. If not, do we need structural sampler changes?

This leads to a disciplined experiment ladder.

## 5) Experiment Ladder

Run these in order. Do not skip stages, because later stages only make sense
once the simpler explanations have been tested.

### Stage A) Long-run diagnostic baseline

Goal:

- answer whether the current kernel can eventually look healthy if given a much
  longer run.

What to vary:

- current tuned RHS MCMC kernel;
- long burn-in;
- long kept chain.

Interpretation:

- if long-run baseline becomes healthy:
  the kernel may simply be too slow for the current defaults;
- if it still fails:
  longer runs alone are not enough.

### Stage B) Initialization-only study

Goal:

- isolate whether a stronger `init_from_vb` warm start fixes the hard roots.

What to vary:

- `vb_warm_start_control`
- keep MCMC `tau` freeze at `0`

Interpretation:

- improvement here means initialization is a major driver;
- no improvement means look beyond the starting point.

### Stage C) Short `tau`-warmup study

Goal:

- test the concrete hypothesis that a short freeze of `tau` stabilizes the RHS
  chain before full updates begin.

What to vary:

- hold the best VB warm start fixed;
- vary MCMC `tau` freeze over:
  - `0`
  - `10`
  - `20`
  - `50`

Interpretation:

- improvement here supports a practical warmup-based fix;
- no improvement says the issue is not mainly early `tau` motion.

### Stage D) RHS slice-width study

Goal:

- test whether the current RHS slice geometry is still too aggressive or too
  unstable on the hard roots.

What to vary:

- `width_rhs_tau`
- `width_rhs_c2`
- secondarily `width_rhs_lambda`
- keep the best short warmup settings fixed.

Interpretation:

- if this helps, then the kernel is basically usable but needs local geometry
  tuning;
- if this does not help, consider structural changes.

### Stage E) Structural sampler alternatives

Goal:

- test whether the current coordinate-wise RHS block is the real bottleneck.

Only enter this stage if A-D do not solve the hard roots convincingly.

Structural options to consider:

- reparameterization;
- blocked updates;
- different hyperparameter sampling strategy;
- different MCMC kernel for the RHS block.

## 6) Hard-Root Set

Use this reduced set to make decisions before any broader rerun.

Primary hard roots:

- `const_small | tau = 0.25 | rhs`
- `sin_asym_small | tau = 0.25 | rhs`

Secondary hard roots / controls:

- `level_shift_small | tau = 0.25 | rhs`
- `level_shift_small | tau = 0.05 | rhs`

These are the right roots because they already showed the remaining RHS-MCMC
failure patterns under tuned phase-1 and phase-2.

## 7) Concrete Candidate Solutions To Test

### 7.1 Practical tuning solutions

These are the first-line candidates because they are cheap and easy to
interpret.

1. Stronger `init_from_vb`
2. Short MCMC `tau` freeze during burn-in
3. Longer burn-in
4. Longer kept chain
5. Narrower RHS slice widths
6. Delayed `tau` updates instead of a hard freeze

### 7.2 Structural solutions

These should be planned now, even if implemented only later.

#### A) Reparameterization

Possible directions:

- rescale or recenter the RHS state;
- non-centered or partially non-centered treatment of shrinkage parameters;
- alternate transform for the global-shrinkage block.

Why:

- if the current parameterization induces strong posterior dependence,
  univariate updates may remain slow regardless of budget tuning.

#### B) Blocked updates

Possible directions:

- blocked update of `(tau, c2)`;
- blocked update of `(tau, lambda_active)` subsets;
- structured partial block for the RHS hyperparameters.

Why:

- current failures may reflect strong coupling across `tau`, `c2`, and
  `lambda`.

#### C) Different hyperparameter sampling strategy

Possible directions:

- specialized sampler for `tau`;
- adaptive slice widths for RHS hyperparameters;
- MH on transformed joint blocks;
- mixture of slice and local proposal corrections.

Why:

- if `tau` is the main instability source, it may deserve a different update
  strategy than the current uniform slice treatment.

#### D) Different MCMC kernel for the RHS block

Possible directions:

- adaptive random-walk MH on transformed RHS blocks;
- blocked MH for the RHS hyperparameters;
- elliptical or other geometry-aware alternatives where defensible.

Why:

- if coordinate-wise slice does not mix well enough in the hard roots, then the
  kernel itself may need to change.

## 8) Exact Experiment Matrix

The machine-readable matrix lives in:

- `config/validation/qdesn_rhs_mcmc_repair_matrix.csv`

Use that file as the canonical experiment list. The stage numbers and run order
below are binding.

### 8.1 Exact profile definitions

The profile names used in the matrix mean the following.

#### `phase1_tuned_vb_rhs`

- `max_iter = 60`
- `min_iter_elbo = 12`
- `n_samp_xi = 128`
- `freeze_tau_iters = 10`
- `freeze_tau_warmup_iters = 10`
- `tau_local_tol = 5e-4`
- `min_tau_updates = 2`

#### `vb_rhs_stronger_tau20`

- `max_iter = 80`
- `min_iter_elbo = 12`
- `n_samp_xi = 200`
- `freeze_tau_iters = 20`
- `freeze_tau_warmup_iters = 20`
- `tau_local_tol = 5e-4`
- `min_tau_updates = 2`

#### `vb_rhs_stronger_tau40`

- `max_iter = 80`
- `min_iter_elbo = 12`
- `n_samp_xi = 200`
- `freeze_tau_iters = 40`
- `freeze_tau_warmup_iters = 40`
- `tau_local_tol = 5e-4`
- `min_tau_updates = 2`

#### Current phase-2 RHS MCMC baseline

- `n_burn = 800`
- `n_mcmc = 1600`
- `width_gamma = 0.55`
- `width_rhs_lambda = 0.25`
- `width_rhs_tau = 0.15`
- `width_rhs_c2 = 0.25`
- `max_steps_out = 60`
- `max_shrink = 250`
- `init_from_vb = TRUE`

#### Short tau-freeze candidates

These are the only realistic MCMC warmup candidates that should be treated as
default-quality options in the near term:

- `0`
- `10`
- `20`
- `50`

## 9) Run Order

Run in this exact order.

### Order 1: Long-run diagnosis

- `A1_current_long`
- `A2_current_long_multichain_stub`

Decision:

- if `A1` fails badly, continue to `B`;
- if `A1` passes cleanly, the kernel may just be slow and we should quantify
  runtime costs before deeper surgery.

### Order 2: Initialization study

- `B1_vbinit_stronger_short`
- `B2_vbinit_stronger_medium`

Decision:

- if either materially fixes the hard roots, initialization becomes the primary
  default-tuning lever.

### Order 3: Short tau-warmup study

- `C1_taufreeze_10`
- `C2_taufreeze_20`
- `C3_taufreeze_50`

Decision:

- if one of these is clearly better than `B`, adopt short tau warmup as the
  practical next direction.

### Order 4: Slice-width study

- `D1_tauc2_narrow`
- `D2_tauc2_lambda_narrow`

Decision:

- if this materially improves drift while keeping runtime moderate, stay in the
  current kernel family.

### Order 5: Structural study design

Do not implement immediately. Enter only if A-D fail to produce a convincing
RHS-MCMC path.

- `E1_reparam_design`
- `E2_blocked_tau_c2_design`
- `E3_rhs_kernel_redesign`

## 10) Acceptance Criteria

Promote a solution only if:

- it removes `FAIL` from the primary hard-root set, or nearly does so;
- it does not damage the already-healthy `vb` paths;
- it does not depend on unrealistic `tau` freezes such as hundreds of
  iterations;
- it does not require absurd runtime inflation relative to the value gained;
- it keeps the observed forecast behavior at least as good as the current
  tuned-phase runs.

## 11) Main Expected Outcomes

This repair plan should let us answer:

1. Is the current RHS MCMC kernel fundamentally viable?
2. Is initialization the main issue?
3. Is short `tau` warmup enough?
4. Is the current RHS block geometry too hard for coordinate-wise slice?
5. Which deeper structural alternative should be implemented if tuning is not
   enough?
