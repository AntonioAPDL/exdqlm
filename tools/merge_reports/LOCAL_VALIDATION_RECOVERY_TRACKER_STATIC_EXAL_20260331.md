# Validation Recovery Tracker: Static exal MCMC Focus

Date: 2026-03-31

Purpose: provide a rigorous, execution-ready recovery plan for the current
validation study, centered on the dominant unresolved problem area while keeping
the validation branch organized and scientifically defensible.

This is a local tracker intended for operational use. It is not a signoff
document and should not be treated as final scientific reporting.

## 0. Synced Integration Continuation Note (2026-04-06)

The active continuation point for the exdqlm validation study is now the
synced integration branch/worktree:

- worktree:
  `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration`
- branch:
  `validation/rerun-after-0.4.0-sync-0p4p0-integration`

Predecessor validation run history remains in:

- worktree:
  `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`
- branch:
  `validation/rerun-after-0.4.0-sync`

Canonical synced-branch status note:

- `reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md`

Accepted publication-target carry-forward state on the synced branch:

- `282 / 288` healthy
- `6 / 288` unresolved

Important caveat:

- the accepted `v4` selection is current and valid as the planning baseline
- but the selected fit paths still point to predecessor-worktree outputs
- synced-base rerun status should therefore be treated as pending rather than
  conflated with accepted carry-forward status

## 0. Dynamic-Only Residual Recovery Checkpoint (2026-04-05)

The next repair phase after the corrected original-`288` carry-forward rebuild
has now been implemented and validated as a dynamic-only residual program.

Primary references:

- `reports/static_exal_tuning_20260405/original_288_dynamic_residual_program_20260405.md`
- `reports/static_exal_tuning_20260405/original_288_dynamic_residual_execution_20260405.md`
- `tools/merge_reports/LOCAL_ORIGINAL288_DYNAMIC_RECOVERY_TRACKER_20260405.md`
- `tools/merge_reports/LOCAL_original288_dynamic_residual_manifest_20260405.csv`

Checkpoint state:

- original publication-target cells: `288`
- healthy now: `280`
- unresolved now: `8`
- all residual debt is dynamic-only
- static should not be reopened by default

Validated residual schedule:

- `22` archive rescoring rows
- `2` relaxed `vb::exdqlm` rows
- `17` targeted dynamic MCMC rows
- `41` total rows

Operational rule carried forward:

- promote only when a residual candidate improves the same original dynamic
  case key from baseline `FAIL` to `PASS` or `WARN`

Archive-stage closeout refinement:

- the `22`-row archive rescoring stage completed successfully
- `11` archive candidates were promoted into the corrected original-`288`
  carry-forward table
- all unresolved `dqlm::mcmc` dynamic cells are now healthy
- all unresolved `exdqlm::vb` dynamic cells are now healthy
- the remaining unresolved tail is now only `8` `exdqlm::mcmc` dynamic cells
- the supervisor stopped because of a merged-schema evaluator/selector bug
  after archive completion, not because the archive compute failed
- that bookkeeping bug has now been fixed
- this checkpoint intentionally stops after applying promotions and
  regenerating health; it does not yet plan the next relaunch

Dynamic tail-only relaunch refinement:

- the next residual execution should now be treated as a reduced tail-only
  program rather than a continuation of the broader mixed residual manifest
- new primary references:
  - `reports/static_exal_tuning_20260405/original_288_dynamic_tail8_closure_program_20260405.md`
  - `reports/static_exal_tuning_20260405/original_288_dynamic_tail8_closure_execution_20260405.md`
- narrowed schedule:
  - `8` exact slice-anchor runs on the full remaining `exdqlm::mcmc` tail
  - `6` low-tail slice escalations on the `tau = 0p05` subset
  - `14` total
- strongest surviving corridor:
  - dynamic `exdqlm mcmc`
  - `slice` proposal
  - `mh_adapt = FALSE`
  - explicit healthy same-scenario `exdqlm vb` warm starts
- lower-value mixed relaunch ideas such as the broader `joint_long`
  follow-up have now been deprioritized

Tail-8 closeout and tail-7 geometry refinement (2026-04-06):

- tail-8 completed cleanly and produced one new promoted rescue:
  - `dynamic::gausmix::0p95::500::default::exdqlm::mcmc`
  - upgraded from `FAIL` to `PASS`
- corrected publication-target state is now:
  - `281 / 288` healthy
  - `7 / 288` unresolved
  - unresolved debt remains dynamic-only
- the old exact slice geometry should now be treated as screened out on the
  surviving low-tail cluster:
  - `slice.width = 0.12`
  - `slice.max.steps = 80`
  - short exact anchor: mostly negative on the remaining tail
  - long low-tail rerun: fully negative on the tau-`0p05` cluster
- the next residual run is therefore a geometry-band relaunch, not another
  length-only rerun:
  - `7` rows at `slice.width = 0.18`, `slice.max.steps = 120`
  - `7` rows at `slice.width = 0.24`, `slice.max.steps = 160`
  - `6` longer `tau = 0p05` follow-ups at the `0.18 / 120` geometry
  - `20` total
- static work remains fully closed and should not be reopened in this phase

Tail-7 closeout and dynamic rw-joint refinement (2026-04-06):

- tail-7 finished cleanly with `20 / 20 FAIL`
- corrected publication-target state therefore stays at:
  - `281 / 288` healthy
  - `7 / 288` unresolved
- the slice-geometry expansion family is now screened out on the surviving
  dynamic tail
- the next credible residual lane should switch to `laplace_rw` and stay
  strictly tail-only:
  - `7` all-tail `laplace_rw` anchors with explicit VB warm starts and
    `joint.sample = TRUE`
  - `4` TT500 refresh-focused follow-ups
  - `3` TT5000 longer joint follow-ups
  - `14` total
- static work remains fully closed and should not be reopened by default

Tail-7 `rw` closeout and promotion checkpoint (2026-04-06):

- tail-7 `rw` completed with:
  - `0 PASS`
  - `1 WARN`
  - `13 FAIL`
- one new original dynamic case was promoted:
  - `dynamic::gausmix::0p05::500::default::exdqlm::mcmc`
  - upgraded from `FAIL` to `WARN`
- corrected publication-target state is now:
  - `282 / 288` healthy
  - `6 / 288` unresolved
- dynamic recovered state is now:
  - `66 / 72` healthy
  - `6 / 72` unresolved
- the remaining unresolved tail is now:
  - `dynamic::gausmix::0p25::500::default::exdqlm::mcmc`
  - `dynamic::laplace::0p05::500::default::exdqlm::mcmc`
  - `dynamic::normal::0p05::500::default::exdqlm::mcmc`
  - `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
  - `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
  - `dynamic::normal::0p05::5000::default::exdqlm::mcmc`
- static work remains fully closed and should not be reopened by default

## 0. Original-288 Realignment Execution Checkpoint (2026-04-05)

The corrected original-`288` carry-forward pipeline has now been implemented
and audited.

Primary execution references:

- `reports/static_exal_tuning_20260405/original_288_realignment_investigation_and_recovery_plan_20260405.md`
- `reports/static_exal_tuning_20260405/original_288_realignment_execution_20260405.md`
- `tools/merge_reports/LOCAL_original288_registry_v1_20260405.csv`
- `tools/merge_reports/LOCAL_original288_carryforward_selection_v1_20260405.csv`
- `tools/merge_reports/LOCAL_original288_health_summary_v1_20260405.csv`
- `tools/merge_reports/LOCAL_original288_audit_v1_20260405.csv`

Executed state:

- original publication-target baseline cells: `288`
- healthy now: `269`
- unresolved now: `19`
- all unresolved cells are dynamic
- all original static cells are now recovered as healthy

Important correction:

- the earlier healthy `291` campaign was a repaired hybrid assembly
- it remains a valid repair evidence pool
- it should **not** be treated as the publication-target comparison universe
- the corrected original-`288` carry-forward table is now the authoritative
  target for broad comparison and remaining repair planning

Operational next step:

- do not relaunch static work by default
- treat the remaining work as a dynamic-only residual repair program
- start that phase from the unresolved queue in:
  `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v1_20260405.csv`

## 0. Execution checkpoint (2026-03-31 06:36 EDT)

Operational progress completed after the initial tracker draft:

- stale dynamic tail refresh was launched on the validation branch under tag
  `dynamic_tail_cppgig_refresh_20260331`
- static `exal` debug worktree created at
  `/home/jaguir26/local/src/exdqlm__wt__debug-static-exal-shared-core-20260331`
- debug branch created:
  `debug/static-exal-shared-core-20260331`
- gated invalid-state snapshot capture implemented on the debug branch and
  committed at `c0bccef`
- static sentinel manifest and launcher created on the debug worktree:
  - `tools/merge_reports/LOCAL_static_exal_sentinel_prepare_20260331.R`
  - `tools/merge_reports/LOCAL_static_exal_sentinel_launch_20260331.sh`
  - `tools/merge_reports/LOCAL_static_exal_sentinel_status_20260331.R`

Important new evidence from actual execution:

1. dynamic stale refresh is genuinely progressing
   - row `5` under `dynamic_tail_cppgig_refresh_20260331` is still active and
     has advanced through burn-in to at least iteration `1400`
   - current evidence path:
     `tools/merge_reports/full288_dynamic_tail_cppgig_refresh_20260331/`

2. exact full-runner static canary still reproduces the historical crash on
   current `HEAD`
   - exact command path:
     `tools/merge_reports/LOCAL_full288_case_runner_20260327.R`
   - exact current-HEAD canary artifact:
     `tools/merge_reports/full288_static_exal_anchor_repro_20260331/rows/row_0261.csv`
   - result:
     `failed_runtime`
   - error:
     `Static MCMC state invalid (iter=2): static_exal chi has 100 non-finite values (first index=1)`

3. the first debug static harness was good enough for broad health comparison,
   but not yet exact enough for crash reproduction
   - anchor `row 83` in the debug harness completed `FAIL` rather than
     reproducing the old runtime crash
   - this correctly triggered a pause before the full matrix was allowed to
     continue

4. one concrete debug-harness mismatch was identified and fixed
   - the debug harness had been inheriting `beta_prior = rhs` from
     `run_config.rds`
   - the exact validation runner uses manifest `prior_override = rhs_ns`
   - the harness was patched to pass the manifest prior override explicitly

5. despite that fix, the debug harness still has at least one remaining
   execution delta relative to the exact full validation runner
   - exact row `261` reproduces the crash
   - debug row `261` with the current harness enters burn-in and continues
   - therefore candidate-comparison results from the current debug harness
     should be treated as provisional until the remaining runner delta is
     removed

Current immediate decision:

- trust the exact full-runner canary evidence
- do not trust the current debug crash matrix as the final reproducer yet
- next tool-building step should be a direct full-runner-based static matrix
  wrapper, not more tuning on top of the current approximate runner

## 0.1 Exact full-runner smoke checkpoint (2026-03-31 06:58 EDT)

The direct full-runner wrapper has now been implemented in the debug worktree
and the first 2-row smoke has been launched and completed.

Operational wrapper and plan artifacts:

- debug wrapper prepare:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_exact_full_runner_prepare_20260331.R`
- debug wrapper launch:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_exact_full_runner_launch_20260331.sh`
- debug wrapper status:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_exact_full_runner_status_20260331.R`
- local operator plan:
  `tools/merge_reports/LOCAL_static_exal_exact_full_runner_PLAN_20260331.md`

Important result:

- the exact wrapper is now trustworthy enough for crash-lane work
- both smoke rows reproduced the same historical runtime failure under the
  debug worktree package code
- both rows emitted the new invalid-state snapshot artifact at `iter=2`

Exact smoke artifacts:

- debug manifest:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_exact_full_runner_manifest_20260331.csv`
- debug status detail:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_exact_full_runner_status_detail_20260331.csv`
- debug status summary:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_exact_full_runner_status_summary_20260331.csv`
- full-runner row `261`:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/full288_static_exal_exact_smoke_20260331/rows/row_0261.csv`
- full-runner row `83`:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/full288_static_exal_exact_smoke_20260331/rows/row_0083.csv`
- invalid snapshot `261`:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/static_exal_exact_smoke_20260331/invalid_state/row_0261/invalid_state_static_exal_iter0002_20260331_065726.rds`
- invalid snapshot `83`:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/static_exal_exact_smoke_20260331/invalid_state/row_0083/invalid_state_static_exal_iter0002_20260331_065746.rds`

