# REPORT: QDESN Validation Repair Wave 4 (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-validation-repair-wave4-20260331a__precommit`

## 1) Purpose

Execute the stronger second candidate inside the conditioning family under the same staged narrow-validation funnel:

1. hard-root canary;
2. severe quartet only if the canary improves materially;
3. full 6-root harness only if the quartet improves materially.

Wave 4 tests whether exact QR-whitening preconditioning of the static `exal` beta-draw geometry is strong enough to repair the hard canary.

## 2) What Changed

Package code:

- `R/exal_inference_config.R`
- `R/qdesn_mcmc.R`
- `R/exal_mcmc_fit.R`
- `R/qdesn_mcmc_validation.R`

Test coverage:

- `tests/testthat/test-exal-mcmc.R`

Execution scaffolding:

- `config/validation/qdesn_validation_repair_wave4_manifest.yaml`
- supervisor used:
  `scripts/run_qdesn_validation_repair_wave3.R`

New conditioning control added in this wave:

- `mcmc_control$conditioning$gram_ridge`

Candidate behavior:

- `R6_qr_whiten_precondition`
- exact QR/whitening beta-draw preconditioning on the non-intercept block
- original-coordinate beta outputs preserved for summaries and forecasts
- explicit transform diagnostics recorded into validation outputs

## 3) Validation Scope

Profiles:

- `R0_legacy_anchor`
- `R6_qr_whiten_precondition`

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

Wave 4 was operationally clean.

- stage execution: `COMPLETED`
- operational pass: `TRUE`
- timeouts: `0`
- runner errors: `0`
- finite/domain regressions: none
- collapse regressions: none

Key supervisor outputs:

- overall summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave4/qdesn-validation-repair-wave4-20260331a__precommit/summary/repair_wave3_results.md`
- stage conditioning summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave4/qdesn-validation-repair-wave4-20260331a__precommit/stages/S1_canary/summary/stage_conditioning_summary.md`
- canary transition:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave4/qdesn-validation-repair-wave4-20260331a__precommit/stages/S1_canary/screen_runs/qdesn-validation-repair-wave4-20260331a__precommit__S1_canary/tables/phase35_transitions_R6_qr_whiten_precondition.csv`

## 5) Canary Result

Target root:

- `dlm_constV_bigW @ tau=0.05 exal ridge`

Comparison against the anchor:

| metric | anchor | QR-whiten candidate | delta | read |
|---|---:|---:|---:|---|
| signoff | `FAIL` | `FAIL` | none | candidate did not clear the hard root |
| min ESS core | `6.25` | `5.49` | `-0.76` | slightly worse |
| max Geweke core | `10.74` | `0.87` | `-9.88` | much better |
| max half drift core | `0.53` | `1.08` | `+0.55` | materially worse |
| runtime (s) | `2.452` | `2.372` | `-0.080` | slightly faster |

Gate result:

- `gate_pass = FALSE`
- `gate_reason = canary_not_improved_enough`

Why the gate failed:

- the candidate stayed `FAIL`;
- the candidate fixed one important symptom (`Geweke`) but did not improve the root in the required overall direction;
- `ESS` did not recover enough;
- `half_drift` worsened too much for the canary to be considered healthier overall.

## 6) Conditioning Activation Read

Unlike Wave 3, the Wave 4 candidate really did change the working geometry.

| field | anchor | QR-whiten candidate |
|---|---:|---:|
| conditioning mode | `none` | `qr_whiten` |
| conditioning active | `FALSE` | `TRUE` |
| raw condition number | `77.60` | `77.60` |
| working condition number | `77.60` | `1.00` |
| condition gain ratio | `1.00` | `77.60` |
| transformed columns | `0` | `20` |

Interpretation:

- this was not a no-op candidate;
- working-space geometry improved dramatically;
- therefore the remaining blocker is not “we forgot to condition the design”;
- the residual failure is about the shared-core chain dynamics that remain bad even after the geometry is cleaned up.

## 7) Main Takeaways

1. The conditioning family is now properly tested.
2. Geometry really is part of the problem, because QR whitening strongly improved the working condition number and Geweke.
3. Geometry alone is not enough, because the canary still failed on the combined ESS/drift picture.
4. The next candidate should be a true blocked or reparameterized shared-core `gamma/sigma` move, not another standalone conditioning variant.
5. Conditioning remains useful as a supporting mechanism for future shared-core work, but not as the lead idea.

## 8) Recommended Next Move

Do next:

1. keep the narrow-wave scaffolding, anchor, and canary unchanged;
2. move to a new family:
   a blocked or reparameterized shared-core `gamma/sigma` candidate;
3. keep QR whitening available as an optional support path if the new family needs it;
4. require the next candidate to improve the hard canary overall, not just `Geweke`.

Do not do next:

- do not rerun Wave 4 on the severe quartet;
- do not promote QR whitening alone into defaults;
- do not reopen broader validation from this result.
