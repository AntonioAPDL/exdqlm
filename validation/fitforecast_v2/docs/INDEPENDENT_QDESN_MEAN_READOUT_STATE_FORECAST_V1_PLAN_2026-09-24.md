# Independent Q-DESN mean-readout-state forecast v1

Status: superseded by
`INDEPENDENT_QDESN_MEAN_READOUT_STATE_FORECAST_V2_PLAN_2026-09-24.md`;
no scientific run was launched from v1.

## 1. Scientific question

The current Q-DESN rolling forecast carries a separate recursively simulated
response history and reservoir trajectory for every posterior draw. At lead
`h`, posterior draw `s` therefore uses

```text
u[s,h]       = input built from that draw's simulated response history
H[s,h]       = reservoir_transition(H[s,h-1], u[s,h])
x[s,h]       = complete readout design built from H[s,h] and lag blocks
q[s,h]       = x[s,h]' beta[s]
yrep[s,h]    = posterior_predictive_draw(q[s,h], sigma[s], gamma[s])
```

This is a coherent full stochastic-recursion estimator, but it propagates
posterior predictive input uncertainty through the nonlinear reservoir before
forming the conditional-quantile draws. The resulting score intervals can
therefore combine uncertainty in the readout coefficients with dispersion from
draw-specific hidden-state paths.

The requested advisor estimator integrates the uncertain recursive inputs at
the reservoir/readout boundary. It retains posterior coefficient uncertainty,
but every coefficient draw is evaluated against one common mean readout state
at each origin and lead. This is a different, explicitly named forecast
estimand. It is not a prior change, a DESN calibration, or a model-selection
screen.

## 2. Repository and authority preflight

This plan is owned only by the independent single-quantile Q-DESN/DQLM
validation lane.

- Shared-validation authority fetched on 2026-09-24:
  `origin/validation/shared-fitforecast-v2-1.0.0` at
  `5b85bb3a3894a88968e4987f330e3ec66711f9c7`.
- Package main fetched on 2026-09-24:
  `origin/main` at `e51045a4324901cced27ca2aaa22569afbc8e0e6`.
- Dedicated worktree:
  `/data/jaguir26/local/src/exdqlm__wt__independent_fixed_state_forecast_plan_20260924`.
- Dedicated branch:
  `validation/independent-fixed-state-forecast-plan-20260924`.
- Reconciliation commit:
  `5a2e1b5ce803ac246daeadb601a2840c5cb6af1a`.

The branch contains the shared validation history and the current package-main
changes. Article-v2, Overleaf, shared validation, JOINT validation, GloFAS, and
PriceFM were not modified. No independent-validation process is active.

The focused package RNG test passed under the reconciled branch. Its one
cross-process/thread case is skipped under the test's existing CRAN guard.

## 3. Audit findings

### 3.1 Current code does not implement the advisor estimator

`R/qdesn_vb.R` currently offers two lattice recursion labels:

- `posterior_predictive`: draw-specific response histories, states, designs,
  and readout paths;
- `conditional_mean_plugin`: the same draw-specific recursion with predictive
  innovations set to zero.

The plug-in mode does not create a common reservoir state. Because posterior
coefficient draws still produce different conditional means, their recursive
histories and states remain draw-specific. It is therefore not a test of the
new proposal and must not be renamed or reused for it.

### 3.2 Prior diagnostics do not invalidate the proposal

The completed interval-dispersion campaign found that setting recursive
innovations to zero did not consistently narrow intervals. Its plug-in/native
forecast-MAE width ratios ranged from 0.975 to 2.204. In contrast, independently
permuting posterior draw identities by forecast origin reduced widths to about
0.207--0.261 of their native values. The origin-horizon audit attributed
0.931--0.961 of variance to cross-origin covariance and found no systematic
late-horizon explosion.

Those results show that zero-noise recursion and smaller `tau0` are not the
answer. They do not test common-state/readout integration. The proposed method
preserves coherent posterior draw identities across origins while removing the
draw-specific nonlinear state path from the readout design. It is therefore a
scientifically distinct and still-open intervention.

### 3.3 Existing compact outputs are insufficient for forecast-only reuse

The current v10/v14 evidence retains fit requests, configs, manifests, scalar
scores, metric draws, path summaries, and update diagnostics. It deliberately
retains no Q-DESN fitted-model binary.

- 126 Q-DESN interval-replay job directories were audited.
- All 126 retain `fit_request.json` and `sigmagam_trace.csv`.
- The 108 MCMC directories retain `theta_trace.csv`, but this file records
  update scheduling and gamma/sigma diagnostics, not beta draws.
- The 18 VB directories do not retain posterior beta draws.
- No audited Q-DESN directory retains a fitted-model binary.

Consequently, existing score CSV files cannot generate the requested forecast.
If no external retained fit object is discovered, the exact frozen fits must be
reconstructed once. This is operational replay, not scientific refitting:
candidate identity, DESN design, prior, likelihood, seeds, budget, and data all
remain fixed, and no selection occurs.

