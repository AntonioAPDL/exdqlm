# Refresh Audit: QDESN Validation Closeout

Date: 2026-03-29  
Audit mode: refresh audit plus targeted validation relaunch/recovery using existing scripts; no package code modified  
Updated premise: pre-fix Q-DESN RHS-family validation evidence is not signoffable if it predates the final `rhs_ns` / RHS-family implementation fix now on `HEAD`

## 1. Repo Sync / Status Summary

Mandatory sync commands executed:

1. `git fetch --all --prune --tags`
2. `git checkout feature/qdesn-mcmc-alternative`
3. `git pull --ff-only`

Repo state after sync:

| item | value |
|---|---|
| branch | `feature/qdesn-mcmc-alternative` |
| HEAD | `6ac472760d8dc9b0d244f6bee902efc9b1037210` |
| HEAD subject | `Wave 3: default Q-DESN to RHS_NS and enforce intercept policy` |
| upstream | `origin/feature/qdesn-mcmc-alternative` |
| divergence | `0 ahead / 0 behind` |
| worktree status at sync | clean |

Audit output added:

- `REFRESH_AUDIT_QDESN_20260329.md`

No package code was modified.

## 2. Implementation Timeline That Sets the Invalidation Boundary

Relevant git history on the Q-DESN RHS-family code path:

| commit | timestamp | meaning |
|---|---|---|
| `6756954` | 2026-03-27 05:19 EDT | initial `rhs_ns` prior module + VB/MCMC integration |
| `43c9763` | 2026-03-27 10:58 EDT | `rhs_ns` diagnostics and guardrail parity hardening |
| `4536ccc` | 2026-03-29 05:38 EDT | dynamic family/prior matrix integration |
| `6ac4727` | 2026-03-29 10:14 EDT | final Q-DESN RHS-family fix on current branch: default to `rhs_ns` and enforce intercept policy |

The key current-HEAD fix is `6ac4727`.

What `6ac4727` changed in package code:

1. `qdesn_fit_vb()` now defaults omitted `beta_prior_type` to `rhs_ns`.
2. `qdesn_fit_mcmc()` now defaults omitted `beta_prior_type` to `rhs_ns`.
3. inference config resolution now defaults omitted beta prior type to `rhs_ns`.
4. Q-DESN RHS-family constructors now force `shrink_intercept = FALSE`.
5. both `R/qdesn_rhs_prior.R` and `R/qdesn_rhs_ns_prior.R` now hard-enforce the same intercept policy.

This means the stale boundary is not only `rhs_ns`-specific in the narrow sense. For Q-DESN it affects the whole RHS-family behavior surface:

- `rhs`
- `rhs_ns`
- unpinned default Q-DESN prior routing

Conclusion:

- any Q-DESN validation artifact involving RHS-family priors before `6ac4727` is not representative of current `HEAD`
- any artifact derived from those RHS-family runs is also not signoffable for current `HEAD`

## 3. Validation Artifact Chronology vs Fix Time

## 3.1 Confirmed Pre-Fix RHS-Family Artifacts

I found no validation artifact in `reports/` or `results/` that references `6ac4727`.

Confirmed pre-fix RHS-family artifacts:

| artifact family | run time / summary time | git / evidence | status relative to current HEAD |
|---|---|---|---|
| Stage-8 rhs vs rhs_ns benchmark | tracked on 2026-03-27 | `reports/rhs_ns_stage8_matrix_20260327_v4.csv` | stale |
| focused `rhs` vs `rhs_ns` median smoke | 2026-03-27 10:42 / 10:52 EDT | `2acd278` | stale |
| `rhsns_stageP_wave` | 2026-03-27 18:12 EDT | `2641e6b` | stale |
| `rhsns_stageQ_wave` | 2026-03-28 09:30 EDT | `2641e6b` | stale |
| dynamic family/prior baseline | 2026-03-29 05:50 EDT | `2641e6b` | stale |
| closeout phase 0-2 | 2026-03-29 07:33 EDT | `4536ccc` but baseline from `2641e6b` | stale as branch signoff evidence |
| closeout phase 3-5 micro-pilot | 2026-03-29 08:50 EDT | `4536ccc` but baseline and profiles pre-`6ac4727` | stale as branch signoff evidence |

