# Validation Campaign: Static Fail-Band Wave-1 Overnight Program

Date: 2026-04-03

Primary references:

- `reports/static_exal_tuning_20260403/static_refresh_closeout_and_failband_program_20260403.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `reports/static_exal_tuning_20260403/fail_only_bridge_results_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_fail_inventory_20260403.csv`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_fail_patterns_20260403.csv`

## Status Note

This is the active next-wave execution program after the completed
`F080_sub2_s105` static refresh closeout.

The study is no longer in broad tuning search. The active goal is now:

1. eliminate the residual static fail band as efficiently as possible
2. preserve the `260` already reusable artifacts
3. keep dynamic row `15` separate until a real repair hypothesis exists

## Current Validated State

### What improved

- the stale static `72`-row slice was refreshed under a scope-correct runner
- the static fail burden fell from `60` FAIL scope-cases to `30`
- the branch now has a reproducible fail inventory and fail-pattern summary
- orchestration risk is low relative to earlier waves because the runner,
  manifest, summary-lock, supervisor, and monitor stack are already proven

### What still fails

- `30` static FAIL scope-cases remain:
  - `21` current RHS-NS
  - `9` legacy RHS
- these `30` scope-cases collapse to `15` unique `(family, tau, tt)` patterns
- dynamic row `15` remains an unresolved sidecar debt

### What worked best

1. `F080`-neighborhood exact-runner candidates with `gamma_substeps = 2`
2. narrow fail-only bridge work instead of reopening the entire tuning grid
3. keeping `WARN` tolerable but treating `FAIL` as the true repair boundary
4. scope-aware current-vs-legacy prior handling

### What clearly did not work

1. promoting `F080_sub2_s105` directly to a signoff-ready campaign baseline
2. revisiting dominated candidates:
   - `F075_sub2_s095`
   - `F080_sub2_s095`
3. reopening broader weak families:
   - `C060`
   - aggressive `F090 / F095`
   - lambda-tempering, no-jump, and pathological `substeps = 3`

### Highest-value directions now

1. rerun only the residual static fail band
2. explore only nearby candidate geometries with prior evidence of viability
3. keep `F080_sub2_s105` as the empirical comparison reference wave
4. defer dynamic row `15` until there is a genuine repair or replacement idea

## Why This Program Is Broad Enough But Still Efficient

The residual fail band is already narrow enough that the most informative broad
search is no longer a `72`-row rerun or another full-neighborhood transfer
wave. It is a focused screen over the remaining `30` failing scope-cases.

This gives the best current compute-to-learning tradeoff because:

- every run in this program directly touches unresolved campaign debt
- current and legacy scope semantics are preserved
- already-valid artifacts are not rerun
- the candidate grid stays inside the only neighborhood that has consistently
  produced viable exact-runner behavior

## Wave-1 Search Space

### Included candidates

| candidate_id | jump | scale | why included |
|---|---:|---:|---|
| `F080_sub2_s100_ref` | 0.0800 | 1.000 | strongest direct backup control from wave-8 |
| `F080_sub2_s0975` | 0.0800 | 0.975 | repaired bridge for the tight `F080` boundary |
| `F0825_sub2_s100` | 0.0825 | 1.000 | midpoint between `F080` and `F085`; tests slightly more movement without scale widening |
| `F075_sub2_s105` | 0.0750 | 1.050 | lower-jump zero-FAIL control; useful hedge against over-aggressive movement |
| `F085_sub2_s095` | 0.0850 | 0.950 | upper-edge tempered control; probes whether the fail band wants more movement but tighter scale |
| `F085_sub2_s105` | 0.0850 | 1.050 | upper-edge wide control; probes whether the fail band wants both more movement and more scale |

### Explicit exclusions

Do **not** rerun:

- `F080_sub2_s105`
  because it already defines the completed reference wave on all `30` rows
- `F075_sub2_s095`
  because it is dominated
- `F080_sub2_s095`
  because the bridge evidence already shows the tighter scale is the problem
- `C060`, `F090`, `F095`, lambda-tempering, no-jump, and `substeps = 3`
  because earlier waves already showed these are weak or unhelpful

## Exact Scope

### Static lane

- target only the `30` residual static FAIL scope-cases
- preserve separate current RHS-NS and legacy RHS labels
- reuse the exact same campaign-equivalent MCMC budget and runner semantics
  used for the completed refresh

Wave-1 size:

| item | count |
|---|---:|
| candidate profiles | 6 |
| residual FAIL scope-cases | 30 |
| total screen runs | 180 |

### Dynamic sidecar

- dynamic row `15` is not launched in this wave
- reason: the current evidence shows a chain-quality failure, but there is no
  new repair hypothesis yet that makes an immediate rerun informative

## Execution Design

### Stage

Single active stage:

- `screen30`
  - run all `6` candidate profiles across all `30` residual static FAIL
    scope-cases

This is intentionally a single broad-but-targeted screen because:

- the scope is already small enough
- it avoids wasting time on another mini-screen that would still need to be
  widened later
- it produces direct candidate-vs-candidate evidence on the full unresolved
  campaign debt

### Baseline comparison

`F080_sub2_s105` is not rerun in this wave. Its completed static refresh
outputs remain the reference results for all `30` rows.

Every row in this new wave therefore starts from the same known baseline:

- current reference state: `FAIL`
- candidate objective: upgrade that row from `FAIL` to `WARN` or `PASS`

## Decision Rules

### Candidate ranking

Rank candidates by:

1. lowest FAIL count
2. lowest WARN count
3. highest PASS count

### Promotion rule

- if any candidate clears all `30` rows to `0 FAIL`, it becomes the leading
  campaign-repair candidate
- if multiple candidates achieve `0 FAIL`, prefer the one with the most PASS
  and then the fewest WARN

### Follow-up rule

- if no candidate reaches `0 FAIL`, do **not** reopen the full campaign
- isolate only the residual rows that still fail under the best one or two
  candidates and launch a narrower wave-2 repair program

## Operational Plan

### Prepare and validate

- generate a deterministic `30`-row fail-band schedule
- verify candidate coverage:
  - `6` candidates
  - `21` current rows
  - `9` legacy rows
  - `180` total runs
- verify that each scheduled row is a baseline `FAIL` in the completed refresh

Readiness verification completed before the overnight launch:

- prepare-only validation confirmed:
  - `180` scheduled runs total
  - `126` current RHS-NS runs
  - `54` legacy RHS runs
  - `30` fail rows per candidate
- a two-row live smoke was executed under `F080_sub2_s100_ref`:
  - current row `79` finished `WARN`
  - legacy row `269` finished `FAIL`
- interpretation:
  - the new fail-band launcher, candidate paths, summary writes, and
    current-vs-legacy prior semantics are working as intended
  - the smoke was a tooling validation, not a scientific decision result

### Launch

- use the existing case runner
- keep the same campaign-equivalent budget:
  - `n_burn = 2000`
  - `n_mcmc = 1000`
  - `thin = 1`
- use `6` parallel jobs
- run under a supervisor and live monitor in tmux

### Expected outcome

This wave should tell us one of two things:

1. one of the nearby zero-FAIL or near-zero-FAIL candidates generalizes across
   the full residual static fail band
2. the remaining unresolved band is narrower and more structured than the
   current `30` scope-cases, which justifies a smaller wave-2 repair program

## Operational Bottom Line

This is the right next wave because it is:

- broad enough to test real nearby alternatives
- disciplined enough to avoid rerunning already-valid work
- directly tied to the unresolved campaign debt
- compatible with the final goal of a comparison-ready merged campaign with
  `0` runtime failures and `0` gate FAILs