### 3.4 Smallest complete replay surface

The article interval authority contains 18 Q-DESN MCMC model/family/quantile
cells and 18 Q-DESN VB cells. Because the article permits metric-specific
sources, the MCMC forecast-MAE and forecast-check roles reference 26 distinct
Q-DESN source identities: 13 AL-RHS and 13 exAL-RHS. Replaying only one source
per displayed row would silently change that contract.

The minimum article-complete forecast replay is therefore:

- 26 distinct MCMC forecast source specifications, each with its three frozen
  chains: 78 fit reconstructions;
- 18 VB forecast source specifications: 18 deterministic fit reconstructions;
- no DQLM or exDQLM fit reconstruction, because they do not use the Q-DESN
  reservoir recursion;
- no fit-only Q-DESN source reconstruction unless a later article decision also
  changes fit metrics. Fit RMSE is unaffected by this forecast intervention.

The exact count must be regenerated from the current v14 article projection and
its validation provenance immediately before materialization. The numbers above
are preflight counts, not a hard-coded launch assumption.

## 4. Frozen mathematical contract

For origin `o`, let `S` be the retained posterior ensemble and let
`Hbar[d,0]` be the observed origin state in layer `d`. At forecast lead `h`:

1. Build one input `u[s,h]` for each draw from that draw's posterior predictive
   response history.
2. Starting from the common previous state, propagate a candidate multilayer
   state for each draw:

```text
Htilde[s,1,h] = F_1(Hbar[1,h-1], u[s,h])
Htilde[s,d,h] = F_d(Hbar[d,h-1], Htilde_projected[s,d-1,h])
```

3. Collapse each internal layer for the next recursive step:

```text
Hbar[d,h] = mean_s Htilde[s,d,h].
```

4. For every candidate state, construct the exact feature vector that would
   enter the readout. This includes the top-layer state, activated/projected
   lower-layer features, direct input features, reservoir lags, fitted linear
   transforms, and fitted scaling.
5. Average the complete post-transform readout feature vectors:

```text
xbar[o,h] = mean_s x[s,o,h].
```

6. Apply each posterior readout draw to the same design:

```text
q[s,o,h] = xbar[o,h]' beta[s].
```

7. Generate a posterior predictive response using that draw's `sigma`, `gamma`,
   and innovation stream. Append it only to that draw's response history.
8. Update the common reservoir-lag buffer from the collapsed readout-state
   feature, then continue to lead `h + 1`.

The primary implementation name will be
`posterior_predictive_mean_readout_state`. The existing
`posterior_predictive` and `conditional_mean_plugin` modes remain unchanged.

### Why the complete readout feature is averaged

For deep reservoirs, lower-layer states are transformed by an activation before
they enter the readout. In general,

```text
k(mean(H)) != mean(k(H)).
```

Averaging only raw hidden states and then rebuilding the design would therefore
change the intended posterior state summary. Averaging the complete feature
that multiplies `beta` implements the requested summary at the readout level
and handles all existing winner specifications, including input and reservoir
lag blocks.

## 5. Interpretation

The new intervals are not full posterior predictive score intervals. They are
posterior score intervals under mean-readout-state recursion: reservoir/input
path uncertainty is integrated into a common design, while posterior readout
coefficient uncertainty remains explicit. Predictive draws remain necessary to
construct future inputs and their integrated state, but their individual state
paths no longer multiply their paired coefficient draws.

Reader-facing labels must state this directly, for example:

```text
95% posterior score interval under mean-readout-state recursion
```

The old estimator remains a compatibility comparator. Neither interval should
be described as broken merely because it is wide or narrow.

## 6. Implementation plan

### Phase A: authority and artifact freeze

1. Re-fetch package main, shared validation, and Article-v2 main read-only.
2. Freeze the v14 Q-DESN forecast role ledger, including candidate IDs, run
   tags, configs, source commits, package versions, all seeds, chain budgets,
   and hashes.
3. Re-run the retained-artifact search. Use an existing fit object only when its
   identity and hash match the frozen source exactly.
4. Materialize the 26 MCMC and 18 VB source identities from the ledger rather
   than hand-maintaining case lists.

### Phase B: package implementation

1. Add an explicit state/readout aggregation policy to
   `forecast_paths.qdesn_fit()` without changing its default behavior.
2. Add `posterior_predictive_mean_readout_state` to
   `forecast_lattice.qdesn_fit()`.
3. Implement the first version in the R backend. The current C++ backend loops
   independently over draws and cannot perform a horizon-wise ensemble
   reduction without a larger API change. The new mode must explicitly record
   `backend = "r"`; silent fallback is forbidden.
4. Return contract metadata and compact diagnostics: aggregation policy,
   ensemble size, state/readout dispersion by lead, and RNG stream identity.
5. Preserve the current mode byte-for-byte when the new option is not selected.

### Phase C: focused tests

The implementation gate requires all of the following:

- one draw: new and native forecasts are identical;
- lead one: new and native forecasts are identical under paired draws and
  innovations;