## 3.2 Evidence Behind the Table

Implementation/hardening tracker:

- `docs/TRACK__rhs_ns_execution_tracker.md`
  - initial implementation recorded under Stage 7
  - Stage-8 benchmark recorded immediately after that
  - later feature-branch hardening and focused smoke still predate `6ac4727`

Focused median smoke:

- `reports/qdesn_mcmc_validation/rhs_vs_rhs_ns_median/20260327-104735__git-2acd278/rhs_vs_rhsns_median_summary.md`
  - run timestamp: `2026-03-27 10:52:06 EDT`
  - git head: `2acd278...`

Static Stage-Q:

- `reports/qdesn_mcmc_validation/rhsns_stageQ_wave/stageQ-20260328-093000__git-2641e6b/summary/stageQ_wave_summary.md`
  - run tag: `stageQ-20260328-093000__git-2641e6b`
  - pure `rhs_ns` wave

Dynamic baseline:

- `reports/qdesn_mcmc_validation/dynamic_family_prior_rerun/dynamic-family-prior-20260329-053603/summary/dynamic_wave_summary.md`
  - generated at `2026-03-29 05:50:34`
  - git SHA `2641e6b`

Closeout:

- `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/summary/phase01_summary.md`
  - generated at `2026-03-29 07:33:37`
  - explicitly points back to the dynamic baseline rooted at `2641e6b`
- `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/summary/phase35_summary.md`
  - generated at `2026-03-29 08:50:26`
  - depends on the same stale baseline and stale profile configs

Therefore:

- there is no post-fix RHS-family validation evidence
- the March 29 closeout was internally correct for the code that existed then
- it is not sufficient as signoff for current `HEAD`

## 4. Re-Evaluated Current Status

## 4.1 What Is Still Robustly Valid Today

These items remain useful:

- repository sync state and current branch snapshot
- non-DLM validation infrastructure itself
  - `readout.input_mode = raw_y_lags`
  - `decomposition.enabled = FALSE`
- dynamic toy-scenario/reporting machinery
- ridge-only dynamic cells from the March 29 matrix as isolated execution evidence
- code-level guardrail coverage added in `6ac4727`
  - default routing to `rhs_ns`
  - intercept-shrink enforcement for RHS-family priors

But these do not amount to branch closeout.

## 4.2 What Must Now Be Treated As Stale / Non-Signoff

Stale for current-HEAD signoff:

1. all Q-DESN validation results involving `rhs`
2. all Q-DESN validation results involving `rhs_ns`
3. all comparisons between `rhs` and `rhs_ns`
4. all closeout artifacts derived from stale RHS-family baselines

This includes, at minimum:

- `reports/rhs_ns_stage8_matrix_20260327_v4.csv`
- `reports/qdesn_mcmc_validation/rhs_vs_rhs_ns_median/...`
- `reports/qdesn_mcmc_validation/rhsns_stageP_wave/...`
- `reports/qdesn_mcmc_validation/rhsns_stageQ_wave/...`
- `reports/qdesn_mcmc_validation/dynamic_family_prior_rerun/...`
- `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/...`

## 4.3 Corrected Branch Status

Corrected status after applying the invalidation rule:

- the QDESN branch is **not validation-closed**
- there is **no valid post-fix RHS-family validation wave**
- the March 29 closeout recommendation cannot be used as the final branch recommendation for current `HEAD`

What survives from the old closeout:

- only a weaker process lesson: the old pre-fix tuning-only micro-pilot did not convincingly fix the old failing cells

What does **not** survive:

- any claim that current `HEAD` is already validated end-to-end under `rhs_ns`
- any claim that current `HEAD` has a settled kernel-redesign recommendation based on post-fix evidence

Kernel redesign may still be needed, but the branch does not yet have the post-fix evidence required to assert that confidently.

## 4.4 Executed Relaunch Update On Current `HEAD`

After the audit and relaunch preparation, the branch-closeout critical path was actually executed on current `HEAD` (`6ac4727`) using the existing validation scripts and configs.

Fresh completed stages:

