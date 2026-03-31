# PLAN: QDESN Validation Phase 3 (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Branch checkpoint at plan creation: `0cef58865ddc874608bbd4ded2af0b2952ad8b3c`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Turn the current post-Wave-2 evidence into a rigorous, efficient, and well-instrumented repair program that:

1. attacks the actual blocker rather than rerunning broad validation prematurely;
2. keeps hypotheses isolated and attributable;
3. prioritizes the highest-signal repair family first;
4. uses strict staged gates so bad candidates fail early;
5. leaves a reusable audit trail for future closeout work.

This plan is the canonical roadmap from the current blocked state to the next credible branch-closeout attempt.

## 2) Current State Snapshot

## Branch and execution health

| item | state | read |
|---|---|---|
| branch | `feature/qdesn-mcmc-alternative` | current working branch |
| repo state | clean at plan creation | no active local edits before this plan |
| live validation jobs | none | no repair or closeout jobs are still running |
| latest narrow wave | operationally healthy | Wave 2 completed with no runner/numerical failures |
| latest scientific decision | blocked | the bridge family and the standalone conditioning family both failed the canary gate |

## Most recent scientific result

The most recent narrow-family results are:

- Wave 3:
  diagonal conditioning (`R5_diag_scale_precondition`) was effectively inactive on the hard canary and failed immediately;
- Wave 4:
  QR whitening (`R6_qr_whiten_precondition`) activated correctly, improved working-space conditioning and Geweke sharply, but still failed because ESS remained too low and half-drift worsened too much.

Implication:

- local traversal reshuffling inside the current core kernel is not enough;
- conditioning alone is also not enough;
- the next candidate should come from a new family:
  a true blocked or reparameterized shared-core move.

## 3) Main Findings That Must Drive The Next Phase

### What is now robustly known

1. The main blocker is the shared static `exal` MCMC core used by QDESN.
2. The blocker is not primarily a `rhs_ns`-only problem.
3. The blocker is not primarily an infrastructure, finite, domain, or collapse problem.
4. The highest-value canary remains `dlm_constV_bigW @ tau=0.05 exal ridge`.
5. The severe cluster remains concentrated on `tiny_d1_n8`.
6. `tiny_d1_n8` readout geometry is genuinely stressed, but conditioning is an amplifier rather than a full explanation.
7. Small width/pass/freeze promotions, the `gamma_sigma_gamma` bridge candidate, and standalone conditioning candidates are informative but not promotable.

### Main takeaways

- The repair target is still the shared `gamma/sigma` chain-quality behavior under stressed readout geometry.
- The next patch should not be another local traversal permutation.
- Standalone conditioning / preconditioning is now tested and insufficient on its own.
- The strongest remaining lever is a true blocked or reparameterized shared-core move, optionally supported by conditioning.
- The right comparison path is still:
  hard canary -> severe quartet -> fixed 6-root harness -> only then broader validation.

## 4) Ultimate Goal

The ultimate goal is not merely to improve one diagnostic. It is to re-establish a credible closeout path for current `HEAD`.

That requires all of the following:

1. a narrow repair candidate that materially improves the common hard case;
2. evidence that the improvement generalizes across the severe quartet;
3. confirmation that the full fixed 6-root harness improves without new regressions;
4. only then a refreshed branch-level closeout sequence.

Until a narrow winner exists, the branch should be treated as scientifically open.

## 5) Recommended Repair Strategy

### Priority order

| priority | candidate family | why this order |
|---|---|---|
| `P0` | substantive shared-core blocked / reparameterized `gamma/sigma` move | strongest remaining untested lever after bridge and conditioning families failed |
| `P1` | conditioning-supported version of the shared-core move | useful support path if Family B benefits from better working geometry |
| `P2` | residual `rhs_ns` warmup / tau-path cleanup | still useful, but only after shared-core progress exists |
| `P3` | broader validation reruns | only after a narrow winner exists |

### Explicit strategic choice

Do next:

- pursue a true blocked/reparameterized shared-core intervention first;
- keep the staged validation funnel unchanged;
- use the hard canary as the first gate for every new candidate family;
- keep conditioning available only as optional support, not the main standalone hypothesis.