- identical draw histories: new and native forecasts are identical;
- permutation of state-ensemble rows leaves the common design unchanged;
- nonlinear multilayer test confirms averaging after the readout transform;
- direct-input and reservoir-lag blocks are included in the common design;
- AL and exact-M0 exAL paths both work;
- decomposition-input and raw-lag modes both work;
- no future observation or oracle path enters recursion;
- fixed seed is repeatable and invariant to chunk size;
- existing native-recursion regression tests remain unchanged.

### Phase D: one-cell scientific smoke

Use one previously wide exAL-RHS cell and one AL-RHS control. Reconstruct each
frozen fit once, then evaluate native and mean-readout-state forecasts from the
same posterior draws and innovation matrices.

The smoke must verify:

- exact source/config/seed identity;
- native replay agreement with retained scores within declared Monte Carlo
  tolerance;
- finite states, designs, conditional quantiles, and scores;
- lead-one identity;
- meaningful but nondegenerate state aggregation;
- no accidental teacher forcing;
- expected runtime and memory before full materialization.

A failed native replay agreement is a provenance problem and stops the full
campaign. It is not fixed by widening tolerances silently.

### Phase E: paired full forecast campaign

For every frozen source/chain job:

1. Reconstruct the fit once under its frozen fit contract.
2. Extract a compact forecast capsule containing only posterior
   `beta/sigma/gamma` draws, reservoir matrices, observed-origin states,
   preprocessing, readout specification, and all identity hashes.
3. From that same capsule and paired random streams, compute both native and
   mean-readout-state forecasts over the unchanged protocol: training indices
   8501--9000, held-out indices 9001--10000, origins every 30, and leads 1--30.
4. Compute point paths and draw-level forecast MAE/check loss under both modes.
5. Keep posterior draw identity coherent across forecast origins. Do not use
   the earlier origin-permutation sensitivity as an interval estimator.
6. Remove the temporary full fit object only after capsule and result hashes
   verify. Retain no unneeded fitted-model binary.

Use one numerical thread per job and a resource-gated worker count. This is a
replay campaign, not a screening campaign; there is no candidate ranking loop.

### Phase F: decision audit

Evaluate each model/family/quantile/metric cell separately. Report:

- posterior mean, median, standard deviation, and equal-tailed 95% interval;
- native versus new interval-width ratio;
- native versus new point forecast MAE and check loss;
- lead- and origin-specific changes;
- state/readout dispersion by lead;
- oracle-path error and realized check-loss calibration;
- between-chain and within-chain summaries for MCMC.

Adoption requires a complete finite surface, passed provenance checks, no
look-ahead, and a coherent interpretation. Width reduction is expected but is
not sufficient by itself. Material score degradation, loss of calibration, or
failure to reproduce the native comparator blocks article replacement and is
reported transparently.

### Phase G: article handoff

No article or Overleaf file is modified in this lane. If the new estimator is
accepted:

1. generate versioned point tables, interval tables, figures, prose, and a
   method note;
2. update Q-DESN forecast columns only; preserve Q-DESN fit RMSE and all
   DQLM/exDQLM values unless separate evidence changes them;
3. never mix native and mean-readout-state forecast intervals without an
   explicit estimator label;
4. provide a clean, hashed integration handoff to the coordinator;
5. let the coordinator merge, compile, and publish Article-v2/Overleaf.

## 7. Reproducibility outputs

The campaign must produce:

- source-role ledger and frozen job plan;
- environment, package, compiler, BLAS/LAPACK, and thread manifest;
- source/config/data/seed hashes;
- per-job status and health records;
- paired native/new draw-level metric files;
- compact state/readout dispersion summaries;
- closeout and decision ledgers;
- artifact hash manifest and storage audit;
- ignored local diagnostic PDF comparing modes by family, quantile, metric,
  origin, and lead;
- final integration handoff with exact changed files and exclusions.

## 8. Risks and controls

| Risk | Control |
|---|---|
| Calling the new bands full predictive uncertainty | Use the frozen estimator label and definition |
| Averaging raw states before nonlinear readout transforms | Average the complete post-transform readout feature |
| Confounding forecast change with model re-selection | Freeze every source identity and prohibit screening |
| Confounding with a package/RNG change | Pair native and new forecasts from the same reconstructed fit/capsule |
| Native replay differs from authority | Stop at the provenance gate and diagnose |
| Missing posterior draws | Reconstruct only frozen Q-DESN forecast sources once |
| Excess disk growth | Retain compact capsules and metrics; prune full fit objects only after hash verification |
| Cross-lane contamination | Work only on the dedicated IND branch; coordinator owns integration |

## 9. Recommended decision

Proceed with this forecast-only redesign. It directly tests the advisor's
proposal and targets the uncertainty mechanism of interest without another
DESN/tau0 screen. Do not refit DQLM/exDQLM, do not reconsider winners, and do
not alter fit metrics. Start with implementation tests and a paired two-cell
smoke. Launch the complete frozen-source replay only after the native replay
gate proves that the comparison is scientifically anchored.