Smoke result summary:

| Row | Scope | Status | Error pattern | Snapshot |
|---|---|---|---|---|
| `261` | `static_shrink / normal / tau=0.25` | `failed_runtime` | `static_exal chi has 100 non-finite values (iter=2)` | yes |
| `83` | `static_paper / gausmix / tau=0.25` | `failed_runtime` | `static_exal chi has 100 non-finite values (iter=2)` | yes |

Interpretation:

- the remaining execution delta between the provisional debug harness and the
  exact validation runner has now been removed for the smoke lane
- the crash is not confined to one root-family combination; it reproduces in
  both the shrink and paper slices under the exact wrapper
- the immediate next debugging step should shift from runner alignment to
  snapshot inspection and then widening to the 6-row crash sentinel under the
  same exact wrapper

Updated immediate decision:

- treat the exact full-runner wrapper as the authoritative static crash
  reproducer
- do not spend more effort on the old approximate static sentinel runner
- inspect the new invalid-state snapshots before proposing repair candidates
- if snapshot structure is coherent, widen from the 2-row smoke to the 6-row
  crash sentinel using the same exact wrapper

## 0.2 Exact crash6 and warm-start root-cause checkpoint (2026-03-31 10:25 EDT)

The exact crash sentinel has now been widened and completed under:

- `static_exal_exact_crash6_20260331`

Result:

- all 6 crash-band rows failed
- all 6 failed at the new beta-step hook, not only later at the `chi` check
- every row emitted a beta-step invalid-state snapshot at iteration `1`

Rows:

- `261`, `83`, `107`, `131`, `165`, `213`

Key artifacts:

- exact crash6 status summary:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_exact_full_runner_status_summary_20260331.csv`
- exact crash6 status detail:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_exact_full_runner_status_detail_20260331.csv`
- exact crash6 invalid-state directory:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/static_exal_exact_crash6_20260331/invalid_state/`

Important new forensic finding:

- in the new beta-step snapshots, `rhs`, `y_star`, and `W_diag` remain finite
- `prior_prec_diag` is already non-finite for the shrunk coefficients and
  finite only for the intercept
- therefore `V_inv` already contains non-finite entries before the beta solve
- then `chol_diag`, `m_beta`, `beta`, and `xb` fail downstream

This localizes the failure more sharply:

- it is not primarily a `chi`-validation problem
- it is not primarily a `v` GIG sampling problem
- it is a corrupted prior-precision problem entering the static beta step

Direct warm-start probe result:

- fresh `exal_static_LDVB(..., beta_prior = "rhs_ns", ...)` calls on rows `83`
  and `261` already produce:
  - fully non-finite `qbeta`
  - non-finite `tau2`, `xi`, `zeta2`, `E_inv_tau2`, `E_inv_zeta2`
  - `lambda2` and `nu` finite only for the intercept
  - warning:
    `NaNs produced`

Supporting artifacts:

- root-cause note:
  `tools/merge_reports/LOCAL_static_exal_root_cause_NOTE_20260331.md`
- snapshot forensics note:
  `tools/merge_reports/LOCAL_static_exal_snapshot_forensics_NOTE_20260331.md`
- VB probe CSV:
  `../exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_rhsns_vb_probe_20260331.csv`

Updated immediate decision:

- treat the static `rhs_ns` LDVB warm-start path as the new lead debugging
  target
- pause any move toward broad reruns
- shift the next code-level diagnosis to `R/exal_static_LDVB.R`, especially the
  `W <- xis$xi1 * E_inv_v` / `Xw <- X * sqrt(W)` / qbeta-prior path

## 0.3 Wave-7 closeout and wave-8 exact-runner transfer program (2026-04-03)

Wave-7 transfer status (exact-runner transfer program):

- wave-7 completed and produced a new best exact-runner transfer baseline:
  `F080_sub2_s100`
- reference decision artifact:
  `/home/jaguir26/local/src/exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_wave7_transfer_final_decision_20260401.md`

Wave-7 transfer result summary:

| candidate_id | pass_n | warn_n | fail_n | healthy_n | exact_ready |
|---|---:|---:|---:|---:|---|
| `F080_sub2_s100` | 7 | 4 | 1 | 11 | `FALSE` |

Interpretation:

- exact-runner baseline is improved but still not exact-ready (`0 FAIL`)
- the remaining uncertainty is now tightly concentrated around the `F080`
  neighborhood

Wave-8 program status:

- wave-8 is the next disciplined exact-runner transfer search focused only on
  the `F080` neighborhood
- the schedule (transfer6 -> guard8 -> mix12_transfer) is defined in:
  `reports/static_exal_tuning_20260403/wave7_closeout_and_wave8_program.md`
- wave-8 launcher + scoring scripts are implemented on the validation branch
  under:
  - `tools/merge_reports/LOCAL_static_exal_wave8_transfer_prepare_20260403.R`
  - `tools/merge_reports/LOCAL_static_exal_wave8_transfer_score_20260403.R`
  - `tools/merge_reports/LOCAL_static_exal_wave8_transfer_launch_20260403.sh`

Updated immediate decision:

- treat `F080_sub2_s100` as the best exact-runner baseline until wave-8
  completes
- proceed with wave-8 overnight to attempt the first `0 FAIL` transfer baseline
- do not relaunch the full 72-row static rerun until wave-8 yields a
  `0 FAIL` candidate or the acceptance rule is revised

## 0.4 Post-wave8 closeout and campaign-completion execution checkpoint (2026-04-03)

Wave-8 and the fail-only bridge lane have now finished successfully.

Validated carry-forward state:

- active exact-runner baseline: `F080_sub2_s105`
- primary backup: `F080_sub2_s100_ref`
- secondary bridge hedge: `F080_sub2_s0975`
- dropped candidate: `F075_sub2_s095`

Debt reduction:

## 0.5 Wave-7 closeout and wave-8 closure checkpoint (2026-04-05)

Current validated state:

- no validation jobs are running in this worktree
- wave-7 completed cleanly
- broad default static baseline remains:
  - `F085_sub2_s100`
- the local static repair baseline should now be treated as `v4`
- promoted row-local improvements after wave-7:
  - row `87` -> `F085_sub2_s1025_slice` (`WARN`)
  - row `190` -> `F0825_sub2_s100_rwlong` (`WARN`)
  - row `206` -> `F0825_sub2_s1025_rwlong` (`PASS`)

Remaining blocking debt:

- static:
  - row `135`
  - row `174`
  - row `269`
- dynamic sidecar:
  - row `15`

Important new finding:

- dynamic row `15` is no longer waiting on a new repair hypothesis
- the exact TT5000 historical artifact
  `slice_wave2_20260319`
  already gates to:
  - `WARN`
  - `healthy = TRUE`

Interpretation:

- static closure is now a row-local problem, not a generic-family problem
- dynamic row `15` is now a replay/confirmation problem, not a blind search

Wave-8 program shape:

- static:
  - one row-`87` confirmation
  - exact short replay plus `vb`-init probes on `135`, `174`, and `269`
- dynamic:
  - exact TT5000 slice replay for row `15`
  - one mild longer slice control

Explicit exclusions:

- no more broad shared-setup search
- no more generic residual-band sweeps
- no more repeated long/slice widening on rows `174` and `269`
- no more dynamic `laplace_rw` refresh reruns before replaying the known-good
  slice setup

Updated immediate decision:

- implement the wave-8 closure lane on the validation branch
- validate prepare/evaluate first
- launch static and dynamic sidecars separately under tmux

- the remaining campaign debt is now `73` cases, not `291`
- breakdown:
  - `72` stale static `exal` reruns
  - `1` dynamic tail debt (`row 15`)
- dynamic tail row `5` is now resolved and should not be relaunched

Important execution correction identified before the focused static rerun:

- the stale `72`-row static slice is not just two disjoint row sets
- the `18` legacy RHS comparison rows overlap the current refresh slice on
  `row_id` and `run_root`
- the static tuning runner therefore needed a scope-aware prior-template path,
  because:
  - current static-paper refresh rows must run as `rhs_ns`, but their original
    baseline fits are still `ridge`
  - overlapping static-shrink comparison rows must remain `rhs`

Focused completion tooling now implemented on the validation branch:

- static completion lane:
  - `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_prepare_20260403.R`
  - `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_evaluate_20260403.R`
  - `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_launch_20260403.sh`
  - `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_supervisor_20260403.sh`
  - `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_monitor_20260403.sh`
- dynamic sidecar bookkeeping:
  - `tools/merge_reports/LOCAL_dynamic_row15_sidecar_prepare_20260403.R`

Current lane decision:

- static `72`-row rerun is the active completion lane
- dynamic row `15` remains a separate sidecar lane and is not yet launch-ready
  until there is a concrete repair hypothesis beyond identical rerun

Primary execution note:

- comparison-ready refresh now depends on preserving current-vs-legacy prior
  semantics during the static rerun, not merely on replaying the `72` stale
  rows with one generic variant tag

## 0.5 Wave-4 closeout and local-repair baseline checkpoint (2026-04-04)

Wave-4 targeted repair status:

- wave-4 completed end to end under the repaired orchestration stack
- active decision artifact:
  `reports/static_exal_tuning_20260404/failband_wave4_closeout_and_wave5_local_repair_program_20260404.md`

Wave-4 result summary:

| stage | total | PASS | WARN | FAIL | missing |
|---|---:|---:|---:|---:|---:|
| `repair9` | 81 | 13 | 28 | 40 | 0 |

Most important scientific update:

- no single shared candidate solved the residual band cleanly
- but the completed evidence now supports a default-plus-local repair map with:
  - `6 PASS`
  - `3 WARN`
  - `0 FAIL`
  across the old `9`-row static residual band

Promoted static baseline:

- default baseline:
  `F085_sub2_s100`
- local overrides:
  - row `87`: `F085_sub2_s1025`
  - row `115`: `F0845_sub2_s1025`
  - row `135`: `F0835_sub2_s1025`
  - row `174`: `F0845_sub2_s100`
  - row `190`: `F085_sub2_s1025`
  - row `206`: `F0835_sub2_s1025`
  - row `278`: `F0845_sub2_s1025`
  - row `181`: keep default `F085_sub2_s100`
  - row `269`: keep default `F085_sub2_s100`

High-value remaining static uncertainty:

- the static problem is no longer unresolved FAIL elimination across the full
  residual band
- the active static uncertainty is now concentrated in the WARN-only rows:
  - current `87`
  - current `174`
  - legacy `269`

Operational implication:

- broad shared-setup search is now lower value than local confirmation/probing
- the next static lane should confirm the chosen local repair map and probe
  only rows `174` and `269` with the one historically credible outlier:
  `F0875_sub2_s105`

Dynamic implication:

- dynamic row `15` is still the only remaining dynamic unresolved row
- it remains deferred until there is a real repair hypothesis beyond replay

## 1. Current validated picture

Current effective study state after the successful row `57` C++-GIG replacement:

| Slice | Total | Done | Failed runtime | Pending | PASS | WARN | FAIL | Healthy TRUE |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Static RHS-NS refresh | 216 | 198 | 18 | 0 | 144 | 25 | 47 | 169 |
| Legacy RHS refresh | 72 | 72 | 0 | 0 | 37 | 22 | 13 | 59 |
| Tail, effective current state | 3 | 2 | 1 | 0 | 1 | 0 | 2 | 1 |
| Overall, effective current state | 291 | 272 | 19 | 0 | 182 | 47 | 62 | 229 |

Primary supporting artifacts:
- `tools/merge_reports/full288_rhsns_impl_refresh_20260329/health_compact_20260329_114727.csv`
- `tools/merge_reports/full288_rhs_legacy_refresh_20260329/health_compact_20260329_123208.csv`
- `tools/merge_reports/full288_dynamic_tail_refresh_20260329/rows/row_0005.csv`
- `tools/merge_reports/full288_dynamic_tail_refresh_20260329/rows/row_0015.csv`
- `tools/merge_reports/full288_row57_cppgig_same_seed_20260330/rows/row_0057.csv`

## 2. Core diagnosis

### 2.1 Dominant pain cluster

Yes: the main current concern is the static `exal` MCMC path.

Evidence:
- all `18` static runtime failures are `model=exal`, `inference=mcmc`,
  `tau=0.25`
- `18/19` total runtime failures in the effective campaign are in that exact
  static `exal` cluster
- `60/62` overall gate FAILs are static `exal` MCMC

The sharp execution-failure cluster is:

| Problem | Count | Scope |
|---|---:|---|
| runtime failure with `static_exal chi has 100 non-finite values` | 18 | `static_paper` + `static_shrink`, all 3 families, `tau=0.25` |

Representative artifacts:
- `tools/merge_reports/full288_rhsns_impl_refresh_20260329/rows/row_0083.csv`
- `tools/merge_reports/full288_rhsns_impl_refresh_20260329/rows/row_0165.csv`
- `tools/merge_reports/full288_rhsns_impl_refresh_20260329/logs/row_83.log`
- `tools/merge_reports/full288_rhsns_impl_refresh_20260329/logs/row_165.log`

The broader scientific-quality cluster is:

| Problem | Count | Scope |
|---|---:|---|
| completed but gate FAIL | 42 | static `exal` MCMC |
| completed but gate WARN | 11 | static `exal` MCMC |
| completed and gate PASS | 1 | static `exal` MCMC |

Among the completed static `exal` MCMC FAIL rows, the dominant gate components are:

| Gate component | FAIL count | WARN count | PASS count |
|---|---:|---:|---:|
| `gate_sigma` | 38 | 3 | 1 |
| `gate_gamma` | 33 | 8 | 1 |
| `gate_ess_sigma` | 32 | 8 | 2 |
| `gate_half_drift_sigma` | 28 | 4 | 10 |
| `gate_ess_gamma` | 26 | 13 | 3 |
| `gate_acf1_gamma` | 6 | 33 | 3 |

Interpretation:
- this is not only a crash problem
- it is also a chain-quality problem, especially low ESS and large half-drift
- the `tau=0.25` rows are failing as an immediate invalid-state crash
- many `tau=0.05` and `tau=0.95` rows complete but mix poorly

### 2.2 What row `57` did and did not solve

What is solved:
- row `57` was a dynamic `dqlm` MCMC stall on the old GH-backed path
- under the C++-GIG patch, the exact same seed completed `done / PASS / TRUE`

What is not solved:
- static `exal` MCMC was already using `sample_gig_devroye_vector()`
- therefore the static `exal` failure band is not explained by the old GH
  sampler issue that affected dynamic row `57`

Code anchors:
- dynamic MCMC fix area: `R/exdqlmMCMC.R`
- static `exal` MCMC already using C++ GIG: `R/exal_static_mcmc.R`

### 2.3 Dynamic tail status

Dynamic tail rows should be treated as follows:

| Row | Current interpretation | Why |
|---|---|---|
| `5` | stale and unresolved | old dynamic MCMC path, supervisor stall, no health row |
| `15` | stale and unresolved | old dynamic MCMC path, completed but unhealthy |
| `57` | resolved | current C++-GIG replacement succeeded |

Supporting artifacts:
- row `5`: `tools/merge_reports/full288_dynamic_tail_refresh_20260329/rows/row_0005.csv`
- row `15`: `tools/merge_reports/full288_dynamic_tail_refresh_20260329/rows/row_0015.csv`
- row `15` health: `tools/merge_reports/full288_dynamic_tail_refresh_20260329/health/health_0015.csv`
- row `57` replacement: `tools/merge_reports/full288_row57_cppgig_same_seed_20260330/rows/row_0057.csv`

Important nuance:
- rows `5` and `15` were produced before the dynamic C++-GIG fix
- they should be refreshed under current `HEAD`
- they are not the main bottleneck, but they are still stale

### 2.4 Cross-study lessons from the QDESN branch

Relevant external evidence reviewed on
`feature/qdesn-mcmc-alternative @ 59e0e2a2aba7b95f75933faffcaf70f25f2edb4e`:
- `docs/TRACK__qdesn_validation_repair_20260331.md`
- `docs/REVIEW__qdesn_exal_kernel_next_steps_20260331.md`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/summary/screen_results.md`
- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/summary/phase01_summary.md`
- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase01_mcmc_fail_forensics.csv`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/tables/profile_rank_summary.csv`

Portable lessons we should explicitly import:

1. shared `exal` core first, rhs-specific overlay second
   - qdesn found the main blocker in shared `exal` mixing, not in the
     `rhs_ns`-specific layer
   - this matches our static evidence because failures occur in both
     `static_paper` and `static_shrink`, not only in the shrink/RHS branch

2. do not use longer chains as the first response
   - qdesn screening showed geometry-improving kernel changes beat longer chains
   - for our static `exal` issue, chain-length inflation should be a late
     confirmation lane, not the first repair lever

3. narrow anchor harness before broad rerun
   - qdesn used a narrow root harness with an anchor baseline and a few focused
     candidates before spending more compute
   - we should do the same with our crash sentinel and mixing sentinel instead
     of jumping directly to the full 72-row static rerun

4. define hard canaries explicitly
   - qdesn benefited from treating one persistent hard root as the benchmark
   - we should do the same here

Recommended hard canaries for this study:
- crash canary: `current_static / static_shrink / normal / tau=0p25 / row 261`
- low-tail mixing canary: `current_static / static_shrink / normal / tau=0p05 / row 245`
- high-tail mixing canary: `current_static / static_shrink / normal / tau=0p95 / row 277`

## 3. Working decision

The optimal efficient plan is:

1. keep the validation branch clean and frozen for validation execution
2. refresh the stale dynamic tail rows `5` and `15` under current `HEAD`
3. do all static `exal` diagnosis and package-code experimentation in a
   separate debug worktree/branch
4. test one shared-core static `exal` candidate at a time on a narrow anchor
   harness before any broad rerun
5. treat rhs/shrink-specific overlays as second-stage cleanup only after the
   shared static `exal` core is healthier
6. treat longer-chain inflation as a confirmation lane, not as the first-line
   repair
7. do not authorize another broad rerun until the static `exal` crash mechanism
   and chain-quality problem are better understood
8. after a credible static `exal` fix exists, run a focused rerun, not a full
   291-row relaunch

## 4. Operating rules

- [ ] Freeze validation execution target at the current pushed validation head
      before launching any new validation jobs.
- [ ] Do not edit package code on `validation/rerun-after-0.4.0-sync` while it
      is serving as the execution branch.
- [ ] Create a separate debug worktree/branch for static `exal` diagnosis.
- [ ] Use same-seed reruns first for any reproduced failure.
- [ ] Preserve all new runs under new tags; do not overwrite older evidence.
- [ ] Qualify row references by wave/tag, not only by `row_id`.

Why the row-id warning matters:
- `row_id` values overlap across `current_static` and `legacy_rhs`
- for example, `165` exists in both waves but refers to different rerun tags

## 5. Workstreams

### WS0. Freeze, inventory, and branch hygiene

Objective:
- ensure validation execution, debugging, and documentation do not contaminate
  one another

Checklist:
- [ ] Confirm `git status --short --branch` is clean on the validation branch.
- [ ] Record validation execution head commit in the next run note.
- [ ] Create a separate debug branch/worktree for static `exal` investigation.
- [ ] Record the diagnostic branch name in the evidence log.

Exit criteria:
- validation branch clean
- debug worktree exists
- roles are separated: validation execution vs code diagnosis

### WS1. Refresh stale dynamic tail rows under current HEAD

Objective:
- refresh rows `5` and `15` using the current dynamic MCMC code
- separate stale dynamic results from the static `exal` problem

Scope:
- rows `5` and `15` only
- do not rerun row `57` unless later regression testing is needed

Preferred launch path:
- use the hardened sequential tail runner directly with a new tag
- avoid reusing the old `dynamic_tail_refresh_20260329` tag

Recommended command pattern:

```bash
bash tools/merge_reports/LOCAL_full288_tail3_hardened_seq_20260329.sh \
  --manifest=tools/merge_reports/LOCAL_targeted_manifest_dynamic_tail3_20260329.csv \
  --rows=5,15 \
  --tag=dynamic_tail_cppgig_refresh_20260331 \
  --interval=30 \
  --inactivity-sec=2400 \
  --force=1 \
  --verbose-mcmc=1 \
  --harness=0