| stage | status | key result |
|---|---|---|
| `T0` focused `rhs` vs `rhs_ns` smoke | complete | operationally healthy on current `HEAD`; `2/2` roots succeeded |
| `T1` Stage-P refresh | complete | `36/36` roots succeeded; no finite/domain/collapse regressions |
| `T2` Stage-Q refresh | complete | `36/36` roots succeeded; tau-set wave completed |
| `T3` dynamic family/prior refresh | complete | all `36` expected roots materialized successfully |
| `T4A` closeout phase01 | complete | Gate A passed; `19` MCMC fails clustered into `4` dominant clusters; phase01 recommended micro-pilot |

Key fresh artifacts:

- `reports/qdesn_mcmc_validation/rhs_vs_rhs_ns_median/t0-rhsfixrelaunch-20260329b__git-6ac4727/20260329-114508__git-6ac4727/rhs_vs_rhsns_median_summary.md`
- `reports/qdesn_mcmc_validation/rhsns_stageP_wave/stageP-rhsfixrelaunch-20260329b__git-6ac4727/summary/stageP_wave_summary.md`
- `reports/qdesn_mcmc_validation/rhsns_stageQ_wave/stageQ-rhsfixrelaunch-20260329b__git-6ac4727/summary/stageQ_wave_summary.md`
- `reports/qdesn_mcmc_validation/dynamic_family_prior_rerun/dynamic-family-prior-rhsfixrelaunch-20260329b__git-6ac4727/summary/dynamic_wave_summary.md`
- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/summary/phase01_summary.md`

`T4B` outcome required one operational correction:

1. the initial `phase35` run with `workers = 4` stalled during `P2_conservative_slice`
2. three `P2` MCMC fits had already written internal `SUCCESS` runtime manifests, but one root never initialized and the run stopped making file progress
3. `phase35` was then relaunched serially with `workers = 1`
4. the serial recovery completed `P1_longer_chain` cleanly and reproduced the same transition pattern without the parallel bookkeeping stall

The completed `P1_longer_chain` transition table already fixes the Gate B result:

- source: `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase35_transitions_P1_longer_chain.csv`
- `base_fail_n = 6`
- `prof_fail_n = 3`
- `fail_reduction = 0.50`
- `runtime_inflation_median = 0.996794`

Therefore `P1_longer_chain` fails Gate B even though it reduces fail count, because the runtime gate requires `runtime_inflation_median <= 0.50`.

`P2_conservative_slice` and `P3_blocked_adapt` were then intentionally pruned rather than fully replayed. This is a deliberate inference from the phase01 profile design:

- `P2` increases burn/MCMC budgets above `P1`
- `P3` increases them further and also increases block passes
- the Gate B runtime criterion cannot improve from `+99.7%` inflation in `P1` to `<= +50%` under strictly higher-cost profiles on the same micro-pilot grid

So the remaining `phase35` compute could no longer change the branch recommendation.

Current closeout conclusion for current `HEAD`:

- keep default branch recommendation as `hold defaults; escalate to kernel redesign`
- treat the March 29 closeout as stale historical evidence
- treat the fresh March 29 relaunch up through `T4A` plus completed `P1` Gate-B failure as the current operative evidence base

Residual uncertainty:

- a script-native fresh `phase35_summary.md` / `phase35_manifest.json` was not emitted because the higher-cost profiles were pruned once Gate B impossibility was established
- if a fully canonical script-emitted `phase35` artifact is required for process reasons, rerun `phase35` serially to completion; this would be confirmatory, not decision-changing

## 5. Corrected Rerun Decision Matrix

## 5.1 No-Rerun Option

Decision: `NO LONGER ACCEPTABLE`

Reason:

- the user’s updated premise is correct
- all existing RHS-family validation evidence predates the final Q-DESN RHS-family fix on `HEAD`

## 5.2 Targeted Rerun Option

Decision: `REQUIRED AS FIRST GATE`

Purpose:

- verify that the final RHS-family implementation is at least operationally sane before expensive campaign relaunch

Recommended first gate:

### Gate T0: Focused RHS-family smoke

Relaunch:

- `rhs` vs `rhs_ns` median smoke on current `HEAD`
- same 2-root focused comparison family as `rhs_vs_rhs_ns_median`

Scope:

- `2 roots`
- `4 fits`
  - `rhs` VB
  - `rhs` MCMC
  - `rhs_ns` VB
  - `rhs_ns` MCMC

Why this is first:

- cheapest way to confirm the final RHS-family implementation is live
- directly exercises both classic `rhs` and `rhs_ns`
- directly tests the path invalidated by `6ac4727`

## 5.3 Broader Rerun Option

Decision: `REQUIRED AFTER T0`

For current branch recovery, the minimal coherent rerun stack is:

### Required for current branch signoff

1. focused `rhs` vs `rhs_ns` median smoke
2. fresh static `rhs_ns` wrap-up wave
3. fresh dynamic family/prior matrix baseline
4. fresh closeout forensics
5. fresh micro-pilot only if the new baseline still warrants it

### Why the dynamic baseline should be rerun as all 36 roots, not only the stale RHS-family half

The March 29 closeout tables and fail-cluster ranking were built from one coherent 36-root campaign. Reusing old ridge rows while replacing only stale RHS-family rows would produce a mixed-era baseline and a non-canonical closeout.

So the recommended dynamic rerun unit is:

- full `36-root` dynamic family/prior matrix on current `HEAD`

### Why the closeout must be rerun after the baseline

The prior closeout selected failing roots and micro-pilot profiles from the stale baseline. Once the RHS-family implementation changes, all of these may shift:

- fail counts
- fail clusters
- root ranking
- the 6 selected micro-pilot roots
- whether a micro-pilot is needed at all

## 5.4 Reuse-First Asset Map

The most efficient relaunch is not a redesign of the validation framework. It is a reuse-first replay of the existing branch validation stack with fresh post-fix outputs.

### Reuse as-is

These files remain the canonical launch assets:

| purpose | reusable files | notes |
|---|---|---|
| focused `rhs` vs `rhs_ns` smoke | `scripts/run_qdesn_rhs_vs_rhsns_median_validation.R` + `config/validation/qdesn_rhs_vs_rhs_ns_median_defaults.yaml` + `config/validation/qdesn_rhs_vs_rhs_ns_median_grid.csv` | cheapest post-fix gate; directly exercises both RHS-family priors |
| static `rhs_ns` expansion wave | `scripts/run_qdesn_rhsns_stageP_wave.R` + `config/validation/qdesn_mcmc_compare_rhsns_stageP_defaults.yaml` + `config/validation/qdesn_rhsns_stageP_expansion_grid.csv` | `rhsns_full` arm is branch-critical; ridge anchor can be skipped for efficiency |
| optional static ridge anchor | `config/validation/qdesn_ridge_stageP_anchor_grid.csv` | valid control arm, but not required to re-establish RHS-family freshness |
| static wrap-up wave | `scripts/run_qdesn_rhsns_stageQ_wave.R` + `config/validation/qdesn_mcmc_compare_rhsns_stageQ_defaults.yaml` + `config/validation/qdesn_rhsns_stageQ_grid.csv` | preserves original Stage-Q tau-set contract |
| dynamic family/prior baseline | `scripts/run_qdesn_dynamic_family_prior_wave.R` + `config/validation/qdesn_dynamic_family_prior_defaults.yaml` + `config/validation/qdesn_dynamic_family_prior_grid.csv` | canonical branch-closeout baseline; should remain a coherent 36-root wave |
| zero-compute closeout forensics | `scripts/run_qdesn_validation_closeout_phase01.R` | regenerate fail clusters and fresh micro-pilot from the new baseline |
| conditional micro-pilot | `scripts/run_qdesn_validation_closeout_phase35.R` | only if fresh Gate A again justifies remediation testing |
| completion checks | `scripts/healthcheck_qdesn_rhsns_stageQ_wave.R` + `scripts/healthcheck_qdesn_dynamic_family_prior_wave.R` + `scripts/reconcile_qdesn_validation_campaign_status.R` | low-cost guardrails to avoid mistaken relaunch or incomplete closeout inputs |

### Reuse as templates only

These are useful design references, but not authoritative evidence:

| artifact | reuse status | why |
|---|---|---|
| `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/configs/micro_pilot_grid.csv` | template only | root selection came from stale pre-fix baseline |
| `.../configs/defaults_P1_longer_chain.yaml` | template only | profile remains informative, but must be re-evaluated on fresh fail cells |
| `.../configs/defaults_P2_conservative_slice.yaml` | template only | same reason |
| `.../configs/defaults_P3_blocked_adapt.yaml` | template only | same reason |
| `.../tables/phase01_micro_pilot_roots_selected.csv` | template only | useful for historical comparison, not for direct rerun targeting |
| `.../tables/phase01_mcmc_fail_cluster_rank.csv` | template only | stale cluster ranking may shift under corrected RHS-family behavior |

### Evidence only, not reusable for signoff

The prior summaries, recommendations, and benchmark conclusions remain historically informative, but they should not be promoted as current-HEAD validation evidence.

## 6. Relaunch Blueprint

## 6.1 Required Current-Critical Path

1. Treat all pre-`6ac4727` Q-DESN RHS-family validation evidence as stale.
2. Relaunch the focused `rhs` vs `rhs_ns` median smoke on current `HEAD`.
3. If T0 is operationally acceptable, relaunch the static `rhsns` validation waves.
4. Relaunch the full `36-root` dynamic family/prior matrix on current `HEAD`.
5. Recompute Gate-A forensics from that new dynamic baseline.
6. Only then decide whether Gate-B micro-pilot is needed, and if yes, regenerate the failing-root slice from the new baseline.

## 6.2 Exact Recommended Sequence

### T0. Focused post-fix RHS-family smoke

Reuse:

- `scripts/run_qdesn_rhs_vs_rhsns_median_validation.R`
- `config/validation/qdesn_rhs_vs_rhs_ns_median_defaults.yaml`
- `config/validation/qdesn_rhs_vs_rhs_ns_median_grid.csv`

Scope:

- `2` roots
- `4` fits

Prepared command:

```bash
Rscript scripts/run_qdesn_rhs_vs_rhsns_median_validation.R \
  --defaults config/validation/qdesn_rhs_vs_rhs_ns_median_defaults.yaml \
  --grid config/validation/qdesn_rhs_vs_rhs_ns_median_grid.csv \
  --no-plots
