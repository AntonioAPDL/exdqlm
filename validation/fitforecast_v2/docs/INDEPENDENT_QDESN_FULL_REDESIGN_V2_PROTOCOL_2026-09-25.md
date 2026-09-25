# Independent Q-DESN full AL/exAL redesign v2

## Decision

The campaign restarts the independent simulation evaluation under one coherent
protocol. It does not resume the superseded fixed-state forecast campaign and
does not alter the article, Overleaf, shared validation, or any other
scientific lane.

Four model classes are compared: DQLM-AL, Q-DESN-AL-RHS, exDQLM-exAL, and
exQ-DESN-exAL-RHS. Only the Q-DESN classes undergo structural selection. The
state-space specifications remain fixed. Their current authority is frozen as
a comparator reference; because its historical origin stride differs, direct
article replacement requires a later common-lattice comparator replay and is
not automatic from this campaign.

Within each family, the three source files share the oracle location path but
intentionally contain different quantile-centered observed series. The freeze
therefore requires identical `mu` paths and separately hashes each `y` path; it
does not incorrectly force the quantile-specific responses to be identical.

## Forecast estimand

The model is fit once. Origins advance one observation at a time, admitting
the newly observed response before the next forecast. Within each fixed origin,
Q-DESN forecasts are recursive for 30 leads because future response lags are
unknown. This combines teacher forcing between origins with genuine recursive
multi-horizon prediction within origins. The final surface contains 971
origins and 29,130 origin-lead pairs per cell.

Q-DESN is evaluated with both path-recursive posterior states and the
advisor-requested mean-complete-readout-state estimator. DQLM and exDQLM use
their standard filtered-state propagation and have no reservoir-state
estimator factor.

## Architecture and search

The Q-DESN readout is exactly one intercept plus every reservoir state from
every layer. Direct response lags, exogenous lags, and lagged reservoir blocks
are excluded from the readout. All lower-layer projections are exact identity
matrices. Reservoir layers use tanh; the lower-state readout transformation and
readout link are identity.

The nonfactorial search covers depth 1-4, widths 20-300, memory 1-150, alpha
0.01-0.99, rho 0.20-0.99, RHS tau0 1e-8 to 1e-1, training-only scaling,
soft bounding, input gain, and exact fan-in topology. It uses 384 deterministic
space-filling candidates per family plus 128 adaptive candidates, then carries
50 family-specific Normal-RHS VB structures into independent AL and exAL
quantile ladders. There is no global specification.

The exAL ladder uses exdqlm 1.1.1 structured LDVB and exact M0 collapsed-slice
MCMC. Pre-M0 exAL rankings are historical diagnostics rather than candidate
authority.

## Selection and confirmation

Selection uses fit 8501:8800 and validation 8801:9000 with horizon 30 and
origin stride 5. The final 9001:10000 block stays sealed. Normal-RHS selection
targets oracle location recovery. Quantile selection targets forecast oracle-
quantile MAE, then forecast check loss and fit oracle-quantile RMSE while
preserving structural diversity.

Up to four VB candidates per family/quantile/likelihood receive direct MCMC
pilots. Up to two receive three full chains. Diagnostic grades are reported but
do not exclude a finite strict score improvement. Broken dimensions,
nonfinite scores, leakage, and architecture-contract failures are hard stops.

## Reproducibility and storage

Every job records source, candidate, package, config, and seed hashes. Workers
are process parallel and single threaded. Runtime files use atomic status
markers and are resumable. Compact score, origin, lead, diagnostic, and winner
ledgers are retained. Nonfinal model binaries are removed only after a verified
closeout; no article promotion is automatic.

The launch uses 15 one-core workers on Muscat. Other projects and their jobs
are neither inspected deeply nor modified.

The resumable stage graph contains 1,152 initial Normal-RHS jobs, 384 adaptive
Normal-RHS jobs, 150 full-budget Normal-RHS jobs, 150 nested AL/exAL VB jobs,
72 MCMC pilots, and 108 full confirmation chains. Confirmation keeps compact
draw-specific metric ledgers so posterior metric intervals can be pooled over
all three chains without retaining fitted-model binaries.
