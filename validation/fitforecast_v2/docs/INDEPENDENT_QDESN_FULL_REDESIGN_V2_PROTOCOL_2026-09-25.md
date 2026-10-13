# Independent Q-DESN full AL/exAL redesign v2.1

## Decision

The campaign restarts the independent simulation evaluation under one coherent
protocol. It does not resume the superseded fixed-state forecast campaign and
does not alter the article, Overleaf, shared validation, or any other
scientific lane.

The first v2 launch stopped after its initial stage with 1,151 of 1,152 jobs
successful. One 300-unit layer received a nonconverged RSpectra eigenpair; the
old leaky-map safeguard interpreted that estimate as instability and introduced
diagonal edges, violating exact fan-in. The completed screen also exposed a
separate design problem: `tau0` was assigned once per structure and truncated
at 0.1, so structure and shrinkage effects were confounded and the strongest
Laplace candidates accumulated at the upper boundary. That run is frozen as
diagnostic evidence and is not eligible for scientific promotion.

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
0.01-0.99, rho 0.20-0.99, training-only scaling, soft bounding, input gain,
and exact fan-in topology. It first generates 256 deterministic space-filling
structures per family. Every structure is evaluated on the same six actual
RHS scales: 0.03, 0.1, 0.3, 1, 3, and 10. The same reservoir matrix seed is
used across those six arms, so within-structure contrasts isolate `tau0`.

The adaptive stage generates 96 new structures per family around forecast-first
parents and unexplored regions. Each receives three local arms at one-third,
one, and three times its parent scale, clipped to 0.01-30. The full-budget stage
retains 50 candidate pairs per family, with no more than two `tau0` arms from
one structure. It then carries those family-specific pairs into independent AL
and exAL quantile ladders. There is no global specification or global `tau0`.

All reservoir matrices up to 512 units use dense exact eigendecomposition for
spectral normalization. Larger matrices may use RSpectra only when the returned
eigenpair passes a relative residual check; otherwise the calculation falls
back to dense eigenvalues. Any extra leaky-map stabilization is scalar and
therefore support preserving. Every job hard-checks exact fan-in, target
spectral radius, and leaky-map stability and exports those diagnostics.

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

Workers load the dedicated worktree with `pkgload::load_all()` and assert both
the 1.1.1 source/namespace version and the frozen launch commit before each
fit. The environment manifest records any different exdqlm version found in
Muscat's default library only as host context; it is not the execution package.

The launch uses 15 one-core workers on Muscat. Other projects and their jobs
are neither inspected deeply nor modified.

The resumable stage graph contains 4,608 initial Normal-RHS jobs, 864 adaptive
Normal-RHS jobs, 150 full-budget Normal-RHS jobs, 150 nested AL/exAL VB jobs,
72 MCMC pilots, and 108 full confirmation chains, for 5,952 jobs in total.
Confirmation keeps compact draw-specific metric ledgers so posterior metric
intervals can be pooled over all three chains without retaining fitted-model
binaries.