```

Checklist:
- [ ] Launch row `5` and row `15` under a fresh tag.
- [ ] Confirm fresh `rows/`, `health/`, `logs/`, `heartbeat/`, and `telemetry/`
      artifacts are created.
- [ ] Capture final `health_compact` for the new tag.
- [ ] Compare new row `15` health to the old `health_0015.csv`.

Acceptance criteria:
- row `5` reaches a terminal row artifact under current `HEAD`
- row `15` reaches a terminal row artifact under current `HEAD`
- neither row is pending or silently missing

Decision after WS1:
- if `5` and `15` improve materially, dynamic stale risk is closed
- if they still fail, keep them as secondary issues and continue with WS2-WS4

### WS2. Static exal crash diagnosis: sentinel matrix

Objective:
- reproduce and diagnose the immediate invalid-state failure in static `exal`
  MCMC at `tau=0.25`
- establish a narrow anchor harness that any code candidate must beat before
  broader reruns are authorized

Sentinel crash matrix:

| Wave | Root | Family | Tau | Row |
|---|---|---|---|---:|
| `current_static` | `static_paper` | `gausmix` | `0p25` | `83` |
| `current_static` | `static_paper` | `laplace` | `0p25` | `107` |
| `current_static` | `static_paper` | `normal` | `0p25` | `131` |
| `current_static` | `static_shrink` | `gausmix` | `0p25` | `165` |
| `current_static` | `static_shrink` | `laplace` | `0p25` | `213` |
| `current_static` | `static_shrink` | `normal` | `0p25` | `261` |

What must be captured before any fix attempt is considered credible:
- exact seed and manifest row
- `i`, `sigma`, `gamma`, `lambda`, `tau`, `c2`
- first invalid `chi_i` index and value
- upstream `z`, `s`, `v`, and derived `psi_i`
- all warnings emitted before failure
- whether failure occurs before or after the first `s` update

Checklist:
- [ ] Implement non-invasive debug instrumentation on the debug branch only.
- [ ] Reproduce at least one crash case with full state capture.
- [ ] Check whether all six sentinel rows fail through the same upstream state.
- [ ] Determine whether the non-finite `chi_i` originates from `z`, `sigma`,
      `s`, `lambda`, or RHS prior hyperparameter drift.
- [ ] If the mechanism is clearly shared, stop at the six-row sentinel.
- [ ] If not clearly shared, expand to the full 18-row crash set.

Full crash set if expansion is needed:
- current static paper: `83,87,107,111,131,135`
- current static shrink: `165,166,173,174,213,214,221,222,261,262,269,270`

Acceptance criteria:
- a concrete upstream mechanism is identified for the invalid `chi_i`
- the mechanism is reproducible on at least two families and both roots
- the crash canary row `261` is explicitly tracked in every candidate run

### WS3. Static exal chain-quality diagnosis: sentinel matrix

Objective:
- diagnose why completed static `exal` MCMC runs frequently fail health gates
- evaluate candidate fixes on a narrow anchor harness instead of broad reruns

Sentinel mixing matrix:

| Wave | Root | Family | Tau | Row |
|---|---|---|---|---:|
| `current_static` | `static_paper` | `gausmix` | `0p05` | `75` |
| `current_static` | `static_paper` | `laplace` | `0p05` | `99` |
| `current_static` | `static_paper` | `normal` | `0p05` | `123` |
| `current_static` | `static_paper` | `gausmix` | `0p95` | `91` |
| `current_static` | `static_paper` | `laplace` | `0p95` | `115` |
| `current_static` | `static_paper` | `normal` | `0p95` | `139` |
| `current_static` | `static_shrink` | `gausmix` | `0p05` | `149` |
| `current_static` | `static_shrink` | `laplace` | `0p05` | `197` |
| `current_static` | `static_shrink` | `normal` | `0p05` | `245` |
| `current_static` | `static_shrink` | `gausmix` | `0p95` | `181` |
| `current_static` | `static_shrink` | `laplace` | `0p95` | `229` |
| `current_static` | `static_shrink` | `normal` | `0p95` | `277` |

What to capture:
- `accept_keep`
- trace of `sigma` and `gamma`
- ESS, ACF1, Geweke, half-drift
- MH adaptation history
- proposal covariance refresh outcomes
- whether the issue is dominated by low movement, sticky tail behavior, or
  unstable adaptation

Checklist:
- [ ] Run the 12-row mixing sentinel under the debug branch after crash
      instrumentation is available.
- [ ] Compare each sentinel row to its current baseline health metrics.
- [ ] Determine whether poor mixing is primarily a `sigma` problem, a `gamma`
      problem, or both.
- [ ] Determine whether behavior differs materially by `tau=0p05` vs `0p95`.
- [ ] Determine whether shrinkage root cases are materially worse than paper
      root cases.

Acceptance criteria for “clear improvement”:
- zero new runtime failures on the 12 sentinel rows
- at least 6 of 12 sentinel rows improve from `FAIL` to `WARN` or `PASS`
- median `ess_sigma` and median `ess_gamma` improve relative to current
  baseline
- median `half_drift_sigma` and `half_drift_gamma` decrease relative to current
  baseline
- at least one of the two mixing canaries (`245`, `277`) improves out of `FAIL`
  or `WARN`

If these are not met, do not authorize the full static rerun yet.

### WS4. Candidate fix implementation and regression protection

Objective:
- implement the smallest credible fix for static `exal`
- verify that the fix does not break already-recovered dynamic behavior

Candidate ordering rule imported from qdesn:

1. Candidate A: shared static `exal` core fix only
2. Candidate B: alternate shared-core fix only if Candidate A misses the
   canaries
3. Candidate C: rhs/shrink-specific overlay only after a shared-core winner is
   known
4. longer-chain inflation only as confirmation, not as first-line repair

Checklist:
- [ ] Keep package-code changes on the debug branch only until the sentinel
      evidence is satisfactory.
- [ ] Write a short fix note explaining the mechanism addressed.
- [ ] Re-run the six crash sentinels after the fix.
- [ ] Re-run the 12 mixing sentinels after the fix.
- [ ] If shared sampler or shared MCMC code changed, re-run dynamic row `57`
      same-seed as a regression guard.
- [ ] If only static `exal` code changed, document why row `57` regression is
      not needed.

Authorization gate for merge into the validation execution branch:
- [ ] crash sentinel: `6/6` done, `0` runtime failures
- [ ] mixing sentinel: passes the WS3 improvement threshold
- [ ] Candidate A has been evaluated before any rhs/shrink-specific overlay is
      attempted
- [ ] no evidence of regression on previously recovered paths

### WS5. Focused validation rerun after accepted fix

Objective:
- refresh only the scientifically affected validation slice

Target rerun scope after accepted static `exal` fix:

#### A. Current static refresh wave: all static exal MCMC rows

Current static row groups:
- `static_paper / 0p05`: `75,79,99,103,123,127`
- `static_paper / 0p25`: `83,87,107,111,131,135`
- `static_paper / 0p95`: `91,95,115,119,139,143`
- `static_shrink / 0p05`: `149,150,157,158,197,198,205,206,245,246,253,254`
- `static_shrink / 0p25`: `165,166,173,174,213,214,221,222,261,262,269,270`
- `static_shrink / 0p95`: `181,182,189,190,229,230,237,238,277,278,285,286`

Total current-static `exal` MCMC rows: `54`

#### B. Legacy RHS wave: all static exal MCMC rows

Legacy RHS row groups:
- `static_shrink / 0p05`: `149,157,197,205,245,253`
- `static_shrink / 0p25`: `165,173,213,221,261,269`
- `static_shrink / 0p95`: `181,189,229,237,277,285`

Total legacy-RHS `exal` MCMC rows: `18`

Important:
- these legacy row IDs overlap numerically with current-static row IDs
- always qualify them by wave/tag

#### C. Dynamic stale tail refresh rows

- row `5`
- row `15`

Grand focused rerun total after accepted fix:
- `72` static `exal` MCMC rows
- plus `2` dynamic stale rows
- `74` rows total

Checklist:
- [ ] Build fresh manifests for the focused rerun under new tags.
- [ ] Run current-static `exal` MCMC rerun.
- [ ] Run legacy-RHS `exal` MCMC rerun.
- [ ] Run dynamic stale tail refresh if not already completed in WS1.
- [ ] Generate fresh compact health tables for each rerun tag.

Acceptance criteria:
- no pending rows
- no silent missing artifacts
- static `exal` runtime failures materially reduced or eliminated
- overall health profile improved enough to support signoff judgment

### WS6. Campaign reconciliation and signoff prep

Objective:
- reconcile replacement artifacts and produce a clean end-state summary

Checklist:
- [ ] Fold row `57` replacement into the final effective study summary.
- [ ] Record whether rows `5` and `15` were replaced and under which tags.
- [ ] Produce a final “effective current state” table with no stale rows mixed
      into the active evidence layer.
- [ ] Write a signoff note that clearly separates:
      - accepted replacement evidence
      - legacy stale evidence
      - unresolved scientific concerns, if any remain

## 6. What we should not do

- [ ] Do not relaunch another broad 291-row campaign now.
- [ ] Do not debug static `exal` by repeatedly rerunning all 72 rows blindly.
- [ ] Do not edit package code directly on the validation execution branch.
- [ ] Do not overwrite the old tail or static tags when creating refreshed runs.
- [ ] Do not use row ID alone without wave/tag qualification.

## 7. Immediate next actions

Recommended order from today:

1. [ ] Create the static `exal` debug worktree/branch.
2. [ ] Refresh dynamic stale rows `5` and `15` under current `HEAD`.
3. [ ] Implement Candidate A as a shared static `exal` core fix only.
4. [ ] Run the six-row static crash sentinel with instrumentation.
5. [ ] Run the twelve-row mixing sentinel.
6. [ ] If Candidate A misses the canaries, evaluate one alternate shared-core
      Candidate B on the same anchor harness.
7. [ ] Only after a shared-core winner exists, consider any rhs/shrink-specific
      overlay.
8. [ ] If sentinel evidence is good enough, authorize the focused 74-row rerun.

## 8. Evidence log

Key current evidence anchors:
- `tools/merge_reports/full288_rhsns_impl_refresh_20260329/health_compact_20260329_114727.csv`
- `tools/merge_reports/full288_rhs_legacy_refresh_20260329/health_compact_20260329_123208.csv`
- `tools/merge_reports/full288_dynamic_tail_refresh_20260329/rows/row_0005.csv`
- `tools/merge_reports/full288_dynamic_tail_refresh_20260329/rows/row_0015.csv`
- `tools/merge_reports/full288_dynamic_tail_refresh_20260329/health/health_0015.csv`
- `tools/merge_reports/full288_row57_cppgig_same_seed_20260330/rows/row_0057.csv`
- `tools/merge_reports/full288_row57_cppgig_same_seed_20260330/health/health_0057.csv`
- `tools/merge_reports/full288_rhsns_impl_refresh_20260329/rows/row_0083.csv`
- `tools/merge_reports/full288_rhsns_impl_refresh_20260329/rows/row_0165.csv`
- `tools/merge_reports/full288_rhsns_impl_refresh_20260329/logs/row_83.log`
- `tools/merge_reports/full288_rhsns_impl_refresh_20260329/logs/row_165.log`

## 9. Bottom line

Current best diagnosis:
- row `57` is fixed
- rows `5` and `15` are stale and need refresh
- the main unresolved scientific blocker is static `exal` MCMC
- the static `exal` issue has two layers:
  - immediate `tau=0.25` invalid-state crashes
  - broader mixing/drift failures even when runs complete

Best next move:
- handle the stale dynamic tail quickly
- focus debugging effort on static `exal` MCMC before authorizing any broad
  rerun

## 10. Repair Candidate A Checkpoint (2026-03-31 11:00 EDT)

Status:
- dynamic stale-refresh lane is now current:
  - row `5` refreshed to `done / PASS / TRUE`
  - row `15` refreshed to `done / FAIL / FALSE`
- the dominant blocker moved from stale evidence to static shared-core quality

Debug branch state:
- worktree:
  `/home/jaguir26/local/src/exdqlm__wt__debug-static-exal-shared-core-20260331`
- branch:
  `debug/static-exal-shared-core-20260331`
- key commits:
  - `c0bccef` add gated static exal invalid-state snapshots for debug
  - `4926763` add beta-step invalid-state capture for static exal debug
  - `7d07bd4` add qbeta invalid-state capture for static ldvb debug
  - `307bc6b` stabilize static ldvb delta xi moments in debug

Root-cause finding now established:
- the original static crash is not first caused inside MCMC acceptance or the
  `chi` update
- the first upstream failure is in static `rhs_ns` LDVB warm-start at `iter=1`
- mechanism:
  - delta-approximated `xis$xi1` became nonpositive
  - `W = xis$xi1 * E_inv_v` became negative
  - qbeta then failed before the warm start produced a valid prior state
- direct warm-start evidence:
  - [LOCAL_static_exal_rhsns_vb_probe_20260331.csv](/home/jaguir26/local/src/exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_rhsns_vb_probe_20260331.csv)
  - [LOCAL_static_exal_root_cause_NOTE_20260331.md](/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/tools/merge_reports/LOCAL_static_exal_root_cause_NOTE_20260331.md)

Candidate A implementation:
- in `R/exal_static_LDVB.R`, positive xi moments now fall back to their
  base-at-the-mode values whenever the second-order delta correction makes them
  non-finite or nonpositive
- guarded components:
  - `xi1`
  - `xi_lambda2`
  - `xi_A2`
  - `zeta_logB` fallback to finite base value

Crash-lane results after Candidate A:
- exact 2-row smoke:
  - tag: `static_exal_exact_smoke_repair1_20260331`
  - rows: `261`, `83`
  - result: `2/2 done`, `0 runtime failures`, `0 invalid-state captures`
- exact 6-row crash sentinel:
  - tag: `static_exal_exact_crash6_repair1_20260331`
  - rows: `83,107,131,165,213,261`
  - result: `6/6 done`, `0 runtime failures`, `0 invalid-state captures`
  - gate distribution: `2 PASS`, `4 FAIL`

Interpretation:
- Candidate A successfully removes the historical `tau=0.25` crash band
- WS2 crash-removal gate is satisfied
- the blocker has shifted from hard runtime failure to chain-quality failure

12-row mixing sentinel after Candidate A:
- tag: `static_exal_exact_mix12_repair1_20260331`
- result:
  - `12/12 done`
  - `0 runtime failures`
  - `0 invalid-state captures`
  - `2 WARN / TRUE`
  - `10 FAIL / FALSE`
- baseline-vs-repair comparison:
  - [LOCAL_static_exal_health_compare_20260331.csv](/home/jaguir26/local/src/exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_health_compare_20260331.csv)

Mixing interpretation:
- Candidate A does **not** satisfy the WS3 improvement gate
- no sentinel row improved from baseline `FAIL` to `WARN` or `PASS`
- rows `181`, `197`, and `277` degraded from baseline `WARN` to `FAIL`
- the two `WARN` rows (`99`, `115`) were already `WARN` at baseline
- therefore Candidate A is not sufficient for focused rerun authorization

Decision after Candidate A:
- keep Candidate A as the first proven crash-removal fix
- do **not** authorize the 72-row static rerun yet
- advance to Candidate B design with a specific goal:
  preserve the crash fix while improving mixing/drift on the 12-row sentinel

## 11. Candidate B checkpoint and execution decision (2026-03-31 13:15 EDT)

Status:
- Candidate B evaluation is now complete enough to make a rerun decision.
- B1 was rejected.
- B2 is the best candidate tested so far, but it is still not strong enough to
  authorize the focused 72-row static rerun.

### 11.1 Candidate B1

Design:
- refresh the initial `(eta, ell)` mode before burn-in in
  `R/exal_static_mcmc.R`

Exact 2-row smoke tag:
- `static_exal_exact_smoke_repair2_modeinit_20260331`

Decision:
- reject B1

Reason:
- it remained crash-safe, but row `83` effectively froze
- key failure signal:
  `accept_keep = 0` with unusable ESS

### 11.2 Candidate B2

Design:
- keep Candidate A in place
- keep the VB coefficient warm start
- stop importing the full `rhs_ns` VB hyper-state into static MCMC
- instead, reset the `rhs_ns` global/slab hierarchy to neutral MCMC defaults
  and recompute moments before the first update

Debug commit:
- `5377050` `debug: neutralize rhs_ns hyper warm start in static exal mcmc`

Code location:
- `../exdqlm__wt__debug-static-exal-shared-core-20260331/R/exal_static_mcmc.R`

Exact 2-row smoke:
- tag: `static_exal_exact_smoke_repair2_neutralrhs_20260331`
- result:
  - `2/2 done`
  - `0 runtime failures`
  - `0 invalid-state captures`

Exact 6-row crash sentinel:
- tag: `static_exal_exact_crash6_repair2_neutralrhs_20260331`
- result:
  - `6/6 done`
  - `0 runtime failures`
  - `0 invalid-state captures`
  - `2 PASS`, `4 FAIL`

Exact 12-row mixing sentinel:
- tag: `static_exal_exact_mix12_repair2_neutralrhs_20260331`
- result:
  - `12/12 done`
  - `0 runtime failures`
  - `0 invalid-state captures`
  - `1 PASS`, `3 WARN`, `8 FAIL`
  - `4 healthy`

Primary comparison artifacts:
- [LOCAL_static_exal_three_way_compare_stack_20260331.csv](/home/jaguir26/local/src/exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_three_way_compare_stack_20260331.csv)
- [LOCAL_static_exal_three_way_compare_summary_20260331.csv](/home/jaguir26/local/src/exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_three_way_compare_summary_20260331.csv)
- [LOCAL_static_exal_three_way_compare_medians_20260331.csv](/home/jaguir26/local/src/exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_three_way_compare_medians_20260331.csv)
- [LOCAL_static_exal_baseline_vs_repair2_detail_20260331.csv](/home/jaguir26/local/src/exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_baseline_vs_repair2_detail_20260331.csv)
- [LOCAL_static_exal_baseline_vs_repair2_summary_20260331.csv](/home/jaguir26/local/src/exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_baseline_vs_repair2_summary_20260331.csv)

Aggregate comparison:

| Candidate | PASS | WARN | FAIL | Healthy | Crash-safe |
|---|---:|---:|---:|---:|---|
| baseline | 0 | 5 | 7 | 5 | no |
| A (`repair1`) | 0 | 2 | 10 | 2 | yes |
| B2 (`repair2`) | 1 | 3 | 8 | 4 | yes |

Median chain-health metrics on the 12-row mixing sentinel:

| Candidate | ess_sigma | ess_gamma | half_drift_sigma | half_drift_gamma | accept_keep |
|---|---:|---:|---:|---:|---:|
| baseline | 5.617 | 6.943 | 0.746 | 0.682 | 0.309 |
| A (`repair1`) | 6.765 | 5.219 | 0.806 | 1.074 | 0.376 |
| B2 (`repair2`) | 8.104 | 5.841 | 0.599 | 0.490 | 0.351 |

Baseline-to-B2 transition summary:
- `FAIL -> WARN/PASS`: `1`
- `WARN -> PASS`: `1`
- `healthy FALSE -> TRUE`: `1`
- `healthy TRUE -> FALSE`: `2`

Interpretation:
- B2 is the best tested candidate so far.
- B2 preserves the crash fix and improves the overall aggregate mix sentinel
  relative to Candidate A.
- B2 is still not good enough to authorize the focused rerun because the hard
  shrink-normal canary (`245`) remains `FAIL`, only one baseline `FAIL` row
  upgraded to `WARN/PASS`, and two baseline-healthy rows became unhealthy.

### 11.3 Important negative finding about a would-be Candidate C

The qdesn-inspired idea of a short MCMC tau-freeze follow-up is **not** a real
new candidate in this study.

Why:
- both Candidate A and Candidate B2 already ran with:
  - `freeze_tau_iters = 50`
  - `freeze_tau_warmup_iters = 50`
  - `force_tau_after_warmup = TRUE`
- this was verified directly from finished repair fit objects under:
  - `static_exal_exact_mix12_repair1_20260331`
  - `static_exal_exact_mix12_repair2_neutralrhs_20260331`

Implication:
- a “Candidate C tau-freeze warmup” would duplicate a control that is already
  active
- therefore it should **not** be treated as a new experiment or a credible
  next-step lever

### 11.4 Execution decision

Decision:
- do **not** authorize the focused 72-row static rerun yet
- keep Candidate B2 as the current best debug baseline
- close the current A/B candidate cycle here

Reason:
- crash removal is now credible
- signoff-grade chain quality is still not credible
- the next valid engineering move must use a genuinely new lever rather than a
  duplicate tau-freeze study

### 11.5 Next valid work, if the study continues

Only these directions are still justified:
- new static `rhs_ns` quality lever that is **not already active**
- same exact crash and mixing sentinels for all further comparisons
- dynamic row `15` remains a separate current-HEAD quality issue and should not
  drive the static rerun decision

What not to do next:
- do not launch the 72-row static rerun now
- do not run a fake “Candidate C tau-freeze” study
- do not broaden back into a full campaign relaunch

## 12. Post-wave-8 baseline promotion and comparison-readiness checkpoint (2026-04-03)

Primary references:

- `reports/static_exal_tuning_20260403/wave8_closeout_and_fail_only_repair_program.md`
- `reports/static_exal_tuning_20260403/fail_only_bridge_results_20260403.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/full288_dynamic_tail_cppgig_refresh_20260331/rows/row_0005.csv`
- `tools/merge_reports/full288_dynamic_tail_cppgig_refresh_20260331/rows/row_0015.csv`

Current validated state after wave-8 closeout and the fail-only bridge run:

- the active exact-runner carry-forward baseline is now `F080_sub2_s105`
- `F080_sub2_s100_ref` remains the primary backup
- `F080_sub2_s0975` is a viable narrow bridge candidate, but not the primary
  production baseline
- `F075_sub2_s095` is now dropped as a dominated candidate

What improved:

- wave-8 completed end to end under the repaired resume stack
- the static `exal` problem is no longer blocked on orchestration
- the exact-runner baseline improved from `F080_sub2_s100` (`7 PASS / 4 WARN /
  1 FAIL`) to `F080_sub2_s105` (`22 PASS / 4 WARN / 0 FAIL`)
- dynamic tail row `5` is now resolved under
  `full288_dynamic_tail_cppgig_refresh_20260331` with `done / PASS / TRUE`

What still remains:

- the stale `72`-row static `exal` rerun debt has not yet been refreshed under
  `F080_sub2_s105`
- dynamic row `15` remains `done / FAIL / FALSE` under the refreshed current
  `HEAD` run
- the full merged validation campaign tables have not yet been regenerated from
  the promoted baseline

Minimal remaining refresh scope for a comparison-ready campaign:

| workstream | cases | note |
|---|---:|---|
| static `exal` current RHS-NS | 54 | stale relative to promoted baseline |
| static `exal` legacy RHS | 18 | stale relative to promoted baseline |
| dynamic tail row `15` | 1 | current-HEAD refresh still fails |
| total rerun debt | 73 | reuse all other currently valid artifacts |

Updated immediate decision:

1. freeze `F080_sub2_s105` as the active static `exal` validation baseline
2. prepare and run the focused `72`-row static rerun under the promoted
   exact-runner baseline
3. keep dynamic row `15` as a separate but active sidecar repair lane
4. merge the refreshed outputs with the reusable campaign artifacts and produce
   the final comparison-ready tables

Operational rule:

- do not reopen a broad tuning wave at this point
- do not relaunch the full `291`-row campaign
- rerun only the `73` cases that still block a no-FAIL comparison-ready
  campaign

## 12.1 Static refresh closeout and fail-band checkpoint (2026-04-03)

Primary references:

- `reports/static_exal_tuning_20260403/campaign_completion_execution_20260403.md`
- `reports/static_exal_tuning_20260403/static_refresh_closeout_and_failband_program_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_fail_inventory_20260403.csv`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_fail_patterns_20260403.csv`

