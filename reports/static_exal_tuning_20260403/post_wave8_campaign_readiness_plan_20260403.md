# Validation Campaign: Post-Wave-8 Baseline and Comparison-Readiness Plan

Date: 2026-04-03

Current tracked context:

- `reports/static_exal_tuning_20260403/wave8_closeout_and_fail_only_repair_program.md`
- `reports/static_exal_tuning_20260403/fail_only_bridge_results_20260403.md`
- `reports/static_exal_tuning_20260403/campaign_completion_execution_20260403.md`
- `tools/merge_reports/LOCAL_VALIDATION_RECOVERY_TRACKER_STATIC_EXAL_20260331.md`
- `tools/merge_reports/full288_dynamic_tail_cppgig_refresh_20260331/rows/row_0005.csv`
- `tools/merge_reports/full288_dynamic_tail_cppgig_refresh_20260331/rows/row_0015.csv`

## Status Note

This is the active planning document after wave-8 closeout and the fail-only
bridge repair.

It replaces the earlier question of "which tuning family should we trust next?"
with the current operational question: "what is the minimum remaining work to
reach a comparison-ready full validation campaign?"

The execution record for the focused completion phase now lives in:

- `reports/static_exal_tuning_20260403/campaign_completion_execution_20260403.md`

The post-refresh closeout and next-wave fail-band plan now lives in:

- `reports/static_exal_tuning_20260403/static_refresh_closeout_and_failband_program_20260403.md`

The active overnight fail-band execution program now lives in:

- `reports/static_exal_tuning_20260403/failband_wave1_overnight_program_20260403.md`

The completed wave-1 closeout and active broad staged wave-2 program now live
in:

- `reports/static_exal_tuning_20260404/failband_wave1_closeout_and_wave2_broad_program_20260404.md`

The wave-2 closeout and active residual-only wave-3 program now live in:

- `reports/static_exal_tuning_20260404/failband_wave2_closeout_and_wave3_residual_program_20260404.md`

The wave-3 closeout and active targeted wave-4 repair program now live in:

- `reports/static_exal_tuning_20260404/failband_wave3_closeout_and_wave4_targeted_repair_program_20260404.md`

The wave-4 closeout and active local repair confirmation/probe program now live
in:

- `reports/static_exal_tuning_20260404/failband_wave4_closeout_and_wave5_local_repair_program_20260404.md`

The wave-5 closeout and active row-specific closure program now live in:

- `reports/static_exal_tuning_20260404/failband_wave5_closeout_and_wave6_row_specific_closure_program_20260404.md`

The wave-6 closeout and active triplet-closure wave-7 program now live in:

- `reports/static_exal_tuning_20260404/failband_wave6_closeout_and_wave7_triplet_closure_program_20260404.md`

## Historical Baseline Promotion

The latest completed results do improve the previous exact-runner baseline.
After the completed static refresh, `F080_sub2_s105` should be treated as the
active repair-planning reference wave, not as a signoff-ready production
baseline.

| role | candidate_id | evidence | current decision |
|---|---|---|---|
| historical stage-budget winner | `C060_110_sub2` | wave-5 `mix12`: `10 PASS / 2 WARN / 0 FAIL` | historical tuning winner only; not the active validation rerun baseline |
| prior exact-runner baseline | `F080_sub2_s100` | wave-7: `7 PASS / 4 WARN / 1 FAIL` | superseded |
| active repair-planning reference wave | `F080_sub2_s105` | wave-8: `22 PASS / 4 WARN / 0 FAIL` | promote for fail-band planning, not final signoff |
| primary backup | `F080_sub2_s100_ref` | wave-8: `19 PASS / 7 WARN / 0 FAIL` | keep as fallback control |
| secondary bridge option | `F080_sub2_s0975` | fail-only bridge: `1 PASS / 1 WARN / 0 FAIL` | optional narrow hedge only |

Important revision after the completed static refresh:

- `F080_sub2_s105` remains the best completed broad exact-runner reference wave
- `F080_sub2_s105` is **not** the final production campaign baseline because
  the completed `72`-row static refresh still left `30` FAIL scope-cases
- the completed refresh should now be treated as the empirical reference wave
  for fail-band repair planning, not as the signoff-ready endpoint

Important refinement after the wave-2 residual-band closeout:

- `F080_sub2_s105` remains the best completed broad refresh reference wave
- `F085_sub2_s100` is now the best completed residual-band repair baseline on
  the `30`-row fail band
- `F0825_sub2_s100` is now the strongest complementary residual-band control
- the active residual search space is no longer the broad `F080` to `F0875`
  neighborhood; it is now the tighter bridge band from `F0825` to `F085`
  with scale in `[1.000, 1.025]`

