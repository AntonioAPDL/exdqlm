# Static exAL Tuning: Wave-4 Finish and Wave-5 Overnight Plan

Date: 2026-03-31

Follow-on state and the next targeted program are recorded in:

- `reports/static_exal_tuning_20260401/wave5_baseline_and_wave6_program.md`

## Wave-4 Finish: Main Takeaways

The narrow finish selected:

- `JF2_sub2_p007_s100`

over the previous anchor:

- `GJ1_sub2_jump005`

### Final mix12 comparison

| candidate_id | pass_n | warn_n | fail_n | healthy_n | gate_points | composite |
|---|---:|---:|---:|---:|---:|---:|
| `GJ1_sub2_jump005` | 3 | 9 | 0 | 12 | 15 | 8.848194 |
| `JF2_sub2_p007_s100` | 7 | 5 | 0 | 12 | 19 | 9.447503 |

### What improved

- keeping `gamma_substeps = 2`
- increasing `p_global_eta_jump` from `0.05` to `0.07`
- keeping `global_eta_jump_scale = 1.0`
- keeping `rhsns_lambda_power = 1.0`

### What clearly did not help

- mild lambda tempering (`LM1`, `LM2`)
- very large jump scale (`JS3`, `scale = 1.5`)
- low-jump `substeps = 3` geometry (`SG1`)
- reopening no-jump or pure-lambda families

### Operational lesson

The most efficient search pattern is now:

1. keep the shared-core crash fix in place
2. search only in the local `JF2` geometry neighborhood
3. treat `FAIL` as the primary blocker and `WARN` as acceptable
4. stop using broad families that already showed weak quality or pathological runtime behavior

## Wave-5 Overnight Objective

Run a broad but targeted overnight matrix around the `JF2` neighborhood to determine whether any nearby configuration can improve on:

- `7 PASS / 5 WARN / 0 FAIL / 12 healthy`

without reopening crash failures or runtime pathologies.

## Candidate Families To Explore

### Frequency neighborhood

- small increases and decreases around `p_global_eta_jump = 0.07`

### Jump-scale neighborhood

- mild scale adjustments around `global_eta_jump_scale = 1.0`
- no return to `1.5`

### Coupled frequency-scale variants

- a few local combinations near the current winner

### Restricted substeps-3 variants

- only high-jump `substeps = 3` variants near `JF2`
- do not revisit low-jump `substeps = 3`

## Candidate Families To Exclude

Do not rerun:

- lambda tempering families
- pure no-jump families
- pure jump-only baselines already dominated by `JF2`
- aggressive jump-scale variants already shown to degrade smoke or canary quality
- low-jump `substeps = 3` families

## Wave-5 Stage Plan

| Stage | Purpose | Rows | Decision use |
|---|---|---|---|
| `smoke` | catch immediate pathologies | `261,83` | must be crash-safe |
| `crash6` | verify crash-band safety | `83,107,131,165,213,261` | must stay `0` runtime failures |
| `quality8` | rank hard quality rows | `91,99,115,197,245,277,181,229` | promote strongest quality variants |
| `mix12` | final same-seed decision | `75,99,123,91,115,139,149,197,245,181,229,277` | compare against `JF2` anchor |

## Promotion Rules

### smoke -> crash6

- `crash_safe = TRUE`

### crash6 -> quality8

- `crash_safe = TRUE`

### quality8 -> mix12

- `fail_n = 0`
- no `FAIL` on rows `99`, `245`, or `277`
- rank by:
  1. more `healthy`
  2. more gate points
  3. better composite

### Final overnight winner

Compare against `JF2_sub2_p007_s100`.

Select a challenger only if it:

1. keeps `fail_n = 0`
2. matches or exceeds `healthy_n`
3. improves gate points or composite

Otherwise keep `JF2` as the production rerun baseline.

## Resource Plan

- stage-level candidate parallelism for `smoke`, `crash6`, and `quality8`
- smaller survivor sets into `mix12`
- no reruns of the existing `JF2` anchor except for anchor-comparison summaries
- use skip-existing semantics whenever a stage is resumed

## Expected Outcome

By the end of the overnight run we should have either:

1. a new winner that strictly improves on `JF2`, or
2. stronger evidence that `JF2_sub2_p007_s100` is stable enough to carry the focused `72`-row static rerun.
