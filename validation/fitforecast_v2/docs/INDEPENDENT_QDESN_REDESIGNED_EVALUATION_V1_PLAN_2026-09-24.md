# Independent Q-DESN redesigned evaluation v1

Status: `PLANNED_NOT_LAUNCHED`

## 1. Decision and boundary

The previous mean-readout-state campaign is not a partially completed version
of this study. It answers a different question because its fitted authorities
can contain direct response lags and deterministic regressors in the readout.
It is frozen under:

```text
SUPERSEDED_BY_REDESIGNED_INDEPENDENT_PROTOCOL
```

No metric, ranking, table, or figure from that partial campaign is eligible for
article use. The reusable posterior-path versus mean-readout-state recursion,
paired innovation support, and focused tests are retained.

This new study begins from the latest shared-validation authority in a separate
branch. It does not modify shared validation, Article-v2, or Overleaf. It is
launch-disabled until the architecture, input, selection, and leakage gates in
this plan are implemented and verified.

## 2. Scientific question

The primary comparison is Q-DESN under an AL likelihood and regularized
horseshoe readout against DQLM under the same AL quantile target. It covers:

- three innovation families: Gaussian, Laplace, and Gaussian mixture;
- three quantiles: 0.05, 0.25, and 0.50;
- a 500-observation fit window, source indices 8501 through 9000;
- a sealed 1000-observation forecast window, 9001 through 10000;
- teacher-forced rolling origins at every held-out observation for which a
  complete 30-step horizon exists; and
- recursive forecasting within each 30-step horizon.

The final design therefore has 971 origins, 30 leads per origin, and 29,130
origin-lead pairs per family, quantile, model, and forecast estimator. Teacher
forcing means observations are admitted only when they are available at a new
origin. Future observations inside one 30-step path are never used.

The exAL/exQ-DESN family is not silently included in this primary redesign. It
can be added later as a separately versioned extension using the current M0
transition. Keeping it outside the primary task prevents another uncontrolled
scope expansion.

## 3. Architecture audit

### 3.1 Activation functions

The current implementation does not use tanh only at the last reservoir layer.
It applies `act_f = tanh` to the preactivation in every reservoir layer. It then
applies `act_k = identity` to lower-layer states when those states are stacked
into the readout. The readout itself is linear.

The redesigned contract keeps exactly that behavior:

1. tanh in every recurrent reservoir layer;
2. identity for the lower-state readout transform;
3. identity link for the Bayesian linear readout.

This retains bounded nonlinear dynamics while avoiding a second nonlinear
transformation of already bounded states before regression.

### 3.2 Identity projections

There is no dimension reduction. For each lower layer `d`, set

```text
n_tilde[d] = n[d].
```

The package then constructs `Q_d = I` and records `Q_is_identity[d] = TRUE`.
Every fit must pass an exact matrix check, not merely a dimension check. With an
intercept, the readout dimension is

```text
1 + sum_d n[d].
```

The readout contains no direct response lags, no direct exogenous lags, and no
lagged reservoir-state block. Response and eligible exogenous lags enter only
through the reservoir input.

### 3.3 Random seed

There is no scientifically optimal integer seed. A seed labels one fixed random
feature map; choosing it by score would be another tuning dimension. The main
screen therefore freezes reservoir seed 910001. Seeds 910002 and 910003 are
reserved for a finalist-only sensitivity analysis and are never used to select
the top 50.

Reservoir, candidate generation, inference, and posterior prediction must use
separate seed namespaces. Each manifest records RNG kind, R version, package
version, candidate hash, and every effective seed.

### 3.4 Sparsity

A fixed connection probability is inappropriate when widths range from 20 to
300 because it changes expected recurrent degree from 2 to 30 at probability
0.1. It confounds capacity with topology. The study instead fixes recurrent
in-degree at 10, corresponding to

```text
pi_w[d] = min(1, 10 / n[d]).
```

Production implementation should sample exactly ten predecessors per row when
the layer has at least ten units, rather than depend on a Bernoulli realization.
This avoids zero rows and holds topology comparable across widths. The first
input and inter-layer maps are dense and row-normalized. Dense input maps are
computationally acceptable at the proposed maximum width and avoid a second,
unplanned input-connectivity search.

### 3.5 Weight distribution and stability

Use independent Uniform(-1, 1) nonzero weights. This distribution is symmetric,
continuous, and bounded. Recurrent matrices are then spectrally normalized to
the requested rho and checked under the actual leaky transition. Input and
inter-layer rows are norm-normalized before the fixed input scale is applied.

The existing radius safeguard is retained, but a spectral radius below one is
not treated as proof of the echo-state property. Canary diagnostics must also
check two-initial-state washout convergence, state saturation, zero-variance
units, finite states, and effective state rank.

## 4. Input and transformation contract