Important refinement after the completed wave-3 bridge closeout:

- `F085_sub2_s100` remains the best completed broad residual-band baseline
- `F0825_sub2_s100` and `F0835_sub2_s1025` remain useful complements, but
  neither beats `F085_sub2_s100` on the full `30`-row confirmation pass
- the active static repair debt is now most usefully expressed as the `9` rows
  still failing under `F085_sub2_s100`, not as the full old `30`-row band
- the next credible search shape is a targeted repair matrix on those `9`
  rows only

Important refinement after the completed wave-4 targeted repair closeout:

- `F085_sub2_s100` remains the default broad residual-band baseline
- a default-plus-local repair map now improves the full `9`-row residual band
  to:
  - `6 PASS`
  - `3 WARN`
  - `0 FAIL`
- the promoted static baseline is now:
  - default: `F085_sub2_s100`
  - local overrides only on the rows where the default still fails
- the active static uncertainty is no longer failure elimination across the
  `9`-row band; it is confirmation/probing of the three WARN-only rows:
  - current `87`
  - current `174`
  - legacy `269`

Important refinement after the completed wave-5 local confirmation/probe
closeout:

- `F085_sub2_s100` remains the broad static default baseline
- the wave-4 provisional local map should no longer be used unchanged
- the active local baseline is now better expressed as an evidence-weighted
  repair map v2:
  - stable/default-adjacent rows keep their strongest repeated non-`FAIL`
    option
  - rows `135`, `190`, and `269` remain the core static closure rows
- the active static closure problem is now:
  - `3` core `FAIL` rows needing direct repair work
  - `6` non-`FAIL` rows needing only confirmation/provenance under the updated
    local map
- the next credible search shape is row-specific closure, not another generic
  bridge search

Important refinement after the completed wave-6 row-specific closure closeout:

- `F085_sub2_s100` remains the broad static default baseline
- the local static baseline should now be treated as `v3`, not `v2`
- wave-6 clearly improved row `135`:
  - promote `F0840_sub2_s1025` as the preferred row-`135` local override
- rows `115`, `181`, and `278` remain stable `PASS`
- rows `135`, `190`, and `206` are now the non-`FAIL` stability/provenance
  lane
- the static blocking core is now only:
  - `87`
  - `174`
  - `269`
- the next credible search shape is a row-local triplet-closure lane plus a
  tiny stability lane, not another band-scale sweep

Important refinement after the completed wave-7 triplet closeout
and dynamic replay discovery (2026-04-05):

- `F085_sub2_s100` remains the broad static default baseline
- the local static baseline should now be treated as `v4`
- row `87` improved from `FAIL` to `WARN` and should now use:
  - `F085_sub2_s1025_slice`
- row `206` improved from reusable `WARN` to fresh `PASS` and should now use:
  - `F0825_sub2_s1025_rwlong`
- row `190` remains non-`FAIL` and should now use:
  - `F0825_sub2_s100_rwlong`
- the static blocking core remains:
  - `135`
  - `174`
  - `269`
- dynamic row `15` is no longer missing a repair hypothesis:
  an exact historical TT5000 `slice_wave2_20260319` replay already gated to
  `WARN / healthy = TRUE`
- the next credible search shape is therefore:
  - one row-`87` confirmation
  - exact short replay plus `vb`-init probes on `135`, `174`, and `269`
  - a tiny dynamic row-`15` slice replay sidecar

## Main Takeaways

### What improved

- wave-8 completed end to end under the repaired resume stack; orchestration is
  no longer the main blocker
- `F080_sub2_s105` became the first clear zero-FAIL exact-runner carry-forward
  candidate in the final `F080` neighborhood
- the fail-only bridge run resolved the remaining ambiguity:
  - `F075_sub2_s095` is dominated and should be dropped
  - `F080_sub2_s095` failed because it was slightly too tight, not because the
    `F080` family is broken
- dynamic tail row `5` improved from `failed_runtime` to `done / PASS / TRUE`
  under `full288_dynamic_tail_cppgig_refresh_20260331`
- dynamic tail row `15` still fails, but its refreshed current-HEAD run now
  finishes much faster than the older refresh and narrows the remaining dynamic
  problem to chain quality rather than pure runtime stall

### What still fails or remains unresolved

- the completed `72`-row static refresh improved the stale slice, but still
  leaves `30` FAIL scope-cases:
  - `21` current RHS-NS
  - `9` legacy RHS
- dynamic row `15` remains `done / FAIL / FALSE` under
  `full288_dynamic_tail_cppgig_refresh_20260331`