Do not do next:

- do not reopen the full validation ladder;
- do not rerun the rejected bridge family;
- do not spend another wave on width/pass tweaks as the main idea;
- do not mix multiple unrelated kernel ideas into one patch.

## 6) Work Package Structure

## WP0: Evidence Freeze and Execution Discipline

Purpose:

- preserve the current blocker map;
- prevent drift in root sets, gates, or comparison baselines.

Checklist:

- [x] preserve Phase 2 audit artifacts
- [x] preserve Wave 2 canary result
- [x] keep the anchor profile fixed across future narrow waves
- [ ] update the tracker after each decision-changing result
- [ ] preserve manifests and run tags for every candidate family

Rules:

- use the same hard canary first unless a new blocker overtakes it;
- do not compare across changing harnesses;
- always carry the anchor baseline in narrow reruns;
- never promote a candidate into defaults before it wins the narrow funnel.

## WP1: Instrumentation and Invariant Preparation

Purpose:

- make the next candidate easier to debug than the bridge wave;
- ensure we can tell whether a candidate is helping geometry, mixing, or neither.

Scope:

- targeted instrumentation only;
- no broad validation relaunch.

Primary files:

- `R/exal_mcmc_fit.R`
- `R/exal_inference_config.R`
- `R/qdesn_mcmc.R`
- validation supervisor/manifests for the next narrow wave

Checklist:

- [ ] add candidate-level metadata capture for new conditioning controls
- [ ] record transformed-design diagnostics when a conditioning mode is active
- [ ] record back-transform sanity summaries for `beta` and fitted means
- [ ] record per-root condition metrics in the narrow-wave outputs
- [ ] keep logging compact enough to compare profiles across runs

Required artifacts:

- root-level transform summary table
- root-level condition metrics table
- candidate metadata manifest
- chain parameter diagnostics table for `gamma` and `sigma`
- stage status JSON and summary markdown

Success condition:

- every future narrow wave can distinguish:
  - no improvement,
  - better geometry but no mixing gain,
  - better mixing but worse drift,
  - true canary improvement.

## WP2: Candidate Family A, Readout Conditioning / Preconditioning

Purpose:

- test the strongest geometry lever before escalating to a deeper sampler redesign.

Core idea:

- improve the geometry seen by the static `exal` MCMC readout update while preserving end-user outputs in the original coefficient space.

Status update:

- `A1` completed and failed as an effectively inactive no-op on the hard canary.
- `A2` completed and failed as an active but insufficient standalone fix on the hard canary.
- Candidate Family A is therefore closed as a standalone family for this phase.

### Candidate A1: diagonal standardization

Intent:

- center and scale the non-intercept augmented readout columns for MCMC only;
- leave the intercept unscaled;
- preserve a clean back-transform path to original coordinates.

Why this is attractive:

- simplest geometry intervention;
- easiest to debug;
- lower implementation risk than a basis rotation;
- likely enough to tell whether conditioning is a first-order lever.

### Candidate A2: QR / whitening preconditioning

Intent:

- if A1 is too weak, move to a stronger basis-level conditioning transform such as pivoted QR or whitened Gram preconditioning;
- sample in transformed coordinates and back-transform for summaries/forecasts.

Why this is second within the same family:

- stronger geometry correction;
- more invasive because transformed-coordinate priors and back-mapping must be handled explicitly.

### Technical requirements for Candidate Family A

These are non-negotiable:

1. MCMC-only scope.
   The intervention should target the static `exal` MCMC path and not silently alter unrelated inference paths.

2. Original-scale outputs.
   Stored summaries and validation artifacts must remain interpretable in original readout coordinates.

3. Explicit prior handling.
   If transformed coordinates change the implied prior geometry, that must be handled intentionally rather than accidentally.

4. Intercept protection.
   The intercept should not be whitened away or entangled with reservoir-column scaling.

5. Reversible mapping.
   The transform and its inverse must be recorded so diagnostics and predictions can be reconciled cleanly.

### Actual outcome inside Candidate Family A

