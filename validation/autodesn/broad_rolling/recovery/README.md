# Recovery status: expanded AutoDESN study

The 500-day, 456-specification study is incomplete. Automated cleanup removed its
uncommitted local source, numeric exports and runtime before the prepared commit
was published. The repository's earlier Gaussian AutoDESN implementation and
100-day rolling study remain intact.

This directory preserves the one expanded-study checkpoint whose uploaded Git
blob identifier was retained in the execution record. It is the recorded broad
fit for smooth_scale, repetition 1. Its numerical contents need fresh-session
validation before reuse. It must not be presented as a complete forecast study.

- Recovered Git blob: 30823b4ddebacad9af12767266edeb756dd04db3.
- Last confirmed local progress before cleanup: four complete series, plus a
  fifth qualified fit with incomplete rolling forecasts.
- No completed expanded-study aggregate audit or updated PDF was produced.
- The repository-hosted workflow had been prepared locally but was not published
  or launched. Earlier statements must not be read as confirmation it ran.

## Reconstructed experiment contract

This is reconstructed from execution notes, rather than the original frozen
source or parameter CSV, which was lost.

Use 500 washout observations (1:500), exactly 2000 training likelihood rows
(501:2500), and 500 test observations (2501:3000). Evaluate daily origins
2500:2970, each forecasting leads 1:30 recursively. Freeze all preprocessing,
posterior draws, model weights and fitted parameters after day 2500. Feed
observed responses back only between origins; simulate unknown responses within
each issued forecast. There are 471 complete origins, not 500 complete H=30
forecasts.

Use the three existing nonlinear heteroscedastic DGPs and their three existing
seeds per process, extending simulations with prefix-invariant random streams.
The earlier first 100 test values were already examined. Report the newly added
400 separately. Any reconstructed new dictionary must additionally disclose
which earlier expanded results were inspected; never portray it as a pristine
unseen-test design.

The intended dictionary was the original 72 plus 32 balanced configurations
crossed with depths 1:4 and seeds 11/29/47, for 456 specifications. Expanded
factor levels were:
- Initial widths 12,25,50,100, with original width20 retained.
- Lags 1,2,5,12,30,60,90,180.
- Leaks .05,.15,.35,.60,.95; uniform or slowing layer time scales.
- Radii .10,.40,.70,.90,.98; original .60/.95 retained.
- Input scales .05,.20,.50,1,2; original .30 retained.
- Bias scales 0,.10,1; fan-in 3,5,10; input fractions .1,.3,.7,1.
- Raw or tanh-bounded inputs; constant or tapered widths; tanh reservoirs,
  identity bridges and all-layer linear readouts, at most400 slopes.

This is balanced marginal coverage, not a complete Cartesian search. The exact
32-row cross-factor pairing must be recovered or newly frozen; do not silently
treat a reconstructed pairing as the lost original dictionary.

Training-only checks should record numerical finiteness, achieved radii,
saturation, near-constant features, rank and sensitivity to opposite initial
states through day500. A maximum initialization disagreement <=.001 was the
empirical admission rule. It is not an echo-state-property proof.

A separate hard-selection comparator used training origins2000/2250, H30,
centered ridge/GCV penalties 10^(-4:4), 32 stochastic paths and mean CRPS.
The selected model then received a full Gaussian independent-ridge Bayesian fit.
Validation scores did not prune or reweight the broad Bayesian bank.

Keep the Gaussian likelihood and independent Gaussian ridge prior. Retain the
proper intercept and existing inverse-gamma variance / gamma ridge-precision
priors. Gibbs, rather than SMC, was used; there is no RHS prior or learned
conditional volatility model. Three-chain diagnostic screens were Rhat<=1.01,
spectral ESS>=400, and maximum individual model-probability chain range<=.05.
Training-diagnostic retries used burn+retained 2000+6000,4000+16000,6000+32000.

Primary forecasts used192 joint posterior selections x8 innovation trajectories,
with each joint model/coefficient/variance draw fixed through all30 leads.
Sensitivity at origins2500/2735/2970 used K4/8/16/32 and an extra192 selections.

Intended comparators: broad AutoDESN, original72 AutoDESN, CV-selected DESN,
fixed DESN, Gaussian AR1/12/90, constant, fitted AR-GJR, known-parameter DGP.
Raw chunks, diagnostic attempts and checkpoint checks must be retained, with
independent score reconstruction and plots. Overlapping forecast scores are
dependent; three series per DGP support descriptive comparisons only.

Before another expensive run, publish all reconstructed code and its frozen
design to Git and verify a durable execution job actually starts. Save numeric
outputs as external job artifacts as they are produced. Never claim the study,
audits or updated report is complete until the corresponding outputs exist.
