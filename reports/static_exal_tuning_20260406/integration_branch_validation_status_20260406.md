# Exdqlm Validation Status on Synced 0.4.0 Integration Branch

Date: 2026-04-06

## Purpose

This note records the current validation status after moving the exdqlm
validation study onto the synced `0.4.0` continuation branch.

It separates two different concepts that must not be conflated:

1. the **accepted publication-target carry-forward state** for the original
   `288` study cells
2. the **rerun-on-this-branch state** for the new synced
   `validation/rerun-after-0.4.0-sync-0p4p0-integration` worktree

## Branch / Worktree Lineage

Predecessor validation worktree and branch:

- worktree:
  `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`
- branch:
  `validation/rerun-after-0.4.0-sync`

Current active synced continuation point:

- worktree:
  `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration`
- branch:
  `validation/rerun-after-0.4.0-sync-0p4p0-integration`

Integration-base merge commit:

- `66d1e3e`
- summary:
  merge `cransub/0.4.0` into the validation continuation branch

Current synced tracker checkpoint on this branch:

- `2026-04-08` post-localmix closeout
- scope:
  - accepted `v7` remains the authoritative carry-forward baseline
  - document the completed tail6-refine and localmix outcomes
  - keep the dynamic-closure runner-fix finding as established background
  - record that the accepted unresolved tail remains `6 / 288`

## Canonical Status Files

Primary operational tracker for the residual original-`288` study:

- `tools/merge_reports/LOCAL_ORIGINAL288_DYNAMIC_RECOVERY_TRACKER_20260405.md`

Primary branch-level readiness / historical rollup:

- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`

Primary accepted carry-forward artifacts:

- `tools/merge_reports/LOCAL_original288_carryforward_selection_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_row_health_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_health_summary_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_recovery_block_status_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_unresolved_inventory_v7_20260407.csv`

Latest completed rerun execution report:

- `reports/static_exal_tuning_20260408/original_288_syncedbase_dynamic_tail6_localmix_execution_20260408.md`

Active residual repair planning / execution notes:

- `reports/static_exal_tuning_20260408/original_288_syncedbase_dynamic_tail6_localmix_program_20260408.md`
- `reports/static_exal_tuning_20260408/original_288_syncedbase_dynamic_tail6_localmix_execution_20260408.md`
- `reports/static_exal_tuning_20260408/original_288_v7_comparison_analysis_plan_20260408.md`
- `reports/static_exal_tuning_20260408/static_bqrgal_alignment_and_relaunch_plan_20260408.md`
- `reports/static_exal_tuning_20260408/static_bqrgal_aligned_execution_20260408.md`

Machine-readable freeze / planning artifacts:

- `tools/merge_reports/LOCAL_static_bqrgal_aligned_relaunch_grid_v1_20260408.csv`
- `tools/merge_reports/LOCAL_validation_workstreams_v7_freeze_20260408.csv`

## Case Universe In Scope

The active publication-target case universe is the corrected original `288`
study-cell registry:

- `72` `static_paper`
- `144` `static_shrink`
- `72` `dynamic`

Grid structure:

- `static_paper`:
  `3` families x `3` taus x `2` sample sizes x `2` models x `2` inference
- `static_shrink`:
  `3` families x `3` taus x `2` sample sizes x `2` prior semantics x
  `2` models x `2` inference
- `dynamic`:
  `3` families x `3` taus x `2` horizons x `2` models x `2` inference

The families remain:

- `gausmix`
- `laplace`
- `normal`

## Health Convention

The active carry-forward uses the existing gate convention:

- `PASS`: healthy and accepted
- `WARN`: non-failing / usable, but still suspicious or uncertified on some
  diagnostic dimension
- `FAIL`: broken, inconsistent, or not acceptable as a healthy final fit

Operationally, the study currently treats:

- `healthy = PASS or WARN`
- `unhealthy = FAIL`

This is the convention encoded in the row-health and health-summary files.

## Accepted Carry-Forward Status

Accepted publication-target state under `v7`:

- overall healthy: `282 / 288`
- overall unresolved: `6 / 288`
- dynamic healthy: `66 / 72`
- static paper healthy: `72 / 72`
- static shrink healthy: `144 / 144`

Accepted gate breakdown:

| slice | total | PASS | WARN | FAIL | healthy |
|---|---:|---:|---:|---:|---:|
| overall | `288` | `230` | `52` | `6` | `282` |
| dynamic | `72` | `56` | `10` | `6` | `66` |
| static_paper | `72` | `57` | `15` | `0` | `72` |
| static_shrink | `144` | `117` | `27` | `0` | `144` |

Method-level breakdown of the accepted state:

| block | model | inference | PASS | WARN | FAIL |
|---|---|---|---:|---:|---:|
| dynamic | `dqlm` | `mcmc` | `17` | `1` | `0` |
| dynamic | `dqlm` | `vb` | `18` | `0` | `0` |
| dynamic | `exdqlm` | `mcmc` | `6` | `6` | `6` |
| dynamic | `exdqlm` | `vb` | `15` | `3` | `0` |
| static_paper | `al` | `mcmc` | `18` | `0` | `0` |
| static_paper | `al` | `vb` | `18` | `0` | `0` |
| static_paper | `exal` | `mcmc` | `9` | `9` | `0` |
| static_paper | `exal` | `vb` | `12` | `6` | `0` |
| static_shrink | `al` | `mcmc` | `36` | `0` | `0` |
| static_shrink | `al` | `vb` | `36` | `0` | `0` |
| static_shrink | `exal` | `mcmc` | `21` | `15` | `0` |
| static_shrink | `exal` | `vb` | `24` | `12` | `0` |

## Latest Completed Validation Campaign

The latest completed rerun campaign is now:

- `reports/static_exal_tuning_20260408/original_288_syncedbase_dynamic_tail6_localmix_execution_20260408.md`

That campaign:

- reran the accepted-tail-only `6`-row dynamic localmix lane
- yielded:
  - `0 PASS`
  - `0 WARN`
  - `6 FAIL`
  - `0 / 6` healthy
- comparison against accepted:
  - `0` better than accepted
  - `6` matched accepted
  - `0` were worse than accepted
- strict improvements promoted:
  - none

That means the accepted publication-target state stays at:

- `282 / 288` healthy
- `6 / 288` unresolved

Important interpretation from this closeout:

- the runner precedence bug discovered during dynamic closure is now fully
  ruled out as the main explanation for the surviving accepted unresolved tail
- faithfully rerunning the intended closure corridors still did not produce a
  rescue
- the remaining blocker is therefore narrower than before:
  - row-local mixing efficiency
  - ESS-per-1k
  - autocorrelation
  - especially on gamma

## Freeze And Next Relaunch Direction

As of `2026-04-08`, the broader `original288 / v7` study is now treated as
frozen.

That means:

- `original288 / v7` remains the accepted broader validation baseline
- it is no longer treated as the paper-aligned static benchmark
- new paper alignment work should proceed in a separate workstream

Why the split is necessary:

- the current accepted static grid uses `tau = 0p05 / 0p25 / 0p95`
- the local `bqrgal-examples` benchmark uses `p0 = 0.05 / 0.25 / 0.50`
- the current accepted static study uses subsampled fit-input slices from a
  larger simulated master dataset
- the local `bqrgal-examples` benchmark uses replicated train/test simulation
- the current accepted static comparison is a mixed accepted carry-forward
  state, not a direct long-budget MCMC AL-vs-GAL benchmark

Next relaunch direction:

- build a new static paper-aligned benchmark lane
- core lane:
  - `n = 100`
  - `tau = 0.05 / 0.25 / 0.50`
  - families: `normal`, `laplace`, `gausmix`
  - models: `al`, `exal`
  - MCMC only
  - exAL uses `slice`
  - long-budget target equivalent to `150000 / 50000 / 20`
- extension lane:
  - `n = 1000`
  - same families / taus / metric bundle
  - always labeled as not directly paper-matched

The broader validation workstreams remain tracked separately, especially the
dynamic unresolved tail under the frozen `v7` baseline.

## Implemented Paper-Aligned Static Benchmark

The new paper-aligned static benchmark stack has now been implemented and
validated as a separate workstream.

Important implementation choice:

- the benchmark uses the local `bqrgal` reference engine
- it is therefore the closest practical apples-to-apples benchmark against the
  local `bqrgal-examples` scripts
- it should not be conflated with the broader exdqlm continuation study

Implemented benchmark shape:

- phases:
  - `phase1_paper_matched_core`
  - `phase2_extension_n1000`
- total rows:
  `3600`
- phase split:
  - `1800` core paper-matched rows
  - `1800` extension rows
- models:
  `al`, `exal`
- taus:
  `0.05`, `0.25`, `0.50`
- core training size:
  `n = 100`
- extension training size:
  `n = 1000`
- exAL gamma kernel:
  `slice`
- budget:
  `150000 / 50000 / 20`

The execution and reproducibility record for this benchmark is:

- `reports/static_exal_tuning_20260408/static_bqrgal_aligned_execution_20260408.md`

## Remaining Failing Cases

The current unresolved accepted tail is:

- `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
- `dynamic::gausmix::0p25::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
- `dynamic::normal::0p05::500::default::exdqlm::mcmc`
- `dynamic::normal::0p05::5000::default::exdqlm::mcmc`

Shape of remaining unresolved tail:

- all `6` are `dynamic`
- all `6` are `exdqlm :: mcmc`
- `3` are `TT500`
- `3` are `TT5000`
- `5` are `tau = 0p05`
- `1` is `tau = 0p25`

## Rerun Status on This Synced Integration Branch

This is the critical distinction for the new branch:

- accepted carry-forward status exists and is current
- but the accepted evidence still points to the predecessor validation
  worktree outputs

Observed fit-path provenance in the accepted `v7` row-health file:

- selected fit paths in new integration worktree:
  - `35 / 288`
- selected fit paths in predecessor worktree:
  - `253 / 288`

So the rerun-on-synced-base status is no longer pending in the broad sense:

- faithful replay of the accepted healthy `282` rows is complete
- first-pass residual repair of the replay failures is complete
- targeted synced-base follow-up is complete
- the active remaining synced-base work is now a dynamic-only localmix lane of:
  - `6` accepted unresolved dynamic-tail rows
  - `6` total dynamic candidates
- deferred from this launch:
  - already screened closure and tail6-refine rows that looked weak or redundant
  - any replay-repair debt outside the accepted publication tail

Therefore:

- accepted publication-target status: `282 healthy / 6 fail`
- synced-base rerun status:
  - broad fidelity replay complete
  - residual repair complete
  - targeted follow-up complete
  - dynamic closure complete
  - corrected tail6 refine complete
  - dynamic tail6 localmix complete with no promotions

## Synced-Base Replay Status

The first broad synced-base rerun attempted on this branch is now deprecated.

Deprecated program:

- `reports/static_exal_tuning_20260406/original_288_syncedbase_rerun_program_20260406.md`
- `reports/static_exal_tuning_20260406/original_288_syncedbase_rerun_execution_20260406.md`

Deprecation reason:

- static and dynamic MCMC replay were not faithful enough to the accepted
  historical reference state
- in particular, MCMC rows were not consistently inheriting accepted replay
  controls, and original `static_shrink::rhs` rows were not uniformly replayed
  under `rhs_ns`

The active replacement sequence on this branch is now:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_faithful_replay_program_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_faithful_replay_execution_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_program_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_execution_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_targeted_followup_program_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_targeted_followup_execution_20260407.md`
- `reports/static_exal_tuning_20260408/original_288_syncedbase_dynamic_tail6_localmix_program_20260408.md`
- `reports/static_exal_tuning_20260408/original_288_syncedbase_dynamic_tail6_localmix_execution_20260408.md`