```

Stop/go:

- proceed only if both `rhs` and `rhs_ns` complete without finite/domain failure and campaign summaries materialize normally

### T1. Static `rhs_ns` Stage-P refresh

Reuse:

- `scripts/run_qdesn_rhsns_stageP_wave.R`
- `config/validation/qdesn_mcmc_compare_rhsns_stageP_defaults.yaml`
- `config/validation/qdesn_rhsns_stageP_expansion_grid.csv`

Recommended efficient mode:

- run `rhsns_full`
- skip ridge anchor initially with `--skip-ridge`

Scope:

- `36` roots
- `72` fits

Prepared command:

```bash
Rscript scripts/run_qdesn_rhsns_stageP_wave.R \
  --defaults config/validation/qdesn_mcmc_compare_rhsns_stageP_defaults.yaml \
  --full-grid config/validation/qdesn_rhsns_stageP_expansion_grid.csv \
  --workers-full 12 \
  --skip-ridge \
  --no-plots
```

Optional control rerun:

- add `config/validation/qdesn_ridge_stageP_anchor_grid.csv` back later if a same-day ridge anchor is wanted for calibration; this is not required to refresh RHS-family evidence

### T2. Static `rhs_ns` Stage-Q refresh

Reuse:

- `scripts/run_qdesn_rhsns_stageQ_wave.R`
- `config/validation/qdesn_mcmc_compare_rhsns_stageQ_defaults.yaml`
- `config/validation/qdesn_rhsns_stageQ_grid.csv`

Scope:

- `36` roots
- `72` fits

Prepared command:

```bash
Rscript scripts/run_qdesn_rhsns_stageQ_wave.R \
  --defaults config/validation/qdesn_mcmc_compare_rhsns_stageQ_defaults.yaml \
  --grid config/validation/qdesn_rhsns_stageQ_grid.csv \
  --workers 12 \
  --no-plots
