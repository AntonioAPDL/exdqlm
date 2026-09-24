# Independent Q-DESN mean-readout-state forecast v3 implementation blueprint

Status: audited and ready for implementation, but implementation and scientific
execution are not authorized by this document. No fit, forecast replay, smoke,
or production job has been launched.

This blueprint supersedes
`INDEPENDENT_QDESN_MEAN_READOUT_STATE_FORECAST_V2_PLAN_2026-09-24.md`.
It retains the scientific objective of v2 and corrects its unconditional MCMC
chain-pooling rule. Posterior states and coefficients may be pooled before the
mean-state calculation only when the chains use the same frozen feature basis.

## 1. Executive decision

The next scientific experiment should be a paired forecast-estimator replay of
the current authoritative Q-DESN VB and MCMC fits. It should not be another
DESN screen, a `tau0` screen, or a model refit with changed priors.

The proposed estimator implements the advisors' request:

1. recursively generate a posterior-predictive ensemble of future inputs;
2. propagate those inputs into candidate reservoir/readout states;
3. replace the draw-specific states by one mean state and one mean complete
   readout feature at each forecast origin and lead;
4. apply every posterior readout-coefficient draw to that common feature;
5. use the resulting conditional-quantile draws to calculate point forecasts
   and posterior score intervals;
6. use simulated response draws only to construct the next lead's inputs.

This directly isolates the uncertainty channel under investigation. The
existing native recursion allows every posterior draw to carry its own noisy
response history and nonlinear reservoir trajectory. The new replay integrates
that input/state uncertainty before applying the readout-coefficient draws.

The experiment must cover the complete authoritative Q-DESN surface for both
VB and MCMC. DQLM and exDQLM have no reservoir recursion and are unchanged.
The estimator must be accepted or rejected as one global forecast contract; it
must not be selected separately by family, quantile, likelihood, or metric.

## 2. Explicit non-goals

This campaign will not:

- select a new DESN specification;
- change `tau0`, priors, likelihood, feature scaling, or reservoir seeds;
- change the DGP, training window, forecast window, origins, or leads;
- refit DQLM or exDQLM;
- use the existing conditional-mean plug-in diagnostic as a substitute for the
  requested estimator;
- average states or coefficients across incompatible random-feature bases;
- choose the recursion method by whichever gives the narrowest interval or
  smallest score in an individual cell;
- edit Article-v2, merge shared validation, or publish to Overleaf from this
  scientific lane;
- delete historical evidence or full fit objects before a verified compact
  capsule exists.

## 3. Audit snapshot

The audit was performed on 2026-09-24 from the dedicated planning worktree:

```text
/data/jaguir26/local/src/exdqlm__wt__independent_fixed_state_forecast_plan_20260924
```

| Surface | Audited state |
|---|---|
| Planning branch | `validation/independent-fixed-state-forecast-plan-20260924` |
| Planning base before v3 | `1647aedcba8137717406c8c30595ba273715985c` |
| Package main | `e51045a4324901cced27ca2aaa22569afbc8e0e6` |
| Shared-validation authority | `5b85bb3a3894a88968e4987f330e3ec66711f9c7` |
| Article-v14 authority inspected read-only | Article-v2 `origin/main` at `757522db0f85815244370ec92a194de132268883` |
| Package version in planning tree | `1.1.2` |
| Active jobs owned by this lane | none |
| Execution host | `muscat.be.ucsc.edu` |
| Hardware observed | 64 logical cores, 479 GiB available RAM, 311 GiB free on `/data` |
| Reserved campaign capacity | 8 concurrent one-core workers |

The Article-v2 working checkout was on an unrelated dirty GloFAS branch during
the audit. It was not modified. Article evidence was read directly from
`origin/main` with Git object reads.

### 3.1 Evidence inspected

The plan is grounded in these current files and retained artifacts:

- native recursion and lattice dispatch: `R/qdesn_vb.R`;
- score-draw calculation:
  `R/qdesn_validation_metric_intervals.R`;
- point-path construction: `R/qdesn_mcmc_validation.R`;
- source replay registry:
  `config/validation/independent_metric_intervals_v1_audit/source_replay_registry.csv`;
- origin-horizon diagnosis:
  `validation/fitforecast_v2/audits/independent_origin_horizon_attribution_v1_20260826/scientific_closeout.md`;
- earlier recursion diagnosis:
  `/data/jaguir26/local/src/exdqlm__wt__independent_interval_dispersion_diagnostic_v1_1p0p0/reports/shared_fitforecast_v2_orchestration/independent_interval_dispersion_diagnostic_v1_20260825_195658/closeout/scientific_closeout.md`;
- special repeated-chain requests:
  `validation/fitforecast_v2/audits/independent_location_orthogonalized_tau0_v2_20260827/requests/`;
- current article source contract:
  `application/config/independent_validation_exdqlm_mcmc_rolling_state_fix_article_v14.yaml`
  at Article-v2 `origin/main`;
