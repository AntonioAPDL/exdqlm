# REPORT: QDESN Validation Phase 4B + Phase 5 Follow-Up (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`

## 1) Purpose

Capture the outcomes of the two immediate follow-up waves after Phase 4:

1. a full-6 confirmation of `R18_split_prior_rhsns_overlay`;
2. a narrow unresolved-root search rooted at the `R18` carry-forward baseline.

These runs are the strongest current evidence about what is actually helping and what remains broken.

## 2) Operational Outcome

Both waves were operationally healthy.

- no runner errors;
- no timeouts;
- no root-level finite/domain/collapse failures;
- all campaigns completed cleanly;
- stage gating behaved correctly.

This is a scientific result set, not an orchestration artifact.

## 3) Phase 4B Outcome

Run:

- manifest:
  `config/validation/qdesn_validation_phase4b_r18_fullsix_manifest.yaml`
- run tag:
  `qdesn-phase4b-r18-fullsix-20260331a__git-cfacba5`

Profiles:

- `R0_current_best_anchor`
- `R18_split_prior_rhsns_overlay`

Full-6 result:

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation |
|---|---:|---:|---:|---:|---:|
| `R18_split_prior_rhsns_overlay` | `3` | `2` | `5` | `0.1667` | `0.3636` |
| `R0_current_best_anchor` | `4` | `2` | `6` | `0.0000` | `0.4998` |

Read:

- `R18` is genuinely better than the current anchor;
- the improvement is real at the full-6 level, not just on the severe quartet;
- however, `R18` is still not strong enough to be the final baseline.

Main takeaway:

- keep the `R18` rhs overlay idea;
- do not stop there.

## 4) Phase 5 Outcome

Run:

- manifest:
  `config/validation/qdesn_validation_phase5_core_triad_screen_manifest.yaml`
- run tag:
  `qdesn-phase5-coretriad-20260331a__git-cfacba5`

### Stage 1: unresolved triad

Winner:

- `R31_r18_rhsns_pass2`

Triad result:

| profile | total_fail_n | fail_reduction | runtime_inflation | gate |
|---|---:|---:|---:|---|
| `R31_r18_rhsns_pass2` | `1` | `0.6667` | `-0.0079` | `TRUE` |
| `R30_r18_baseline` | `3` | `0.0000` | `0.0200` | `FALSE` |

Read:

- `R31` was a clear and substantial improvement;
- the extra `rhs_ns` core pass is a real lever;
- this was the first profile to reduce the unresolved triad from `3 FAIL` to `1 FAIL`.

### Stage 2: full-6 confirmation

Profiles:

- `R30_r18_baseline`
- `R31_r18_rhsns_pass2`

Full-6 result:

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation |
|---|---:|---:|---:|---:|---:|
| `R31_r18_rhsns_pass2` | `3` | `0` | `3` | `0.5000` | `0.6981` |
| `R30_r18_baseline` | `4` | `1` | `5` | `0.1667` | `0.3361` |

Read:

- `R31` is the strongest profile we have produced so far;
- it cut the full-6 fail count from `5` to `3`;
- it removed all sentinel fails;
- it still did not auto-advance because runtime rose too much and `3 FAIL` remain.

## 5) Exact Remaining Fail Set Under `R31`

Current full-6 fail roots:

1. `dlm_ar1V @ tau=0.95 exal rhs_ns`
2. `dlm_constV_bigW @ tau=0.05 exal ridge`
3. `dlm_constV_smallW @ tau=0.95 exal ridge`

### `ar1V exal rhs_ns`

Current fail reason:

- `half_chain_drift`

Important read:

- ESS, ACF, and Geweke are now good enough;
- this root is no longer a broad rhs pathology;
- it is now a narrow drift-stabilization problem.

### `constV_bigW exal ridge`

Current fail reason:

- `low_ess; high_autocorrelation; half_chain_drift`

Important read:

- Geweke is no longer the main blocker;
- this root now looks like an ESS + drift ridge-core problem.

### `constV_smallW exal ridge`

Current fail reason:

- `low_ess; half_chain_drift`

Important read:

- this is also now an ESS + drift ridge-core problem;
- it is no longer primarily a Geweke-limited root.

## 6) What Worked Best

1. The `R18` rhs overlay was real and worth keeping.
2. The `R31` extra `rhs_ns` core pass was the strongest new lever.
3. `R31` fixed both sentinel roots and the `smallW exal rhs_ns` fail.
4. The remaining ridge problem is now cleaner than before:
   it is mostly ESS plus half-drift.

## 7) What We Should Stop Repeating

These ideas have now been tested enough as lead families:

- global QR-led families;
- standalone soft-pass rhs variants;
- ridge-only pass families as used in Phase 5;
- combined Phase-5 balanced/soft hybrids as currently parameterized;
- broad split-prior sweeps that do not keep the `R31` improvement.

## 8) Main Takeaways

1. `R31_r18_rhsns_pass2` is the current best profile.
2. The `rhs_ns` side is no longer the broad blocker. It now has one narrow drift issue on `ar1V`.
3. The ridge side is now the dominant remaining blocker.
4. The next overnight screen should start from `R31`, not `R18`.
5. The overnight search should target:
   - rhs drift stabilization around `R31`;
   - ridge ESS + half-drift recovery around `R31`;
   - a few combined descendants of those two ideas.

## 9) Recommended Next Move

Run one broad overnight `R31`-descendant full-6 screen.

Why:

- the full-6 harness is only 6 roots and is now cheap enough to screen broadly;
- the remaining fail set is well characterized;
- the next useful information is no longer “which family in general?”;
- it is “which targeted descendants of `R31` best remove the last three FAILs without losing the repaired roots?”.