| step | candidate | result |
|---|---|---|
| `A1` | diagonal standardization | inactive on the canary, rejected |
| `A2` | QR / whitening preconditioning | active and informative, but still failed the canary, rejected as standalone |

## WP3: Candidate Family B, Structural Shared-Core Kernel Move

Purpose:

- provide the next primary repair path now that conditioning alone is not enough.

When to enter WP3:

- now
- Candidate Family A has already failed as a standalone family

Most plausible directions:

1. blocked `gamma/sigma` move rather than sequential local refreshes;
2. stronger reparameterization of the shared core rather than another traversal order change;
3. a move that preserves the drift containment seen in `R2` while recovering ESS more reliably.

What not to do in WP3:

- do not retry bridge/width permutations as the main hypothesis;
- do not compensate with long-chain inflation as the primary mechanism.

## WP4: Residual `rhs_ns` Overlay

Purpose:

- clean up residual `rhs_ns` sentinel behavior after a shared-core or conditioning winner exists.

When to use:

- only after Candidate Family A or B has already demonstrated a real narrow-wave win.

Candidate ingredients already supported by the evidence:

- moderate `freeze_tau_burnin_iters`
- multistart pilot screening

What this work package is not:

- it is not the next primary repair;
- it is not the explanation for the ridge hard case.

## WP5: Branch Revalidation Path

Purpose:

- convert a narrow winner into refreshed branch-level evidence.

Entry condition:

- a candidate has cleared the full 6-root harness with no new operational regressions and a materially improved fail profile.

Recommended rerun order:

1. refreshed closeout micro-pilot
2. refreshed dynamic family/prior baseline
3. regenerated closeout recommendation

Do not enter WP5 before WP2 or WP3 produces a real narrow winner.

## 7) Validation Funnel

## Stage V0: unit and smoke invariants

Scope:

- local tests only;
- no multi-root validation yet.

Required checks:

- candidate config resolves correctly
- identity / off mode preserves historical behavior
- transformed and back-transformed summaries are numerically sane
- no intercept corruption
- no obvious forecast or posterior-shape regressions on smoke cases

Exit condition:

- package-level invariants and targeted tests pass cleanly.

## Stage V1: single hard canary

Root:

- `dlm_constV_bigW @ tau=0.05 exal ridge`

Required comparison:

- `R0_legacy_anchor` vs one new candidate only

Gate:

- no new finite/domain/collapse issues
- candidate must remain operationally healthy
- candidate must improve the root in the overall intended direction

Recommended quantitative rule:

- signoff reason count is smaller, or signoff improves;
- `ESS` improves materially;
- `half_drift` does not worsen materially;
- runtime increase remains moderate.

The canary should continue to reject candidates early if they merely trade `Geweke` against `ESS` or drift.

## Stage V2: severe quartet

Scope:

- the four severe roots only

Gate:

- severe fail count must fall below the current quartet baseline;
- no new root-level operational failures;
- no clear regression on the easier severe roots;
- runtime inflation remains below the previously accepted narrow-wave ceiling.

## Stage V3: fixed 6-root harness

Scope:

- the same 6 roots used in Wave 1 and Wave 2

Gate:

- total fail count improves materially;
- sentinel roots do not regress;
- no new numerical pathologies appear;
- candidate remains operationally stable.

## Stage V4: broader validation

Entry condition:

- V3 produces a narrow winner.

Scope:

- closeout micro-pilot
- dynamic family/prior refresh
- final closeout only after refreshed dynamic evidence exists

## 8) Proposed Gate Matrix

| stage | objective | pass standard | fail / stop condition |
|---|---|---|---|
| `V0` | protect invariants | targeted tests pass; transform metadata sane | any back-transform inconsistency or forecast corruption |
| `V1` | canary improvement | better overall canary behavior than anchor | signoff unchanged with worse ESS/drift, or any new numerical issue |
| `V2` | severe-quartet generalization | severe fail count drops below current baseline | no quartet improvement, or runtime becomes disproportionate |
| `V3` | 6-root confirmation | total fail count improves and sentinels hold | severe gain disappears on the full six, or sentinels regress |
| `V4` | branch-closeout restart | narrow winner survives broader reruns | refreshed baseline reproduces the old blocked outcome |