The archived DGP fixture has columns `t`, `y`, `mu`, `q_target`, `eps`, and
`source_index`; it contains no exogenous predictors. Thus the primary study has
`m_x = 0`. An exogenous-lag dimension is enabled only for a future DGP that
actually supplies covariates known at each forecast origin.

The innovation is centered at its target quantile, but the observed response is
not centered at zero: it contains the dynamic location. Raw response values can
therefore saturate tanh units. For reservoir input only, fit a median and
consistent MAD on the permitted fit prefix and apply those frozen parameters to
all lag values, including recursively generated values. If MAD is zero, use
training SD, then one. The response target and reported forecasts remain on the
original scale.

The primary transform is standardized level lags with no additional clipping.
A single canary compares soft `tanh(z/3)` bounding only if the primary transform
still produces material saturation. This is a diagnostic gate, not a broad
screening factor.

Do not log, Box-Cox, or asinh-transform the target in the first campaign. Such
transformations change quantile interpretation after back-transformation and
would blur whether the reservoir architecture itself solved the problem.
First-difference and period-90 difference channels are explicitly deferred.
They may become a second-stage ablation only if the primary run shows a clear
trend or seasonal-memory failure.

## 5. Search design

### 5.1 Tuned dimensions

The broad Normal-RHS VB search varies:

- depth `D` from 1 through 4;
- the full layer-width vector, using widths from 20 through 300 and flat,
  tapered, expanding, and bottleneck shapes;
- response memory `m_y` from 1 through 150, including 90 and 120 to cover the
  DGP period and longer memory;
- shared leakage alpha over 0.01 through 0.99;
- shared spectral radius rho over 0.20 through 0.99; and
- RHS tau0 over eight orders of magnitude, with both log-space anchors and a
  dimension-aware reference.

At least 40 percent of candidates must have alpha at or above 0.4. This directly
covers the previously sparse high-alpha region without discarding low-alpha
long-memory designs.

### 5.2 Fixed dimensions

The following are not screened: reservoir seed, activation functions,
projection matrices, topology rule, nonzero-weight distribution, preprocessing,
washout rule, source trajectories, or scoring definitions. Holding them fixed
is what lets the screen attribute changes to `D`, `n`, `m`, alpha, rho, and
tau0.

### 5.3 Efficient candidate generation

Do not enumerate a Cartesian product. Generate 512 reproducible maximin,
space-filling candidates per family with discrete stratification over depth,
shape, memory, and readout dimension. Allocate approximately 70 percent to
readout dimensions at most 500, 20 percent to 501-800, and 10 percent to
801-1201. This includes the requested large D=3/4 and width-200/300 models while
preventing them from consuming the entire budget.

Candidate signatures must be checked against the historical signature ledger.
Exact repeats are allowed only as labeled controls. The new architecture and
input contracts mean old scores are context, not candidate authority.

### 5.4 Tau0

Tau0 must not be held at one universal value as readout dimension changes. Each
candidate receives a logged absolute tau0 and a dimension-aware reference based
on training size, readout dimension, robust residual scale, and a declared
expected number of nonzero coefficients. Candidate generation samples log10
tau0 from -8 through -1 with explicit anchors at powers of ten.

This broad range tests both aggressive pruning and permissive readouts. It does
not presume that smaller tau0 must improve forecast intervals: excess spread
can arise from dynamic-state uncertainty or misspecified memory, not only from
readout overfitting.

## 6. Selection without held-out leakage

The final 9001-10000 block stays sealed. Stage A fits each Normal-RHS VB
candidate on 8501-8800 and evaluates teacher-forced 30-step forecasts over
8801-9000 with origin stride 5. The short fixed inference budget is identical
across candidates.

Select 50 candidates separately for each family using:

1. forecast oracle-quantile MAE as the primary criterion;
2. forecast check loss and fit oracle-quantile RMSE as secondary criteria;
3. a Pareto front followed by diversity across depth, width, memory, alpha,
   rho, tau0, and complexity; and
4. numerical validity as a hard requirement.

There is no global winner across families or quantiles. Diagnostic grades are
reported but do not exclude a finite metric improvement. Nonfinite output,
broken dimensions, leakage, or contract violations do exclude a candidate.

Stage B refits all 50 family-specific candidates with the full Normal-RHS VB
budget. Keeping all 50, rather than only one Normal winner, protects tail
quantiles from a mean-optimal structural bottleneck.

## 7. Nested quantile inference

For each family and retained structure:

1. initialize the median AL-RHS VB fit from the Normal-RHS VB posterior;
2. initialize p=0.25 from the median;
3. initialize p=0.05 from p=0.25; and
4. independently restart the final few candidates from the Normal fit to audit
   warm-start path dependence.

Each quantile still optimizes its own objective. A warm start is not permission
to copy a posterior from another quantile. Winners remain family- and
quantile-specific.