- current interval table:
  `tables/qdesn_validation_500obs_metric_intervals_v14_summary.csv`
  at Article-v2 `origin/main`;
- retained interval-replay jobs:
  `/data/jaguir26/local/src/exdqlm__wt__independent_metric_intervals_v1_1p0p0/results/qdesn_mcmc_validation/qdesn_dqlm_500obs_independent_metric_intervals_v1/independent_metric_intervals_v1_production_20260823_225856/jobs`.

The retained job root contains 126 job directories and no `.rds`, `.rda`, or
`.RData` fitted-model payload. Scalar summaries, requests, paths, and manifests
remain, but posterior beta matrices do not.

### 3.2 Plan lineage and corrections

| Version | Contribution | Limitation or correction |
|---|---|---|
| v1 | Defined the common predictive-state/readout idea | Did not fully specify VB/MCMC score reconstruction |
| v2 | Added both inference methods, separated `yrep` from `qdraw`, froze point and interval estimands, and planned capsules | Assumed all MCMC chains could be pooled before state averaging |
| v3 | Retains the v2 estimands, adds content-addressed basis groups, corrects `idolp` aggregation, narrows initial code support to the exact authority surface, and specifies implementation files and gates | Current authoritative blueprint |

No run was launched from v1 or v2. The v3 correction therefore changes only
the prospective design; it does not invalidate or require cleanup of a partial
mean-state campaign.

### 3.3 Alternatives considered

| Alternative | Decision | Reason |
|---|---|---|
| Reduce `tau0` and refit | Reject for this experiment | Confounds posterior shrinkage with the recursive-state question and repeats prior tuning |
| Increase DESN depth/width/memory | Reject for this experiment | Changes the selected model instead of testing the advisors' forecast estimator |
| Use `conditional_mean_plugin` | Reject as primary method | Removes innovations but preserves draw-specific paths; it is not a mean-state estimator |
| Average final score draws only | Reject | The existing metric already aggregates over origins/leads; it does not remove nonlinear path propagation |
| Average raw hidden states and then transform | Reject as primary contract | Nonlinear readout transformations do not commute with averaging |
| Average complete readout features | Accept | Directly integrates the object multiplied by posterior beta while retaining layer means for recursion |
| Pool all MCMC chains in feature space | Reject | Invalid when reservoirs/transforms define different coordinate systems |
| Pool only basis-compatible chains | Accept | Preserves posterior pooling without mixing incompatible feature coordinates |
| Select native or mean-state recursion per cell | Reject | Creates an unreported forecast-estimator tuning step |
| Refit all four model classes | Reject | DQLM/exDQLM have no reservoir-state uncertainty to summarize |

This alternatives audit makes the proposed replay the smallest experiment that
directly answers the scientific question while preserving the current
case-specific DESN winners.

## 4. What the existing results establish

### 4.1 Existing score bands are not response-predictive bands

For posterior quantile draw `s`, the current code calculates

```text
fit_RMSE[s] = sqrt(mean_t((qfit[s,t] - q_true[t])^2))

forecast_MAE[s] = mean_g(abs(qforecast[s,g] - q_true[g]))

forecast_check[s] = mean_g(
  (y[g] - qforecast[s,g]) *
  (tau - I(y[g] - qforecast[s,g] < 0))
)
```

The displayed 95% interval is the equal-tailed interval of these draw-level
scores. `qforecast` is a posterior conditional-quantile draw. A simulated
response draw is not scored; it is used only to propagate recursive inputs.

The current point path is the posterior median quantile at each scored target.
The point score and the mean draw-level score are distinct estimands:

```text
score(pointwise posterior-median quantile path)
mean_s(score(posterior quantile draw s))
```

Both must continue to be reported with unambiguous labels.

### 4.2 Forecast grid

The fixed protocol has:

- training source indices 8501--9000;
- held-out source indices 9001--10000;
- 34 origins, from 9000 to 9990 in increments of 30;
- maximum lead 30;
- 1,000 unique scored targets.

There are 1,020 potential origin-lead slots, but the final origin has only ten
targets inside the held-out block. The official score therefore uses exactly
1,000 origin-lead-target rows.

### 4.3 Previous diagnosis does not answer the advisor question

Seven sentinel cells were covariance-dominant across forecast origins. The
estimated origin-covariance fraction ranged from 0.931 to 0.961. Lead profiles
did not show systematic late-horizon explosion, and a prior conditional-mean
plug-in diagnostic gave mixed width changes.

That plug-in diagnostic only set predictive innovations to zero while retaining
draw-specific coefficients, response histories, and reservoir paths. It did
not average the predictive reservoir/readout state before applying posterior
coefficients. It therefore cannot validate or reject the estimator proposed
here.

These findings also explain why reducing `tau0` is not the first causal test.
`tau0` changes the fitted coefficient posterior and potentially the center of
the forecast. The requested experiment changes how predictive input/state
uncertainty enters the forecast while holding the fitted posterior fixed.

## 5. Exact estimator contract

