# Validation Campaign: Fail-Band Wave-7 Closeout and Wave-8 Seed-Init + Dynamic Closure Program

Date: 2026-04-05

Primary references:

- `reports/static_exal_tuning_20260404/failband_wave6_closeout_and_wave7_triplet_closure_program_20260404.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/full288_dynamic_tail_cppgig_refresh_20260331/rows/row_0015.csv`
- `tools/merge_reports/LOCAL_dynamic_case_health_summary_slice_wave2_20260319.csv`

## Status Note

Wave-7 is complete, nothing is currently running, and the branch is clean.

This is still positive progress even though wave-7 did not close the remaining
static hard core outright.

Why this is good news:

- the row-local triplet lane completed cleanly end to end
- row `87` improved from `FAIL` to `WARN`
- row `206` improved from a reusable `WARN` anchor to a fresh `PASS`
- row `190` stayed non-`FAIL` under fresh confirmation
- the remaining static blocking core is now sharply concentrated:
  - current row `135`
  - current row `174`
  - legacy row `269`
- dynamic row `15` is no longer waiting for a vague hypothesis:
  we now have an exact historical TT5000 `slice` configuration that already
  gated to `WARN / healthy=TRUE`

The active question is therefore no longer:

- "which broad bridge band should we search next?"

It is now:

- keep `F085_sub2_s100` as the broad static default
- promote the wave-7 row-local improvements into the active repair map
- spend new compute only on:
  - row `87` confirmation
  - rows `135`, `174`, `269` closure
  - dynamic row `15` replay/confirmation

## Wave-7 Closeout

### Final wave-7 result

| stage | total | PASS | WARN | FAIL | missing | resolved |
|---|---:|---:|---:|---:|---:|---:|
| `stability3_v3` | 3 | 1 | 1 | 1 | 0 | 2 |
| `core17_triplet` | 17 | 0 | 2 | 15 | 0 | 2 |
| `overall` | 20 | 1 | 3 | 16 | 0 | 4 |

### What improved

- row `87` now has a fresh non-`FAIL` anchor:
  - `F085_sub2_s1025` with `slice_eta`
- row `206` now has a fresh `PASS` anchor:
  - `F0825_sub2_s1025_rwlong`
- row `190` keeps a durable fresh `WARN` anchor:
  - `F0825_sub2_s100_rwlong`
- wave-7 provided strong negative evidence that the remaining hard rows are not
  going to be fixed by simply:
  - running longer
  - widening the same geometry corridor
  - switching to `slice_eta` on every hard row
- dynamic row `15` now has a concrete replay target from historical evidence:
  - `slice_wave2_20260319` on TT5000 `gausmix / tau_0p25`

### What still fails

The remaining static blocking rows are:

| scope | row_id | family | tt | tau | best current anchor |
|---|---:|---|---:|---|---|
| `current_rhsns_refresh` | `135` | `normal` | `1000` | `0p25` | `F0835_sub2_s1025` short-replay corridor |
| `current_rhsns_refresh` | `174` | `gausmix` | `1000` | `0p25` | `F0875_sub2_s105` short-replay corridor |
| `legacy_rhs_refresh` | `269` | `normal` | `1000` | `0p25` | `F0825_sub2_s100` short-replay corridor |

Rows that are already non-`FAIL` and should not drive broad search anymore:

| scope | row_id | current best read | preferred candidate |
|---|---:|---|---|
| `current_rhsns_refresh` | `87` | `WARN` | `F085_sub2_s1025_slice` |
| `current_rhsns_refresh` | `115` | `PASS` | `F0825_sub2_s100` |
| `current_rhsns_refresh` | `190` | `WARN` | `F0825_sub2_s100_rwlong` |
| `current_rhsns_refresh` | `206` | `PASS` | `F0825_sub2_s1025_rwlong` |
| `current_rhsns_refresh` | `278` | `PASS` | `F0845_sub2_s1025` |
| `legacy_rhs_refresh` | `181` | `PASS` | `F0825_sub2_s100` |

Dynamic unresolved sidecar:

| workstream | row | current-HEAD status | best replay target |
|---|---:|---|---|
| `dynamic_tail_cppgig_refresh_20260331` | `15` | `FAIL` | `slice_wave2_20260319` TT5000 gausmix slice replay |

## What Worked Best

1. keeping `F085_sub2_s100` as the broad static default instead of replacing
   it globally again
2. promoting row-local improvements only when fresh evidence clearly beats the
   older provisional map
3. exact historical rescue anchors on the remaining hard rows
4. isolating `vb` init as the new high-value axis on the static hard core
5. treating row `174` as a row-specific exception instead of widening back out
   to another broad family sweep
6. treating dynamic row `15` as a replayable sidecar instead of an undefined
   future research problem

## What Clearly Did Not Help

1. another broad shared-setup search after wave-4 already showed the problem
   was local
2. the wave-7 assumption that "longer is better" for rows `135`, `174`, and
   `269`
3. repeating `slice_eta` as a generic fix for rows `174` and `269`
4. rerunning already-screened weak families:
   - `F075_*`
   - `F080_*` as the active residual repair lane
   - outer-frontier `F088+` broad restarts
5. treating dynamic row `15` as if the only option were the failed
   current-HEAD `laplace_rw` refresh artifact

## Promoted Static Baseline v4

The active static baseline should now be treated as:

- broad default:
  - `F085_sub2_s100`
- promoted local repair baseline v4:
  only where the completed evidence is cleaner than the prior map