## 9) Implementation Standards

Every Phase 3 candidate should satisfy these standards:

1. One hypothesis per patch.
2. One clear candidate family per run.
3. A unique manifest and run tag.
4. A stable anchor profile.
5. Explicit recording of parameter/control deltas.
6. Compact but sufficient logging to reconstruct what happened without rerunning.
7. Tests for any new config path and any new transform/back-transform logic.
8. Tracker and report updates before moving to the next family.

## 10) Documentation and Artifact Standards

For every candidate family, produce:

- a plan or report doc in `docs/`
- a candidate manifest in `config/validation/`
- a narrow-wave supervisor in `scripts/` if needed
- summary markdown under `reports/`
- root-level transition tables
- runtime summary
- condition/transform diagnostics when relevant

Minimum decision packet for each family:

1. what changed
2. what was tested
3. what gate failed or passed
4. what the hard canary did
5. whether the family is promotable, deferable, or rejected

## 11) Risks and Mitigations

| risk | why it matters | mitigation |
|---|---|---|
| transformed-coordinate prior drift | a conditioning patch can silently change the effective prior | handle prior geometry explicitly and document it |
| back-transform mismatch | could make summaries or forecasts misleading | add dedicated invariance/sanity tests before validation |
| false optimism from one root | single-root wins may not generalize | keep the severe quartet and full-six gates mandatory |
| overfitting to `tiny_d1_n8` | a fix might only help one geometry regime | use the same fixed 6-root harness before any broad rerun |
| expensive dead-end reruns | broad validation could waste compute before a real winner exists | keep the staged funnel strict and stop early on gate failure |

## 12) Immediate Execution Plan

### Step 1: implement Candidate Family B

Files most likely involved:

- `R/exal_mcmc_fit.R`
- `R/exal_inference_config.R`
- possibly `R/qdesn_mcmc.R` if candidate controls need to be threaded through
- targeted tests under `tests/testthat/`

Deliverables:

- one opt-in blocked/reparameterized shared-core control path
- tests for the new core move and any conditioning-support invariants it uses
- one new narrow-wave manifest for the Family-B candidate

### Step 2: run the staged funnel for Candidate Family B

Sequence:

1. `V0` invariants
2. `V1` hard canary
3. `V2` severe quartet only if `V1` passes
4. `V3` full six only if `V2` passes

### Step 3: decide from Family B

Decision matrix:

| Family-B outcome | next move |
|---|---|
| clearly fails on canary | either try one alternate Family-B variant or escalate to deeper redesign |
| helps canary but not enough | consider adding conditioning support under the same Family-B hypothesis |
| clears canary and quartet | run full 6-root harness |
| clears full 6-root harness | prepare refreshed closeout path |

### Step 4: only then use secondary support paths

If the first Family-B candidate is mixed:

- keep Family-B attribution clear;
- decide whether QR-whitening support belongs inside the same hypothesis family;
- do not reopen broader branch validation in between.

## 13) Definition of Done For This Phase

Phase 3 is complete only when one of these is true:

1. a narrow winner exists and is ready for refreshed branch-level validation; or
2. both the conditioning family and the next structural-core family have been tested and rejected with clean documentation, making a deeper redesign the only honest next step.

Anything short of that is progress, but not closure.

## 14) Main Docs To Keep Open

Planning and tracker:

- `docs/TRACK__qdesn_validation_repair_20260331.md`
- `docs/PLAN__qdesn_validation_phase3_20260331.md`

Current evidence:

- `docs/REPORT__qdesn_validation_phase2_audit_20260331.md`
- `docs/REPORT__qdesn_validation_repair_wave2_20260331.md`
- `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/summary/phase2_audit_summary.md`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave2/qdesn-validation-repair-wave2-20260331__git-49c96b4/summary/repair_wave2_results.md`

## 15) Bottom-Line Recommendation

Move next to a blocked or reparameterized shared-core candidate, not another local traversal reshuffle or another standalone conditioning variant.

Run it through the same strict funnel:

- canary first
- quartet second
- fixed 6-root harness third
- broader validation only after a narrow win

That is the most efficient, highest-signal, and best-documented path from the current blocked state.
