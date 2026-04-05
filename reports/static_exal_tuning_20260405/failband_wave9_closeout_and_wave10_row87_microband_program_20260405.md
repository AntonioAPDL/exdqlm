# Validation Campaign: Wave-9 Closeout and Wave-10 Row-87 Micro-Band Closure Program

Date: 2026-04-05

Primary references:

- `reports/static_exal_tuning_20260405/failband_wave8_rootcause_and_wave9_exact_replay_noneinit_program_20260405.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave9_schedule_20260405.csv`
- `tools/merge_reports/LOCAL_dynamic_row15_wave8_matrix_20260405.csv`

## Status Note

Wave-9 completed cleanly. Nothing is currently running.

Post-wave-10 correction:

- a deeper row-`87` artifact audit shows that the surviving non-`FAIL` history
  was broader than this report's initial framing
- historical `WARN` anchors also exist in the lower-mid
  `F0825` / `F0835` `laplace_rw` short-run corridor
- wave-10 is still valid and useful, but it should now be read as an
  exhaustion test of the later `F085` / `F0855` scale-`1.025` micro-band only,
  not as proof that all credible row-`87` space has been exhausted

This is still a strong result even though row `87` remains unresolved, because
the final campaign tail is now almost entirely closed:

- row `135` improved to `PASS`
- row `174` improved to `WARN`
- row `269` improved to `WARN`
- dynamic row `15` improved to `WARN`
- the only remaining blocking case is now:
  - current static row `87`

The campaign is therefore no longer in a broad closure phase.
It is now in a one-row micro-band stabilization phase.

## Wave-9 Closeout

### Final wave-9 result

| stage | total | PASS | WARN | FAIL | missing | resolved |
|---|---:|---:|---:|---:|---:|---:|
| `stability7_exact` | 7 | 0 | 1 | 6 | 0 | 1 |
| `closure12_exact_none` | 12 | 1 | 1 | 10 | 0 | 2 |
| `overall` | 19 | 1 | 2 | 16 | 0 | 3 |

### What improved

- row `135` is now closed to `PASS` under:
  - `F0825_sub2_s105`
  - `init_mode = none`
- row `174` is now closed to `WARN` under:
  - `F085_sub2_s105`
  - exact historical short replay
- row `269` is now closed to `WARN` under:
  - `F0845_sub2_s100`
  - exact historical short replay
- dynamic row `15` is now closed to `WARN / healthy = TRUE` under:
  - the exact TT5000 slice replay
- the static launcher/supervisor completeness fix held:
  wave-9 finished with `0 missing`

### What still fails

The only remaining blocking validation case is:

| scope | row_id | family | tt | tau | current best read |
|---|---:|---|---:|---|---|
| `current_rhsns_refresh` | `87` | `gausmix` | `1000` | `0p25` | `FAIL` |

### What worked best

1. exact historical replay plus `init_mode = none` on row `135`
2. exact historical replay on row `174`
3. exact historical short replay on row `269`
4. treating dynamic row `15` as a replay/confirmation problem instead of a new
   broad dynamic search
5. keeping the broad default static baseline fixed while promoting only local
   row-level improvements

### What did not help

1. any further broad static search
2. `vb`-style warm-start dependence as the main closure path
3. widening back out across already screened `F075`, `F080`, or outer-frontier
   families
4. row-`87` exact-history replays by themselves; all fresh wave-9 row-`87`
   replays still failed

## Promoted Static Baseline v7

The active campaign baseline should now be:

- broad default:
  - `F085_sub2_s100`
- promoted row-local map:

| scope | row_id | preferred candidate | role | current best read |
|---|---:|---|---|---|
| `current_rhsns_refresh` | `87` | open `F085/F0855` micro-band | remaining blocker | `FAIL` |
| `current_rhsns_refresh` | `115` | `F0825_sub2_s100` | stable `PASS` | `PASS` |
| `current_rhsns_refresh` | `135` | `F0825_sub2_s105_none` | promoted `PASS` | `PASS` |
| `current_rhsns_refresh` | `174` | `F085_sub2_s105_histshort` | promoted `WARN` | `WARN` |
| `current_rhsns_refresh` | `190` | `F0825_sub2_s100_rwlong` | stable `WARN` | `WARN` |
| `current_rhsns_refresh` | `206` | `F0825_sub2_s1025_rwlong` | stable `PASS` | `PASS` |
| `current_rhsns_refresh` | `278` | `F0845_sub2_s1025` | stable `PASS` | `PASS` |
| `legacy_rhs_refresh` | `181` | `F0825_sub2_s100` | stable `PASS` | `PASS` |
| `legacy_rhs_refresh` | `269` | `F0845_sub2_s100_histshort` | promoted `WARN` | `WARN` |

Dynamic local baseline:

| workstream | row | preferred candidate | current best read |
|---|---:|---|---|
| `dynamic_tail_cppgig_refresh_20260331` | `15` | `row15_slice_exact_20260405` | `WARN` |

## Highest-Value Directions Now

1. do **not** spend more compute on anything except row `87`
2. stay inside the only two row-`87` proposal families that have ever reached
   `WARN`:
   - `F085_sub2_s1025` with `slice_eta`
   - `F0855_sub2_s1025` with `rwlong`
3. allow only a tiny micro-band around those anchors:
   - `F08525_sub2_s1025`
   - `F08575_sub2_s1025`
4. allow slightly longer confirmations because the active failure signal on row
   `87` is chain quality, especially the gamma-side ESS/mixing gates
5. do **not** reopen any already-screened low-value geometry or family search

## Wave-10 Strategy

### Guiding principle

Wave-10 should be the last broad-but-disciplined row-`87` search.

It is broad only inside the tiny surviving row-`87` micro-band and should not
touch any already-resolved row.

### Stage design

| stage | purpose | runs |
|---|---|---:|
| `anchor4_confirm` | exact and slightly longer confirmations of the only two surviving row-`87` anchors | 4 |
| `micro4_expand` | narrow micro-band probes around those anchors | 4 |
| `overall` | total | 8 |

### Included candidates

| candidate | why included |
|---|---|
| `F085_sub2_s1025` `slice_eta` exact anchor | only historical slice WARN anchor |
| `F0855_sub2_s1025` `rwlong` exact anchor | only historical rwlong WARN anchor |
| longer `F085_sub2_s1025` `slice_eta` | tests whether extra keep stabilizes gamma ESS |
| longer `F0855_sub2_s1025` `rwlong` | tests whether extra keep stabilizes the rw corridor |
| `F08525_sub2_s1025` `slice_eta` | midpoint micro-step between the two surviving jump frequencies |
| `F08525_sub2_s1025` `rwlong` | midpoint micro-step in the rw corridor |
| `F0855_sub2_s1025` `slice_eta` | tests whether the upper anchor benefits from slice dynamics |
| `F08575_sub2_s1025` `rwlong` | tiny upper micro-step beyond the surviving rw anchor |

### Explicit exclusions

Wave-10 intentionally excludes:

- all resolved rows (`135`, `174`, `269`, row `15`)
- all weak/dominated families outside the `F085`/`F0855` micro-band
- more `vb` work on row `87`
- more `F0825`, `F0835`, `F0845`, `F0860+` row-`87` restarts
- any new broad static or dynamic search

## Bottom line

The campaign is very close.

Current endgame:

- static resolved to non-`FAIL`: `135`, `174`, `269`
- dynamic resolved to non-`FAIL`: `15`
- only blocker left: `87`

Wave-10 should now be interpreted more narrowly:

- it exhausted the later `F085` / `F0855` row-`87` micro-band
- it did **not** exhaust the overlooked lower-mid historical non-`FAIL`
  corridor in `F0825` / `F0835`

That lower-mid replay/confirmation lane is the right next move after this
report.