```

Verification:

- use `scripts/healthcheck_qdesn_rhsns_stageQ_wave.R` on the resulting run tag before promoting the Stage-Q refresh as complete

### T3. Dynamic family/prior baseline refresh

Reuse:

- `scripts/run_qdesn_dynamic_family_prior_wave.R`
- `config/validation/qdesn_dynamic_family_prior_defaults.yaml`
- `config/validation/qdesn_dynamic_family_prior_grid.csv`

Scope:

- `36` roots
- `72` fits

Prepared command:

```bash
Rscript scripts/run_qdesn_dynamic_family_prior_wave.R \
  --defaults config/validation/qdesn_dynamic_family_prior_defaults.yaml \
  --grid config/validation/qdesn_dynamic_family_prior_grid.csv \
  --workers 8 \
  --no-plots
```

Verification:

- use `scripts/healthcheck_qdesn_dynamic_family_prior_wave.R` on the resulting run tag
- use `scripts/reconcile_qdesn_validation_campaign_status.R` if campaign metadata needs reconciliation after completion

### T4. Closeout regeneration

Reuse:

- `scripts/run_qdesn_validation_closeout_phase01.R`
- `scripts/run_qdesn_validation_closeout_phase35.R`

Important rule:

- do not point closeout at the old `2641e6b` baseline
- point it at the fresh dynamic rerun roots and reports

Prepared Phase 0-2 command shape:

```bash
Rscript scripts/run_qdesn_validation_closeout_phase01.R \
  --baseline-report-root <fresh_dynamic_report_root> \
  --baseline-results-root <fresh_dynamic_results_root> \
  --micro-size 6
