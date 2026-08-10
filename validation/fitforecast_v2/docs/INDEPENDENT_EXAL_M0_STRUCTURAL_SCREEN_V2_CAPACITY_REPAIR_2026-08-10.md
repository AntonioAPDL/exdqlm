# Independent exQ-DESN M0 Structural Screen v2 Capacity Repair

## Decision

The successor campaign must use a maximum realized readout dimension of 900.
The frozen 96-profile Wave-1 ledger is repaired deterministically: retain every
feasible profile exactly and replace only profiles above the cap. No scientific
target, family/quantile quota, M0 kernel choice, source contract, inference
budget, or promotion rule changes.

## Failure diagnosis

Run `ind-exal-m0-struct-v2-20260810_011245__git-20b8022` passed both smoke jobs
and 11 of 12 runtime-calibration jobs. The remaining candidate,
`ssv2_gausmix_t0p25_broad_06_fbc476115e`, had `D=2`, `n=(300,300)`,
`reservoir_lags=3`, `readout_y_lags=6`, and an observed design matrix with 2,412
columns. It reached only burn-in iteration 100 of 200 after roughly two CPU
hours. Its projected 12--14 hour calibration runtime necessarily violated the
predeclared six-hour gate, so the campaign was stopped before Wave 1.

The closeout evidence is:

```text
reports/shared_fitforecast_v2_orchestration/
  independent_exal_m0_structural_screen_v2_20260810_011245/
  capacity_gate_closeout.json
```

The later audit also found and terminated only that run's orphaned timeout/child
pair; the PID, file-handle, signal, and exit evidence is recorded beside the
closeout in `orphan_process_cleanup.json`.

The stop produced no promotable evidence and did not change the article.

## Capacity contract

The exact readout dimension observed by the pipeline is

```text
p_eff = (sum(n_tilde) + tail(n, 1)) * (reservoir_lags + 1)
        + readout_y_lags + 6.
```

This formula reproduces the observed 2,412-column failure and the feasible
calibration designs with 514, 607, and 608 columns. The cap `p_eff <= 900` keeps
the search broad while removing the superlinear tail that cannot satisfy the
runtime gate. Depth through four, memory through 150, total states through 600,
multiscale alpha/rho profiles, and recurrent degrees through 16 remain eligible.

## Deterministic repair

The repair script reads the predecessor ledger directly from Git commit
`20b8022`, rather than trusting mutable local state. For each out-of-contract
row it:

1. preserves its target cell and broad/boundary selection arm;
2. excludes historical exact profiles, all predecessor profiles, and earlier
   replacements;
3. filters the frozen 50,000-profile universe to `p_eff <= 900`;
4. selects one deterministic maximin replacement against the retained profiles
   and parent for that cell;
5. records both identities, signatures, dimensions, the predecessor Git blob,
   and output hashes.

The canonical evidence is:

```text
config/validation/qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_structural_screen_v2_capacity_repair_ledger.csv
config/validation/qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_structural_screen_v2_capacity_repair_manifest.json
```

Fresh Wave-1 selection and every adaptive pool apply the same cap. Job
materialization, static verification, and the worker independently recompute the
dimension and fail explicitly on drift.

## Telemetry repair

Health checks now combine the compact progress trace with
`logs/pipeline_child_live.log`. A job is considered alive when either its config
is present in a process command line or that exact child log is held open as
stdout/stderr. Burn-in and retained-sampling iterations are parsed from the live
log, which prevents active long MCMC kernels from being mislabeled stale merely
because the parent trace has not yet been written.

## Relaunch gates

The successor run may proceed only after all of the following pass under R
4.6.0:

- package load and focused testthat suite;
- deterministic repair invariants and tracked-manifest hashes;
- 96 Wave-1 profiles and seven parents under the 900-column cap;
- static source/window/M0/storage verification;
- two real smoke roots with finite metrics and zero forbidden binaries;
- 12 runtime-calibration roots, each completing within six hours.

The campaign remains screening-only. Full canonical confirmation is still
materialized but cannot launch without explicit human approval.

## Prelaunch verification evidence

The repaired contract passed the focused structural-screen suite, M0 collapsed
scale/shape tests, rolling-origin tests, interface/storage tests, static
verification, and config verification for smoke, calibration, and Wave 1 under
R 4.6.0.

Real smoke tag:

```text
ind-exal-m0-struct-v2-capacity-smoke-20260810_035614__git-precommit
```

Both roots completed successfully in parallel in 38.2 and 43.6 seconds. Their
objective metrics were finite, required fit/forecast summaries were present,
and no `.rds`, `.rda`, or `.RData` payload remained. Runtime verification is at:

```text
reports/shared_fitforecast_v2_orchestration/
  independent_exal_m0_structural_screen_v2_materialization/
  smoke_capacity_repair_runtime_verification.json
```