Use `o` for a forecast origin, `h` for lead, `r` for a recursive predictive
particle, `s` for a posterior coefficient draw, and `d` for reservoir layer.

### 5.1 Initialization

At every origin, reconstruct the fitted state from data available through that
origin only. Let `Hbar[d,o,0]` be the observed-origin state for layer `d`.
Each predictive particle starts with the same observed response history and
origin state. No future observation or oracle quantile may enter the recursion.

### 5.2 Candidate state propagation

At lead `h`, build the input of particle `r` from its simulated response
history:

```text
u[r,o,h] = input(y_observed_through_o, yrep[r,o,1:(h-1)]).
```

Starting from the common previous state, calculate candidate deep states:

```text
Hcand[d,r,o,h] = F_d(
  Hbar[d,o,h-1],
  u[r,o,h],
  Hcand[d-1,r,o,h]
).
```

Within a lead, a particle's lower layer feeds that particle's next layer. The
common mean from lead `h-1`, not a draw-specific prior state, supplies the
recurrent state.

Carry the layer-wise means to the next lead:

```text
Hbar[d,o,h] = mean_r(Hcand[d,r,o,h]).
```

### 5.3 Mean complete readout feature

For every candidate particle, build the exact complete feature vector used by
the fitted beta coefficient. This includes, in fitted column order:

- top-layer state;
- activated/projected lower-layer states;
- intercept;
- direct response/input lags;
- exogenous inputs, when present;
- reservoir-lag blocks, when present;
- the fitted linear readout transform;
- fitted feature scaling.

Then average the post-transform feature:

```text
xbar[o,h] = mean_r(x[r,o,h]).
```

This is the readout-level mean requested by the advisors. It is not generally
valid to average raw hidden states and then apply a nonlinear readout mapping,
because `k(mean(H))` need not equal `mean(k(H))`. Layer means are retained for
the recurrent transition; the complete feature mean is used for beta.

### 5.4 Quantile and response draws

Apply every posterior beta draw from the same compatible basis group:

```text
qdraw[s,o,h] = xbar[o,h]' beta[s].
```

Generate a response draw using the fitted likelihood and the corresponding
posterior scale/shape draw:

```text
yrep[s,o,h] = draw_working_likelihood(
  qdraw[s,o,h], sigma[s], gamma[s], innovation[s,o,h]
).
```

`yrep` updates the particle-specific response histories at lead `h+1`.
`qdraw` is the only object used for forecast MAE, RMSE, and check-loss draws.

The state-particle index and posterior-draw index use the same chain-balanced
posterior ensemble in the primary implementation. The common `xbar` removes
one-to-one draw-specific state/readout paths before beta is applied. Innovation
arrays and posterior-row ordering are frozen in the run manifest.

## 6. Critical correction: feature-basis compatibility

Version 2 proposed pooling every MCMC chain before calculating the state mean.
That is valid only when the chain coefficients and states are expressed in the
same feature basis.

A `feature_basis_hash` must cover at least:

- reservoir matrices (`Win`, recurrent matrices, projections, and stored `Q`);
- reservoir seed and all deterministic construction settings;
- depth, layer widths, input lag order, activations, `alpha`, and `rho`;
- readout block definitions and fitted column order;
- fitted linear transform, including loadings and retained rank;
- fitted feature-center and feature-scale vectors;
- decomposition and reservoir-lag contracts;
- source data and training-window identity required to reconstruct origin
  states.

Object hashes, not seed equality alone, are authoritative. A matching seed is
only a preliminary check.

### 6.1 Compatible-chain rule

If all chains for a source have the same `feature_basis_hash`:

1. retain equal posterior-draw counts from every chain;
2. concatenate the chain-balanced draws;
3. calculate one common state/readout feature from that pooled ensemble;
4. preserve `chain_id` and `within_chain_draw_id` in score outputs;
5. report pooled bands plus chain-specific sensitivity summaries.

The 25 current IMI MCMC source identities are expected to satisfy this rule,
but the materializer must recompute and verify their hashes before pooling.

### 6.2 Incompatible-chain rule

The special source `idolp_v2_winner_three_chain_pool` uses three separately
generated orthogonalized reservoir bases. Its retained interval requests use:

| Chain | Reservoir seed ID | Reservoir seed |
|---:|---|---:|
| 1 | `confirmation_r01` | 144669038 |
| 2 | `confirmation_r02` | 23171880 |
| 3 | `confirmation_r03` | 99995492 |

Coefficient vectors and hidden states from these bases cannot be averaged in
feature space. For this source:

1. calculate one mean-state forecast separately within each basis/chain;
2. calculate draw-level metric distributions within each basis;
3. pool draw-level metrics with equal chain weights only after scoring;
4. preserve the current article point contract by taking the arithmetic mean
   of chain-specific median-path scores;
5. report between-basis sensitivity explicitly.

The implementation must stop, rather than coerce, if one requested pooling
group contains more than one basis hash.

## 7. Frozen scientific surface

The current article-v14 interval authority has 72 model rows and 216 metric
roles. The Q-DESN subset has:

