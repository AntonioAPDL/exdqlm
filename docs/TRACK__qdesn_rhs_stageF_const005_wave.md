# TRACK: QDESN RHS Stage-F Const(0.05) Drift Rescue

Date: 2026-03-22  
Branch: `feature/qdesn-mcmc-alternative`  
Scope: simulation/validation only (non-DLM; guardrails on)

## Trigger

From drift-rescue wave `20260321-195253__git-88c0369`:

- Stage D passed.
- Stage E failed gate with one remaining blocker:
  - `scenario=const_small`
  - `tau=0.05`
  - `beta_prior_type=rhs`
  - `mcmc_signoff_reason=geweke_drift`

## Stage-F objective

Run a focused profile matrix on that single failing root, select a winner, then
run broader 8-root reconfirmation with the winner.

## Inputs

- rescue manifest:
  - `config/validation/qdesn_rhs_stageF_const005_manifest.yaml`
- targeted root grid:
  - `config/validation/qdesn_rhs_stageF_const005_target_grid.csv`
- profile matrix:
  - `config/validation/qdesn_rhs_stageF_const005_profiles.yaml`
- broader grid:
  - `config/validation/qdesn_mcmc_multichain_rhs_broader_confirmation_grid.csv`

## Launch

```bash
Rscript scripts/run_qdesn_rhs_guardrail_steps_1_to_5.R \
  --rescue-manifest config/validation/qdesn_rhs_stageF_const005_manifest.yaml \
  --target-grid config/validation/qdesn_rhs_stageF_const005_target_grid.csv \
  --profiles config/validation/qdesn_rhs_stageF_const005_profiles.yaml \
  --no-plots
```

## Promotion gate

Promote only if broader reconfirmation has:

- `n_pair_fail = 0`
- `n_pair_eligible = n_pairs`
- no `rhs_trace_unavailable` signs
