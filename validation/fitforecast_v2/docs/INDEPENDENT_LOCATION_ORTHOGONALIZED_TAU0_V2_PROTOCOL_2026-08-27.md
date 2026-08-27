# Independent Q-DESN Location-Orthogonalized Readout Campaign V2

## Decision and scientific scope

This protocol governs the next independent, single-quantile Q-DESN/DQLM
validation campaign. It is intentionally narrower than another DESN-capacity
screen. The completed v1 capacity-by-`tau0` experiment ran 64 of 64 discovery
jobs without execution failure and found only two small point-score gains, both
for the exact AL Normal `p=0.05` parent at `tau0=1e-9`. Larger and deeper
reservoirs did not repair the remaining forecast gaps and frequently produced
rank-deficient readouts with condition numbers near `1e16`.

The origin-horizon audit gives the causal direction: most posterior score
dispersion is a coherent dynamic-location shift. The current authoritative
parents already include the known period-90 Fourier terms and a trend feature,
so adding those terms again would repeat prior work. V2 instead asks whether
the RHS prior is being forced to allocate shrinkage across a collinear mixture
of deterministic location features and reservoir states. It fits a
training-only projection of the reservoir readout onto the deterministic block
and uses the residual reservoir component for fitting and every recursive
forecast. A rank-controlled version additionally compresses that residual
block by a training-only SVD.

The campaign touches no DQLM/exDQLM implementation, no joint-QDESN work, no
article source, and no application lane. Article publication remains the
integration coordinator's responsibility after a frozen handoff.

## Frozen authorities and estimands

The materializer verifies the v9 point interface, v9 remaining-gap ledger, v10
posterior metric intervals, canonical source registry, exact parent requests,
and the original 10,000-observation source hashes. The evaluation contract is:

- training source indices 8501--9000;
- held-out source indices 9001--10000;
- 34 origins, 9000 through 9990, spaced by 30;
- leads 1--30 at every origin;
- point forecast oracle-path MAE as the primary promotion metric;
- realized-observation forecast check loss as an independent promotion metric;
- fit oracle-path RMSE, posterior metric intervals, origin/lead attribution,
  common-shift interventions, conditioning, and MCMC diagnostics as supporting
  evidence;
- reconstruction tolerance `1e-6`;
- exact `m0_v_collapsed_support_logit` for exAL and `sigma_then_gamma` for AL;
- one process and one numerical thread per assigned CPU;
- no posterior recycling into a prior.

Diagnostic PASS/WARN/FAIL grades are disclosed but do not veto a finite strict
metric gain. Execution failure, source drift, nonfinite metrics, a broken
recursive transform contract, or metric reconstruction error does veto a job.

## Target cells

V2 targets only unresolved Normal-family forecast cells:

1. AL at `p=0.05`, where forecast MAE remains about 81% above the best
   DQLM/exDQLM comparator and the v1 `tau0=1e-9` gain requires replication;
2. AL at `p=0.50`, where forecast MAE remains about 81% above the comparator;
3. exAL at `p=0.50`, where forecast MAE remains about 70% above the comparator.

exAL Normal `p=0.05` is frozen as a negative control conclusion rather than
rerun: it already beats the comparator on both forecast criteria and v1 did not
improve it. Other family/quantile cells remain outside this mechanism test.

## Readout intervention

All arms retain the exact cell-specific authoritative DESN architecture,
memory, alpha, rho, sparsity, activation, washout, y lags, source trajectory,
and deterministic features.

| Arm | Operation |
|---|---|
| `C0_parent` | Existing augmented readout, used only at the authority `tau0` as a matched control. |
| `O1_orthogonalized` | Residualize every non-intercept reservoir and reservoir-lag column against the intercept and deterministic period/trend columns using training rows only. |
| `O2_orthogonalized_svd` | Apply O1, then retain the smallest residual-reservoir SVD rank explaining 99.5% training energy, capped at 40. |

The fitted projection coefficients and SVD loadings are stored in the
`readout_spec` and applied before train-fitted readout scaling for every future
recursive design row. The C++ posterior-predictive path is disabled for active
transforms until it implements the same contract; transformed jobs use the R
recursion. No outcome, oracle quantile, held-out value, or future residual is
used to fit either transform.

## Cell-specific tau0 ladders

The ladders are not shared globally. They reflect the v1 response surface and
the scale of each authoritative parent:

- AL Normal `p=0.05`: `1e-10, 3e-10, 1e-9, 3e-9, 1e-8`;
- AL Normal `p=0.50`: `1e-7, 1e-6, 1e-5, 1e-4, 3e-4`;
- exAL Normal `p=0.50`: `3e-8, 3e-7, 3e-6, 3e-5, 3e-4`.

Only O1 and O2 cross the ladders. C0 is evaluated once at its authority scale.
This yields 33 structural discovery jobs rather than an infeasible full
factorial and avoids repeating the 64 v1 capacity designs.

## Gated execution

1. **Static verification.** Validate authority hashes, source overlap,
   transform signatures, candidate nonrepeat, finite dimensions, exact sampler
   modes, and storage settings.
2. **Boundary smoke.** Run one AL O2 lower-tail job and one exact-M0 exAL O2
   median job with minimal iterations. Both must exercise fitting, recursive
   transform application, compact diagnostics, resume semantics, and binary
   cleanup.
3. **V1-gain replication.** Compare the exact AL `p=0.05` parent at `tau0=1e-9`
   with its `tau0=1e-8` control on two matched reservoir/chain panels. This is
   independent of the structural screen.
4. **Structural discovery.** Run 33 direct-MCMC jobs at 1,000 burn-in plus
   4,000 retained iterations.
5. **Adaptive matched replication.** For each forecast metric and cell, retain
   the best structural candidate only when it strictly improves the frozen
   authority by more than `1e-6`; deduplicate candidates across metrics and run
   each beside its C0 control on two new matched panels.
6. **Canonical confirmation.** A replicated candidate advances only when its
   panel mean is below both its matched control mean and the frozen authority
   for at least one declared metric. Run each advancing candidate and one C0
   control per affected cell for three chains at 5,000 burn-in plus 20,000
   retained iterations.
7. **Metric-specific closeout.** Promote every finite three-chain mean that is
   strictly below the frozen authority by more than `1e-6`, however small the
   gain. Different metrics and cells may select different specifications.

If no structural candidate advances, the correct conclusion is that
readout collinearity is not the missing mechanism. V2 then closes without an
article update; another capacity-only or scalar-`tau0` screen is prohibited.

## Reproducibility and storage

Every job has a frozen JSON request, SHA-256 hash, deterministic seed bundle,
source index contract, CPU assignment, status record, compact metric tables,
transform diagnostics, reconstruction audit, and retention manifest. Full fit
objects and posterior path arrays are transient. Terminal job directories must
contain zero `.rds`, `.rda`, or `.RData` payloads. The final handoff records all
stage counts, selected candidates, metric deltas, hashes, tests, and the exact
decision required by the integration coordinator.