The focused `72`-row static rerun under `F080_sub2_s105` is now complete.

Validated final static refresh result:

| scope | total | PASS | WARN | FAIL |
|---|---:|---:|---:|---:|
| current RHS-NS | 54 | 11 | 22 | 21 |
| legacy RHS | 18 | 4 | 5 | 9 |
| overall static refresh | 72 | 15 | 27 | 30 |

What improved:

- the stale static fail burden was cut from `60` FAIL scope-cases to `30`
- current RHS-NS improved from `47 FAIL / 7 WARN / 0 PASS` to
  `21 FAIL / 22 WARN / 11 PASS`
- legacy RHS improved from `13 FAIL / 4 WARN / 1 PASS` to
  `9 FAIL / 5 WARN / 4 PASS`
- the refresh orchestration and scope-aware prior semantics held to completion

What did not improve enough:

- `F080_sub2_s105` did not generalize cleanly enough to become a
  comparison-ready full-campaign baseline
- the campaign still violates the `0 FAIL` rule
- dynamic row `15` remains unresolved and separate

Important decision update:

- keep the completed `F080_sub2_s105` refresh as the new empirical reference
  wave for repair planning
- do **not** treat it as the final production baseline
- the remaining campaign debt is now:
  - `30` residual static FAIL scope-cases
  - `1` dynamic row `15`
  - total unresolved debt: `31`

