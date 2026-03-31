# PLAN: QDESN Validation Phase 2 Forward Program (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Define the next disciplined phase of the QDESN validation repair effort after Repair Wave 1.

This plan assumes the following are already true:

- the branch-level validation blocker is still unresolved;
- the repair harness is operationally stable;
- the latest width/pass/freeze candidate family improved diagnostics but did not produce a validation winner;
- no broad rerun is justified yet.

The goal of Phase 2 is to move from "narrow tuning evidence" to "genuinely new kernel hypothesis" in a way that is efficient, reproducible, and easy to audit.

## 2) Ultimate Goal

Reach a defensible branch-closeout state for QDESN by:

1. identifying the true remaining kernel-level blocker;
2. implementing a justified repair rather than another weak tuning variation;
3. proving that repair on the smallest valid validation ladder;
4. only then restarting broader branch validation and closeout.

## 3) Current Status Snapshot

Current status as of this plan:

- no QDESN validation or repair jobs are currently running;
- the repair-wave harness is complete and reproducible;
- Repair Wave 1 finished with `4/4` profiles completed and `0` operational failures;
- all evaluated profiles were numerically healthy;
- no evaluated profile passed Gate B;
- no evaluated profile reduced the severe fail set below `4`.

Current best rank from Repair Wave 1:

| profile | total fail n | severe fail n | sentinel fail n | median runtime inflation | gate B |
|---|---:|---:|---:|---:|---|
| `R3_x10_plus_x8_rhsns_overlay` | `5` | `4` | `1` | `0.4218` | `FALSE` |
| `R1_promoted_x10_core` | `5` | `4` | `1` | `0.4422` | `FALSE` |
| `R2_x3_alternate` | `6` | `4` | `2` | `0.4160` | `FALSE` |
| `R0_legacy_anchor` | `6` | `4` | `2` | `-0.0686` | `FALSE` |

Interpretation:

- the severe quartet is still intact;
- the persistent hard root still fails;
- the `rhs_ns` overlay helps one sentinel but does not change the branch-level decision;
- the next move should be structural debugging, not another minor default promotion.

### Status update after WP1 and WP2 execution

The Phase 2 audit has now completed from existing artifacts:

- hard-root forensics are complete;
- the `tiny_d1_n8` conditioning audit is complete;
- the new audit report is:
  `docs/REPORT__qdesn_validation_phase2_audit_20260331.md`

Key additions from that audit:

- the hard root is still `dlm_constV_bigW @ tau=0.05 exal ridge`;
- current candidates trade off `gamma` ESS against `gamma` / `sigma` drift instead of jointly stabilizing the core;
- `tiny_d1_n8` geometry is clearly stressed, but the same design keys appear in both severe and sentinel roots, so conditioning is an amplifier rather than a complete explanation;
- the next implementation target should therefore be a shared-core structural `gamma/sigma` traversal repair.

## 4) Main Blocker Map

### Primary blocker

Shared static `exal` MCMC kernel behavior in the QDESN readout path.

### Main evidence

- `16/19` closeout MCMC FAIL rows were `exal`;
- failures split across `ridge` and `rhs_ns`, so this is not a purely `rhs_ns` problem;
- the severe cluster is concentrated on `tiny_d1_n8`;
- the strongest persistent canary remains:
  `dlm_constV_bigW @ tau=0.05 exal ridge`

### Secondary issue

Residual `rhs_ns` warmup / initialization behavior.

This matters, but only after the shared-core issue is improved enough to matter.

### Non-issues for prioritization

- orchestration stability;
- finite/domain failures;
- collapse / unhealthy-fit behavior;
- pure chain-length shortage alone.

## 5) Phase 2 Operating Principles

1. One hypothesis per code patch.
2. Keep the 6-root repair harness fixed.
3. Do not restart broad validation before a narrow winner exists.
4. Prefer explanation over tuning volume.
5. Preserve all manifests, run tags, and comparison tables.
6. Any new rerun must be comparable to Repair Wave 1.

## 6) Work Packages

### WP0: Evidence Freeze And Readiness

