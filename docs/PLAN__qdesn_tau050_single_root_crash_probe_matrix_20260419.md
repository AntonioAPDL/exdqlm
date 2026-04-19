# QDESN Tau050 Single-Root Crash-Probe Matrix

Date: 2026-04-19

## Purpose

Before spending more time on broad crash-only reruns, isolate one genuinely
hard fit and run a small but information-dense matrix of inference specs against
that exact fit. The goal is not immediate throughput. The goal is to learn,
cleanly and cheaply, which levers actually change the latent-`v` crash
behavior.

This plan defines that single-root matrix.

## Why A Single-Root Matrix Is The Right Next Step

From the completed relaunch history:

- original failed-only rerun recovered only part of the `23` crash surface
- `sfreeze` improved that surface to `8 / 23` successful, but still left
  `15 / 23` hard failures
- the remaining hard failures are now much cleaner:
  - all are `fit_size = 5000`
  - most occur after thaw
  - the hard failure family is still the same latent-`v` invalid-draw crash
  - `rhs_ns` is weaker than `ridge`
  - `laplace` and `gausmix` remain the hardest interpretable pockets

That means the next best use of compute is not another broad wave. It is a
controlled probe on one hard fit where we can vary a small number of levers and
read the result clearly.

## Chosen Probe Fit

Primary probe fit:

- root:
  `root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_rhs_ns`
- method:
  `mcmc`
- likelihood:
  `exal`

Why this one:

1. it sits in the remaining hard-fail surface after `sfreeze`
2. it is long-window (`5000`), which is where the unresolved hard failures now
   live
3. it uses `rhs_ns`, the weaker prior pocket
4. it is `laplace / tau = 0.50`, which is a hard but still interpretable stress
   surface
5. `exal` remains the more problematic lane overall, so it is the best place to
   learn first

Secondary shadow comparator, only if needed later:

- same root cell but `ridge`
- same root cell but `al`

Those comparators should not be in the first matrix unless the primary probe
finishes too quickly or behaves unexpectedly.

## Questions This Matrix Must Answer

1. Is the remaining crash mainly improved by **theta freezing**?
2. Is **tau-only stabilization** already enough without extra latent-state
   controls?
3. Does **bounded latent-`v` rescue** convert hard crashes into completions on
   this root?
4. Is the new **GIG floor** a strong enough intervention by itself, or do we
   need a configurable stronger floor?
5. Does the fit fail during:
   - hard freeze
   - sparse window
   - post-thaw scheduled updates
6. If it still fails, does the failure timing or the `chi_v` / `psi_v` regime
   shift in a useful way?

## Fixed Factors

Across all arms:

- same source fit
- same lane: `mcmc_exal`
- same root ID
- same data
- same burn / keep budget:
  - `n_burn = 5000`
  - `n_mcmc = 20000`
  - `thin = 1`
- same worker policy:
  - `1` worker only
- same run-tag family and report/result root family
- same deterministic seed contract

The only things that should change across arms are the scheduler and rescue
controls we are explicitly testing.

## Experiment Arms

This is the recommended first-pass matrix.

### Group A: Warmup Structure

| Arm | Purpose | Tau freeze | Theta freeze | Latent `s` freeze | Latent `v` freeze | Rescue |
|---|---|---|---|---|---|---|
| `A1_tau_only` | clean baseline for “tau only” | yes | no | no | no | no |
| `A2_theta_tau` | current thetafreeze hypothesis | yes | yes | no | no | no |
| `A3_s_tau` | compare against previously better-performing `sfreeze` style | yes | no | yes | yes | no |

Read:

- `A1` tells us whether the extra theta logic is needed at all
- `A2` tests the current new hypothesis directly
- `A3` anchors against the previous best broad stabilization direction

### Group B: Rescue Structure

| Arm | Purpose | Warmup base | Rescue |
|---|---|---|---|
| `B1_tau_only_rescue` | can rescue alone save a tau-only lane? | `A1` | on |
| `B2_theta_tau_rescue` | does rescue materially improve thetafreeze? | `A2` | on |

Recommended bounded rescue spec:

- `rescue_on_invalid = true`
- `rescue_strategy = previous_state`
- `rescue_max_consecutive = 1`
- `rescue_burn_only = false`

If those fields are not yet exposed in the current config surface, add them
before launching the matrix.

### Group C: GIG-Floor Sensitivity

| Arm | Purpose | Warmup base | GIG floor |
|---|---|---|---|
| `C1_theta_tau_gig1e-10` | current hardened floor | `A2` | `1e-10` |
| `C2_theta_tau_gig1e-08` | test whether a stronger floor changes the regime | `A2` | `1e-8` |

