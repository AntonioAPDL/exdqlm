# RHS_NS Stage-8 Decision (2026-03-27)

## Scope

This note records the Stage-8 comparative decision for `rhs` vs `rhs_ns` on the
`feature/qdesn-mcmc-alternative` line.

Artifact used:

- `reports/rhs_ns_stage8_matrix_20260327_v4.csv`

Benchmark design:

- 3 synthetic seeds (`1101`, `2202`, `3303`)
- Methods: `vb`, `mcmc`
- Priors: `rhs`, `rhs_ns`
- Total runs: `12` (all completed without fit errors)

## Results Summary

| Method | Prior | Mean Runtime (s) | Mean RMSE | Mean MAE |
|---|---|---:|---:|---:|
| VB | rhs | 7.792 | 0.5478 | 0.4278 |
| VB | rhs_ns | 1.246 | 0.5281 | 0.4038 |
| MCMC | rhs | 33.889 | 0.5262 | 0.4035 |
| MCMC | rhs_ns | 9.152 | 0.5307 | 0.4061 |

Derived speedups:

- VB: `rhs / rhs_ns ~= 6.25x`
- MCMC: `rhs / rhs_ns ~= 3.70x`

Predictive deltas (`rhs_ns - rhs`):

- VB RMSE: `-0.0196` (better)
- VB MAE: `-0.0240` (better)
- MCMC RMSE: `+0.0046` (near parity)
- MCMC MAE: `+0.0026` (near parity)

## Decision

1. `rhs_ns` demonstrates material runtime gains with close predictive parity.
2. For release safety and backward compatibility, current API defaults are not
   globally switched in this cycle.
3. `rhs_ns` is considered production-ready as an opt-in prior type and is the
   recommended choice for new runtime-sensitive workflows.

## Follow-Up

1. Perform dedicated native `rhs_ns` port on `cransub/0.4.0` legacy static stack.
2. Re-evaluate default-switch policy after 0.4.0-native validation matrix.
