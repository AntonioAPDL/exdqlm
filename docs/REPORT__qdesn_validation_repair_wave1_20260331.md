# REPORT: QDESN Validation Repair Wave 1 (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-validation-repair-wave1-20260331__git-59e0e2a`

## 1) Purpose

Test the first narrow repair wave on current `HEAD` without relaunching the full branch validation ladder.

The wave kept the fixed 6-root closeout harness and compared:

- `R0_legacy_anchor`: explicit historical controls
- `R1_promoted_x10_core`: promoted shared-core candidate from the prior screen winner
- `R2_x3_alternate`: immediate same-family alternate
- `R3_x10_plus_x8_rhsns_overlay`: promoted shared core plus the best rhs_ns residual overlay

## 2) Executive Outcome

The repair wave completed cleanly and answered the decision question.

- all `4/4` profiles completed with `6/6` root success;
- all profiles had `all_finite_ok = TRUE`, `all_domain_ok = TRUE`, `unhealthy_n = 0`, `collapse_n = 0`;
- no profile passed Gate B;
- no profile reduced the severe fail set below `4`;
- the best profiles only reduced the total fail count from `6` to `5`.

Decision:

- do not promote `X10` into package defaults;
- do not switch to `X3` as the shared-core default;
- do not promote the `X8` rhs_ns overlay as a default layer;
- keep the repair harness and manifests as the reproducible evaluation path for the next kernel hypothesis.

## 3) Final Ranking

| profile | total fail n | severe fail n | sentinel fail n | fail reduction | runtime inflation median | gate B |
|---|---:|---:|---:|---:|---:|---|
| `R3_x10_plus_x8_rhsns_overlay` | `5` | `4` | `1` | `0.1667` | `0.4218` | `FALSE` |
| `R1_promoted_x10_core` | `5` | `4` | `1` | `0.1667` | `0.4422` | `FALSE` |
| `R0_legacy_anchor` | `6` | `4` | `2` | `0.0000` | `-0.0686` | `FALSE` |
| `R2_x3_alternate` | `6` | `4` | `2` | `0.0000` | `0.4160` | `FALSE` |

## 4) Main Findings

### What improved

- `R1` and `R3` each cleaned one sentinel root, cutting the total fail count from `6` to `5`.
- `R3` was the best runtime-balanced profile of the non-anchor candidates.
- all non-anchor profiles improved median diagnostic summaries relative to baseline, especially `ESS` and `Geweke`.

### What did not improve enough

- the severe fail set stayed at `4` for every candidate;
- the persistent common hard root stayed `FAIL`;
- `R2` improved diagnostics but did not produce any root-level `FAIL -> WARN/PASS` reduction;
- the `rhs_ns` overlay was not enough to change the branch-level decision.

### What this means

- the current problem is still not solved by the screened shared-core width/pass candidates;
- the next fix should not be another minor default-promotion attempt;
- the next fix should be based on a genuinely new kernel hypothesis.

## 5) Root-Level Read

The persistent severe cluster still centers on the same closeout roots:

- `dlm_ar1V @ tau=0.95 exal rhs_ns`
- `dlm_constV_smallW @ tau=0.95 exal ridge`
- `dlm_constV_bigW @ tau=0.05 exal ridge`
- `dlm_constV_smallW @ tau=0.95 exal rhs_ns`

The strongest sentinel movement in this wave was:

- `dlm_constV_bigW @ tau=0.95 al rhs_ns`: `FAIL -> WARN` under `R3`
- `dlm_constV_smallW @ tau=0.50 exal rhs_ns`: `FAIL -> WARN` under `R1`

But that was not enough, because the common severe ridge hard case stayed `FAIL` throughout.

## 6) Interpretation

This wave narrows the problem further:

- the issue is still operationally stable and reproducible;
- the issue is still centered in the static `exal` MCMC kernel;
- the current width/pass/freeze candidate family is too weak on current `HEAD`;
- the next move should focus on structural kernel behavior or conditioning, not another simple promotion of screened defaults.

## 7) Recommended Next Step

Use the same repair-wave harness, but only after a new hypothesis is ready.

Highest-value next investigations:

1. structural debugging on the persistent `dlm_constV_bigW @ tau=0.05 exal ridge` hard root;
2. conditioning / geometry audit focused on the `tiny_d1_n8` severe cluster;
3. only then a new narrow rerun through this same repair manifest pattern.

## 8) Key Files

- summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/summary/screen_results.md`
- rank table:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/profile_rank_summary.csv`
- execution table:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/profile_execution_status.csv`
- transitions:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R1_promoted_x10_core.csv`
- transitions:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R2_x3_alternate.csv`
- transitions:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R3_x10_plus_x8_rhsns_overlay.csv`
- diagnostic deltas:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_micro_pilot_diag_shift.csv`
