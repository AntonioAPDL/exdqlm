# Validation Campaign: Static Refresh Closeout and Fail-Band Program

Date: 2026-04-03

Primary references:

- `reports/static_exal_tuning_20260403/campaign_completion_execution_20260403.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_fail_inventory_20260403.csv`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_fail_patterns_20260403.csv`
- `tools/merge_reports/LOCAL_dynamic_row15_sidecar_schedule_20260403.csv`

## Status Note

The focused `72`-row static refresh under `F080_sub2_s105` is complete.

This report supersedes the earlier assumption that `F080_sub2_s105` could be
promoted directly from wave-8 into a comparison-ready campaign baseline. The
completed static refresh materially improves the stale validation state, but it
does **not** satisfy the campaign acceptance rule of `0` gate FAILs.

The study is now in a new state:

- the full stale static slice has been refreshed once under a clean,
  scope-correct exact-runner baseline
- the refreshed outputs are the new empirical reference wave for next-wave
  repair work
- the next active task is a narrow fail-band program, not another broad rerun

## Final Static Refresh Outcome

### Scope-level final results

| scope | total | PASS | WARN | FAIL | note |
|---|---:|---:|---:|---:|---|
| current RHS-NS refresh | 54 | 11 | 22 | 21 | fully complete |
| legacy RHS refresh | 18 | 4 | 5 | 9 | fully complete |
| static refresh overall | 72 | 15 | 27 | 30 | fully complete |

### Apples-to-apples improvement over the stale slices

| slice | old stale | new refresh | net read |
|---|---|---|---|
| current RHS-NS | `47 FAIL / 7 WARN / 0 PASS` | `21 FAIL / 22 WARN / 11 PASS` | large improvement, still not acceptable |
| legacy RHS | `13 FAIL / 4 WARN / 1 PASS` | `9 FAIL / 5 WARN / 4 PASS` | improvement, still not acceptable |
| overall static slice | `60 FAIL / 11 WARN / 1 PASS` | `30 FAIL / 27 WARN / 15 PASS` | big gain, but still too many FAILs |

### Key interpretation

The refresh **did improve** the stale static evidence substantially. It did
**not** make the campaign comparison-ready.

The correct interpretation is:

- `F080_sub2_s105` is the best completed broad exact-runner reference wave so
  far
- `F080_sub2_s105` is **not** a valid final production baseline for the full
  campaign because it still leaves `30` static scope-cases at `FAIL`

## Main Takeaways

### What improved

- the entire stale `72`-row static `exal` slice is now refreshed under a
  scope-correct exact-runner orchestration stack
- the current RHS-NS static slice improved from `47` FAILs to `21`
- the legacy RHS comparison slice improved from `13` FAILs to `9`
- the study now has `42` refreshed static non-FAIL artifacts (`15 PASS`,
  `27 WARN`) that can be reused directly
- the branch now has a reproducible fail inventory and fail-pattern summary
  for next-wave planning

### What still fails

- `30` static scope-cases still fail:
  - `21` in current RHS-NS
  - `9` in legacy RHS
- dynamic row `15` remains the only dynamic unresolved debt
- no merged comparison-ready campaign table can be signed off yet because the
  campaign still violates the `0 FAIL` rule

### What worked best

1. scope-aware static rerun orchestration with explicit prior templates
2. reuse of valid artifacts rather than reopening broad slices
3. fail-band reasoning based on completed full-slice evidence, not on partial
   wave heuristics
4. treating `WARN` as acceptable but `FAIL` as the true repair boundary

### What clearly did not work

1. promoting `F080_sub2_s105` directly from wave-8 into a production
   full-slice baseline
2. assuming that a zero-FAIL transfer wave would necessarily generalize across
   the full stale campaign slice
3. treating the static refresh itself as the endpoint rather than as a new
   evidence baseline

### Highest-value directions now

1. freeze the completed static refresh as the new reference wave
2. rerun **only** the residual static FAIL band, not the `42` refreshed
   non-FAIL rows
3. prioritize the recurring fail clusters that appear in both current and
   legacy scopes
4. keep dynamic row `15` separate until there is an actual repair hypothesis

## Remaining Campaign Debt

After closing the static refresh wave, the unresolved campaign debt is now:

| workstream | cases | current state |
|---|---:|---|
| refreshed static non-FAIL rows | 42 | reusable now |
| previously reusable campaign artifacts | 218 | reusable now |
| residual static FAIL scope-cases | 30 | next-wave target set |
| dynamic row `15` | 1 | separate unresolved debt |
| total unresolved campaign debt | 31 | current minimum remaining work |

This is the key update:

- remaining unresolved debt is now `31`, not `73`

## Residual Static Fail Band

### Scope-case inventory

- fail inventory:
  `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_fail_inventory_20260403.csv`
- fail-pattern summary:
  `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_fail_patterns_20260403.csv`

### Counts

| fail view | count |
|---|---:|
| current RHS-NS fail scope-cases | 21 |
| legacy RHS fail scope-cases | 9 |
| combined fail scope-cases | 30 |
| unique `(family, tau, tt)` fail patterns | 15 |

### Highest-priority recurring patterns

These are the strongest next-wave anchors because they recur across scopes:

| family | tau | tt | fail scope-cases |
|---|---|---:|---:|
| gausmix | `0p25` | 1000 | 4 |
| gausmix | `0p05` | 1000 | 3 |
| gausmix | `0p25` | 100 | 3 |
| laplace | `0p05` | 1000 | 3 |
| gausmix | `0p95` | 100 | 2 |
| gausmix | `0p95` | 1000 | 2 |
| laplace | `0p95` | 1000 | 2 |
| normal | `0p05` | 1000 | 2 |
| normal | `0p25` | 1000 | 2 |
| normal | `0p95` | 100 | 2 |

### Exact recurring cross-scope anchors

These specific row-pattern combinations fail in both current and legacy scope:

| row_id | family | tt | tau |
|---:|---|---:|---|
| 157 | gausmix | 1000 | `0p05` |
| 165 | gausmix | 100 | `0p25` |
| 173 | gausmix | 1000 | `0p25` |
| 237 | laplace | 1000 | `0p95` |

## Baseline Decision After the Full Refresh

The completed refresh should be treated as the **new empirical baseline for
repair planning**, but not as the final campaign baseline.

Updated interpretation of the candidate stack:

| role | candidate | decision now |
|---|---|---|
| best completed broad reference wave | `F080_sub2_s105` | keep as the reference wave for fail-band comparisons |
| fallback control | `F080_sub2_s100_ref` | still relevant as a targeted next-wave comparison candidate |
| narrow bridge | `F080_sub2_s0975` | still relevant for fail-only repair lanes |
| final campaign baseline | none yet | not earned; still blocked by `30` static FAIL scope-cases |

## Recommended Next Program

The next program should be fail-only and narrow.

### Scope

- include only the `30` residual static FAIL scope-cases
- keep current and legacy scope labels separate
- keep dynamic row `15` out of the static fail-band wave
- do not rerun the `42` refreshed static non-FAIL rows
- do not rerun the `218` already reusable non-static artifacts

### Experimental priorities

1. anchor on the `4` recurring cross-scope fail rows
2. stress the dominant `gausmix` fail clusters first
3. include `F080_sub2_s100_ref` and `F080_sub2_s0975` as natural comparison
   candidates because they are the strongest nearby controls already validated
4. only broaden beyond those if the first fail-only wave still leaves a narrow
   unresolved band

### Dynamic row `15`

Row `15` remains a sidecar lane.

Current recommendation:

- do not relaunch it blindly
- define a true repair hypothesis first
- keep it separate from the static fail-band program

## Operational Bottom Line

The study is still moving in the right direction.

The completed static refresh was not a failed experiment. It was a **successful
reduction in uncertainty**:

- it cut the stale static fail burden in half
- it identified the exact residual fail band
- it reduced the unresolved campaign debt from `73` to `31`

The next best move is now clear:

1. update the trackers and treat this completed refresh as the new planning
   baseline
2. prepare a fail-only next wave around the `30` static FAIL scope-cases
3. keep row `15` separate
4. aim the next wave at eliminating residual FAILs without reopening the full
   campaign