Validated faithful-replay structure:

| phase | rows | purpose |
|---|---:|---|
| `phase1_vb_all` | `144` | replay all accepted healthy VB rows |
| `phase2_static_paper_mcmc` | `36` | faithful replay of paper-static MCMC |
| `phase3_static_shrink_ridge_mcmc` | `36` | faithful replay of shrink ridge MCMC |
| `phase4_static_shrink_rhsns_mcmc` | `36` | faithful replay of shrink rhs rows under forced `rhs_ns` |
| `phase5_dynamic_mcmc` | `30` | faithful replay of accepted healthy dynamic MCMC |

Validated operational assumptions:

- accepted reference state still checks out as:
  - `282 / 288` healthy
  - `6 / 288` unresolved
- this faithful replay intentionally scopes to the accepted healthy `282`
  rows only
- predecessor-worktree input files are readable for all reference rows
- all MCMC replay rows have accepted companion VB reference fits
- all original `static_shrink::rhs` replay rows now use
  `prior_override = rhs_ns`
- faithful-replay final state is:
  - `282 / 282` done
  - `198 / 282` healthy
  - `84 / 282` fail

## Faithful-Replay Closeout and Residual Repair Status

The faithful replay answered the main synced-base question clearly:

- `VB` reproduced cleanly
- `dynamic :: mcmc` reproduced reasonably
- the dominant residual problem is now `static :: mcmc`