- 18 VB rows: 2 likelihoods x 3 families x 3 quantiles;
- 18 MCMC rows on the same cell surface;
- 18 distinct VB forecast source identities;
- 26 distinct MCMC forecast source identities because forecast MAE and check
  loss can use different case-specific winners;
- 44 distinct Q-DESN forecast source identities in total.

The MCMC role map is frozen as follows:

| Family | Tau | AL MAE | AL check | exAL MAE | exAL check |
|---|---:|---|---|---|---|
| normal | 0.05 | `idolp_v2_winner_three_chain_pool` | same | `imi_v1_source_075` | same |
| normal | 0.25 | `imi_v1_source_044` | `imi_v1_source_085` | `imi_v1_source_076` | `imi_v1_source_086` |
| normal | 0.50 | `imi_v1_source_074` | same | `imi_v1_source_077` | same |
| laplace | 0.05 | `imi_v1_source_055` | same | `imi_v1_source_079` | `imi_v1_source_088` |
| laplace | 0.25 | `imi_v1_source_056` | `imi_v1_source_087` | `imi_v1_source_059` | `imi_v1_source_089` |
| laplace | 0.50 | `imi_v1_source_078` | `imi_v1_source_057` | `imi_v1_source_080` | `imi_v1_source_060` |
| gausmix | 0.05 | `imi_v1_source_067` | `imi_v1_source_090` | `imi_v1_source_082` | same |
| gausmix | 0.25 | `imi_v1_source_068` | same | `imi_v1_source_083` | same |
| gausmix | 0.50 | `imi_v1_source_081` | same | `imi_v1_source_084` | same |

The VB sources are `imi_v1_source_007`--`012`, `019`--`024`, and
`031`--`036`.

### 7.1 Exact computational inventory

No reusable fitted posterior object was found. If the preflight search remains
negative, the minimum frozen reconstruction is:

| Work unit | Count | Explanation |
|---|---:|---|
| VB fit reconstructions | 18 | One per authoritative VB source |
| MCMC fit reconstructions | 78 | 25 IMI sources x 3 chains plus 3 `idolp` chains |
| Total frozen fits | 96 | No DQLM/exDQLM and no new candidate fits |
| VB basis forecast evaluations | 18 | One compatible basis per VB source |
| IMI MCMC basis forecast evaluations | 25 | One pooled compatible basis per IMI source |
| `idolp` basis forecast evaluations | 3 | One per incompatible basis/chain |
| Total basis forecast evaluations | 46 | Wrapped as 44 article source identities |
| Screening candidates | 0 | Winner identities remain fixed |

These counts must be regenerated from the freshly fetched article authority
immediately before materialization. A change in authority is a stop condition,
not a reason to silently append sources.

### 7.2 Verified current feature contract

Across the current Q-DESN sources, the audited design surface includes:

- depth `D` from 1 through 3;
- scalar widths 4, 6, 8, 10, 20, 30, and 40, plus layered widths such as
  20/20 and 18/17/17;
- input memory `m` values 1, 2, 3, 12, 15, and 120;
- scalar and layer-specific `alpha` and `rho` settings;
- `input_mode = raw_y_lags`;
- `include_input = TRUE`;
- `reservoir_lags = 0`;
- no decomposition;
- fitted response/input scaling;
- no fitted linear readout transform for the IMI sources;
- `orthogonalize_reservoir` for the special `idolp` source.

The first implementation should support this exact authority contract. It
should hard-stop on decomposition or positive reservoir lags until those modes
receive separate tests. Existing native modes continue to support their wider
contract unchanged.

## 8. Implementation architecture

### 8.1 Preserve the native engine

Do not refactor the existing large native forecast engine before proving the
new estimator. Keep `forecast_paths.qdesn_fit()` and both existing lattice
recursion modes behaviorally unchanged.

Add one isolated R implementation, proposed as:

```text
R/qdesn_mean_readout_state_forecast.R
```

Extend only the `forecast_lattice.qdesn_fit()` dispatcher in `R/qdesn_vb.R`
with:

```text
recursion_mode = posterior_predictive_mean_readout_state
```

The new mode must force the R backend. The current C++ backend advances draws
independently and cannot implement a cross-draw state reduction without a new
interface. C++ optimization is deferred until the R estimator is verified.

### 8.2 Proposed package helpers

Keep the new logic in small internal functions:

```text
.qdesn_mean_state_basis_hash()
.qdesn_mean_state_validate_contract()
.qdesn_mean_state_prepare_origin()
.qdesn_mean_state_candidate_chunk()
.qdesn_mean_state_readout_chunk()
.qdesn_forecast_paths_mean_readout_state()
```

The validator should produce a structured incompatibility report before any
forecast work. It must verify beta/readout dimensions, feature names and order,
transform/scaling hashes, origin states, chain balance, and finite posterior
parameters.

### 8.3 Streaming algorithm

At every origin and lead:

