# Independent Q-DESN canonical-gap MCMC v2

## Decision

This campaign targets only the four largest remaining independent-validation
forecast-MAE gaps in the frozen v8 authority. It does not modify package APIs,
article files, joint-QDESN, PriceFM, GloFAS, or application pipelines. Every
family, quantile, likelihood, and metric retains its own specification winner.

The completed v8 campaign showed that development-source rankings did not
reliably transport to the canonical article dataset. V2 therefore changes the
experimental axis: candidate selection is performed directly on the frozen
canonical source with staged MCMC budgets. This is a calibration study for the
displayed simulation cells, not an out-of-sample model-selection claim.

## Frozen targets

| Cell | Current forecast MAE | Comparator | Relative gap |
|---|---:|---:|---:|
| AL-RHS, Gaussian, p=0.05 | 8.4101 | 3.8294 | 119.6% |
| AL-RHS, Gaussian, p=0.50 | 2.1042 | 1.1615 | 81.2% |
| exAL-RHS, Gaussian, p=0.50 | 1.9707 | 1.1615 | 69.7% |
| exAL-RHS, Gaussian mixture, p=0.50 | 2.5623 | 1.9321 | 32.6% |

Fit RMSE is descriptive and cannot select or promote a candidate. Forecast MAE
is primary; forecast check loss is evaluated and may be promoted independently.
There is no minimum gain threshold and diagnostics are retained but are not a
promotion veto.

## Novel candidate design

Each cell receives sixteen deterministic, history-checked profiles. The design
combines compact local neighborhoods suggested by v8 with previously uncovered
depth, memory, capacity, alpha, rho, and RHS-scale boundaries. It includes
depths 1--4, memory 12--150, up to 200 states per layer, alpha from 0.08
through 0.999, rho from 0.35 through 0.999, and tau0 from
1e-8 through 3e-4. Exact signatures present in the frozen 9,420-row history
ledger are forbidden and deterministically perturbed before execution.

## Stages

| Stage | Jobs | Budget per job | Decision |
|---|---:|---:|---|
| Smoke | 2 | 4 + 4 | AL and exact-M0 exAL contract |
| Calibration | 4 | 300 + 700 | largest design runtime and storage gate |
| Canonical screen | 128 | 1,000 + 4,000 | sixteen candidates, two chains per cell |
| Canonical refine | 36 | 2,500 + 7,500 | top three candidates per cell, three chains |
| Confirmation | at most 24 | 5,000 + 20,000 | up to two metric winners per cell, three chains |

Short-budget selection ranks the arithmetic mean forecast MAE, then check loss,
with finite-output and successful-execution requirements. Full confirmation
promotes each metric independently when its three-chain arithmetic mean is
strictly below the frozen v8 value. All nonwinning v8 values remain unchanged.

## Inference and reproducibility

- exAL uses exact `m0_v_collapsed_support_logit` (M0); pre-M0 scores do not veto a
  DESN design.
- AL uses the frozen `sigma_then_gamma` transition.
- Every model uses one computational thread.
- Progress is emitted every 50 iterations; heartbeat and stale thresholds are
  1,800 seconds.
- Rolling-origin forecasting uses leads 1--30, stride 30, observed-lag state
  updates, and no refitting.
- Fitted-model `.rds`, `.rda`, and `.RData` payloads are pruned after compact
  CSV/JSON evidence is written.
- The launcher requires a clean, pushed task branch and waits for all twenty
  requested worker CPUs to be idle, 64 GiB available memory, and 80 GiB free disk. It does not
  compete with active joint or application campaigns.

Runtime outputs remain ignored under the campaign-specific reports and results
roots. A later closeout must freeze plans, configs, source hashes, metric rows,
lead summaries, diagnostics, promotion decisions, and a remaining-gap ledger
before requesting integration.