- the campaign-level merged health tables and publishable comparison summary
  table still cannot be signed off because the campaign still violates the
  `0 FAIL` rule
- the remaining scientific uncertainty is now much narrower:
  it is concentrated in the static fail band identified by the completed
  refresh plus the dynamic row `15` sidecar

### What worked best

1. `F080`-family exact-runner candidates with `gamma_substeps = 2`
2. slightly widened scale around the `F080` center, especially
   `F080_sub2_s105`
3. narrow, fail-only bridge experiments rather than reopening the whole grid
4. the repaired orchestration stack:
   deterministic manifests, auditable logs, locked summaries, supervisor, and
   live monitor
5. local row-level tuning once the broad shared search was exhausted
6. evidence-weighted baseline promotion after wave-5 instead of trusting the
   first provisional local map unchanged
7. after wave-6, letting the remaining hard rows use row-specific execution
   controls instead of pretending geometry-only tuning is still sufficient

### What clearly did not work

- the `C060` family as the active exact-runner carry-forward baseline
- `F075_sub2_s095`, which repeatedly failed on the same row and is now
  dominated
- `F080_sub2_s095` as a full carry-forward candidate; it is too tight
- aggressive `F090 / F095` frontier families
- lambda-tempering, no-jump, and pathological `substeps = 3` lanes
- any broad rerun before exact-runner carry-forward evidence was clean
- continuing to chase a single generic residual-band setup after wave-4 had
  already shown that a local repair map is better
- preserving the wave-4 provisional local choices after wave-5 directly
  weakened several of them
- repeating scale-`1.000` controls on row `269` without changing anything else
  once they had already regressed multiple times

### Highest-value directions now

1. treat the completed static refresh as the new repair-planning baseline
2. keep `F085_sub2_s100` as the broad default baseline, not the only tuning
   profile
3. use the completed local repair map as the new active static baseline for
   the residual band
4. update that local map again after wave-6 where fresh results clearly
   improved the old choices
5. spend new compute only on:
   - confirming the non-`FAIL` `v3` map on rows `135`, `190`, and `206`
   - repairing rows `87`, `174`, and `269`
6. allow a very small row-specific execution-control lane
   - longer run length
   - targeted `slice_eta` pilots on the remaining hard rows only
7. repair or replace dynamic row `15` under current `HEAD`
8. merge the reusable refreshed outputs only after the residual FAIL band is
   eliminated and the local repair map is confirmed

Latest refinement after wave-7:

1. do not spend more compute on another generic shared setup
2. keep `F085_sub2_s100` as the broad default and let the local map carry the
   remaining closure work
3. use exact historical non-`FAIL` anchors as the geometry baseline for rows
   `135`, `174`, and `269`
4. use `init_mode = vb` as the new high-value static closure axis
5. replay the exact TT5000 dynamic slice rescue for row `15` before trying any
   broader dynamic alternatives

Latest refinement after the wave-8 static root-cause checkpoint (2026-04-05):

1. the static wave-8 stop was real and two-part:
   - rows `135` and `174` crashed under `init_mode = vb`
   - the static launcher/supervisor path allowed those crashed rows to remain
     `MISSING` while still exiting as if the stage had completed
2. the launcher now treats `missing > 0` after launch as a hard failure
3. row `269` improved from `FAIL` to `WARN` and should now promote:
   - `F0845_sub2_s100_vb`
4. row `87` is no longer just a warn-only confirmation item; it is now an
   unstable exact-history replay problem after the fresh wave-8 replay
   regressed to `FAIL`
5. `init_mode = vb` should now be treated as:
   - useful for row `269`
   - explicitly low-value for rows `135` and `174`
6. the next credible static search shape is:
   - exact historical seed replay on row `87`
   - exact historical short anchors plus `init_mode = none` on rows `135` and
     `174`
   - confirmation / hardening of the promoted row-`269` local rescue

Latest refinement after the completed wave-9 closeout (2026-04-05):

1. wave-9 closed three of the four active static endgame rows:
   - row `135` -> `PASS`
   - row `174` -> `WARN`
   - row `269` -> `WARN`
2. dynamic row `15` is now resolved to `WARN / healthy = TRUE` under the exact
   TT5000 slice replay
3. the campaign now has only one remaining blocking case:
   - static row `87`
4. row `87` is not a broad-family problem; it is now a one-row chain-quality
   stabilization problem inside the tiny `F085` / `F0855` scale-`1.025`
   micro-band
5. the next and likely last credible search shape is:
   - exact anchor confirmations,
   - slightly longer confirmations,
   - and a tiny micro-band expansion on row `87` only