1. process predictive particles in a fixed, recorded chunk order;
2. compute all layer candidates for one chunk;
3. accumulate layer sums and complete readout-feature sums;
4. discard chunk candidate states after accumulation;
5. form `Hbar` and `xbar` over the complete ensemble;
6. multiply `xbar` by all beta draws in vectorized form;
7. generate responses from pre-generated innovations;
8. retain only response-lag buffers, quantile draws, requested response draws,
   common states, compact dispersion summaries, and provenance.

Do not allocate a full draw x layer x state x origin x lead array. Fixed draw
ordering, chunk size, and summation order belong in the manifest. Numerical
replay comparisons use a predeclared absolute and relative tolerance of
`1e-6`; the tolerance must not be widened after results are observed.

### 8.4 Output contract

The new mode should return or export:

- `qdraw_by_origin` with source draw and chain identifiers;
- `yrep_by_origin` only when needed for verification or the next recursion;
- common layer states by origin and lead;
- common complete readout features by origin and lead;
- candidate-state and candidate-readout dispersion summaries;
- `feature_basis_hash` and pooling group;
- posterior draw IDs and innovation IDs;
- recursion, estimator, package, and source metadata.

Use these stable identifiers:

```text
recursion_mode = posterior_predictive_mean_readout_state
metric_estimator = mean_readout_state_quantile_draw_metric_equal_tailed_95cri_v1
```

## 9. Forecast capsule design

Reconstruct each frozen fit at most once and immediately export two compact,
versioned capsules.

### 9.1 Basis capsule

The basis capsule contains:

- all reservoir matrices and layer metadata;
- `alpha`, `rho`, activations, depth, widths, and lags;
- exact readout specification and feature names;
- fitted readout transform and scaling objects;
- fitted states needed at all 34 origins;
- observed history and exogenous inputs needed by the forecast;
- data, DGP, window, and `feature_basis_hash` values.

### 9.2 Posterior capsule

The posterior capsule contains:

- beta draws in fitted feature order;
- sigma and gamma draws;
- chain ID, within-chain draw ID, and source draw index;
- VB or MCMC method metadata;
- retained-draw selection and hashes;
- fit environment and RNG provenance.

### 9.3 Environment manifest

Every reconstruction records:

- source request and config hashes;
- package version, commit or source tarball hash;
- R version and `sessionInfo()`;
- compiler, BLAS/LAPACK, OpenMP, and thread variables;
- data/DGP, reservoir, fit, MCMC, and forecast seeds;
- reconstruction command and exit status.

The frozen source environment, not the planning branch package version, governs
fit reconstruction. If an old object needs a converter, run that converter in
the historical environment and export the neutral capsule. Silent schema
coercion is forbidden.

Full fitted-model binaries may be deleted only after capsule hashes, native
replay, and downstream score reconstruction all pass.

## 10. File-by-file implementation map

| File or path | Planned change | Guard |
|---|---|---|
| `R/qdesn_mean_readout_state_forecast.R` | New isolated estimator and basis validation | No native behavior changes |
| `R/qdesn_vb.R` | Add one lattice dispatch value and documentation | Existing two modes must replay exactly |
| `tests/testthat/test-qdesn-mean-readout-state-forecast.R` | Unit, invariance, depth, transform, and leakage tests | No fixture may depend on article output |
| `validation/fitforecast_v2/R/independent_mean_readout_state_forecast_v1.R` | Authority ledger, capsules, scoring, diagnostics, and closeout helpers | Independent lane only |
| `validation/fitforecast_v2/scripts/materialize_independent_mean_readout_state_forecast_v1.R` | Freeze article source-role ledger and job plans | Read Article-v2; never write it |
| `validation/fitforecast_v2/scripts/run_independent_mean_readout_state_fit_job.R` | Exact fit reconstruction and capsule export | One core, source environment pinned |
| `validation/fitforecast_v2/scripts/run_independent_mean_readout_state_forecast_job.R` | Paired native/new forecast replay by compatible basis | Atomic outputs and resumable markers |
| `validation/fitforecast_v2/scripts/orchestrate_independent_mean_readout_state_forecast_v1.R` | Dependency-aware load-balanced scheduler | Fixed maximum of eight one-core workers |
| `validation/fitforecast_v2/scripts/launch_independent_mean_readout_state_forecast_v1.sh` | Muscat preflight, one-thread environment, and background `tmux` launch | Exactly eight workers; no duplicate controller |
| `validation/fitforecast_v2/scripts/healthcheck_independent_mean_readout_state_forecast_v1.R` | Read-only progress and integrity report | Never mutates run state |
| `validation/fitforecast_v2/scripts/closeout_independent_mean_readout_state_forecast_v1.R` | Full-surface comparison and decision packet | Partial surfaces cannot close |
| `validation/fitforecast_v2/scripts/verify_independent_mean_readout_state_forecast_v1.R` | Hash/schema/count/replay verifier | Nonzero exit on any mismatch |
| `validation/fitforecast_v2/tests/testthat/test-independent-mean-readout-state-forecast-v1.R` | Campaign regression tests | Uses compact fixtures |
| `config/validation/independent_mean_readout_state_forecast_v1/` | Frozen defaults, source ledger, basis groups, plans, and hashes | Generated deterministically |
| ignored `reports/` and `results/` roots | Runtime logs, capsules, scores, and diagnostics | No fitted binary accumulation |
| ignored local tracker | Review PDF and operator notes | Never treated as article authority |

