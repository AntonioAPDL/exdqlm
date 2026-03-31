# REPORT: QDESN Validation Repair Wave 3 (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-validation-repair-wave3-20260331a__precommit`

## 1) Purpose

Execute the first geometry-aware candidate family under the same strict staged funnel used by earlier narrow repair waves:

1. hard-root canary;
2. severe quartet only if the canary improves materially;
3. full 6-root harness only if the quartet improves materially.

Wave 3 specifically tests whether simple diagonal standardization of the static `exal` readout design is enough to change the hard-canary behavior.

## 2) What Changed

Package code:

- `R/exal_inference_config.R`
- `R/qdesn_mcmc.R`
- `R/exal_mcmc_fit.R`
- `R/qdesn_mcmc_validation.R`

Test coverage:

- `tests/testthat/test-exal-mcmc.R`

Execution scaffolding:

- `config/validation/qdesn_validation_repair_wave3_manifest.yaml`
- `scripts/run_qdesn_validation_repair_wave3.R`

New conditioning controls:

- `mcmc_control$conditioning$mode`
- `mcmc_control$conditioning$scale_metric`
- `mcmc_control$conditioning$scale_floor`
- `mcmc_control$conditioning$intercept_column`
- `mcmc_control$conditioning$constant_tol`

Candidate behavior:

- `R5_diag_scale_precondition`
- scales non-intercept beta-draw columns for MCMC only when the design is not already in that regime
- preserves original-coordinate beta outputs and adds explicit conditioning diagnostics to validation summaries

## 3) Validation Scope

Profiles:

- `R0_legacy_anchor`
- `R5_diag_scale_precondition`

Stages:

- `S1_canary`
- `S2_severe_quartet`
- `S3_full_six`

Actual progression:

- `S1_canary` ran
- `S2_severe_quartet` did not run
- `S3_full_six` did not run

Reason:

- the candidate failed the canary gate, so the staged funnel stopped immediately by design

## 4) Operational Health

Wave 3 was operationally clean.

- stage execution: `COMPLETED`
- operational pass: `TRUE`
- timeouts: `0`
- runner errors: `0`
- finite/domain regressions: none
- collapse regressions: none

Key supervisor outputs:

- overall summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave3/qdesn-validation-repair-wave3-20260331a__precommit/summary/repair_wave3_results.md`
- stage conditioning summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave3/qdesn-validation-repair-wave3-20260331a__precommit/stages/S1_canary/summary/stage_conditioning_summary.md`
- canary transition:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave3/qdesn-validation-repair-wave3-20260331a__precommit/stages/S1_canary/screen_runs/qdesn-validation-repair-wave3-20260331a__precommit__S1_canary/tables/phase35_transitions_R5_diag_scale_precondition.csv`

## 5) Canary Result

Target root:

- `dlm_constV_bigW @ tau=0.05 exal ridge`

Comparison against the anchor:

| metric | anchor | diag-scale candidate | delta | read |
|---|---:|---:|---:|---|
| signoff | `FAIL` | `FAIL` | none | candidate did not clear the hard root |
| min ESS core | `6.25` | `3.32` | `-2.94` | worse |
| max Geweke core | `10.74` | `5.41` | `-5.33` | better |
| max half drift core | `0.53` | `1.31` | `+0.78` | materially worse |
| runtime (s) | `2.452` | `2.355` | `-0.097` | slightly faster |

Gate result:

- `gate_pass = FALSE`
- `gate_reason = canary_not_improved_enough`

## 6) Conditioning Activation Read

The most important result from Wave 3 is that the candidate was effectively inactive on the canary.

| field | anchor | diag-scale candidate |
|---|---:|---:|
| conditioning mode | `none` | `diag_scale` |
| conditioning active | `FALSE` | `FALSE` |
| raw condition number | `77.60` | `77.60` |
| working condition number | `77.60` | `77.60` |
| condition gain ratio | `1.00` | `1.00` |
| scaled columns | `0` | `0` |

Interpretation:

- the diagonal-scale family did not materially change the working geometry seen by the beta update on this root;
- this makes Wave 3 a genuine no-op style negative result rather than a hidden failure of the staging harness;
- the candidate worsening the canary is still relevant, but the stronger scientific lesson is that simple per-column scaling is too weak for the current QDESN hard case.

## 7) Main Takeaways

1. The staged funnel again did its job: it stopped a weak candidate at the cheapest possible point.
2. Diagonal standardization is not enough to change the effective geometry of the QDESN hard canary.
3. The conditioning family therefore needed to escalate immediately to a stronger basis-level transform rather than spend any quartet/full-six compute.
4. Wave 3 does not support promoting diagonal conditioning into defaults or using it as the main next repair lever by itself.

## 8) Recommended Next Move

Do next:

1. keep the same narrow-wave scaffolding and anchor;
2. escalate within the conditioning family to a true basis-level transform;
3. require explicit conditioning diagnostics so we can tell whether the candidate really changes working geometry;
4. keep the canary-first gate unchanged.

Do not do next:

- do not rerun Wave 3 on the severe quartet;
- do not treat diagonal scaling as a serious standalone fix;
- do not reopen broader validation from this result.
