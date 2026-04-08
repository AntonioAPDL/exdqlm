# Original-288 Synced-Base Dynamic Tail6 Localmix Program

Date: 2026-04-08

## Purpose

This program continues from the completed synced-base dynamic tail6 refine wave.

Accepted publication-target state is unchanged:

- `282 / 288` healthy
- `230 PASS`
- `52 WARN`
- `6 FAIL`

All `6` remaining publication-target failures are still:

- `dynamic`
- `exdqlm :: mcmc`

## Dynamic Tail6 Refine Closeout

The completed synced-base dynamic tail6 refine wave finished:

- `6 / 6` complete
- `0 PASS`
- `0 WARN`
- `6 FAIL`
- `6` matches accepted
- `0` better than accepted
- `0` worse than accepted

Strict promotion result:

- none
- accepted `v7` remains authoritative

## What Improved

- no publication-target promotions landed, but the wave still improved the
  row-local diagnosis
- `gausmix / 0p25 / TT500` is now the clearest ESS-efficiency near-miss:
  - drift and Geweke are clean
  - ACF is already in-range
  - remaining blocker is ESS-per-1k, not gross instability
- `gausmix / 0p05 / TT5000` and `laplace / 0p05 / TT5000` both stabilized
  materially under slice:
  - drift improved a lot relative to earlier attempts
  - but per-1k efficiency and ACF still stayed below gate
- `normal / 0p05 / TT5000` improved meaningfully under RW:
  - drift and Geweke became reasonable
  - high autocorrelation and low ESS-per-1k still blocked promotion

## What Still Fails

Accepted unresolved publication-target tail:

- `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
- `dynamic::gausmix::0p25::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
- `dynamic::normal::0p05::500::default::exdqlm::mcmc`
- `dynamic::normal::0p05::5000::default::exdqlm::mcmc`

Persistent pattern:

- gamma remains the universal failing gate
- but several rows are no longer failing because of gross drift alone
- the remaining bottleneck is increasingly efficiency:
  - ESS-per-1k
  - autocorrelation
  - especially on gamma

## Which Ideas Worked Best

1. keeping the accepted carry-forward frozen and only promoting strict same-row
   improvements
2. using row-local kernels instead of family-generic sweeps
3. preserving the historical stronger RW family on the normal rows as evidence
4. using slice on the long gausmix and laplace rows where it softened drift
   more effectively than RW
5. letting the refine wave tell us that some rows are now efficiency-limited
   rather than simply unstable

## Which Ideas Did Not Help

1. another generic “run longer everywhere” step
2. the deep `0.18 / 320` slice geometry as a universal follow-up
3. joint-deep RW on the normal rows
4. reopening replay-repair debt inside the accepted-tail lane
5. repeating already weaker opposite-kernel alternates without a row-specific
   justification

## Highest Expected-Value Direction

1. keep the next run accepted-tail only
2. use the runner-fix knowledge explicitly:
   - closure corridors that never actually ran at intended budgets should be
     re-opened where they still show signal
3. focus on row-local efficiency rather than raw chain length:
   - moderate-budget slice corridors for the two long slice candidates and the
     single ESS-near-miss row
   - adaptive non-joint RW for the two normal rows
4. defer broad replay-repair and static work again

## Program Shape

| phase | rows | intent |
|---|---:|---|
| `phase1_dynamic_tail6_localmix` | `6` | one row-local efficiency correction per accepted unresolved dynamic row |
| `total` | `6` | compact accepted-tail-only localmix lane |

## Candidate Schedule

| case | reference | planned corridor | why it is included |
|---|---|---|---|
| `gausmix / 0p05 / TT5000` | closure slice alternate | `slice`, `0.16 / 240`, `6000 + 18000` | the intended closure corridor never truly ran because overrides were shadowed; reopen it faithfully rather than deepen slice again |
| `gausmix / 0p25 / TT500` | closure slice primary | `slice`, `0.16 / 240`, `2000 + 8000` | clearest ESS-limited near-miss; test the intended closure corridor at its true budget before widening search |
| `laplace / 0p05 / TT500` | closure RW primary | `laplace_rw`, joint, refresh `10 / 50 / 0.9`, `2500 + 10000` | best near-miss corridor, but the intended stronger RW budget never actually ran |
| `laplace / 0p05 / TT5000` | closure slice alternate | `slice`, `0.16 / 240`, `6000 + 18000` | refine deep-slice improved stability, but the intended closure efficiency corridor still needs a faithful run |
| `normal / 0p05 / TT500` | historical `rhsns_full_relaunch_20260327` RW fit | `laplace_rw`, non-joint, adapt on, refresh `25 / 25 / 0.6`, `3000 + 12000` | historical RW family was stronger than the newer joint-deep run; add adaptation instead of more joint depth |
| `normal / 0p05 / TT5000` | historical `rhsns_full_relaunch_20260327` RW fit | `laplace_rw`, non-joint, adapt on, refresh `25 / 25 / 0.6`, `6000 + 18000` | keep the historically stronger RW geometry but target efficiency with adaptation and shorter kept length than tail6 refine |

## Resource Plan

Default launch parallelism:

- `6` workers for the single localmix phase

This is intentionally narrow:

- no replay-repair rows
- no static reopening
- no redundant alternate sweep inside the same launch
- no reopening of already screened weak tail6-refine geometries

## Validation Requirements Before Launch

- `prepare` writes a `6`-row manifest
- `0` missing inputs
- evaluator sees `0 / 6` complete before launch
- `bash -n` passes for launch / supervisor / monitor
- launcher `--prepare-only=1 --skip-prepare=1` passes
- launcher `--dry-run=1 --skip-prepare=1` passes

## Primary References

- `reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_closure_execution_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_tail6_refine_execution_20260407.md`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_schedule_20260408.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_deferred_inventory_20260408.csv`