Article assets are not edited in this branch. A successful closeout produces a
candidate promotion packet for the integration coordinator.

## 11. Staged execution plan

### Stage A: freeze authority

1. fetch package, shared-validation, and Article-v2 remotes read-only;
2. verify the expected authority commits or stop for review;
3. derive the 44-source role ledger from the article-v14 table;
4. resolve every request, config, seed, and environment path;
5. calculate source, config, data, and basis hashes;
6. materialize the 96 fit jobs and 46 basis forecast evaluations;
7. prove there are no duplicate jobs or unresolved roles.

### Stage B: implement and unit-test

1. add the isolated R estimator;
2. add lattice dispatch without changing native behavior;
3. add basis-group validation and hard failures;
4. add capsule schemas and deterministic RNG interfaces;
5. pass all package and validation tests in Section 12.

### Stage C: representative smoke

Use already reconstructed capsules with reduced forecast draw counts, not
shorter scientific fits. Cover at least:

- one VB AL source;
- one VB exAL source with a wide current band;
- one compatible-basis MCMC AL source;
- one compatible-basis deep or long-memory MCMC exAL source;
- the transformed, incompatible-basis `idolp` source.

The smoke determines peak memory, stable chunk size, output schema, basis
guard behavior, and approximate runtime. It does not make scientific claims.

### Stage D: native replay gate

For every reconstructed smoke capsule, rerun the native estimator with the
frozen draw selection and innovations. Verify within `1e-6`:

- point forecast MAE and check loss;
- posterior score means, medians, and interval endpoints;
- origin/lead indexing and output scale;
- chain and source identities.

A failure is diagnosed as provenance, package, RNG, draw-selection, or scale
drift. Do not proceed to the full campaign and do not loosen the tolerance.

### Stage E: frozen fit reconstruction

Run the 18 VB and 78 MCMC reconstructions through the eight-slot Muscat queue.
Export capsules atomically. Each fit receives one process and one thread. As
soon as a compatible basis group has every required capsule, its forecast job
becomes eligible for the same queue. Do not refit a source whose verified
capsule already exists.

### Stage F: full paired forecast replay

Run all 46 compatible-basis evaluations through the same eight-slot queue.
Native and new forecasts use the same posterior capsule and pre-generated
innovations. For compatible MCMC chains, pool chain-balanced draws before
calculating the common state. For `idolp`, run three basis-specific forecasts
and aggregate only after scoring.

### Stage G: score and diagnose

For every source, calculate:

- point-path forecast MAE and check loss;
- draw-level forecast MAE, RMSE, and check loss;
- posterior mean, median, SD, and 2.5%/97.5% limits;
- interval width and center shift relative to native recursion;
- lead profiles, origin profiles, and origin-by-lead heatmaps;
- common-state, candidate-state, and readout dispersion by lead;
- chain/basis sensitivity;
- VB/MCMC agreement and DGP-oracle distance.

Fit-window metrics are unchanged by the forecast estimator. Recompute them only
as a reconstruction check, then carry the existing authority forward with its
original provenance.

### Stage H: freeze the scientific decision

The closeout must classify the full campaign as one of:

```text
ACCEPT_MEAN_READOUT_STATE_FOR_FULL_QDESN_SURFACE
RETAIN_NATIVE_QDESN_FORECAST_RECURSION
BLOCKED_PROVENANCE_OR_IMPLEMENTATION_FAILURE
```

Only the first decision creates article replacement candidates. Either valid
scientific outcome is reportable; surprising or still-wide intervals are not
discarded merely because they are inconvenient.

## 12. Verification gates

### 12.1 Unit and invariance tests

The implementation cannot launch production until all of these pass:

- one posterior draw gives native/new equality;
- lead one gives native/new equality under identical inputs and innovations;
- identical particle histories give native/new equality;
- posterior-draw permutation leaves the common state and feature unchanged;
- fixed draw ordering and seed reproduce within `1e-6`;
- averaging is performed on the complete post-transform feature;
- intercept and direct response/input lag columns preserve fitted order;
- scaling and orthogonalizing transforms reproduce direct matrix calculations;
- depths 1, 2, and 3 work with scalar and layer-specific parameters;
- unsupported decomposition and reservoir-lag modes stop clearly;
- no future response or oracle quantity enters recursion;
- basis hashing is stable under serialization and rejects incompatible bases;
- equal-chain weighting is invariant to input file ordering;
- all existing native forecast tests remain unchanged and pass.

### 12.2 Monte Carlo integration checks