Observed failure queue after faithful replay:

| residual lane | rows | interpretation |
|---|---:|---|
| `phase1_static_al_mcmc_bugfix` | `54` | invalid runtime failures caused by a shared proposal-resolution bug |
| `phase2_static_exal_mcmc_exact` | `27` | completed-but-unhealthy static `exal :: mcmc` rows needing exact replay / local repair |
| `phase3_dynamic_exdqlm_mcmc_exact` | `3` | completed-but-unhealthy dynamic `exdqlm :: mcmc` rows needing exact replay |
| `total residual queue` | `84` | active next-phase repair scope |

Key interpretation:

- all `54` static `al :: mcmc` failures are operationally invalid
- the remaining `30` rows are scientifically meaningful unhealthy reruns
- the unresolved accepted tail of `6` dynamic `exdqlm :: mcmc` rows remains
  separate from this residual queue and should be reopened only after the
  replay-repair checkpoint is complete

The active next-phase program is now:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_program_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_execution_20260407.md`

## Interpretation

The synced integration branch is now the correct place to continue the study,
because it contains:

- the updated `0.4.0` base
- the latest accepted validation-tracker state
- the accepted `v7` carry-forward artifacts

What exists here right now is:

- a clean synced continuation branch
- the accepted `v7` carry-forward state
- a completed faithful replay of the accepted healthy `282` rows
- completed synced-base residual, follow-up, closure, and tail6-refine evidence
- completed compact row-local dynamic localmix evidence for the remaining `6`
  accepted failures

## Highest-Priority Next Validation Tasks

1. Freeze this branch as the active synced continuation point.
2. Treat accepted `v7` as the working publication-target baseline.
3. Treat the deprecated `2026-04-06` broad rerun as invalid for scientific
   comparison.
4. Focus only on the unresolved `6` dynamic `exdqlm :: mcmc` publication-tail
   rows.
5. Treat the current localmix closeout as informative but non-promotable:
   - do not rerun the same `slice 0.16 / 240` long-row localmix profiles
   - do not rerun the same adaptive non-joint long `RW` normal profile
6. Build the full original-`288` comparison-analysis bundle from accepted `v7`
   before deciding whether more residual tuning is still worth it.
7. Review the completed original-`288` comparison bundle from accepted `v7`:
   - use `reports/static_exal_tuning_20260408/original_288_v7_comparison_analysis_execution_20260408.md`
   - use the audited outputs under `tools/merge_reports/LOCAL_original288_*_v1_20260408.csv`
   - interpret the accepted `282 / 288` state as a whole before reopening any
     more residual tuning
8. If the tail is reopened again, use a smaller row-specific micro-tuning lane
   rather than another broad family band.
9. Keep replay-confidence debt and static work out of the accepted-tail lane
   unless new evidence makes them necessary again.

## Original-288 Comparison Analysis Status

The comparison-analysis bundle from accepted `v7` is now complete and audited.

Completed comparison artifacts:

- `tools/merge_reports/LOCAL_original288_comparison_long_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_broad_comparison_table_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_static_scenario_comparison_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_scenario_comparison_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_static_model_pair_summary_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_static_inference_pair_summary_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_model_pair_summary_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_inference_pair_summary_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_warn_inventory_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_fail_inventory_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_comparison_audit_v1_20260408.csv`

Comparison-analysis execution note:

- `reports/static_exal_tuning_20260408/original_288_v7_comparison_analysis_execution_20260408.md`

Audit outcome:

- comparison-long rows: `288`
- `WARN` rows: `52`
- `FAIL` rows: `6`
- total scenarios: `72`
- pair tables:
  - static model: `108`
  - static inference: `108`
  - dynamic model: `36`
  - dynamic inference: `36`
- accepted summary totals match `v7`
- accepted method breakdown totals match `v7`
- fail inventory matches the unresolved dynamic `v7` tail exactly

High-level read from the audited bundle:

- the accepted `v7` comparison baseline is fully usable as a study-level
  comparison bundle
- the unresolved tail remains exactly the known `6` dynamic
  `exdqlm :: mcmc` rows
- static comparison remains complete and interpretable
- dynamic comparison remains interpretable, but it must be read with the
  explicit unresolved tail in view
