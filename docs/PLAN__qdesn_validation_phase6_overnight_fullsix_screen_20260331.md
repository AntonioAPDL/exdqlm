# PLAN: QDESN Validation Phase 6 Overnight Full-6 Screen (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Run one broad overnight screen that starts from the best current profile, `R31_r18_rhsns_pass2`, and
searches only the remaining useful tuning space on the fixed 6-root harness.

This wave is designed to:

1. preserve the proven `R18 -> R31` progress rather than resetting the search;
2. target the exact remaining fail mechanisms instead of replaying dead families;
3. accept `WARN` as usable and optimize for removing `FAIL`;
4. use the server efficiently overnight with the proven staged-screen runner;
5. leave a clean audit trail and clear morning decision rules.

## 2) Current Best Read

The latest completed evidence says:

- `R18_split_prior_rhsns_overlay` improved the full-6 harness from `6 FAIL -> 5 FAIL`;
- `R31_r18_rhsns_pass2` improved the full-6 harness again from `5 FAIL -> 3 FAIL`;
- `R31` removed all sentinel fails;
- the remaining fail set under `R31` is:
  1. `dlm_ar1V @ tau=0.95 exal rhs_ns`
  2. `dlm_constV_bigW @ tau=0.05 exal ridge`
  3. `dlm_constV_smallW @ tau=0.95 exal ridge`

Current mechanism read:

- `ar1V exal rhs_ns` is now mostly a half-drift stabilization problem;
- `constV_bigW exal ridge` is now an ESS + high-ACF + half-drift problem;
- `constV_smallW exal ridge` is now an ESS + half-drift problem;
- the unresolved blocker is therefore mostly ridge-core mixing, with one narrow rhs drift residual.

## 3) Main Takeaways From The Completed Waves

What clearly worked:

- the `R18` rhs overlay was real and should be preserved;
- the extra rhs core pass in `R31` was the strongest single new lever we have found;
- transformed sigma is now part of the winning baseline;
- the fixed 6-root harness is now the right decision surface, not the severe quartet alone.

What clearly did not work as lead families:

- standalone bridge traversals;
- standalone conditioning / QR as the main hypothesis;
- broad split-prior sweeps that do not retain the `R18 -> R31` improvement;
- ridge-only pass changes in the exact Phase 5 forms we already tried;
- soft rhs-only pass changes in the exact `R32` form;
- broad chain-led reruns that do not target the remaining fail roots.

## 4) Overnight Objective

Primary objective:

- remove as many of the final `FAIL` rows as possible on the fixed 6-root harness.

Acceptance logic:

- `WARN` is acceptable;
- `PASS` is welcome but not required;
- the first meaningful overnight win is `total_fail_n <= 2`;
- the stronger win is `total_fail_n <= 1`;
- the stretch goal is `0 FAIL`.

Preferred additional conditions:

- `sentinel_fail_n = 0`
- `fail_reduction >= 0.30`
- `runtime_inflation <= 1.25`

## 5) What This Wave Will Not Redo

Explicitly out of scope:

- rerunning `R18` or `R31` predecessor families as the lead idea;
- replaying the old Family-B global transformed-sigma schedule;
- replaying the Phase 4 broad split-prior family;
- replaying QR-led ridge families without new ridge recovery levers;
- replaying Phase 5 `R32` through `R36` exactly as they were;
- reopening the broader closeout ladder.

This is intentionally an `R31`-descendant screen, not a general search.

## 6) Candidate Design

### Anchor

`R40_r31_baseline`

- exact `R31_r18_rhsns_pass2` behavior
- included as the live comparison anchor for the overnight run

### RHS drift-stabilization descendants

`R41_r31_rhs_burn700_freeze120`

- keep ridge equal to `R31`
- increase rhs burn-in and extend tau freeze
- target: reduce half-drift on `dlm_ar1V @ tau=0.95 exal rhs_ns`

`R42_r31_rhs_burn700_chain1400`

- keep ridge equal to `R31`
- extend rhs burn-in, tau freeze, and kept-chain length
- target: convert the rhs drift root from `FAIL -> WARN` without losing the repaired sentinels

`R43_r31_rhs_burn650_chain1200_softsigma`

- keep ridge equal to `R31`
- extend rhs stabilization and soften rhs local sigma/gamma movement modestly
- target: test whether the remaining rhs drift issue wants a gentler local path, not just more samples

### Ridge recovery descendants

`R44_r31_ridge_chain900_stepsout`

- keep rhs equal to `R31`
- extend ridge burn/chain and widen step-out budgets
- target: low ESS and high ACF on both remaining ridge roots

`R45_r31_ridge_chain1200_softsigma`