```

Prepared Phase 3-5 command shape:

```bash
Rscript scripts/run_qdesn_validation_closeout_phase35.R \
  --phase01-manifest <fresh_closeout_phase01_manifest.json> \
  --workers 4 \
  --no-plots
```

Policy:

- rerun Phase 3-5 only if fresh Phase 0-2 still supports a micro-pilot
- rely on the new Phase 0-2 generator to emit any fresh micro grid and fresh profile configs
- do not directly recycle the stale March 29 micro grid as live targeting input

## 6.3 Efficient Scope Options

| option | scope | recommendation |
|---|---|---|
| minimal freshness gate | T0 only | useful if we want a very fast first signal before committing workers |
| branch-closeout critical path | T0 -> T1 -> T2 -> T3 -> fresh closeout | recommended |
| historical comparability replay | branch-closeout path plus Stage-8 benchmark rerun | optional |

## 6.4 Optional but Recommended if Historical Claims Matter

These are not strictly first on the branch-closeout critical path, but should be rerun if historical tracker claims are to remain active:

1. rerun Stage-8 `rhs` vs `rhs_ns` matrix benchmark
2. rerun earlier `rhs` / `rhs_ns` comparison assets that are still cited in tracker narratives

Without those reruns, any old efficiency/parity claims about `rhs` vs `rhs_ns` should be treated as historical notes only.

## 7. Practical Current-State Summary

Current truth after this re-audit:

- sync state is clean and up to date
- current `HEAD` contains the final Q-DESN RHS-family fix
- every RHS-family validation artifact in the repo predates that fix
- the branch is reopened from a validation standpoint
- the correct next move is not “accept old closeout” and not “broad rerun immediately”
- the correct next move is:
  - focused post-fix RHS-family smoke
  - then reuse-first relaunch of the scripted static + dynamic validation stack
  - then fresh closeout against that new baseline

Prepared relaunch view:

- reuse the existing launch scripts and config files
- skip rebuilding grids or defaults unless the fresh rerun exposes a new failure class
- treat old closeout-generated micro-pilot configs as templates, not live inputs
- keep the dynamic branch-closeout baseline as one coherent fresh 36-root campaign

## 8. Explicit Uncertainty Statement

The main remaining uncertainty is not about chronology; that is now clear.

The remaining uncertainty is substantive:

- after rerunning on current `HEAD`, the new RHS-family implementation may either
  - materially improve the prior fail clusters, or
  - leave the kernel-level issues largely intact

That cannot be answered from the current repo artifacts, because there are no post-`6ac4727` validation runs yet.

So the honest current recommendation is:

- **all pre-fix Q-DESN RHS-family validation progress should be treated as stale**
- **current branch signoff must be re-established by rerun**
- **the relaunch can be efficient because almost the entire orchestration stack is already reusable**