Fail-band structure:

- `30` static FAIL scope-cases collapse to `15` unique `(family, tau, tt)`
  patterns
- highest-priority recurring anchors across current and legacy scope:
  - row `157` / `gausmix` / `tt1000` / `tau0p05`
  - row `165` / `gausmix` / `tt100` / `tau0p25`
  - row `173` / `gausmix` / `tt1000` / `tau0p25`
  - row `237` / `laplace` / `tt1000` / `tau0p95`

Updated immediate decision:

1. freeze the completed static refresh as the new repair-planning baseline
2. do not rerun the `42` refreshed static non-FAIL rows
3. prepare a fail-only next wave on the `30` static FAIL scope-cases
4. keep dynamic row `15` as a separate sidecar lane

## 12.2 Static fail-band wave-1 overnight plan (2026-04-03)

Primary references:

- `reports/static_exal_tuning_20260403/failband_wave1_overnight_program_20260403.md`
- `reports/static_exal_tuning_20260403/static_refresh_closeout_and_failband_program_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_fail_inventory_20260403.csv`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_fail_patterns_20260403.csv`

Current planning baseline:

- keep the completed `F080_sub2_s105` refresh as the empirical reference wave
- do not treat it as a signoff-ready production baseline

Main planning takeaways:

- the study improved materially, but the remaining static debt is still a real
  `30`-case fail band
- broad reruns are no longer justified
- the next useful broad search is now "broad within the fail band," not broad
  across the whole campaign

Wave-1 candidate set:

| candidate_id | jump | scale | role |
|---|---:|---:|---|
| `F080_sub2_s100_ref` | 0.0800 | 1.000 | strongest direct control |
| `F080_sub2_s0975` | 0.0800 | 0.975 | repaired bridge candidate |
| `F0825_sub2_s100` | 0.0825 | 1.000 | midpoint hedge |
| `F075_sub2_s105` | 0.0750 | 1.050 | lower-jump hedge |
| `F085_sub2_s095` | 0.0850 | 0.950 | upper-edge tempered hedge |
| `F085_sub2_s105` | 0.0850 | 1.050 | upper-edge wide hedge |

Explicit exclusions:

- `F080_sub2_s105` rerun: use existing completed reference results instead
- `F075_sub2_s095`: dominated
- `F080_sub2_s095`: too tight
- `C060`, `F090`, `F095`, lambda-tempering, no-jump, `substeps = 3`: already
  screened as weak or unhelpful

Wave-1 scope:

- `30` residual static FAIL scope-cases only
- `21` current RHS-NS
- `9` legacy RHS
- `6` candidate profiles
- `180` total runs

Dynamic row `15` decision:

- keep separate
- do not relaunch in the overnight static wave
- require a genuine repair hypothesis first

Readiness verification completed:

- prepare-only counts confirm `180` total runs (`126` current, `54` legacy)
- two-row live smoke under `F080_sub2_s100_ref` succeeded operationally:
  - current row `79` -> `WARN`
  - legacy row `269` -> `FAIL`
- conclusion:
  - the new wave-1 tooling is launch-ready
  - the smoke is evidence of orchestration correctness, not of final candidate
    ranking

Updated immediate decision:

1. launch the fail-band-only overnight screen on the `30` static FAIL rows
2. preserve `F080_sub2_s105` as the non-rerun reference wave
3. rank candidates strictly by FAIL count first
4. if no candidate reaches `0 FAIL`, isolate only the remaining residual rows
   for wave-2

## 12.3 Fail-band wave-1 closeout and broad staged wave-2 program (2026-04-04)

Primary references:

- `reports/static_exal_tuning_20260404/failband_wave1_closeout_and_wave2_broad_program_20260404.md`
- `reports/static_exal_tuning_20260403/failband_wave1_overnight_program_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave1_schedule_20260403.csv`

Wave-1 closeout summary:

| candidate_id | PASS | WARN | FAIL | resolved |
|---|---:|---:|---:|---:|
| `F080_sub2_s0975` | 7 | 11 | 12 | 18 |
| `F085_sub2_s105` | 7 | 11 | 12 | 18 |
| `F075_sub2_s105` | 3 | 13 | 14 | 16 |
| `F0825_sub2_s100` | 3 | 13 | 14 | 16 |
| `F080_sub2_s100_ref` | 3 | 8 | 19 | 11 |
| `F085_sub2_s095` | 3 | 7 | 20 | 10 |

Main operational takeaways:

- wave-1 completed cleanly; orchestration is still solid
- no candidate reached `0 FAIL`
- the co-lead repair anchors are now:
  - `F080_sub2_s0975`
  - `F085_sub2_s105`
- the tertiary midpoint control worth preserving is:
  - `F0825_sub2_s100`
- the following candidates should now be treated as screened out for the
  active residual-band search:
  - `F075_sub2_s105`
  - `F080_sub2_s100_ref`
  - `F085_sub2_s095`

Hardest rows after wave-1:

- failed under all six screened candidates:
  - current `87`, `254`, `286`
  - legacy `269`

Updated immediate decision:

1. keep dynamic row `15` separate
2. keep the static scope at the same `30` residual FAIL scope-cases
3. broaden only within the surviving upper-central neighborhood
4. use a staged wave-2 screen rather than another flat full-band pass

Wave-2 candidate neighborhood:

| class | candidates |
|---|---|
| retained anchors | `F080_sub2_s0975`, `F0825_sub2_s100`, `F085_sub2_s105` |
| new bridge variants | `F0825_sub2_s1025`, `F0825_sub2_s105`, `F085_sub2_s100`, `F085_sub2_s1025` |
| cautious upper-edge extension | `F0875_sub2_s100`, `F0875_sub2_s1025`, `F0875_sub2_s105` |

Wave-2 staging rule:

1. `sentinel12` on the hardest `12` rows across all `10` candidates
2. advance top `5` candidates to `expand20`
3. advance top `2` candidates to `full30`
4. keep ranking order:
   - lowest FAIL
   - lowest WARN
   - highest PASS

Operational objective:

- spend full-band budget only on finalists
- keep the search broad enough to find a real alternative if one exists
- avoid reopening low-jump, tight upper-edge, or frontier families that now
  have enough negative evidence

Readiness verification completed:

- prepare-only counts:
  - `sentinel12 = 120`
  - `expand20 = 200`
  - `full30 = 300`
- actual staged execution budget remains bounded at `280` runs
- shell launch/supervisor/monitor scripts parse cleanly
- stage promotion now penalizes missing rows before FAIL/WARN ranking

## 12.4 Fail-band wave-2 closeout and residual-only wave-3 checkpoint (2026-04-04)

Primary references:

- `reports/static_exal_tuning_20260404/failband_wave2_closeout_and_wave3_residual_program_20260404.md`
- `reports/static_exal_tuning_20260404/failband_wave1_closeout_and_wave2_broad_program_20260404.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave2_schedule_20260404.csv`

Operational state:

- wave-2 is not running
- no tmux session or runner process remains active
- the launched wave-2 evidence is still strong enough to move forward without
  resuming the old staged program

Actual launched wave-2 stage summary:

| stage | total | done | missing | PASS | WARN | FAIL |
|---|---:|---:|---:|---:|---:|---:|
| `sentinel12` | 120 | 119 | 1 | 10 | 42 | 67 |
| `expand20` | 100 | 100 | 0 | 13 | 47 | 40 |
| `full30` | 60 | 59 | 1 | 13 | 27 | 19 |

Important closeout findings:

- new best completed broad residual-band baseline:
  - `F085_sub2_s100` on `full30`: `6 PASS / 15 WARN / 9 FAIL`
- strongest complementary control:
  - `F0825_sub2_s100` on `full30`: `7 PASS / 12 WARN / 10 FAIL / 1 MISSING`
- the remaining useful search space tightened materially:
  - keep only jump in `[0.0825, 0.0850]`
  - keep only scale in `[1.000, 1.025]`
- screened out for the active residual-band search:
  - `F080_sub2_s0975`
  - `F0825_sub2_s105`
  - `F085_sub2_s105`
  - all `F0875_sub2_*`

Residual row structure after wave-2:

- the union of rows still `FAIL` or `MISSING` under
  `F085_sub2_s100` or `F0825_sub2_s100` is `18`
- two especially stubborn shared fail rows remain:
  - current row `87` / `gausmix / tt1000 / tau0p25`
  - current row `174` / `gausmix / tt1000 / tau0p25`
- the only bookkeeping miss that remains decision-relevant is:
  - `F0825_sub2_s100 / current row 103 / laplace / tt1000 / tau0p05`

Updated immediate decision:

1. do **not** resume the old wave-2 staged program
2. treat `F085_sub2_s100` as the new residual-band planning baseline
3. treat `F0825_sub2_s100` as the primary complement
4. open a residual-only wave-3 bridge search on the `18` unresolved rows
5. confirm the top `2` wave-3 candidates on the full `30` residual rows
6. keep dynamic row `15` separate until it has its own repair hypothesis

## 12.5 Fail-band wave-3 closeout and wave-4 targeted repair checkpoint (2026-04-04)

Primary references:

- `reports/static_exal_tuning_20260404/failband_wave3_closeout_and_wave4_targeted_repair_program_20260404.md`
- `reports/static_exal_tuning_20260404/failband_wave2_closeout_and_wave3_residual_program_20260404.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave3_schedule_20260404.csv`

Wave-3 closeout summary:

| stage | total | PASS | WARN | FAIL | missing |
|---|---:|---:|---:|---:|---:|
| `residual18` | 144 | 28 | 44 | 72 | 0 |
| `confirm30` | 60 | 7 | 28 | 25 | 0 |

Main operational takeaways:

- wave-3 completed cleanly; orchestration is still not the blocker
- `F085_sub2_s100` remains the best completed broad residual-band baseline
- `F0825_sub2_s100` and `F0835_sub2_s1025` tied on `residual18`, but both
  failed to beat `F085_sub2_s100` on the broad confirmation pass
- the active static repair problem is now most usefully expressed as the
  `9` rows still failing under `F085_sub2_s100`

Static rows still failing under the best broad baseline:

- current: `87`, `115`, `135`, `174`, `190`, `206`, `278`
- legacy: `181`, `269`

Important row-level evidence:

- rows `87`, `174`, and `269` remain the hardest shared repair cluster
- row `135` has one uniquely useful observed rescue:
  - `F0825_sub2_s105`
- row `190` is most favorable to:
  - `F0825_sub2_s1025`
- row `206` is favorable to:
  - `F0825_sub2_s100`
  - `F085_sub2_s1025`
- rows `115`, `181`, and `278` now have multiple plausible repair candidates

Updated immediate decision:

1. freeze `F085_sub2_s100` as the best completed broad static repair baseline
2. do **not** run another broad shared-setup wave
3. open a targeted wave-4 repair matrix on only the `9` rows still failing
   under that baseline
4. keep candidate search inside the surviving `F0825` to `F085` band, with
   `F0825_sub2_s105` retained only as a special-case probe
5. keep dynamic row `15` separate until it has a true repair hypothesis

## 12.6 Fail-band wave-5 closeout and wave-6 row-specific closure checkpoint (2026-04-04)

Primary references:

- `reports/static_exal_tuning_20260404/failband_wave5_closeout_and_wave6_row_specific_closure_program_20260404.md`
- `reports/static_exal_tuning_20260404/failband_wave4_closeout_and_wave5_local_repair_program_20260404.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave5_schedule_20260404.csv`

Wave-5 closeout summary:

| stage | total | PASS | WARN | FAIL | missing |
|---|---:|---:|---:|---:|---:|
| `confirm9` | 9 | 1 | 4 | 4 | 0 |
| `probe2` | 2 | 0 | 1 | 1 | 0 |
| `overall` | 11 | 1 | 5 | 5 | 0 |

Main operational takeaways:

- wave-5 completed cleanly; orchestration remains healthy
- the wave-4 provisional local map should **not** be used unchanged
- the better static baseline is now:
  - broad default: `F085_sub2_s100`
  - evidence-weighted local overrides only where repeated row-level evidence
    supports them
- the active static problem is now best expressed as:
  - `3` core closure rows: `135`, `190`, `269`
  - `6` non-`FAIL` rows needing only stability/provenance confirmation

Promoted local repair baseline v2:

- `87` -> `F085_sub2_s1025`
- `115` -> `F0825_sub2_s100`
- `135` -> `F0845_sub2_s100` (current safest fallback; still active closure row)
- `174` -> `F0875_sub2_s105`
- `181` -> `F0825_sub2_s100`
- `190` -> `F0825_sub2_s1025`
- `206` -> `F0825_sub2_s1025`
- `269` -> `F0845_sub2_s100` (current safest fallback; still active closure row)
- `278` -> `F0845_sub2_s1025`

Important row-level evidence after wave-5:

- row `115`: `F0825_sub2_s100` is materially stronger than the older
  provisional `F0845_sub2_s1025` choice
- row `174`: `F0875_sub2_s105` remains the only durable row-specific exception
- row `181`: `F0825_sub2_s100` is more stable than keeping the broad default
- row `190`: `F0825_sub2_s1025` is now the best closure anchor
- row `269`: `F0845_sub2_s100` is the safest current non-`FAIL` fallback

Updated immediate decision:

1. keep `F085_sub2_s100` as the broad static default baseline
2. promote the evidence-weighted local repair baseline v2
3. do **not** reopen any shared residual-band search
4. open a wave-6 row-specific closure lane with:
   - full `9`-row confirmation of the improved local baseline
   - extra repair probes only on rows `135`, `190`, and `269`
5. keep dynamic row `15` separate until it has a true repair hypothesis

## 12.7 Fail-band wave-6 closeout and wave-7 triplet closure checkpoint (2026-04-04)

Primary references:

- `reports/static_exal_tuning_20260404/failband_wave6_closeout_and_wave7_triplet_closure_program_20260404.md`
- `reports/static_exal_tuning_20260404/failband_wave5_closeout_and_wave6_row_specific_closure_program_20260404.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave6_schedule_20260404.csv`

Wave-6 closeout summary:

| stage | total | PASS | WARN | FAIL | missing | resolved |
|---|---:|---:|---:|---:|---:|---:|
| `confirm9_v2` | 9 | 3 | 2 | 4 | 0 | 5 |
| `repair13` | 13 | 0 | 5 | 8 | 0 | 5 |
| `overall` | 22 | 3 | 7 | 12 | 0 | 10 |

Main operational takeaways:

- wave-6 completed cleanly; orchestration is still not the blocker
- the static repair problem is now no longer a nine-row band
- wave-6 reduced the active static blocking core to:
  - current `87`
  - current `174`
  - legacy `269`
- rows `135`, `190`, and `206` are now the non-`FAIL`
  stability/provenance lane
- rows `115`, `181`, and `278` remain stable `PASS`

Promoted local repair baseline v3:

- `87` -> `F085_sub2_s1025` (best unresolved anchor only)
- `115` -> `F0825_sub2_s100`
- `135` -> `F0840_sub2_s1025`
- `174` -> `F0875_sub2_s105` (best unresolved anchor only)
- `181` -> `F0825_sub2_s100`
- `190` -> `F0825_sub2_s100`
- `206` -> `F0825_sub2_s1025`
- `269` -> `F0845_sub2_s100` (best unresolved anchor only)
- `278` -> `F0845_sub2_s1025`

Important row-level evidence after wave-6:

- row `135`: `F0840_sub2_s1025` is the first fresh wave-6 improvement that
  clearly beats the old fallback anchor
- row `190`: the durable non-`FAIL` ridge remains centered on:
  - `F0825_sub2_s100`
  - `F0825_sub2_s1025`
  - `F0835_sub2_s1025`
  - `F0845_sub2_s1025`
- row `206`: still non-`FAIL`; keep it narrow and do not waste broad search
- row `87`: only the `F085_sub2_s1025` corridor plus the lower fallback
  `F0825_sub2_s100` still show any real non-`FAIL` signal
- row `174`: remains the lone `F0875_sub2_s105` exception
- row `269`: repeated scale-`1.000` reruns regressed again, so the next lane
  must allow a small execution-control pivot, not just more identical reruns

Updated immediate decision:

1. keep `F085_sub2_s100` as the broad static default baseline
2. promote the local repair baseline to `v3`
3. do **not** reopen any generic shared-setup search
4. open a wave-7 triplet-closure lane with:
   - a tiny `v3` stability confirmation lane on `135`, `190`, `206`
   - a row-local closure matrix only on `87`, `174`, and `269`
5. allow a very small execution-control lane on the blocking rows only:
   - longer runs
   - targeted `slice_eta` pilots
6. keep dynamic row `15` separate until it has its own repair hypothesis

## 12.8 Wave-7 closeout and wave-8 seed-init + dynamic replay checkpoint (2026-04-05)

Primary references:

- `reports/static_exal_tuning_20260405/failband_wave7_closeout_and_wave8_seedinit_dynamic_closure_program_20260405.md`
- `reports/static_exal_tuning_20260404/failband_wave6_closeout_and_wave7_triplet_closure_program_20260404.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave8_schedule_20260405.csv`
- `tools/merge_reports/LOCAL_dynamic_row15_wave8_matrix_20260405.csv`

Wave-7 closeout summary:

| stage | total | PASS | WARN | FAIL | missing | resolved |
|---|---:|---:|---:|---:|---:|---:|
| `stability3_v3` | 3 | 1 | 1 | 1 | 0 | 2 |
| `core17_triplet` | 17 | 0 | 2 | 15 | 0 | 2 |
| `overall` | 20 | 1 | 3 | 16 | 0 | 4 |

Main operational takeaways:

- wave-7 completed cleanly; orchestration remains stable
- row `87` improved from `FAIL` to `WARN`
- row `206` improved from reusable `WARN` to fresh `PASS`
- row `190` remains non-`FAIL`
- the static blocking core is now:
  - `135`
  - `174`
  - `269`
- dynamic row `15` now has a concrete replayable rescue:
  - TT5000 `slice_wave2_20260319`

Promoted local repair baseline v4:

- default:
  - `F085_sub2_s100`
- row-local:
  - `87` -> `F085_sub2_s1025_slice`
  - `115` -> `F0825_sub2_s100`
  - `135` -> open anchor `F0835_sub2_s1025`
  - `174` -> open anchor `F0875_sub2_s105`
  - `181` -> `F0825_sub2_s100`
  - `190` -> `F0825_sub2_s100_rwlong`
  - `206` -> `F0825_sub2_s1025_rwlong`
  - `269` -> open anchor `F0825_sub2_s100`
  - `278` -> `F0845_sub2_s1025`

Updated immediate decision:

1. keep `F085_sub2_s100` as the broad static default baseline
2. do **not** reopen any generic shared-setup search
3. open a wave-8 closure lane with:
   - one row-`87` confirmation
   - exact short replay plus `vb`-init probes on `135`, `174`, `269`
4. open a separate dynamic row-`15` sidecar with:
   - exact TT5000 slice replay
   - one mild longer slice control
5. treat this as a final closure phase, not another discovery wave

## 12.9 Wave-8 static root-cause checkpoint and wave-9 exact-replay program (2026-04-05)

Primary references:

- `reports/static_exal_tuning_20260405/failband_wave8_rootcause_and_wave9_exact_replay_noneinit_program_20260405.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave8_failures_20260405_010431_8030_1967051.log`
- `tools/merge_reports/LOCAL_static_exal_failband_wave9_schedule_20260405.csv`

Main root-cause finding:

- the static wave-8 stop was caused by both:
  - a scientific crash lane:
    all six `vb` probes on rows `135` and `174` failed immediately with
    `Static MCMC state invalid (iter=2): static_exal chi has 1000 non-finite values`
  - an orchestration bug:
    the static launcher/supervisor path allowed those crashed rows to remain
    `MISSING` while still exiting as if the stage had completed

Root-cause fix now applied:

- the static launcher now runs the evaluator after each stage and exits
  non-zero if `missing > 0`
- this prevents another overnight static lane from silently "finishing" with
  missing rows

Scientific implications:

- `init_mode = vb` is now explicitly low-value for rows `135` and `174`
- row `269` is different:
  `F0845_sub2_s100_vb` improved it from `FAIL` to `WARN` and should now be the
  promoted local anchor
- row `87` is now understood as a seed-stability problem, not a missing
  geometry-corridor problem

Promoted static baseline v5:

- broad default:
  - `F085_sub2_s100`
- row-local promotions:
  - `87` -> exact-history `F085_sub2_s1025` replay corridor
  - `190` -> `F0825_sub2_s100_rwlong`
  - `206` -> `F0825_sub2_s1025_rwlong`
  - `269` -> `F0845_sub2_s100_vb`

Updated immediate decision:

1. keep `F085_sub2_s100` as the broad static default baseline
2. do **not** reopen any generic shared-setup search
3. leave the dynamic row-`15` slice sidecar running
4. open a wave-9 static closure lane with:
   - exact historical seed replay on row `87`
   - exact historical short-anchor replay plus `init_mode = none` on rows
     `135` and `174`
   - confirmation / hardening of the promoted row-`269` rescue
5. treat rows `135`, `174`, and dynamic row `15` as the remaining true
   blocking debts, with `87` and `269` as unstable/promoted local exceptions

## 12.10 Wave-9 closeout and wave-10 row-87 micro-band checkpoint (2026-04-05)

Primary references:

- `reports/static_exal_tuning_20260405/failband_wave9_closeout_and_wave10_row87_microband_program_20260405.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave9_schedule_20260405.csv`
- `tools/merge_reports/LOCAL_dynamic_row15_wave8_matrix_20260405.csv`

Wave-9 closeout summary:

| stage | total | PASS | WARN | FAIL | missing | resolved |
|---|---:|---:|---:|---:|---:|---:|
| `stability7_exact` | 7 | 0 | 1 | 6 | 0 | 1 |
| `closure12_exact_none` | 12 | 1 | 1 | 10 | 0 | 2 |
| `overall` | 19 | 1 | 2 | 16 | 0 | 3 |

Main takeaways:

- wave-9 completed cleanly with `0 missing`; the static completeness fix held
- row `135` improved to `PASS`
- row `174` improved to `WARN`
- row `269` improved to `WARN`
- dynamic row `15` improved to `WARN / healthy = TRUE` under the exact slice
  replay
- only one blocking validation case now remains:
  - static row `87`

Promoted local baseline v7:

- broad default:
  - `F085_sub2_s100`
- row-local promotions:
  - `135` -> `F0825_sub2_s105_none`
  - `174` -> `F085_sub2_s105_histshort`
  - `190` -> `F0825_sub2_s100_rwlong`
  - `206` -> `F0825_sub2_s1025_rwlong`
  - `269` -> `F0845_sub2_s100_histshort`
  - dynamic row `15` -> `row15_slice_exact_20260405`

Updated immediate decision:

1. keep `F085_sub2_s100` as the broad static default baseline
2. freeze the newly promoted non-`FAIL` local baselines for:
   - `135`
   - `174`
   - `269`
   - dynamic row `15`
3. do **not** spend more compute on any resolved row
4. open a wave-10 row-`87`-only closure lane with:
   - exact historical anchor confirmations
   - slightly longer confirmations
   - a tiny micro-band expansion around the only surviving `F085` / `F0855`
     scale-`1.025` corridors
5. treat this as the final static closure program unless row `87` still
   refuses to reach non-`FAIL`

## 12.11 Wave-10 closeout and wave-11 row-87 lower-mid checkpoint (2026-04-05)

Primary references:

- `reports/static_exal_tuning_20260405/failband_wave10_closeout_and_wave11_row87_lowermid_program_20260405.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave10_schedule_20260405.csv`

Wave-10 closeout summary:

| stage | total | PASS | WARN | FAIL | missing | resolved |
|---|---:|---:|---:|---:|---:|---:|
| `anchor4_confirm` | 4 | 0 | 0 | 4 | 0 | 0 |
| `micro4_expand` | 4 | 0 | 0 | 4 | 0 | 0 |
| `overall` | 8 | 0 | 0 | 8 | 0 | 0 |

Main takeaways:

- wave-10 completed cleanly and therefore gives valid negative evidence
- dynamic row `15` is already resolved to `WARN` and no longer blocks closure
- static row `87` remains the only campaign blocker
- wave-10 exhausted the later `F085` / `F0855` scale-`1.025` row-`87`
  micro-band
- a deeper row-`87` artifact audit corrected the earlier framing:
  historical non-`FAIL` anchors also exist in:
  - `F0825_sub2_s100`
  - `F0825_sub2_s1025`
  - `F0835_sub2_s1025`
  - `F085_sub2_s1025`
  under short `laplace_rw` runs

Promoted local baseline v8:

- broad default:
  - `F085_sub2_s100`
- row-local promotions:
  - `135` -> `F0825_sub2_s105_none`
  - `174` -> `F085_sub2_s105_histshort`
  - `190` -> `F0825_sub2_s100_rwlong`
  - `206` -> `F0825_sub2_s1025_rwlong`
  - `269` -> `F0845_sub2_s100_histshort`
  - dynamic `15` -> `row15_slice_exact_20260405`
- remaining blocker:
  - `87` -> open lower-mid replay/confirmation corridor

Updated immediate decision:

1. do **not** reopen any broad shared-setup search
2. do **not** spend more compute inside the exhausted late
   `F085` / `F0855` micro-band
3. open a wave-11 row-`87`-only closure lane with:
   - exact short replays of the lower-mid historical non-`FAIL` anchors
   - moderate-length confirmations on that same lower-mid corridor
   - a tiny `init_mode = none` lane on the lower-mid anchors only
4. keep the rest of the campaign frozen and reusable while row `87` is being
   closed

## 12.12 Wave-11 closeout and comparison-ready handoff (2026-04-05)

Primary references:

- `reports/static_exal_tuning_20260405/failband_wave11_closeout_and_comparison_ready_handoff_20260405.md`
- `reports/static_exal_tuning_20260405/failband_wave10_closeout_and_wave11_row87_lowermid_program_20260405.md`
- `tools/merge_reports/LOCAL_validation_campaign_promoted_local_map_v9_20260405.csv`

Wave-11 closeout summary:

| stage | total | PASS | WARN | FAIL | missing | resolved |
|---|---:|---:|---:|---:|---:|---:|
| `anchor4_short_hist` | 4 | 0 | 1 | 3 | 0 | 1 |
| `confirm4_medium` | 4 | 0 | 1 | 3 | 0 | 1 |
| `none3_lowermid` | 3 | 0 | 1 | 2 | 0 | 1 |
| `overall` | 11 | 0 | 3 | 8 | 0 | 3 |

Main takeaways:

- wave-11 completed cleanly with `0 missing`
- row `87` is now closed to non-`FAIL` at the promoted row-best level
- the remaining tail is now fully non-`FAIL`:
  - `87` -> `WARN`
  - `135` -> `PASS`
  - `174` -> `WARN`
  - `269` -> `WARN`
  - dynamic `15` -> `WARN`
- there are no active validation jobs running in this worktree now
- repair search is complete unless a later merge/provenance audit finds a real
  regression

Promoted campaign map v9:

- broad default:
  - `F085_sub2_s100`
- row-local promotions:
  - `87` -> `F085_sub2_s1025_histshort`
  - `135` -> `F0825_sub2_s105_none`
  - `174` -> `F085_sub2_s105_histshort`
  - `190` -> `F0825_sub2_s100_rwlong`
  - `206` -> `F0825_sub2_s1025_rwlong`
  - `269` -> `F0845_sub2_s100_histshort`
  - dynamic `15` -> `row15_slice_exact_20260405`

Updated immediate decision:

1. stop opening new repair waves by default; the active tail is closed
2. freeze the promoted campaign map v9 and preserve manifest-level provenance
3. build the merged final campaign selection table
4. regenerate campaign-level health and comparison tables
5. only reopen tuning if the merge/provenance audit reveals a real regression

## 12.13 Comparison-ready assembly planning checkpoint (2026-04-05)

Primary references:

- `reports/static_exal_tuning_20260405/comparison_ready_assembly_plan_20260405.md`
- `reports/static_exal_tuning_20260405/failband_wave11_closeout_and_comparison_ready_handoff_20260405.md`
- `tools/merge_reports/LOCAL_validation_campaign_promoted_local_map_v9_20260405.csv`

Planning conclusions:

- the repair phase is complete at the promoted row-best level
- the next work is an assembly problem, not a tuning problem
- the final merged campaign must reconcile exactly to:
  - `218` reusable historical artifacts
  - `42` refreshed static non-`FAIL` rows
  - `21` residual-band broad-default rows
  - `9` promoted local static overrides
  - `1` dynamic local override
- the exact final accounting invariant is therefore:
  - `218 + 42 + 21 + 9 + 1 = 291`

Most important execution findings:

1. the stale static debt is already defined cleanly by:
   - `LOCAL_targeted_manifest_current_static_rhsns_20260329.csv`
   - `LOCAL_targeted_manifest_legacy_rhs_refresh_20260329.csv`
2. the refresh health pools already expose compact row-level health schemas and
   should be joined by normalized row metadata plus scope, not by ad hoc file
   names
3. the reusable `218`-case pool likely still needs a canonical materialized
   inventory table before final merge
4. the safest final merge path is:
   - freeze map
   - build manifest registry
   - materialize reusable inventory
   - build merged selection table
   - regenerate campaign health
   - run provenance audit

Updated immediate decision:

1. implement the comparison-ready assembly scripts next
2. do not reopen tuning unless the assembly audit reveals a real regression
3. keep the promoted campaign map v9 as the scientific decision baseline

## 12.14 Comparison-ready assembly execution (2026-04-05)

Primary references:

- `reports/static_exal_tuning_20260405/comparison_ready_assembly_execution_20260405.md`
- `reports/static_exal_tuning_20260405/comparison_ready_assembly_plan_20260405.md`
- `tools/merge_reports/LOCAL_validation_campaign_frozen_policy_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_selection_table_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_health_summary_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_audit_v1_20260405.csv`

Execution summary:

| slice | total | PASS | WARN | FAIL | healthy false |
|---|---:|---:|---:|---:|---:|
| merged final campaign | 291 | 208 | 83 | 0 | 0 |

Verified pool accounting:

| pool | count |
|---|---:|
| historical reusable static | 216 |
| refreshed static non-`FAIL` | 42 |
| residual-band broad default | 21 |
| promoted local static overrides | 9 |
| historical dynamic reusable | 2 |
| promoted dynamic local override | 1 |
| total | 291 |

Main takeaways:

- the comparison-ready assembly scripts are now implemented and exercised end
  to end
- the promoted campaign map is frozen and machine-readable
- the final merged campaign table is unique, provenance-backed, and fully
  non-`FAIL`
- the broad-default residual pool required scope-aware pairing of the old
  `failband2` checkpoints; a row-id-only summary view would have undercounted
  that pool by four duplicated RHS scope-cases
- repair mode is now over at the selected-artifact level unless a later
  comparison-table generation step reveals a real regression

Updated immediate decision:

1. stop opening any further tuning or repair waves by default
2. treat the merged `291`-row selection table as the comparison-ready campaign
   baseline
3. use the regenerated merged health outputs as the new branch-tracked
   validation truth source
4. move next into broad comparison table generation and publication-ready
   reporting

## 12.15 Broad comparison and final reporting execution (2026-04-05)

Primary references:

- `reports/static_exal_tuning_20260405/final_comparison_reporting_plan_20260405.md`
- `reports/static_exal_tuning_20260405/final_comparison_reporting_execution_20260405.md`
- `tools/merge_reports/LOCAL_validation_campaign_comparison_long_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_broad_comparison_table_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_comparison_audit_v1_20260405.csv`

Execution summary:

| artifact | rows / status |
|---|---:|
| comparison-long dataset | `291` |
| static broad comparison table | `72` |
| dynamic comparison supplement | `3` |
| model-pair comparison rows | `144` |
| inference-pair comparison rows | `144` |
| selected `FAIL` in reporting bundle | `0` |

Key comparison conclusions:

1. the final selected campaign remains fully non-`FAIL` in the reporting
   bundle
2. the branch now has one canonical long-format comparison dataset plus one
   canonical broad comparison table for reporting
3. `al` remains the cleaner broad static baseline in most matched model-pair
   comparisons, while promoted `exal` rows remain scientifically necessary to
   keep the campaign fully non-`FAIL`
4. `vb` is overwhelmingly faster than `mcmc` in matched static comparisons,
   while final gate comparisons are mostly ties with a smaller number of true
   wins on either side
5. `tau = 0p25` remains the hardest broad final stratum by WARN burden
6. repaired/default MCMC rows must use the summary-row files as the row-unique
   diagnostic source; reused generic case-health filenames are safe for
   provenance but not as canonical reporting inputs

Updated immediate decision:

1. stop building new validation or comparison pipeline code unless a reporting
   review finds a concrete inconsistency
2. treat the comparison-long dataset and broad comparison table as the
   branch-level reporting baseline
3. move next into manuscript-facing synthesis, figure selection, and narrative
   interpretation

## 12.16 Original-288 realignment investigation checkpoint (2026-04-05)

Primary references:

- `reports/static_exal_tuning_20260405/original_288_realignment_investigation_and_recovery_plan_20260405.md`
- `tools/merge_reports/LOCAL_original288_realignment_block_status_20260405.csv`
- `tools/merge_reports/LOCAL_original288_realignment_unresolved_dynamic_inventory_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_selection_table_v1_20260405.csv`

Key investigation result:

The current healthy `291`-row selected campaign is not the same study universe
as the original March 9 `288`-cell baseline design.

Root-cause summary:

1. the final repaired campaign retained only `3` dynamic selected rows instead
   of the full original `72` dynamic baseline rows
2. later static repair semantics (`rhs_ns`) drifted away from the original
   static shrink baseline semantics (`rhs` / `ridge`)
3. the selected `291` table contains only `233` unique `selected_fit_path`
   values; all duplicate artifact reuse is concentrated in `static_shrink`

Important salvage result:

If repaired selections are re-anchored by actual artifact root path rather than
by the later campaign semantic label, then the original `288` study can already
be recovered to:

| block | original cells | healthy now | unresolved |
|---|---:|---:|---:|
| `static_paper` | `72` | `72` | `0` |
| `static_shrink` | `144` | `144` | `0` |
| `dynamic` | `72` | `48` | `24` |
| total | `288` | `264` | `24` |

The residual debt is now cleanly identified:

- exactly `24` unresolved original-baseline rows remain
- all `24` are dynamic
- no original static rows remain unresolved under the corrected remap

Updated immediate decision:

1. stop treating the hybrid `291` campaign as the final publication target
2. treat it instead as a repair knowledge base and artifact pool
3. do not launch new runs yet
4. next implement:
   - a canonical original-`288` registry
   - a corrected carry-forward table mapped by actual artifact root path
   - a duplicate-key truth rebuild for static-shrink rows where the hybrid
     `291` table contains conflicting non-`FAIL` labels or multiple candidate
     paths for the same original key
   - a dynamic artifact-harvest / rescoring phase using the already existing
     model-matched dynamic repair archive
   - a mechanical verification of the `264 healthy / 24 unresolved` accounting
5. only after that, design the dynamic-only repair program for the remaining
   original dynamic gaps

Operational rule carry-forward for the next phase:

1. keep the accepted baseline as the default policy and promote only proven
   improvements
2. allow local scenario-specific overrides where the default is not enough
3. spend no effort reopening broad solved regions
4. require tracker/reporting updates before any new launch
5. require prepare-only validation, clean commit, and push before any overnight
   dynamic repair run
