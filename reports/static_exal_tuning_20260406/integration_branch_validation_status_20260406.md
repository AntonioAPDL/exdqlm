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

## Static Shrink RHS Governance Update

As of `2026-04-09`, the accepted `static_shrink / rhs` branch is now frozen as
**legacy mixed-prior historical output**.

Why:

- the scientific rule is now explicit: always use `rhs_ns`, never legacy `rhs`
- the accepted `static_shrink / rhs` branch is mixed rather than cleanly
  `rhs_ns`

Audit summary:

- total affected rows: `72`
- share of accepted `288`: `25.0%`
- share of `static_shrink`: `50.0%`
- inference split:
  - `36` MCMC
  - `36` VB
- evidence split:
  - `35` explicit `rhsns`
  - `27` baseline ambiguous
  - `7` repaired ambiguous non-`rhsns`
  - `3` explicit legacy `rhs`

Operational decision:

- keep the current branch as a reproducible legacy record
- do not use `static_shrink / rhs` as a clean prior-family result
- do not propagate from that branch
- rebuild all `72` rows as explicit `rhs_ns`
- rerun the broader metric comparison and cluster diagnosis after the corrected
  `rhs_ns` branch is available

Reference investigation and inventories:

- `reports/static_exal_tuning_20260409/original288_static_shrink_rhs_mixed_prior_investigation_20260409.md`
- `tools/merge_reports/original288_static_shrink_rhs_prior_audit_20260409/original288_static_shrink_rhs_row_audit_20260409.csv`
- `tools/merge_reports/original288_static_shrink_rhs_prior_audit_20260409/original288_static_shrink_rhsns_rebuild_inventory_20260409.csv`

## Static Shrink RHS_NS Rebuild Launch Stack

As of `2026-04-09`, the correction wave for the mixed-prior shrinkage branch is
implemented as a regeneration-based rebuild.

Why regeneration instead of replay:

- the old replay path depended on dead reference artifacts
- the source shrinkage input CSVs still exist and are sufficient to rebuild the
  branch cleanly

Program and execution notes:

- `reports/static_exal_tuning_20260409/original_288_static_shrink_rhsns_rebuild_program_20260409.md`
- `reports/static_exal_tuning_20260409/original_288_static_shrink_rhsns_rebuild_execution_20260409.md`

Validated launch stack:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_helpers_20260409.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_prepare_20260409.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_run_row_20260409.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_evaluate_20260409.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_launch_20260409.sh`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_monitor_20260409.sh`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_supervisor_20260409.sh`

Validation summary before full launch:

- prepare: `72` rows, `0` missing inputs
- phase split: `36` VB + `36` MCMC
- `bash -n` passed
- launcher `--prepare-only=1` passed
- launcher `--dry-run=1 --skip-prepare=1` passed
- live smoke tests:
  - row `1` `vb :: al`
  - row `37` `mcmc :: al`
  - row `38` `mcmc :: exal`

Recent closeout summary:

- the rebuild has now completed
- overall outcome:
  - `47` `PASS`
  - `13` `WARN`
  - `12` `FAIL`
  - `60 / 72` healthy
- status outcome:
  - `63` `done`
  - `6` `failed_runtime`
  - `3` `skipped_existing`
- block outcome:
  - `vb :: al`: `18 / 18` healthy
  - `vb :: exal`: `18 / 18` healthy
  - `mcmc :: al`: `18 / 18` healthy
  - `mcmc :: exal`: `6 / 18` healthy, `12 / 18` fail

Failure concentration:

- all `12` failures are in `static_shrink / rhs_ns / exal / mcmc`
- family split:
  - `6` `gausmix`
  - `3` `laplace`
  - `3` `normal`
- tau split:
  - `4` at `0p05`
  - `6` at `0p25`
  - `2` at `0p95`

Operational interpretation:

- this wave successfully created the explicit `rhs_ns` replacement branch
- it does **not** directly replace accepted `v7`
- the old accepted `static_shrink / rhs` branch therefore remains frozen as
  legacy mixed-prior historical output
- the rebuilt `rhs_ns` branch should instead be treated as the corrected
  downstream input for metric comparison, cluster diagnosis, and propagation
  planning

Primary result artifacts:

- `reports/static_exal_tuning_20260409/original_288_static_shrink_rhsns_rebuild_program_20260409.md`
- `reports/static_exal_tuning_20260409/original_288_static_shrink_rhsns_rebuild_execution_20260409.md`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_phase_summary_20260409.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_block_summary_20260409.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_manifest_status_20260409.csv`

