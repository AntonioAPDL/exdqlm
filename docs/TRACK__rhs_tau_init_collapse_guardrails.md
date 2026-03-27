# RHS Tau-Init Collapse Guardrails (Benchmarking + Simulation)

## Why this reminder exists

We observed a reproducible intercept-only collapse in VB-RHS QDESN runs after inference config centralization.
The trigger was an initialization semantic change: `init_log_tau: null` started propagating as literal `NULL`,
which initialized `tau` at `tau0` (very small in our defaults), causing extreme shrinkage.

## Root-cause summary

1. Legacy behavior (pre-online/pre-benchmark fit path): `init_log_tau` effectively defaulted to `0.0` (so `tau=1` at init), even if YAML had `null`.
2. New centralized resolver path preserved nullable init keys and allowed `NULL` to override stable defaults.
3. With `tau0=0.001`, this produced `tau` initialization at `0.001`, then practical intercept-only fits.

## Required invariants for future runs

1. `init_log_tau` default must be treated as `0.0` unless explicitly overridden by a numeric value.
2. Explicit YAML `null` for init fields must behave as "unset", not as "force NULL".
3. Collapse monitoring must include a shrinkage-mode detector, not only near-lower-bound tau checks.

## Current implementation anchors

1. `R/exal_inference_config.R`
   - `.exal_default_rhs_cfg()` defaults `init_log_tau = 0.0`
   - `.exal_resolve_beta_prior_settings()` restores default init values when nullable keys are explicitly `NULL`
2. `R/exal_ldvb_engine.R`
   - periodic `RHS_MONITOR` now reports `beta_small_frac_1e4`
   - `RHS_MONITOR` prints `collapse_flag_bound`, `collapse_flag_shrink`, and combined `collapse_flag`
3. `scripts/pipeline_sim_main.R`
   - RHS preflight line logs:
     - `beta_prior_type`
     - `tau0`
     - resolved `init_log_tau`
     - `eta_bounds$tau`
   - for VB+RHS runs, `rhs_trace` is force-enabled to guarantee collapse monitoring persistence
   - `rhs_run_summary.csv` now reports:
     - `beta_small_frac_1e4_last`
     - `collapse_flag_bound`
     - `collapse_flag_shrink`
     - `collapse_flag` (combined)
     - `unhealthy_flag`
     - `unhealthy_reason`
     - `root_cause_context`
4. `tests/testthat/test-exal-inference-config.R`
   - regression tests for `NULL` fallback, explicit numeric override, and non-numeric fallback warning behavior
5. `R/pipeline_inference_validation.R` + `R/qdesn_mcmc_validation.R`
   - run summaries ingest `rhs_run_summary.csv`
   - shrinkage-collapse is promoted to method-level `unhealthy` with root-cause context
   - signoff pipelines fail unhealthy runs instead of treating them as healthy-successful fits

## Operational preflight for benchmarking/simulation

1. Confirm resolved config before long runs:
   - `init_log_tau` resolved numeric
   - `tau0` and RHS hyperparameters match intended experiment
2. During runs, monitor:
   - `tau`, `E_invV_med`, `beta_l2`, `beta_small_frac_1e4`
3. Early-stop unhealthy runs when:
   - `E_invV_med` is very high, `beta_l2` is very small, and `beta_small_frac_1e4` is near 1

## Guardrail permanence

These semantics are part of the default validation guardrails for benchmarking/simulation.
Do not change `init_log_tau` fallback/monitoring/unhealthy propagation behavior without explicit instruction and a tracker update in this file.

## Current operational default path (2026-03-23)

For post Stage-J/K/L validation relaunches, generate wave defaults by applying
the guardrail lock to the promoted base profile:

- base: `config/validation/qdesn_mcmc_compare_rhs_stageJKL_promoted.yaml`
- lock: `config/validation/qdesn_rhs_guardrail_lock.yaml`
- materialized output: `config/validation/qdesn_mcmc_compare_rhs_stageM_guardrailed.yaml`

This ensures all new Stage-M and follow-up simulation studies inherit the same
RHS init/collapse protections before any long campaign is launched.

## Codex handoff prompt (copy/paste template)

Use this prompt when asking Codex to run benchmarking/simulation work:

```text
You are working in this QDESN repository. Before any benchmarking or simulation run, enforce the RHS tau-init guardrails:

1) Resolve inference config and verify RHS init semantics:
   - init_log_tau must default to 0.0 unless a numeric override is provided.
   - YAML null init values must be treated as unset (fallback to defaults), not literal NULL.
2) Print preflight diagnostics for each run:
   - tau0, init_log_tau (resolved), eta_bounds$tau, beta prior type.
3) Monitor and persist collapse diagnostics:
   - tau, E_invV_med, beta_l2, beta_small_frac_1e4, collapse_flag_bound, collapse_flag_shrink, collapse_flag.
4) If shrinkage-collapse is detected (high E_invV_med + low beta_l2 + high beta_small_frac_1e4), flag run as unhealthy and report root-cause context.
5) Do not silently change these semantics; preserve this guardrail for all future benchmarking/simulation studies unless explicitly instructed.

Reference implementation anchors:
- R/exal_inference_config.R
- R/exal_ldvb_engine.R
- scripts/pipeline_sim_main.R
- tests/testthat/test-exal-inference-config.R
```