Purpose:

Lock the current baseline and prepare the Phase 2 workspace without changing the scientific reference point.

Tasks:

- treat Repair Wave 1 as the active comparison baseline;
- preserve the legacy anchor profile;
- use the same 6-root harness for future Phase 2 comparisons;
- do not promote any candidate defaults from Wave 1 into package code.

Deliverables:

- this plan;
- the updated repair tracker;
- the Wave 1 report;
- a stable list of canonical evidence files.

Exit criteria:

- team agrees the current baseline is frozen;
- no one is using `X10`, `X3`, or `X8` as if they are production defaults.

### WP1: Hard-Root Forensic Debug

Purpose:

Explain why the hardest ridge canary remains `FAIL` under every tested candidate.

Primary root:

- `dlm_constV_bigW @ tau=0.05 exal ridge`

Secondary comparison roots:

- `dlm_constV_smallW @ tau=0.95 exal ridge`
- `dlm_ar1V @ tau=0.95 exal rhs_ns`

Questions to answer:

1. Is the dominant failure on this root still Geweke drift, half-drift, low ESS, or a mix?
2. Does the chain appear trapped, slow-mixing, or highly start-state sensitive?
3. Are `gamma` and `sigma` moving coherently or fighting each other?
4. Is VB warm start helping, neutral, or harmful on this root?

Evidence to inspect first:

- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase01_mcmc_fail_forensics.csv`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R1_promoted_x10_core.csv`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R3_x10_plus_x8_rhsns_overlay.csv`

Expected outputs:

- a concise forensic memo for the hard root;
- a table of root-level metric shifts across `R0`, `R1`, and `R3`;
- 2 to 3 concrete kernel hypotheses ranked by plausibility.

Exit criteria:

- we can name the likely dominant mechanism for the hard-root failure;
- we have a short list of real next hypotheses rather than more generic tuning ideas.

### WP2: `tiny_d1_n8` Conditioning Audit

Purpose:

Determine whether the severe cluster is being amplified by readout-design geometry rather than only by sampler tuning.

Questions to answer:

1. Are severe roots systematically worse-conditioned than easier roots?
2. Is the ridge hard root showing extreme predictor scaling, collinearity, or effective rank loss?
3. Is the problem specific to `tiny_d1_n8`, or does the same scenario fail on broader reservoirs?

Comparison set:

- severe quartet from the closeout harness;
- at least 2 non-severe roots from the same harness;
- if needed, one comparable non-`tiny_d1_n8` reservoir reference.

Suggested metrics:

- predictor scaling summary;
- singular values / condition number;
- effective rank;
- pairwise correlation concentration;
- any dominant columns or near-duplicate columns;
- intercept and input-lag contribution patterns.

Expected outputs:

- a conditioning summary table;
- a one-page judgment on whether conditioning is material, secondary, or negligible.

Exit criteria:

- clear yes/no on whether conditioning deserves to be the next primary hypothesis.

### WP3: Hypothesis Selection Gate

Purpose:

Choose the next implementation target from evidence, not intuition.

Allowed hypothesis families:

- `H1`: structural shared `gamma`/`sigma` traversal change;
- `H2`: readout design conditioning / preconditioning change;
- `H3`: warm-start or initialization change targeted to the hard-root regime;
- `H4`: `rhs_ns`-specific residual change only if shared-core evidence improves first.

Selection rule:

- choose exactly one primary hypothesis;
- document why the other candidates were not chosen first;
- keep the patch attributable to that hypothesis only.

Exit criteria:

- one implementation candidate is chosen;
- its predicted target roots and predicted failure mode are explicit.

### WP4: Implementation Of One New Kernel Hypothesis

Purpose:

Implement the smallest real code change that tests the chosen Phase 2 hypothesis.

Implementation standards:

- one hypothesis only;
- no silent default promotion unrelated to the hypothesis;
- preserve current validation harness compatibility;
- add only minimal comments needed to explain non-obvious behavior;
- document exact behavior changes before rerunning.

Suggested code focus areas:

- `R/exal_mcmc_fit.R`
- `R/exal_inference_config.R`
- only additional files if the selected hypothesis genuinely requires them.

Exit criteria:

- code parses and targeted smoke checks pass;
- the candidate is ready for narrow validation.

### WP5: Validation Funnel For The New Hypothesis

Purpose:

Prove the new candidate through the smallest reliable ladder.

Validation stages:

| stage | scope | purpose |
|---|---|---|
| `A` | single hard ridge canary | test the hardest failure directly |
| `B` | severe quartet | test whether improvement generalizes across the severe cluster |
| `C` | full 6-root repair harness | confirm broader narrow-wave benefit |
| `D` | closeout micro-pilot refresh | only if `C` yields a real winner |
| `E` | broader dynamic / branch reruns | only after `D` supports it |

Hard gates:

| gate | requirement |
|---|---|
| `G1` | no new finite/domain/collapse regressions |
| `G2` | hard ridge canary improves materially |
| `G3` | severe fail count drops below `4` at Stage B |
| `G4` | Stage C total fail count improves materially over `R0` |
| `G5` | runtime inflation remains acceptable for the branch use case |

Stop conditions:

- the hard canary does not improve at all;
- the candidate merely shifts failure type without net gain;
- the candidate requires near-rejected chain inflation to look acceptable;
- the candidate introduces new instability classes.

### WP6: Broader Validation Restart

Purpose:

Only after a narrow winner exists, restart the validation ladder needed for branch signoff.

Restart order:

1. refreshed closeout micro-pilot;
2. refreshed dynamic family/prior baseline;
3. refreshed closeout recommendation;
4. only then any branch-level signoff language.

Do not start WP6 unless:

- Stage C shows a real narrow winner;
- the severe cluster is reduced enough to justify compute spend;
- the hard ridge canary no longer dominates the decision.

## 7) Prioritized Next Actions

Immediate next actions:

1. use the completed Phase 2 audit as the active hypothesis gate;
2. implement exactly one shared-core structural `gamma/sigma` candidate;
3. validate it on the single hard ridge canary;
4. only if the canary improves, move to the severe quartet and then the full 6-root harness.

Recommended order:

- `WP1` and `WP2` are now complete;
- `WP3` is now ready and should select `H1` as the primary hypothesis;
- `WP4` should implement only that `H1` candidate;
- `WP5` begins only after `WP4` is complete.

## 8) What We Should Not Do Next

- do not rerun the full branch validation ladder now;
- do not promote `X10`, `X3`, or `X8` defaults;
- do not run another large sweep of width/pass/freeze variants;
- do not treat the problem as purely `rhs_ns`-specific;
- do not abandon the legacy anchor profile.

## 9) Success Definition For Phase 2

Phase 2 is successful if it produces all of the following:

1. a clear explanation of the persistent hard-root failure;
2. a new, justified kernel hypothesis;
3. a narrow validation winner that beats the Wave 1 baseline;
4. a credible basis for restarting broader validation.

If Phase 2 cannot produce a narrow winner, that itself is a useful decision:

- it would mean the current exAL kernel likely needs a deeper redesign than the present validation study can justify incrementally.

## 10) Main Files To Follow

### Active baseline and reports

- `docs/TRACK__qdesn_validation_repair_20260331.md`
- `docs/REPORT__qdesn_validation_phase2_audit_20260331.md`
- `docs/REPORT__qdesn_validation_repair_wave1_20260331.md`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/summary/screen_results.md`
- `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/summary/phase2_audit_summary.md`

### Root-level evidence

- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase01_mcmc_fail_forensics.csv`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/profile_rank_summary.csv`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R1_promoted_x10_core.csv`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R3_x10_plus_x8_rhsns_overlay.csv`

### Main code paths

- `R/qdesn_mcmc.R`
- `R/exal_mcmc_fit.R`
- `R/exal_inference_config.R`

### Validation scaffolding to preserve

- `config/validation/qdesn_dynamic_family_prior_repair_defaults.yaml`
- `config/validation/qdesn_validation_repair_wave1_manifest.yaml`