## Updated Remaining Comparison Debt

The current goal is not to relaunch the full `291`-row campaign. The current
goal is to reuse all trustworthy artifacts and rerun only the stale or still
failing debt.

| workstream | cases | current state | why still needed |
|---|---:|---|---|
| refreshed static non-FAIL rows | 42 | reusable now | these are already valid and should not be rerun |
| previously reusable campaign artifacts | 218 | reusable now | these do not require rerun if provenance is preserved |
| resolved residual-band static rows under `F085_sub2_s100` | 21 | reusable broad default coverage | these no longer need active repair search |
| promoted local repair baseline v3 rows | 9 | locally resolved from completed evidence | these define the active row-specific static baseline |
| static blocking core | 0 | no longer blocking after wave-9 | none |
| static unstable local exception | 1 | still needs final closure | row `87` |
| promoted warn-only local rescues | 2 | now reusable under the active local map | rows `174`, `269` |
| promoted local PASS | 1 | now reusable under the active local map | row `135` |
| static stability/provenance rows | 2 | non-`FAIL`, no new search needed now | rows `190`, `206` |
| dynamic tail row `15` | 1 | resolved to `WARN` | reusable resolved sidecar |

Minimal active scientific debt after the completed wave-6 closeout:

- `4` blocking cases total (`3` static blocking rows + `1` dynamic sidecar)
- plus `3` static non-`FAIL` stability rows
- not `7`

Minimal active scientific debt after the completed wave-9 closeout:

- only `1` blocking case remains:
  - static row `87`
- dynamic row `15` is now resolved to `WARN`
- rows `135`, `174`, and `269` are now resolved to non-`FAIL`

## Comparison-Ready Acceptance Rule

For the final publishable campaign summary, the acceptance target should be:

| criterion | requirement |
|---|---|
| full campaign coverage | all targeted cases represented in the merged final table |
| stale baseline debt | `0` stale rows remaining |
| runtime failures | `0` |
| gate FAIL count | `0` |
| gate WARN count | acceptable if documented and scientifically interpretable |
| provenance | each refreshed slice tagged and traceable to its manifest and baseline |

This keeps the standard aligned with the working rule already used in the
study: `WARN` can be tolerated, `FAIL` cannot.

## Recommended Next-Phase Plan

### Phase A: Freeze the promoted reference wave

- [ ] Keep `F080_sub2_s105` as the historical repair-planning reference wave
- [ ] Keep `F085_sub2_s100` as the broad static default baseline
- [ ] Promote the evidence-weighted local repair baseline v3 as the active
      static residual baseline

### Phase B: Confirm the local static repair map

- [ ] keep `F085_sub2_s100` as the broad static default baseline
- [ ] probe only the remaining blocking row:
      `87`
- [ ] use only:
      exact historical anchor confirmation,
      slightly longer confirmation,
      and a tiny micro-band expansion around the only surviving row-`87`
      corridors
- [ ] preserve separate current RHS-NS and legacy RHS scope labels
- [ ] do not reopen any broad shared-setup search
- [ ] preserve deterministic manifests, failure logs, supervisor logs, and
      monitor heartbeats

### Phase C: Keep the dynamic tail debt separate but active

- [ ] keep the resolved row-`15` slice replay as the active dynamic local
      baseline
- [ ] do not let row `15` trigger another broad dynamic search
- [ ] do not relaunch rows `5`, `15`, or `57` unless later regression work is
      required

### Phase D: Merge and summarize the refreshed campaign

- [ ] merge the refreshed `72` static rows and refreshed row `15` with the
      existing reusable artifacts
- [ ] regenerate campaign-level health tables
- [ ] produce summary distributions by model, inference, root kind, family, and
      tau
- [ ] produce the final comparison-ready summary table used for reporting

### Phase E: Stop rule if a narrow residual fail band remains

- [ ] if the refreshed `72`-row rerun leaves only a narrow residual fail band,
      do not reopen a broad tuning search
- [ ] isolate only the remaining failing rows and repair them with the same
      narrow fail-only discipline used successfully after wave-8

## Operational Bottom Line

The study is in a materially better place now.

The open problem is no longer "find a plausible static tuning family" and it is
no longer "fix the resume chain." The open problem is now much cleaner:

1. close row `87` with one final disciplined micro-band program
2. freeze the promoted local baselines for `135`, `174`, `269`, and row `15`
3. regenerate the full campaign tables once row `87` is non-`FAIL`

That is the shortest rigorous path from the current branch state to a
comparison-ready and publication-ready validation summary.
