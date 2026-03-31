# REPORT: QDESN Validation Phase 3 Family-B Screen (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-phase3-familyb-screen-20260331a__git-7ef7554`

## 1) Purpose

Run the first broad transformed-sigma screen after the earlier bridge and standalone-conditioning families were rejected, while keeping the repair ladder stage-gated:

1. canary;
2. severe quartet;
3. fixed 6-root harness.

The goal was to find a genuinely better shared-core family without reopening broad validation.

## 2) Operational Outcome

The run was operationally healthy end to end.

- top-level runner completed;
- `S1_canary_screen` completed;
- `S2_severe_quartet` completed;
- `S3_full_six_final` completed;
- no timeouts;
- no runner errors;
- no finite/domain/collapse regressions.

This was a real scientific screen, not an orchestration failure.

## 3) Stage Outcome

### S1 canary

Selected survivors:

- `R8_logsigma_gamma_focus`
- `R12_logsigma_sigma_focus`
- `R9_logsigma_gamma_focus_qr`

Main read:

- transformed sigma plus gamma focus was the strongest single-direction canary pattern;
- sigma-focused transformed sigma looked promising locally;
- QR support remained viable enough to advance, but only as a secondary candidate.

### S2 severe quartet

Selected survivor:

- `R8_logsigma_gamma_focus`

Quartet result:

| profile | severe_fail_n | total_fail_n | runtime_inflation | selected |
|---|---:|---:|---:|---|
| `R8_logsigma_gamma_focus` | `2` | `2` | `0.5356` | yes |
| `R12_logsigma_sigma_focus` | `4` | `4` | `-0.0680` | no |
| `R9_logsigma_gamma_focus_qr` | `4` | `4` | `0.5264` | no |

Main read:

- `R8` was the only candidate that materially reduced the severe quartet;
- global QR did not generalize across the severe roots;
- global sigma-focus alone was too weak.

### S3 fixed 6-root harness

Final result:

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | runtime_inflation | gate |
|---|---:|---:|---:|---:|---|
| `R0_legacy_anchor` | `4` | `1` | `5` | `0.0032` | `FALSE` |
| `R8_logsigma_gamma_focus` | `4` | `1` | `5` | `0.4761` | `FALSE` |

Main read:

- the best transformed-sigma candidate did not beat the anchor at the full 6-root level;
- the quartet win did not translate into a full-harness win;
- transformed sigma plus gamma focus is a useful ingredient, but not a sufficient final repair.

## 4) Important Telemetry Clarification

The initial stage summary tables reported `mcmc_use_log_sigma = FALSE` for the Family-B profiles.
That turned out to be a reporting issue, not an execution issue.

Confirmed from per-fit request/config artifacts:

- `cfg_received.json` and `fit_request.json` for `R8` show
  `inference.mcmc.transforms.use_log_sigma = true`;
- the transformed-sigma controls were reaching the fit runner;
- the missing values came from incomplete control fields stored on the returned `exal_mcmc` object.

This means the Family-B conclusions remain valid:
the transformed-sigma family really was tested.

## 5) What Worked Best

### Strongest working pattern

`R8_logsigma_gamma_focus` is still the best working shared-core template:

- transformed sigma enabled;
- one extra core pass;
- sharper gamma movement;
- moderate sigma width.

What it did well:

- reduced the severe quartet from `3 FAIL` to `2 FAIL`;
- improved several `Geweke` and `ESS` diagnostics substantially;
- stayed operationally clean.

### Secondary helpful pattern

QR support was locally useful on ridge geometry:

- it strongly improved the hard ridge canary on some diagnostics;
- it appears to be more promising as a ridge-only helper than as a global switch.

### What did not work as a lead idea

- standalone bridge-family traversals;
- standalone diagonal conditioning;
- standalone QR conditioning;
- global sigma-focus by itself;
- global QR + gamma focus as a whole-profile strategy.

## 6) Root-Level Failure Decomposition Under The Best Candidate

The best candidate after the full 6-root stage (`R8`) still left `5` FAIL roots.

### Ridge failures

`dlm_constV_bigW @ tau=0.05 exal ridge`

- `ESS` recovered enough (`14.56`) to clear the warn floor;
- remaining blockers were `geweke_drift` and `half_chain_drift`.

`dlm_constV_smallW @ tau=0.95 exal ridge`

- remaining blockers were `low_ess`, `high_autocorrelation`, and `geweke_drift`;
- drift was already acceptable.

Interpretation:

- the two ridge hard cases want different help;
- `bigW` ridge looks drift/Geweke-limited;
- `smallW` ridge looks ESS/ACF/Geweke-limited.

### RHS-NS failures

`dlm_ar1V @ tau=0.95 exal rhs_ns`

- remaining blockers were `geweke_drift` and `half_chain_drift` in the core;
- rhs diagnostics also remained elevated.

`dlm_constV_smallW @ tau=0.95 exal rhs_ns`

- remaining blockers were `low_ess`, `high_autocorrelation`, and `half_chain_drift`;
- rhs diagnostics were already acceptable.

`dlm_constV_bigW @ tau=0.95 al rhs_ns`

- remaining blocker was `geweke_drift` on the rhs side only;
- core diagnostics were already healthy.

Interpretation:

- the remaining `rhs_ns` problem is not one thing;
- one root is rhs-only (`al`);
- one root is core-plus-rhs (`ar1V exal`);
- one root is mostly core mixing (`smallW exal`).

## 7) Main Takeaways

1. The transformed-sigma family was the first broad family to produce a real severe-quartet improvement.
2. The exact best pattern is not global QR or global sigma-focus. It is gamma-focused transformed sigma.
3. The remaining fail set is now clearly split by prior family.
4. Ridge and `rhs_ns` should no longer share the same repair profile.
5. The next broad screen should use the best transformed-sigma gamma-focus profile as the baseline anchor, not the older historical anchor.
6. The next objective should be `zero FAIL`, not “all PASS”. `WARN` is acceptable if it removes `FAIL`.

## 8) Recommended Next Move

Move to a split-prior zero-FAIL screen:

- keep the transformed-sigma gamma-focus family as the baseline anchor;
- give ridge its own candidate levers:
  QR support, sigma-focused widths, and possibly modest ridge-only chain extension;
- give `rhs_ns` its own candidate levers:
  stronger warmup/freeze behavior, stronger rhs block passes, and one mild multistart edge candidate;
- stage on the severe quartet first, then the full 6-root harness.

That is the right next repair wave because it builds directly on what worked in Family-B without repeating the families that already failed.