The mean state is itself a Monte Carlo estimate. Quantify its stability with
predeclared odd/even and replicate-innovation splits. Report the maximum common
state, readout-feature, point-score, and interval-endpoint discrepancy. These
checks diagnose integration error; they must not be used to tune an article
cell selectively.

### 12.3 Campaign integrity checks

- 44/44 source identities resolved;
- 96/96 required fits or verified capsules available;
- 46/46 basis forecast evaluations successful;
- 18/18 VB and 18/18 MCMC article cells complete;
- every metric finite;
- no basis-crossing pool;
- 1,000 unique scored targets per replay;
- all manifests and content hashes pass;
- no unexplained source, scale, draw-count, or estimator mixture;
- zero untracked fitted-model binaries in the retained publication bundle.

## 13. Scientific and article decision rules

The primary question is whether the advisor estimator is a coherent and useful
way to summarize recursive input/state uncertainty before applying posterior
readout uncertainty. It is not a competition to manufacture narrow bands.

Acceptance requires:

1. exact implementation and provenance gates pass;
2. the complete VB and MCMC Q-DESN surface is available;
3. score centers, intervals, and point paths are finite;
4. any material center, bias, or check-loss changes are explained;
5. integration Monte Carlo error is small relative to the reported bands;
6. results are stable to chain/basis decomposition;
7. the estimator is adopted consistently for every Q-DESN forecast row.

Narrower bands are supporting evidence, not a sufficient condition. A method
that narrows bands by producing materially worse centers or a poorly calibrated
quantile path is not automatically preferable. Conversely, a correctly
implemented method is not rejected solely because some intervals remain wide.

If accepted, the promotion packet contains:

- regenerated Q-DESN VB and MCMC point forecast values;
- regenerated Q-DESN score means and 95% intervals;
- updated compact tables and interval figures with DGP references;
- estimator-specific methods and supplement prose;
- native-versus-new diagnostics kept as supporting evidence;
- unchanged DQLM/exDQLM rows and unchanged fit metrics with hashes.

The integration coordinator independently reviews, compiles, merges, and
publishes. This lane never edits or pushes Article-v2 main or Overleaf.

## 14. Muscat launch and scheduler policy

The production campaign is pinned to `muscat.be.ucsc.edu`. It uses a local
background controller in a named `tmux` session, following the repository's
existing load-balanced orchestration pattern. It does not use Slurm, PBS, or a
remote scheduler.

The fixed campaign limit is eight concurrent workers. "All in parallel" means
that every scientifically independent ready job is eligible for immediate
parallel execution, while no more than eight one-core workers run at once.
Stages with scientific dependencies remain ordered: a forecast cannot start
until all capsules required by its basis group verify, and closeout cannot
start until the full forecast surface is terminal.

Every fit or forecast worker uses one process with:

```text
OMP_NUM_THREADS=1
OPENBLAS_NUM_THREADS=1
MKL_NUM_THREADS=1
VECLIB_MAXIMUM_THREADS=1
```

The committed runtime defaults must include:

```text
execution_host: muscat.be.ucsc.edu
scheduler: load_balanced
campaign_workers: 8
max_active_workers: 8
threads_per_worker: 1
```

Eight is a hard ceiling, not an adaptive target above eight. The smoke still
measures peak resident memory. If eight observed workers would violate a 25%
RAM safety headroom, the launch must stop for review rather than silently
reducing or increasing the declared campaign capacity.

### 14.1 Dependency-aware eight-worker queue

The controller maintains one queue containing:

1. capsule reconstruction jobs whose source evidence is fully resolved;
2. VB forecast jobs whose single capsule verifies;
3. compatible-basis MCMC forecast jobs whose three chain capsules verify;
4. basis-specific `idolp` forecasts whose corresponding chain capsule verifies;
5. deterministic score and verification jobs after their forecast dependency
   completes.

The controller continuously backfills idle slots from ready work. At most eight
fit or forecast workers may be alive in aggregate; it must not run eight fits
and eight forecasts simultaneously. Tiny deterministic aggregation steps run
in the controller only when they cannot oversubscribe the eight-core contract.

Within a priority class, use longest-observed-runtime-first scheduling after
the smoke estimates runtimes. This reduces the final long-job tail without
changing scientific order. A job's output never depends on queue order because
all seeds, posterior rows, innovations, and source hashes are frozen.

### 14.2 Muscat preflight

Immediately before launch, the controller must verify:

- `hostname -f` is exactly `muscat.be.ucsc.edu`;
- at least eight logical cores are visible;
- the dedicated branch and expected implementation commit are checked out;
- the worktree is clean and synchronized with its upstream;
- no earlier campaign controller or worker is active;
- all eight worker thread environments resolve to one thread;
- `/data` has sufficient free space for the dry-run estimate plus 25%;
- available memory exceeds eight times smoke peak RSS plus 25% headroom;
- all authority, config, package, and capsule-schema hashes match;
- the materialized plan contains 96 reconstruction jobs and 46 basis forecast
  evaluations before reuse is applied.

