# REPORT: QDESN Validation Phase 4 Split-Prior Screen (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-phase4-splitprior-screen-20260331b__git-5f02a8a`

## 1) Purpose

Run the next broad repair wave after the Family-B transformed-sigma screen by:

1. keeping the best transformed-sigma gamma-focus pattern as the anchor;
2. separating ridge and `rhs_ns` tuning into different profiles;
3. targeting `FAIL -> WARN` instead of universal `PASS`;
4. stopping after the severe quartet if nothing truly improved.

## 2) Operational Outcome

The run was operationally healthy.

- `S1_severe_quartet_broad` completed;
- no timeouts;
- no runner errors;
- all `8/8` profiles completed with `4/4` root success;
- no finite/domain/collapse/unhealthy regressions;
- the screen stopped correctly because no candidate met the quartet advance gate.

This was a clean scientific negative, not an orchestration failure.

## 3) Main Result

The split-prior family produced one real improvement:

- `R18_split_prior_rhsns_overlay`

Quartet summary:

| profile | severe_fail_n | total_fail_n | fail_reduction | runtime_inflation |
|---|---:|---:|---:|---:|
| `R18_split_prior_rhsns_overlay` | `3` | `3` | `0.25` | `0.2019` |
| `R0_current_best_anchor` | `4` | `4` | `0.00` | `0.5344` |
| all other Phase 4 candidates | `4` | `4` | `0.00` | `0.1799` to `0.2455` |

Interpretation:

- the split-prior idea itself was useful;
- the useful part was not ridge-only QR or ridge-only pass/chain changes;
- the useful part was the stronger `rhs_ns` overlay;
- the automatic gate was stricter than the current practical objective, because the user goal is now zero `FAIL`, with `WARN` acceptable.

## 4) What Actually Improved

`R18` repaired one severe root:

- `dlm_ar1V @ tau=0.95 exal rhs_ns`

Under the anchor, this root was:

- `FAIL`
- `low_ess; high_autocorrelation; half_chain_drift`

Under `R18`, this root became:

- `WARN`
- `chain_marginal_but_usable`

Key movement:

| metric | anchor | `R18` |
|---|---:|---:|
| `mcmc_min_ess_core` | `6.36` | `21.24` |
| `mcmc_max_acf1_core` | `0.9873` | `0.9534` |
| `mcmc_max_half_drift_core` | `0.7182` | `0.2793` |

This is the strongest new scientific result from Phase 4:

- the `rhs_ns` overlay is real;
- it is not noise;
- it is worth carrying forward.

## 5) What Did Not Improve Enough

The remaining `R18` fail cluster is:

1. `dlm_constV_bigW @ tau=0.05 exal ridge`
2. `dlm_constV_smallW @ tau=0.95 exal ridge`
3. `dlm_constV_smallW @ tau=0.95 exal rhs_ns`

These are now the actual unresolved pain points.

### `constV_bigW exal ridge`

Still fails on:

- `low_ess`
- `high_autocorrelation`
- `geweke_drift`
- `half_chain_drift`

This remains the hardest root and the main canary for any real core repair.

### `constV_smallW exal ridge`

Still fails on:

- `low_ess`
- `high_autocorrelation`
- `half_chain_drift`

This looks like a ridge-core mixing problem, not a residual rhs problem.

### `constV_smallW exal rhs_ns`

Still fails on:

- `low_ess`
- `half_chain_drift`

This suggests that after the new `rhs_ns` overlay, the remaining `rhs_ns` blocker is now closer to core mixing than to generic rhs pathology.

## 6) What Phase 4 Exhausted

Phase 4 materially narrowed the search space.

The following ideas are now de-prioritized as lead families:

- ridge-only QR as the main lever;
- ridge-only extra-pass changes without a stronger core rationale;
- mild rhs multistart as a lead idea;
- broad split-prior schedules that do not carry the `R18` rhs overlay.

That does not mean they are useless forever. It means they should not be the next primary search family.

## 7) Main Takeaways

1. `R18_split_prior_rhsns_overlay` is the only Phase 4 profile that produced a real quartet improvement.
2. The repaired root was `rhs_ns`, which confirms the overlay should be kept.
3. The remaining blocker cluster is now mostly core mixing, centered on two ridge roots plus one `rhs_ns` small-`W` root.
4. The next search should no longer be a broad split-prior sweep.
5. The next efficient program is:
   - carry `R18` into a full-6 confirmation against the current anchor;
   - run a narrow core-triad screen on the three unresolved roots using `R18` as the baseline.

## 8) Recommended Next Move

Immediate next steps:

1. `Phase 4B`: full-6 confirmation of `R18` versus `R0_current_best_anchor`
2. `Phase 5`: targeted core-triad screen on:
   - `dlm_constV_bigW @ tau=0.05 exal ridge`
   - `dlm_constV_smallW @ tau=0.95 exal ridge`
   - `dlm_constV_smallW @ tau=0.95 exal rhs_ns`

The next wave should keep the `R18` overlay and search only inside the remaining core-mixing space.
