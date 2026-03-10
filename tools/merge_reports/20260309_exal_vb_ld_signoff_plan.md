# 2026-03-09 exAL VB LD Signoff Plan

## Scope
This plan is for the remaining static `exAL` `VB` issue only.

It is explicitly **not** a broader `exAL` model audit, and it is **not** an `s_i`-update audit.

Current evidence supports the following narrowed diagnosis:
- the previous catastrophic failure mode was a 2-cycle in the nonconjugate `(
  sigma, gamma)` Laplace-Delta block,
- `s_i` followed that instability but did not cause it,
- the new stabilization path removes the catastrophic 2-cycle,
- the remaining problem is now a **signoff-layer issue**: fit quality is good, but the current `VB` convergence and LD-mode quality gates still do not clear the run.

So the next work should target the **LD signoff layer**, not the broader model and not the `s_i` update itself.

## Current reference evidence

### Fixed benchmark
Reference run:
- `results/function_testing_20260309_static_paper_normal_dense_nonzero_qspec_ldfix/tau_0p05/run_tt10000_vbns1000_burn2000_n1000`

Main read:
- `AL` remains stable under both `VB` and `MCMC`.
- `exAL` now beats `AL` under both `VB` and `MCMC` on fit quality and coefficient recovery.
- `exAL VB` no longer explodes.
- `exAL VB` still reports:
  - `converged = FALSE`
  - `stop_reason = max_iter`
  - `ld_local_mode_pass = FALSE`
  - high `ld_xi` drift / LD stability gate failure
- `exAL MCMC` remains scientifically useful, but still has weak tail mixing.

### What this means
The main debugging question is now:

> Why does stabilized `exAL VB` recover a good fit but still fail the formal LD signoff checks?

This is now a much narrower and more tractable problem than the earlier catastrophic oscillation failure.

## Objectives

### Objective A
Determine whether the remaining `exAL VB` failure is:
1. a **real residual numerical defect** in the LD block, or
2. a **signoff/gating defect**, where the fit is practically stable but the current LD gate is too strict or monitoring the wrong quantities.

### Objective B
Once the answer is clear for static `exAL VB`, extract the minimal guardrails that should later be propagated to all `exAL`-type VB paths:
- static `exAL VB`
- dynamic `exDQLM LDVB`
- dynamic `exDQLM ISVB` only if the same guardrail is conceptually relevant

## Phased plan

### LD1. Freeze the reference cases
Goal:
- work from a fixed reference set and do not move targets while debugging.

Reference cases:
1. reduced `n=100` debug case from:
   - `results/sim_suite_static/audits/exal_vb_ld_stabilization_20260309`
2. full `n=10000`, `tau=0.05` dense-normal reference run from:
   - `results/function_testing_20260309_static_paper_normal_dense_nonzero_qspec_ldfix/tau_0p05/run_tt10000_vbns1000_burn2000_n1000`

Checklist:
- [ ] confirm these are the sole reference cases for LD debugging
- [ ] do not reopen old pre-fix runs as optimization targets
- [ ] use these cases for all subsequent comparisons

### LD2. Instrument the LD signoff layer better
Goal:
- make the current signoff failure observable in terms of *candidate vs committed* LD states, not only the committed state.

Add diagnostics for each VB iteration:
- candidate LD mode quality before commit
- whether the candidate was rejected
- whether commit used direct or damped update
- whether `xi` used `delta` or `mc`
- stabilization reason
- candidate-to-committed step size in `eta` and `ell`
- candidate-to-committed change in `xi`
- optional LD objective delta before/after commit

Checklist:
- [ ] candidate LD diagnostics saved in trace rows
- [ ] commit-rejection count and commit-mode count summarized
- [ ] plots/tables added only if they materially help debugging

### LD3. Separate "fit stability" from "LD local-mode quality"
Goal:
- explicitly measure whether the fit is practically stable even when the local-mode gate fails.

Add summary diagnostics over the last tail window:
- split-half stability of fitted quantile path
- split-half stability of coefficient means
- last-window RMSE drift against truth
- last-window relative drift in sigma/gamma means
- last-window drift in `xi`

Interpretation target:
- if fit quantities are stable but local-mode metrics fail, the problem is likely in the LD signoff definition rather than the fit itself.

Checklist:
- [ ] define last-window stability metrics
- [ ] compare them between `AL VB`, stabilized `exAL VB`, and `exAL MCMC`
- [ ] classify failure as `signoff-only` or `real-instability`

