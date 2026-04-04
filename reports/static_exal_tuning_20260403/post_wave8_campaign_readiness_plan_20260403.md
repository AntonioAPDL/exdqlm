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

### What clearly did not work

- the `C060` family as the active exact-runner carry-forward baseline
- `F075_sub2_s095`, which repeatedly failed on the same row and is now
  dominated
- `F080_sub2_s095` as a full carry-forward candidate; it is too tight
- aggressive `F090 / F095` frontier families
- lambda-tempering, no-jump, and pathological `substeps = 3` lanes
- any broad rerun before exact-runner carry-forward evidence was clean

### Highest-value directions now

1. treat the completed static refresh as the new repair-planning baseline
2. treat `F085_sub2_s100` as the new residual-band repair baseline and
   `F0825_sub2_s100` as the complementary control
3. search only inside the surviving bridge neighborhood:
   `F0825` through `F085`, scale `1.000` through `1.025`
4. spend broad compute only on the `18` still-informative residual rows, then
   confirm finalists on the full `30`
5. repair or replace dynamic row `15` under current `HEAD`
6. merge the reusable refreshed outputs only after the residual FAIL band is
   eliminated

## Updated Remaining Comparison Debt

The current goal is not to relaunch the full `291`-row campaign. The current
goal is to reuse all trustworthy artifacts and rerun only the stale or still
failing debt.

| workstream | cases | current state | why still needed |
|---|---:|---|---|
| refreshed static non-FAIL rows | 42 | reusable now | these are already valid and should not be rerun |
| previously reusable campaign artifacts | 218 | reusable now | these do not require rerun if provenance is preserved |
| residual static FAIL scope-cases | 30 | unresolved | these now define the next-wave static repair scope |
| dynamic tail row `15` | 1 | current-HEAD refresh still `FAIL` | only remaining dynamic unresolved row |

Minimal unresolved campaign debt after the completed static refresh:

- `31` cases total (`30` static fail scope-cases + `1` dynamic sidecar)
- not `73`

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

- [ ] Freeze `F080_sub2_s105` as the active static `exal` repair-planning
      reference wave
- [ ] Keep `F080_sub2_s100_ref` as the fallback control in case the full rerun
      exposes a concentrated regression
- [ ] Record `F080_sub2_s0975` as a secondary bridge candidate, not the primary
      production baseline

### Phase B: Prepare the fail-band-only static repair wave

- [ ] isolate only the `30` residual static FAIL scope-cases
- [ ] preserve separate current RHS-NS and legacy RHS scope labels
- [ ] prioritize the recurring cross-scope fail anchors and dominant family/tau
      clusters
- [ ] use the completed `F080_sub2_s105` refresh as the empirical comparison
      baseline for next-wave candidates
- [ ] do not rerun the `42` refreshed static non-FAIL rows
- [ ] run the active wave-1 overnight screen across the `6` retained nearby
      candidate profiles only
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

1. isolate and repair the residual `30`-case static fail band
2. clean up dynamic row `15`
3. regenerate the full campaign tables once all FAILs are removed

That is the shortest rigorous path from the current branch state to a
comparison-ready and publication-ready validation summary.