| scope | row_id | preferred candidate | role | current best read |
|---|---:|---|---|---|
| `current_rhsns_refresh` | `87` | `F085_sub2_s1025_slice` | promoted WARN anchor needing one confirmation | `WARN` |
| `current_rhsns_refresh` | `115` | `F0825_sub2_s100` | stable local `PASS` | `PASS` |
| `current_rhsns_refresh` | `135` | `F0835_sub2_s1025` | open fail anchor for wave-8 closure | `FAIL` |
| `current_rhsns_refresh` | `174` | `F0875_sub2_s105` | open fail anchor for wave-8 closure | `FAIL` |
| `current_rhsns_refresh` | `190` | `F0825_sub2_s100_rwlong` | promoted stability anchor | `WARN` |
| `current_rhsns_refresh` | `206` | `F0825_sub2_s1025_rwlong` | promoted local `PASS` anchor | `PASS` |
| `current_rhsns_refresh` | `278` | `F0845_sub2_s1025` | stable local `PASS` | `PASS` |
| `legacy_rhs_refresh` | `181` | `F0825_sub2_s100` | stable local `PASS` | `PASS` |
| `legacy_rhs_refresh` | `269` | `F0825_sub2_s100` | open fail anchor for wave-8 closure | `FAIL` |

Interpretation:

- stable resolved rows:
  - `115`, `181`, `206`, `278`
- non-`FAIL` but still operationally relevant:
  - `87`, `190`
- remaining blocking static rows:
  - `135`, `174`, `269`

## Highest-Value Directions Now

1. keep `F085_sub2_s100` as the broad static default
2. do not spend more compute on another generic shared setup
3. use wave-8 only for:
   - exact short replay of the strongest remaining rescue anchors
   - `vb` init probes on those same anchors
   - one confirmation of row `87`
4. keep dynamic row `15` separate and replay the exact historical TT5000 slice
   rescue before trying anything broader
5. merge the final publishable comparison table only after:
   - static rows `135`, `174`, `269` are at least `WARN`
   - dynamic row `15` is at least `WARN`

## Wave-8 Strategy

### Guiding principle

Wave-8 should not reopen a family search.

It should do three things only:

1. confirm the new row-`87` slice anchor
2. close rows `135`, `174`, and `269` using exact anchor replay plus `vb`
   init
3. replay the exact historical dynamic row-`15` slice rescue under current
   `HEAD`

### Static stage design

| stage | rows | purpose | run count |
|---|---:|---|---:|
| `stability1_warn87` | 1 | confirm the promoted row-`87` slice anchor | 1 |
| `core12_seedinit` | 3 | exact short replays plus `vb`-init probes for `135`, `174`, `269` | 12 |
| `overall static` | 4 | targeted static closure program | 13 |

### Dynamic stage design

| stage | rows | purpose | run count |
|---|---:|---|---:|
| `row15_replay2` | 1 | exact TT5000 slice replay plus one mild longer control | 2 |

### Why these candidates are included

#### Row `135`

Included:

- `F0835_sub2_s1025` exact short replay
- `F0835_sub2_s1025` with `init_mode=vb`
- `F0825_sub2_s105` with `init_mode=vb`
- `F0840_sub2_s1025` with `init_mode=vb`

Why:

- `F0835_sub2_s1025` is the strongest surviving short-run rescue corridor
- `F0825_sub2_s105` is the only clean historical PASS anchor still worth
  revisiting
- `F0840_sub2_s1025` stays alive only because it is the freshest midpoint WARN
  anchor, but wave-8 changes the init path instead of running it longer again

Excluded:

- another long-run `F0840_sub2_s1025`
- generic scale-`1.000` controls that never helped row `135`
- outer `F085+` row-135 restarts that already screened weak or redundant

#### Row `174`

Included:

- `F0875_sub2_s105` exact short replay
- `F0875_sub2_s105` with `init_mode=vb`
- `F0845_sub2_s100` with `init_mode=vb`
- `F0835_sub2_s1025` with `init_mode=vb`

Why:

- wave-7 showed that running longer or widening around `F0875_sub2_s105` is
  not enough
- the best remaining value is exact replay of the historical rescue plus a new
  init path
- the lower-mid comparators are included only because they already produced
  historical non-`FAIL` evidence on this exact row

Excluded:

- more `F0865/F0880/F0885` long-run widening
- more `slice_eta` probes on row `174`
- any return to broad residual-band search

#### Row `269`

Included:

- `F0825_sub2_s100` exact short replay
- `F0825_sub2_s100` with `init_mode=vb`
- `F0825_sub2_s1025` with `init_mode=vb`
- `F0845_sub2_s100` with `init_mode=vb`

Why:

- `F0825_sub2_s100` is the strongest repeated legacy WARN anchor
- wave-7 showed that longer/slice versions of the same idea regress
- the best remaining value is to keep the strong short-run geometry anchors and
  vary the init path instead

Excluded:

- more `slice_eta` probes on row `269`
- more upper-frontier `F0875+` restarts
- more unchanged scale-`1.000` long-run reruns

#### Dynamic row `15`

Included:

- exact TT5000 `slice_wave2_20260319` replay
- one mild longer TT5000 slice control

Why:

- there is already a known exact historical rescue on this case
- the current-HEAD failed refresh used a different kernel and should not keep
  defining the sidecar plan

Excluded:

- more `laplace_rw` refresh reruns
- broad dynamic family sweeps

## Acceptance Rule

The comparison-ready rule is unchanged:

- every case must be at least `PASS` or `WARN`
- no runtime failures
- no gate `FAIL`s
- `WARN` remains acceptable if documented and scientifically interpretable

Wave-8 is therefore a closure program, not another discovery wave.