### LD4. Reduced-case ablation grid
Goal:
- use the cheap `n=100` benchmark to identify which remaining LD ingredients are still driving the bad signoff outcome.

Ablations to test:
1. stabilized current path
2. always use `mc` `xi`
3. delayed `mc` fallback only after a bad-mode event
4. stronger damping on committed LD updates
5. tighter `eta` / `ell` step caps
6. commit rejection when:
   - local mode fails,
   - gradient norm is above threshold,
   - Hessian sign condition fails
7. more `xi` samples to reduce MC noise

Checklist:
- [ ] run all reduced ablations on the same fixed seed/data
- [ ] compare: convergence status, fit RMSE, coefficient RMSE, LD signoff metrics
- [ ] rank by stability gain vs complexity cost

### LD5. Minimal-fix implementation in static exAL VB
Goal:
- implement the least invasive change that clears the reference benchmark without degrading the already-fixed behavior.

Priority order:
1. signoff logic redesign if the problem is only gating
2. candidate-mode rejection if bad candidates are still being accepted
3. stronger default stabilized path if needed
4. broader `mc xi` fallback only if necessary

Checklist:
- [ ] fix is minimal and local to static `exAL VB`
- [ ] no regression to `AL VB`
- [ ] no reopening of the previous 2-cycle

### LD6. Full reference rerun
Goal:
- rerun the `n=10000`, `tau=0.05` dense-normal case with the selected fix.

Success criteria:
- `exAL VB` still beats `AL VB`
- no catastrophic oscillation
- formal signoff either passes, or any remaining failure is tightly justified and materially smaller than before
- outputs and plots regenerated cleanly

Checklist:
- [ ] rerun completed
- [ ] compare to previous `ldfix` baseline
- [ ] summarize fit, convergence, and LD diagnostics side by side

### LD7. Propagation plan for other exAL/exDQLM VB paths
Goal:
- only after static reference success, decide which guardrails should become standard in all extended-model VB paths.

Possible guardrails to propagate:
- cycle detection
- bad-mode commit rejection
- stabilized commit mode
- `mc xi` fallback under detected LD failure
- improved LD signoff diagnostics

Targets:
1. static `exAL VB`
2. dynamic `exDQLM LDVB`
3. dynamic `exDQLM ISVB` only if directly relevant

Checklist:
- [ ] propagate only proven guardrails
- [ ] do not copy exploratory debugging settings blindly into dynamic code
- [ ] validate after propagation on one reduced dynamic reference case first

## Definition of success for this debugging thread
This debugging thread is successful if all of the following are true:
- catastrophic 2-cycle remains eliminated,
- `exAL VB` fit quality remains good on the full reference benchmark,
- we can state clearly whether the remaining issue was a true LD numerical defect or a signoff-layer defect,
- we have a minimal patch that addresses it,
- we have a justified list of which guardrails should later be propagated to the dynamic/static extended-model VB paths.

## What not to do yet
- do not reopen the broader `exAL` model-vs-data question here
- do not debug `s_i` as if it were the primary failure source
- do not change `AL`
- do not change `exAL MCMC`
- do not propagate any new guardrail to dynamic code until the static reference case is settled

## Current narrowing note after the full n=10000 stabilized rerun

The completed full reference run sharpened the next debugging decision.

Observed in the final stabilized `exAL VB` fit:
- fit quality is now good and `exAL VB` beats `AL VB`,
- parameter deltas at the end are tiny,
- but `converged = FALSE` and the LD signoff still fails,
- every late iteration is still marked `ld_bad_mode = TRUE`,
- stabilization stays active with reason `ld_used_fallback`,
- `xi_method = mc` throughout the stabilized tail,
- `ld_mode_local_pass = FALSE` throughout the tail,
- the candidate-state gradient norm is moderate rather than catastrophic,
- the fit itself drifts very little near the end.

This means the next debugging target is now even narrower than before:

> determine why the LD block is forced into fallback mode and bad-mode classification even when the committed fit state is already stable and accurate.

So the immediate next job under `LD2` and `LD3` is:
1. inspect why `find_mode_ld()` keeps returning `used_fallback = TRUE`,
2. distinguish optimizer fallback from Hessian fallback,
3. inspect whether the current local-mode test is too strict for the stabilized path,
4. decide whether the right fix is in:
   - optimizer/Hessian construction, or
   - LD local-mode signoff logic.
