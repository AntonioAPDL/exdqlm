# PLAN: QDESN Dynamic Effective-W300 Deep-DESN Full Rerun

Date: 2026-04-08  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Run a new full dynamic effective-w300 validation campaign under a richer shared DESN specification,
applied uniformly to every in-scope case, while preserving the current effective-w300 zero-FAIL
baseline as the prior authoritative source of truth.

This phase changes the **DESN architecture only**. It does not change:

- the effective sample-size contract,
- the post-washout source totals,
- the prior set,
- the likelihood set,
- the inference methods, or
- the posterior-metric evaluation layer.

## 2) Source Baseline Being Superseded For Testing

Current authoritative baseline before this rerun:

- report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_outputs_20260408.md`
- authoritative comparison pack:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5`
- rolled state:
  - `144` fit rows
  - `68 PASS`
  - `76 WARN`
  - `0 FAIL`
  - `36/36` comparison-eligible-full

This baseline remains authoritative until the new DESN rerun completes and is evaluated.

## 3) New DESN Spec

Requested shared DESN specification for every case:

- `D = 3`
- `n = [100, 100, 100]`
- `n_tilde = [100, 100]`
- `m = 30`
- `alpha = [0.2, 0.2, 0.2]`
- `rho = [0.95, 0.95, 0.95]`
- `act_f = [tanh, tanh, tanh]`
- `act_k = [identity, identity, identity]`
- `pi_w = [0.1, 0.1, 0.1]`
- `pi_in = [1.0, 1.0, 1.0]`
- `washout = 300`

Checked-in reservoir profile name:

- `deep_d3_n100x3_skip100_w300_m30`

## 4) Scope

The rerun keeps the same dynamic effective-w300 case lattice:

- scenario:
  - `dlm_constV_smallW`
- families:
  - `gausmix`, `laplace`, `normal`
- taus:
  - `0.05`, `0.25`, `0.95`
- effective fit sizes:
  - `500`, `5000`
- priors:
  - `ridge`, `rhs_ns`
- methods:
  - `vb`, `mcmc`
- likelihoods:
  - `al`, `exal`

Expected run size:

- `36` roots
- `144` fit rows

## 5) Contract Being Preserved

The new architecture rerun preserves the effective-w300 study contract:

- effective fit sizes:
  - `500`
  - `5000`
- source totals:
  - `813`
  - `5313`
- shared MCMC depth:
  - burn-in `1000`
  - kept iterations `2000`
- posterior metric draw budget:
  - `1000`

Important note:

- increasing `m` from `4` to `30` does **not** require a new source-total contract here because
  `washout = 300` remains the active drop bottleneck (`max(m, washout) = 300`).

## 6) Implementation Assets

New defaults and wrappers:

- defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_defaults.yaml`
- checked-in grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.csv`
- materializer:
  - `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.R`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation.R`
- launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation.R`

## 7) Validation And Launch Procedure

Required gating sequence:

1. materialize and check in the canonical `36`-root grid for the new DESN profile,
2. run `prepare-only` on the full batch,
3. if the setup is still clean, launch the full rerun from committed state,
4. monitor the run with the dedicated deep-DESN healthcheck wrapper,
5. regenerate comparison outputs only after the full rerun settles.

## 8) Primary Comparison Questions

This rerun is meant to answer:

1. does the richer shared DESN reduce or increase overall `PASS/WARN/FAIL` quality?
2. does it shift the stability-vs-fit tradeoff across `vb/mcmc`, `al/exal`, and `ridge/rhs_ns`?
3. does it improve difficult slices without requiring the local repair ladder used in the prior
   zero-FAIL effective-w300 reconciliation?

## 9) Reproducibility Rule

This rerun should be treated as a separate architecture experiment:

- do not overwrite the prior effective-w300 zero-FAIL source;
- keep the new campaign in its own results/report roots;
- only promote it if its completed evidence clearly improves on the current authoritative baseline.
