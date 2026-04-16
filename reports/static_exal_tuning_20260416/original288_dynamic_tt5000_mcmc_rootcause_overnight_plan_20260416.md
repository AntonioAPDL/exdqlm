# Dynamic TT5000 MCMC Root-Cause Overnight Plan

Date: 2026-04-16

## Why this lane exists

The current post-fix repair pocket has become informative:

- `VB` is now repeatedly healthy on completed `TT5000` cases
- `MCMC` is still failing at `iter=1`
- the current failures are **not** poor-mixing failures
- the current failures are now concentrated into a small set of numerical-startup signatures

There is also now a second, very important provenance finding:

- the current `phase1_dynamic_tt5000_exact_replay` manifest in the validation repo is
  missing `source_reference_fit_path`, `baseline_fit_path`, and the MCMC
  `vb_reference_fit_path` for all rows
- as a result, the current repair lane is not replaying from preserved historical
  selected fits; it is falling back to synthetic dynamic baselines whenever those
  sibling synthetic baselines exist or can be rebuilt

That means tonight's root-cause lane needs to answer **both** questions:

1. what is the numerical MCMC failure under the currently executing synthetic-baseline path
2. how much of the “why is this different now?” story is actually provenance drift rather
   than a new mathematical bug

That means the safest next move is **not** another broad relaunch. The right move
is a narrow, reproducible root-cause lane that isolates:

1. whether the remaining failure is caused by `VB` initialization
2. whether the remaining failure is caused by the `MCMC` state-sampling path itself
3. whether stronger covariance / `q` regularization removes the failure

## Main questions

1. Why does `VB` now complete while `MCMC` still fails?
2. Did the old `computationally singular` failure disappear and get replaced by a
   more localized `MCMC` invalid-state failure?
3. Does `MCMC` fail even when we bypass `VB` init?
4. Do stronger dynamic regularization floors remove the first invalid state?
5. Are the failures stable across families, or only in one pocket?

## Overnight matrix

### Failing MCMC anchors

- `dynamic::gausmix::0p05::5000::default::dqlm::mcmc`
- `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
- `dynamic::gausmix::0p95::5000::default::dqlm::mcmc`
- `dynamic::gausmix::0p95::5000::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::5000::default::dqlm::mcmc`
- `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
- `dynamic::normal::0p05::5000::default::dqlm::mcmc`
- `dynamic::normal::0p05::5000::default::exdqlm::mcmc`

### Healthy VB controls

- `dynamic::gausmix::0p05::5000::default::dqlm::vb`
- `dynamic::gausmix::0p05::5000::default::exdqlm::vb`
- `dynamic::laplace::0p05::5000::default::dqlm::vb`
- `dynamic::laplace::0p05::5000::default::exdqlm::vb`
- `dynamic::normal::0p05::5000::default::dqlm::vb`
- `dynamic::normal::0p05::5000::default::exdqlm::vb`

### Variants

For `MCMC` anchors:

- `exact_short`
  - preserve exact source semantics
  - override only to bounded debug budgets
- `no_vb_init_short`
  - force `init.from.vb = FALSE`
  - force `init.from.isvb = FALSE`
  - isolates whether failure depends on `VB` warm start
- `regfloor_short`
  - exact source semantics
  - stronger dynamic covariance / `q` floors
  - isolates whether remaining failure is primarily regularization-sensitive

For `VB` controls:

- `exact_short`

## Debug budgets

### MCMC

- `n.burn = 2`
- `n.mcmc = 1`
- `trace.every = 1`
- `progress_callback` enabled

This is deliberate: the current failures occur at `iter=1`, so longer chains do
not add value for root-cause isolation.

### VB

- `max_iter = 40`
- `n.samp = 300`

## Instrumentation

The package debug lane writes per-case dumps through:

- `EXDQLM_DEBUG_DIR`
- `EXDQLM_DEBUG_CASE`
- `EXDQLM_DEBUG_LABEL`

Dump points now include:

- non-finite covariance input
- `NA` scalar variance input
- non-finite / negative `chi`
- invalid GIG draws
- `dqlm_mcmc_pre_uts` invalid state
- `exdqlm_mcmc_pre_uts` invalid state

## Success criteria

This overnight lane is successful if it gives us at least one of these:

1. a clean proof that `no_vb_init_short` fixes the MCMC failures
2. a clean proof that `regfloor_short` fixes the MCMC failures
3. a stable first-invalid-state dump that localizes the failure to one exact
   object (`theta`, `reg1`, `st`, `u_t`, or `q_t`)
4. a proof that the failure pattern is family-specific rather than universal
5. a proof that the current failing lane is driven by synthetic-baseline replay drift,
   rather than by preserved historical reference fits

## Stop/go rule for the next repair wave

We only relaunch the broader dynamic `TT5000` repair wave if one of these is true:

- the root-cause lane identifies a stable fix or narrowed variant that succeeds
  on representative MCMC anchors
- or the root-cause lane proves the failure is only in one sharply bounded
  sub-pocket and we can rerun everything else safely

If none of those happen, the next move is **code-level debugging only**, not
another validation rerun.