## Static Shrink RHS_NS exAL MCMC Repair Plan

As of `2026-04-10`, the branch moves next into a dedicated repair wave for the
remaining corrected shrinkage failures.

Promotion decision before the repair wave:

- accepted `v7` remains unchanged
- no completed result is promoted yet
- reason:
  - the explicit `rhs_ns` rebuild is scientifically cleaner than the legacy
    mixed-prior `rhs` branch
  - but the corrected branch is still incomplete because `12` exAL/MCMC rows
    remain `FAIL`

Remaining unresolved corrected rows:

- total: `12`
- scope: `static_shrink / rhs_ns / exal / mcmc`
- split:
  - runtime invalid-state crash band at `tau = 0p25`: `6`
  - completed-but-unhealthy chain-quality failures: `6`

Current best read:

- what improved:
  - `60 / 72` corrected `rhs_ns` rows are already healthy
  - `vb :: al`, `vb :: exal`, and `mcmc :: al` are fully healthy
- what still fails:
  - only the `12` corrected `rhs_ns` `exal :: mcmc` rows
- what worked best:
  - explicit `rhs_ns` regeneration
  - row-local historical anchors
  - selective transfer of strong static exAL ideas, including `slice`
- what did not help:
  - replaying the rebuild defaults unchanged
  - keeping the VB warm-start path in the `tau = 0p25` crash band
- highest expected-value directions:
  - `init_from_vb = FALSE` crash-removal probes
  - selective `slice` probes
  - longer row-local rw anchors only on the completed-but-still-failing rows

Planned overnight repair wave:

- program note:
  - `reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_repair_program_20260410.md`
- execution note:
  - `reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_repair_execution_20260410.md`
- launch stack:
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_helpers_20260410.R`
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_prepare_20260410.R`
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_run_row_20260410.R`
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_evaluate_20260410.R`
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_launch_20260410.sh`
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_monitor_20260410.sh`
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_supervisor_20260410.sh`

Planned tracked artifacts:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_schedule_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_manifest_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_stage_counts_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_manifest_status_20260410.csv`

## Static RHS_NS working-state update and final closure decision (2026-04-10)

The `rhs_ns` exAL/MCMC repair wave has now completed and the accepted branch has
been updated where justified.

Accepted promotion result:

- accepted branch advanced from `v7` to `v8`
- accepted healthy count remains `282 / 288`
- one accepted row improved:
  - `static_shrink::gausmix::0p25::100::rhs::exal::mcmc`
  - gate change: `WARN -> PASS`

Current accepted `v8` block state:

- overall: `282 / 288` healthy
- dynamic: `66 / 72` healthy, `6` unresolved
- static_paper: `72 / 72` healthy
- static_shrink: `144 / 144` healthy

Current corrected `static_shrink / rhs_ns` working state:

- `70 / 72` healthy
- `2` unresolved
- unresolved rows:
  - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`
  - `static_shrink::normal::0p25::1000::rhs_ns::exal::mcmc`

Clean summary of the current state:

- what improved:
  - the `rhs_ns` repair wave reduced the corrected shrinkage hole from `12` rows
    to `2`
  - one accepted row was promotable and is now part of accepted `v8`
- what still fails:
  - the `2` corrected `rhs_ns` static rows above
  - the `6` accepted dynamic `exdqlm :: mcmc` rows
- which ideas worked best:
  - row-local no-VB-init rw crash-removal probes
  - selective transfer of `slice` where the exact-kernel hedge had real
    historical support
  - keeping the tuning scenario-specific rather than global
- which ideas did not help:
  - rerunning the corrected rebuild defaults unchanged
  - broad reuse of weak dynamic faithful/localmix corridors
- highest expected-value directions now:
  - a final static closure lane for the last `2` corrected `rhs_ns` rows
  - a separate dynamic closure lane only after the missing dynamic source
    artifacts are restored or the rerunner is rewritten to avoid them

Static final-closure lane:

- program:
  - `reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_final_closure_program_20260410.md`
- execution:
  - `reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_final_closure_execution_20260410.md`
- schedule:
  - `18` candidates across the final `2` corrected rows
- validation:
  - prepare passed
  - `--prepare-only=1` passed
  - `--dry-run=1 --skip-prepare=1` passed

## Static RHS_NS final-closure closeout and gausmix last-mile relaunch (2026-04-10)

The final-closure wave is now complete and the corrected `rhs_ns` branch has
been updated again where justified.

Accepted branch state remains:

- accepted baseline: `v8`
- accepted healthy count: `282 / 288`
- accepted unresolved tail: `6 / 288`
- no new accepted promotion from the final-closure wave

Corrected `static_shrink / rhs_ns` working state now:

- `71 / 72` healthy
- `1 / 72` unresolved
- promoted corrected row:
  - `static_shrink::normal::0p25::1000::rhs_ns::exal::mcmc`
  - chosen final-closure profile:
    - `final_rw_none_f0835_s1025_xlong`
  - gate change on corrected branch:
    - `FAIL -> WARN`
- remaining corrected unresolved row:
  - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`

