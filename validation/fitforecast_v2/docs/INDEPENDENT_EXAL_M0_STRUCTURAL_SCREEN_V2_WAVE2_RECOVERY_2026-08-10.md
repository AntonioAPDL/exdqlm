# Independent exAL M0 Structural Screen v2: Wave-2 Recovery

Date: 2026-08-10

Scope: independent single-quantile exQ-DESN validation only

Package baseline: exdqlm 1.0.0

Branch: `validation/independent-exal-m0-structural-screen-v2-1.0.0`

## Frozen Run

- Run ID: `independent_exal_m0_structural_screen_v2_capacity_repair_20260810_040208`
- Run tag: `ind-exal-m0-struct-v2-capacity-20260810_040208__git-8f1898a`
- State root: `reports/shared_fitforecast_v2_orchestration/independent_exal_m0_structural_screen_v2_capacity_repair_20260810_040208`
- Result root: `results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_structural_screen_v2/ind-exal-m0-struct-v2-capacity-20260810_040208__git-8f1898a`
- Canonical registry identity: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Materialized source-registry file SHA-256: `5314c39f26cdcd7a2bf2b35ed1e802ed807fcad039eb54276012456ab18f6edb`

The original run completed 282 roots: 2 smoke, 12 calibration, 103 Wave 1,
and 165 Wave 2. Every completed root has status `SUCCESS`, finite objective
metrics, the expected compact fit and forecast summaries, and no `.rds`,
`.rda`, or `.RData` payload. These roots are immutable recovery inputs and
must not be recomputed.

## Failure Diagnosis

The pipeline stopped in `advance_after_wave2`; model fitting did not fail.
Two selector defects were confirmed.

1. Some single-layer job profiles deserialize `n_tilde` as a zero-length JSON
   value. Direct `as.data.frame(job$profile)` then combines length-one and
   length-zero fields and stops with `arguments imply differing number of
   rows: 1, 0`.
2. Wave 1 and Wave 2 both evaluate surviving candidates on `dev09`. Combining
   both stages without resolving repeated candidate/source observations gives
   `dev09` twice the weight of `dev10` and `dev11`. There are exactly 55 such
   repeated observations, and their later values are not numerically identical
   to the earlier values.

## Recovery Contract

The recovery implements these predeclared rules:

- Normalize null or zero-length profile fields to an explicit empty scalar
  before constructing a one-row profile.
- Define an observation by target cell, candidate, source, objective metric,
  and chain. A later stage supersedes an earlier repeat of that observation.
- Emit a row-level repeat-resolution ledger. For this run it must contain
  exactly 55 `wave1` to `wave2` resolutions.
- Preserve the failed `adaptive/` directory. Generate all corrected adaptive
  artifacts under `adaptive_recovery_selector_v1/`.
- Reverify all 282 prior roots before advancing. Never rerun smoke,
  calibration, Wave 1, or Wave 2.
- Run only Wave 3 (72 roots) and sealed evaluation (76 roots), using at most 20
  one-thread workers selected from idle CPUs.
- Append recovery states to the existing stage ledger and use attempt-specific
  logs. A same-tag retry may skip only config-identical successful jobs.
- Materialize, but never launch, the 21-job canonical confirmation plan. It
  remains blocked on explicit human approval.
- Keep the article unchanged until sealed evidence is complete and audited.

## Verification Gates

Before Wave 3 starts, recovery must pass:

1. clean branch with synchronized upstream;
2. package load under R 4.6.0 and exdqlm version 1.0.0;
3. focused structural-screen tests;
4. runtime verification of all 282 prior roots;
5. a 55-row repeat-resolution ledger with Wave 2 retained;
6. a 72-row Wave-3 plan with valid hashes, exact source windows, M0 inference,
   one thread per job, readout dimension at most 900, and storage-light output;
7. load, memory, disk, and idle-CPU gates.

The same contracts are rechecked for the 76-row sealed plan. After sealed
closeout, the canonical confirmation plan must contain 21 rows and
`launch_approved = FALSE` for every row.

## Reproducible Command

The wrapper launches the append-only recovery in a detached tmux session:

```bash
WORKERS=16 bash \
  validation/fitforecast_v2/scripts/launch_resume_independent_exal_m0_structural_screen_v2_after_wave2.sh \
  /data/jaguir26/local/src/exdqlm__wt__independent_exal_m0_structural_screen_v2_1p0p0 \
  independent_exal_m0_structural_screen_v2_capacity_repair_20260810_040208 \
  ind-exal-m0-struct-v2-capacity-20260810_040208__git-8f1898a \
  adaptive_recovery_selector_v1
```

No full confirmation or article promotion is part of this command.
