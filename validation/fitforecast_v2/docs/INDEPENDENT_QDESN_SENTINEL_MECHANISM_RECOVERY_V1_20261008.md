# Independent Q-DESN sentinel mechanism recovery v1

## Decision

The frozen sentinel campaign is scientifically unchanged and remains the parent
record. It paused after 529 successful jobs because six extreme-scale hybrid
fits triggered a first-step identity assertion expressed only as an absolute
prediction tolerance. Direct reconstruction showed exact teacher-forced input
vectors and relative agreement at floating-point precision. The assertion, not
the transition or forecast protocol, was the implementation failure.

## Root correction

The recovery replaces the absolute output-scale assertion with two checks:

1. The actual first-step readout vector must equal the independently rolled,
   teacher-forced design row under strict absolute and relative tolerances.
2. The resulting first-step prediction must agree under a scale-aware absolute
   plus relative tolerance.

Every origin writes `first_step_guard.csv`, and the worker diagnostics retain
the maximum absolute and relative discrepancies. Nonfinite values and genuine
feature/state mismatches remain fatal.

## Immutable continuation

The recovery run imports 529 successful parent jobs by path and verified hash.
It creates new configurations for exactly 161 quantile-screen jobs: six parent
failures and 155 jobs that had not started. It does not overwrite or reinterpret
parent evidence. Downstream plans are generated only after all 204 quantile
screen rows are successful under the combined imported/recovery ledger.

The scientific contract remains fixed: candidate bank, data, folds, seeds,
priors, likelihoods, M0 exAL MCMC transition, training length, 30-step horizon,
teacher forcing between origins, recursion within origins, score definitions,
and selection rules are unchanged.

## Forecast-window audit

For the current four-fold leader (`23eb3c867723c85379f2`), mean forecast MAE
was 2.488, 3.098, and 2.613 over early, middle, and late origin thirds. Mean MAE
was 2.659, 2.730, 2.723, and 2.734 over lead bands 1--5, 6--10, 11--20, and
21--30. There is no monotone deterioration across validation time or recursive
lead. Shortening the primary validation window would reduce temporal coverage
without addressing the observed problem and is therefore rejected. Origin and
lead profiles remain required diagnostics.

## Execution and promotion boundary

The scheduler uses at most 15 unused physical cores and one computational
thread per model. Any worker failure drains active jobs and pauses scheduling.
No article result is changed automatically. Completion produces an investigator
review packet; article integration remains a separate decision and repository.