Any failed preflight is a hard stop. Existing unrelated Muscat jobs and tmux
sessions must not be stopped or modified.

### 14.3 Background launch contract

The implementation must provide one checked launch wrapper. The wrapper sets
and verifies the one-thread environment, performs the Muscat preflight, records
the launch manifest, and starts the named `tmux` controller. Its eventual
invocation should have this shape:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__independent_fixed_state_forecast_plan_20260924
validation/fitforecast_v2/scripts/launch_independent_mean_readout_state_forecast_v1.sh \
  --workers 8 --scheduler load_balanced --background --resume
```

The wrapper uses the fixed session name
`ind_qdesn_mean_readout_state_v1_8core`. It may add frozen run-tag and manifest
arguments, but it may not change the eight-worker or one-thread-per-worker
contract. The controller PID, tmux session, start time, branch HEAD, command,
environment, and run root must be written to the orchestration manifest before
the first worker starts.

### 14.4 Runtime observability

The scheduler must provide:

- atomic `PLANNED`, `RUNNING`, `SUCCESS`, and `FAILED` markers;
- heartbeat and process identity;
- immutable job request and hash;
- per-job stdout/stderr;
- resume by verified success marker;
- no automatic retry after a deterministic scientific or provenance failure;
- a read-only health reporter with completed, running, failed, and remaining
  counts by stage and inference method.

The health report must also show active worker count out of eight, queued-ready
jobs, dependency-blocked jobs, peak RSS, disk growth, and estimated completion
based on completed jobs of the same class.

No scheduler, tmux session, or scientific job is created by this planning
document.

## 15. Storage, cleanup, and rollback

Retain through scientific closeout:

- frozen ledgers, requests, configs, seeds, and environment manifests;
- verified basis and posterior capsules;
- compact score draws and point paths;
- origin/lead, state, readout, and chain/basis summaries;
- tests, logs, closeout, hashes, and integration handoff.

Do not retain:

- duplicate full fitted objects after capsule and native replay verification;
- full candidate-state arrays;
- duplicate native path matrices already represented by verified compact
  artifacts;
- abandoned smoke payloads after their evidence is summarized and hashed.

Cleanup requires a dry-run inventory and must exclude active jobs,
authoritative/promoted evidence, unresolved ownership, and all other project
lanes. The old native evidence remains immutable, providing the rollback path.

## 16. Risks and mitigations

| Risk | Consequence | Mitigation |
|---|---|---|
| Pooling incompatible bases | Meaningless state and beta averages | Content-addressed basis hash and hard stop |
| Historical environment drift | Forecast change confounded with refit change | Source-specific reconstruction environment and native replay gate |
| Mean computed before nonlinear transform | Wrong estimator | Average complete post-transform readout feature |
| Hidden future-data leakage | Optimistic forecasts | Origin-index tests and no-oracle recursion contract |
| Excess memory | Worker or host failure | Streaming chunks, smoke profiling, fixed eight-worker cap, and hard preflight |
| Monte Carlo noise in common state | Artificial method differences | Frozen innovations and split/replicate integration checks |
| Cell-wise estimator selection | Hidden tuning and biased comparison | One global recursion decision for the complete Q-DESN surface |
| Partial article replacement | Incoherent table | No promotion until all 36 Q-DESN rows are complete |
| Confusing response and quantile draws | Invalid interval interpretation | Separate `yrep` and `qdraw` schemas and labels |
| Cross-chat modification | Corrupted authority | Dedicated branch and coordinator-only integration |

## 17. Readiness checklist

The following are complete now:

- scientific estimand defined;
- current code paths and score formulas audited;
- article source-role surface counted;
- forecast protocol verified;
- retained posterior-object gap confirmed;
- chain/basis incompatibility identified and corrected in the plan;
- implementation files and interfaces specified;
- staged verification and decision gates specified;
- resource, storage, rollback, and integration policies specified;
- no active IND job or launch requiring interruption.

The following remain implementation work and are deliberately not performed:

- package helper and dispatch implementation;
- tests and compact fixtures;
- authority materializer and capsule exporters;
- smoke and native replay;
- 96 frozen reconstructions;
- 46 basis forecast evaluations;
- full score/diagnostic closeout;
- promotion-candidate and coordinator handoff.

## 18. Final recommendation

Implement this v3 blueprint next, beginning with basis hashing, the isolated R
estimator, and unit tests. Launch no expensive reconstruction until the
representative smoke and native replay gates pass. Once those gates pass,
launch the full campaign on Muscat with exactly eight concurrent one-core
workers using the background contract in Section 14.

This is the most direct and efficient test of the advisors' proposal because it
holds every fitted model choice fixed and changes only the recursive forecast
estimator. It also avoids the central error in v2 by respecting random-feature
basis boundaries. If the experiment succeeds, it can replace the complete
Q-DESN VB and MCMC forecast surface coherently. If it does not, the existing
native authority remains intact and the failure will still identify whether
the wide score bands arise from recursive state propagation or from posterior
readout uncertainty that remains after state integration.
