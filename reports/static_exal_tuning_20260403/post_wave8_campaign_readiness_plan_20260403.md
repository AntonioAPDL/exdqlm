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

### Highest-value directions now

1. treat the completed static refresh as the new repair-planning baseline
2. keep `F085_sub2_s100` as the broad default baseline, not the only tuning
   profile
3. use the completed local repair map as the new active static baseline for
   the residual band
4. spend new compute only on:
   - confirming the chosen local repair map
   - probing the WARN-only rows with row-specific high-value exceptions
5. repair or replace dynamic row `15` under current `HEAD`
6. merge the reusable refreshed outputs only after the residual FAIL band is
   eliminated and the local repair map is confirmed

## Updated Remaining Comparison Debt

The current goal is not to relaunch the full `291`-row campaign. The current
goal is to reuse all trustworthy artifacts and rerun only the stale or still
failing debt.

| workstream | cases | current state | why still needed |
|---|---:|---|---|
| refreshed static non-FAIL rows | 42 | reusable now | these are already valid and should not be rerun |
| previously reusable campaign artifacts | 218 | reusable now | these do not require rerun if provenance is preserved |
| resolved residual-band static rows under `F085_sub2_s100` | 21 | provisionally reusable repair coverage | these no longer need active repair search |
| provisional static repair-map rows | 9 | locally resolved from completed evidence | these define the promoted local static baseline |
| WARN-only static confirmation/probe rows | 3 | high-risk but not failing | these define the next-wave static scope |
| dynamic tail row `15` | 1 | current-HEAD refresh still `FAIL` | only remaining dynamic unresolved row |

Minimal active scientific debt after the completed wave-4 closeout:

- `4` cases total (`3` static WARN-only scenarios + `1` dynamic sidecar)
- not `10`

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
- [ ] Promote the local repair map from wave-4 as the active static residual
      baseline

### Phase B: Confirm the local static repair map

- [ ] rerun only the `9` selected local repair-map rows under fresh final tags
- [ ] preserve separate current RHS-NS and legacy RHS scope labels
- [ ] probe only the WARN-only stubborn rows with row-specific high-value
      exceptions
- [ ] do not reopen any broad shared-setup search
- [ ] preserve deterministic manifests, failure logs, supervisor logs, and
      monitor heartbeats

### Phase C: Keep the dynamic tail debt separate but active

- [ ] open a narrow row-`15` current-HEAD refresh/repair lane
- [ ] do not let row `15` block preparation of the larger static rerun
- [ ] treat row `15` as the only remaining dynamic debt; do not relaunch rows
      `5` or `57`

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

1. confirm the local static repair map and close the remaining WARN-only
   uncertainty
2. clean up dynamic row `15`
3. regenerate the full campaign tables once all FAILs are removed

That is the shortest rigorous path from the current branch state to a
comparison-ready and publication-ready validation summary.