This group is only worth running if we expose the GIG floor as a lane-level
control. Right now the floor is hardcoded in:

- [R/utils.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/utils.R)

So a configurable floor should be added before this group is run. If we do not
want to add that control yet, skip Group C in the first pass.

## Recommended First Pass

To stay efficient, do **not** run the full matrix immediately.

Run in this order:

1. `A1_tau_only`
2. `A2_theta_tau`
3. `A3_s_tau`

Then:

4. if all 3 still hard-crash in the same way, run `B2_theta_tau_rescue`
5. if the crash still looks unchanged, add `C2_theta_tau_gig1e-08`

That keeps the first pass to `3` runs, with `1–2` escalation runs only if
needed.

## Current Recommended Specs

### `A1_tau_only`

- VB:
  - `max_iter = 500`
  - `min_iter_elbo = 80`
  - keep current VB `sigmagam` warmup
  - explicitly keep VB tau freeze:
    - `freeze_tau_iters = 50`
    - `freeze_tau_warmup_iters = 50`
    - `force_tau_after_warmup = true`
- MCMC:
  - tau freeze:
    - `freeze_tau_burnin_iters = 500`
  - theta:
    - off
  - latent `v`:
    - off
  - latent `s`:
    - off
  - `sigmagam` freeze:
    - off
  - rescue:
    - off

### `A2_theta_tau`

- same as `A1`, plus:
  - theta enabled
  - `freeze_burnin_iters = 50`
  - `sparse_update_every = 10`
  - `sparse_update_until_iter = 500`
  - `force_first_postwarmup_update = true`

### `A3_s_tau`

- same strengthened tau baseline
- latent `v` and latent `s` enabled with:
  - `freeze_burnin_iters = 50`
  - `sparse_update_every = 10`
  - `sparse_update_until_iter = 500`
  - `force_first_postwarmup_update = true`
- theta off

### `B2_theta_tau_rescue`

- same as `A2`, plus bounded rescue:
  - `rescue_on_invalid = true`
  - `rescue_strategy = previous_state`
  - `rescue_max_consecutive = 1`
  - `rescue_burn_only = false`

## What To Record For Each Arm

For each single-root run, persist:

1. terminal status:
   - `SUCCESS`
   - `FAIL`
2. signoff:
   - `PASS`
   - `WARN`
   - `FAIL`
3. failure timing:
   - iteration
   - `burn` vs `keep`
4. scheduler state at failure:
   - tau frozen?
   - theta update reason
   - latent `s` update reason
   - latent `v` update reason
5. latent-`v` diagnostics:
   - `chi_v min / median / max`
   - `psi_v min / median / max`
   - rescue count
6. runtime:
   - wall time
   - whether run reaches keep phase

This is the minimum needed to make the next decision evidence-based.

## Wiring Plan

If we implement this matrix, keep it isolated in its own files.

Recommended new assets:

- defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_tau_only_defaults.yaml`
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_theta_tau_defaults.yaml`
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_stau_defaults.yaml`
  - optional rescue / gig-floor variants

- single-row grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_exal_laplace_tau050_rhsns_grid.csv`

- wrappers:
  - extend [launch wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
  - extend [healthcheck wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)

- docs:
  - implementation report
  - launch report
  - result comparison report

## Decision Rules After The Probe

### Promote Theta-Freeze

Promote thetafreeze to a larger relaunch only if:

- `A2_theta_tau` clearly outperforms `A1_tau_only`
- and either:
  - completes successfully
  - or shifts the failure materially later / softer
  - or enters keep phase where `A1` does not

### Promote Rescue

Promote rescue next if:

- `A2` still crashes hard
- but `B2_theta_tau_rescue` converts the crash into:
  - `SUCCESS`
  - or at least a repeated rescue pattern that carries the chain into keep

### Promote Stronger GIG Floor

Promote a stronger configurable floor only if:

- the same root still crashes under `A2` and `B2`
- and the failure payload still shows tiny positive `chi_v` right at the floor
  boundary

## Bottom Line

Yes, focusing on a single run first is the right move.

The best single-fit probe is:

- `mcmc_exal`
- `laplace`
- `tau = 0.50`
- `fit_size = 5000`
- `rhs_ns`

And the best first-pass matrix is:

1. `tau only`
2. `theta + tau`
3. `s + tau`

with bounded latent-`v` rescue and a stronger configurable GIG floor added only
if the first three runs do not separate cleanly.