Final-closure wave read:

- total candidates: `18`
- healthy candidates: `3`
- better than failed corrected baseline: `3`
- better than accepted baseline: `0`
- row-level outcome:
  - `normal / 0p25 / 1000`: `3 / 9` healthy, credible `WARN` rescue
  - `gausmix / 0p25 / 1000`: `0 / 9` healthy, still unresolved

Clean summary of the current state:

- what improved:
  - corrected `rhs_ns` branch advanced from `70 / 72` to `71 / 72` healthy
  - the `normal / 0p25 / 1000` row is no longer part of the corrected fail set
- what still fails:
  - corrected static row:
    - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`
  - accepted dynamic tail:
    - `6` `dynamic / exdqlm / mcmc` rows
- which ideas worked best:
  - no-VB-init row-local `laplace_rw` corridors on the corrected rhs_ns branch
  - on the normal row, the `F0835 / s1025 / xlong` rw band was the best late
    closure profile
  - on the hard gausmix row, the strongest anchors were still rw rather than
    slice
- which ideas did not help:
  - simply widening slice on the hard gausmix row
  - replaying the same short/medium rw bands without a real gamma-ESS plan
  - another generic dynamic sweep without source artifacts
- highest expected-value directions now:
  - a gausmix-only `rhs_ns` last-mile lane focused on gamma ESS and refresh
    tuning
  - a separate non-compute recovery step for the `6` blocked dynamic rows so
    they become runnable again

New gausmix-only last-mile lane:

- target:
  - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`
- purpose:
  - close the last corrected static rhs_ns failure without reopening any solved
    rows
- search-space rules:
  - keep no-VB-init as the default because it converts the old iter-2 crash
    into a scored-but-unhealthy chain
  - focus on the strongest rw anchors:
    - `F085 / s100`
    - `F0845 / s100`
    - one softer `F0825 / s1025` hedge
  - add longer chains, more gamma substeps, and earlier/heavier laplace refresh
    before discarding rw
  - keep slice as a disciplined exact-kernel hedge, but do not let it dominate
    the schedule after repeated weak results

Validated gausmix last-mile artifacts:

- program:
  - `reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_program_20260410.md`
- execution:
  - `reports/static_exal_tuning_20260410/original_288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_execution_20260410.md`
- schedule:
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_schedule_20260410.csv`
- manifest:
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_manifest_20260410.csv`
- stage counts:
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_stage_counts_20260410.csv`
- working baseline inputs:
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_baseline_v2_20260410.csv`
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_summary_v2_20260410.csv`
  - `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_unresolved_v2_20260410.csv`

Validation summary:

- post-final-closure promotion script: passed
- updated corrected working state: `71 / 72` healthy
- prepare: `28` rows
- missing inputs: `0`
- `bash -n`: passed
- `--prepare-only=1`: passed
- `--dry-run=1 --skip-prepare=1`: passed

Dynamic blocker remains unchanged:

- the accepted unresolved dynamic tail is still the same `6` rows
- the final dynamic closure lane remains deferred because its required source
  `.rds` and `sim_output.rds` inputs are missing

Dynamic final-closure lane:

- program:
  - `reports/static_exal_tuning_20260410/original_288_syncedbase_dynamic_final_closure_program_20260410.md`
- execution:
  - `reports/static_exal_tuning_20260410/original_288_syncedbase_dynamic_final_closure_execution_20260410.md`
- important result:
  - design is complete, but launch is deferred
  - blocker:
    - the required dynamic source `.rds` / `sim_output.rds` artifacts are
      missing
- blocker audit:
  - `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_blocker_audit_20260410.csv`