MCMC is not used in the broad structural screen. Only a small per-cell VB
shortlist is promoted to full MCMC, with three independent chains and the same
frozen reservoir feature basis. This is the expensive confirmation stage, not
another hidden search.

## 8. Forecast estimators

For Q-DESN, generate paired forecasts under:

- posterior-predictive path recursion, where each posterior path carries its
  own recursively generated input and reservoir state; and
- posterior-predictive mean-readout-state recursion, where the complete
  post-transform readout vector is averaged before coefficient draws are
  applied.

The estimators use the same posterior draws and paired predictive innovations.
DQLM has no reservoir-state estimator factor and receives its standard recursive
forecast only.

For final evaluation, refit on 8501-9000 and forecast from origins 9000 through
9970. At every new origin, observed values through that origin update lag and
state history. Within each 30-step path, only recursive simulated or summarized
values are available.

## 9. Metrics and intervals

Report fit oracle-quantile RMSE, fit oracle-quantile MAE, fit check loss,
forecast oracle-quantile MAE, forecast oracle-quantile RMSE, and forecast check
loss. Preserve draw-, origin-, and lead-level rows before aggregation.

For each metric, report the posterior mean and equal-tailed 95 percent posterior
interval of draw-specific metric values. These are posterior intervals for the
metric induced by posterior quantile paths; they are not repeated-simulation
confidence intervals.

The primary aggregate weights every origin-lead pair equally. Also report
lead-specific profiles, origin-specific profiles, and a lead-balanced
sensitivity summary. This prevents one scalar from hiding heterogeneous
long-horizon behavior.

## 10. Implementation phases

### Phase 0: protocol and branch freeze

- freeze this YAML, plan, source commit, and package version;
- retain `launch_enabled: false`;
- verify the superseded campaign has no active worker;
- record no article promotion from the superseded campaign.

### Phase 1: reservoir contract

- add named bounded-uniform weight generation;
- add exact fixed-in-degree recurrent topology;
- add dense row-normalized input/inter-layer maps;
- enforce `n_tilde = n[-D]` and exact identity Q;
- export matrix hashes, realized degree, spectral radius, leaky radius, zero-row
  count, saturation, state variance, and effective rank.

### Phase 2: input builder

- implement training-prefix-only robust response-lag scaling;
- apply frozen scaling identically during fit and recursion;
- support exogenous lag blocks only when the source supplies eligible columns;
- forbid direct lag columns in the readout;
- test transformations for zero scales, extreme tails, and origin leakage.

### Phase 3: design generator

- generate the 512-per-family space-filling design deterministically;
- reject malformed vectors and duplicate signatures;
- compute readout dimension and tau0 metadata before fitting;
- freeze candidate, data, seed, and source manifests with SHA-256 hashes.

### Phase 4: Normal-RHS VB screen

- run deterministic canaries first;
- run one single-thread worker per model under the declared worker cap;
- write atomic status, compact metrics, and no unnecessary fitted binaries;
- select the family-specific diverse top 50 from the inner window only.

### Phase 5: full VB and nested quantiles

- refit top 50 per family at full budget;
- run median, 0.25, and 0.05 nested warm starts;
- perform independent restart audits for finalists;
- choose separate winners by family and quantile.

### Phase 6: MCMC confirmation

- promote only the compact VB shortlist;
- run three independent chains per candidate on the identical feature basis;
- retain posterior draws needed for fit and forecast metric intervals;
- separate diagnostic findings from score rankings.

### Phase 7: full rolling forecast

- refit winners on all 500 fit observations;
- run 971 teacher-forced origins and 30 recursive leads;
- pair path and mean-readout-state estimators;
- export granular and aggregate metric evidence.

### Phase 8: closeout and integration handoff

- verify all hashes, counts, source windows, seeds, and finite outputs;
- compact nonfinal fitted objects only after metric and replay evidence is
  independently verified;
- build tables and diagnostic figures in the validation branch;
- hand off to the integration coordinator without changing shared validation,
  Article-v2, or Overleaf.

## 11. What to avoid

- Do not resume or complete the superseded campaign.
- Do not use final-window scores to select a structure or tau0.
- Do not choose a favorable reservoir seed during screening.
- Do not use one global specification across families or quantiles.
- Do not let fixed connection probability confound width with degree.
- Do not insert response or exogenous lags directly into the readout.
- Do not use random Q matrices when no reduction is intended.
- Do not transform the response target without a separately justified study.
- Do not treat rho below one as a complete stability proof.
- Do not run a full factorial grid.
- Do not mix old stride-30 rows with the new stride-1 protocol in one table.
- Do not promote a partial surface to the article.

## 12. Current readiness

The scientific contract and reusable forecast code are ready for implementation
review. The production materializer, sparse-topology implementation, robust
input builder, candidate generator, scheduler, and closeout pipeline do not yet
exist. No new computation should be launched until those components and their
focused tests are complete and the launch flag is deliberately changed in a
separate reviewed commit.