- keep rhs equal to `R31`
- extend ridge burn/chain and soften ridge sigma/gamma widths modestly
- target: ESS recovery plus lower half-drift on the ridge pair

`R46_r31_ridge_pass1_chain900`

- keep rhs equal to `R31`
- add one ridge-only extra pass plus a moderate chain extension
- target: mix better than the Phase 5 ridge-pass family without repeating it exactly

`R47_r31_ridge_pass1_chain1200_softsigma`

- keep rhs equal to `R31`
- combine the moderate ridge pass idea with the longer/softer ridge chain idea
- target: a heavier but still targeted ridge repair candidate

### Combined descendants

`R48_r31_rhsfreeze120_ridgechain900`

- combine `R41` rhs stabilization with `R44` ridge recovery

`R49_r31_rhsfreeze120_ridgechain1200soft`

- combine `R41` rhs stabilization with `R45` ridge recovery

`R50_r31_rhslong_ridgepass1_chain900`

- combine `R42` rhs stabilization with `R46` ridge recovery

`R51_r31_rhssoft_ridgepass1_chain1200`

- combine `R43` rhs stabilization with `R47` ridge recovery

## 7) Exact Overnight Schedule

| profile | bucket | main change | main target |
|---|---|---|---|
| `R40_r31_baseline` | anchor | exact `R31` | live comparison baseline |
| `R41_r31_rhs_burn700_freeze120` | rhs | more rhs stabilization burn | `ar1V exal rhs_ns` drift |
| `R42_r31_rhs_burn700_chain1400` | rhs | more rhs stabilization plus more kept draws | rhs drift with low regression risk |
| `R43_r31_rhs_burn650_chain1200_softsigma` | rhs | stabilization plus gentler rhs local movement | rhs drift if the current local path is too sharp |
| `R44_r31_ridge_chain900_stepsout` | ridge | moderate chain extension plus wider step-outs | both ridge roots |
| `R45_r31_ridge_chain1200_softsigma` | ridge | longer softer ridge chain | ESS + drift ridge pair |
| `R46_r31_ridge_pass1_chain900` | ridge | one extra ridge pass plus chain support | ridge mixing without the old Phase 5 dead form |
| `R47_r31_ridge_pass1_chain1200_softsigma` | ridge | heavier ridge repair | hardest ridge carry-forward candidate |
| `R48_r31_rhsfreeze120_ridgechain900` | combined | `R41 + R44` | balanced low-risk joint repair |
| `R49_r31_rhsfreeze120_ridgechain1200soft` | combined | `R41 + R45` | stronger ridge recovery with preserved rhs stabilization |
| `R50_r31_rhslong_ridgepass1_chain900` | combined | `R42 + R46` | runtime-heavier joint recovery |
| `R51_r31_rhssoft_ridgepass1_chain1200` | combined | `R43 + R47` | broadest high-coverage descendant |

## 8) Execution Design

This wave uses one stage only:

- root set: the fixed 6-root harness
- stage mode: full-6 only
- supervisor mode: sequential profiles
- campaign workers: `4`
- threads per worker: `1`
- plots: off
- timeout protection: on

Why this is the right structure:

- the fixed 6-root harness is already small enough to screen broadly overnight;
- the triad gate question has already been answered in Phase 5;
- staging again would mostly burn time without adding much information;
- a single full-6 stage gives directly comparable results across all candidates.

## 9) Logging And Morning Review

Artifacts to inspect first tomorrow:

1. `summary/family_b_screen_results.md`
2. `tables/profile_execution_status.csv`
3. `tables/profile_rank_summary.csv`
4. `summary/stage_candidate_selection.md`
5. `summary/stage_mcmc_config_summary.md`

What to look for:

- any profile with `total_fail_n <= 2`
- any profile with `sentinel_fail_n = 0`
- whether the remaining fail set stays ridge-dominant or shifts again
- whether the rhs drift root is finally downgraded from `FAIL -> WARN`
- whether the best ridge repair requires chain, pass, or step-out movement

## 10) Morning Decision Rules

If one or more profiles achieve:

- `total_fail_n <= 2`
- `sentinel_fail_n = 0`
- `runtime_inflation <= 1.25`

then:

- promote the best such profile into the next closeout-facing confirmation wave.

If the best profile remains at `3 FAIL` but clearly improves the remaining root mechanics:

- keep the best descendant as the new local baseline;
- stop broad tuning after this wave;
- use the new evidence to decide whether one final narrow repair wave is justified.

If no profile beats `R40_r31_baseline` materially:

- treat configuration-only tuning as close to exhausted;
- pivot from manifest-level tuning to deeper kernel work.
