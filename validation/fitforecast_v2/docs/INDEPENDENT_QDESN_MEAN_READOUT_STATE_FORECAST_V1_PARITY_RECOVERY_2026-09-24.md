# Independent Q-DESN mean-readout-state forecast parity recovery

Status: implemented and validated locally; a fresh immutable production run is
required. The failed run is diagnostic evidence and must not be resumed.

## 1. Decision

The campaign should proceed with the original scientific experiment, but the
historical-authority gate must distinguish stochastic compatibility from exact
same-run consistency.

The production failure was not caused by the mean-readout-state estimator. No
candidate forecast reached execution. Eight canary fits completed and exported
valid native artifacts and capsules, then stopped because newly sampled score
summaries under exdqlm 1.1.2 were required to match score summaries sampled
under exdqlm 1.0.0 to an absolute tolerance of `1e-6`.

That requirement is invalid for independent stochastic refits. Increasing its
tolerance would also be invalid. The root repair is a two-gate design:

1. **Historical stochastic compatibility:** verify that a refit remains
   compatible with the frozen authority distribution using a predeclared,
   familywise-controlled multicomponent test.
2. **Same-run causal consistency:** continue to require the native artifacts
   consumed by the candidate comparison to reproduce their own summaries at
   `1e-6`. Native and candidate recursion then use the same posterior capsules,
   feature basis, forecast grid, and paired innovations.

This preserves a strict causal comparison without pretending two independent
Monte Carlo samples should be numerically identical.

## 2. Scope and ownership

| Item | Frozen contract |
|---|---|
| Scientific lane | Independent single-quantile Q-DESN/DQLM validation only |
| Worktree | `/data/jaguir26/local/src/exdqlm__wt__independent_fixed_state_forecast_plan_20260924` |
| Branch | `validation/independent-fixed-state-forecast-plan-20260924` |
| Candidate change | Forecast recursion only |
| Fit reconstructions | 96 |
| Forecast evaluations | 46 |
| Metric roles | 72 |
| Historical compatibility comparisons | 192 |
| Execution | 8 one-core workers on Muscat |
| Article/Overleaf edits | Prohibited in this lane |

The campaign does not retune DESN specifications, `tau0`, priors, data,
windows, likelihoods, MCMC budgets, seeds, or scoring definitions. DQLM and
exDQLM rows are outside the intervention because they have no DESN reservoir
state to average.

## 3. Failure diagnosis

### 3.1 Failed production root

```text
reports/shared_fitforecast_v2_orchestration/
  independent_mean_readout_state_forecast_v1_20260924_045653
```

Observed state:

- no active controller or worker;
- 8 failed fit statuses;
- 0 successful fit statuses;
- 0 candidate forecast statuses;
- 134 jobs had not started;
- each failed fit completed its package pipeline and exported valid basis and
  posterior capsules before the historical check;
- fitted-model binaries were not retained;
- the failed root occupies approximately 140 MB and remains immutable
  diagnostic evidence.

### 3.2 Version boundary

The principal historical score authority was generated at:

```text
c72e19f345da88fc1a8175ed30bdde328eab88be
exdqlm 1.0.0
```

The basis-specific Gaussian `p = 0.05` authority was generated at:

```text
d6bc4c5e47a922ea0255f3ad8d73e58f374827a0
exdqlm 1.0.0
```

The failed reconstruction used exdqlm 1.1.2. RNG and inference implementation
changes make posterior draw identity unavailable across this version boundary.
The frozen requests, source trajectories, winning specifications, priors, and
draw budgets remain the same scientific contract.

### 3.3 Offline recovery audit

The repaired policy was applied read-only to all eight completed failed fits.
Its ignored diagnostic ledger is:

```text
reports/shared_fitforecast_v2_orchestration/
  independent_mean_readout_state_forecast_v1_20260924_045653/
  health/recovery_historical_compatibility_diagnostic.csv
```

| Quantity | Result |
|---|---:|
| Completed fit jobs audited | 8 |
| Metric comparisons | 16 |
| Compatibility passes | 16 |
| Exact draw-identity passes | 0 |
| Distributional passes | 16 |
| Maximum relative mean difference | 0.034216 |
| Maximum familywise KS ratio | 0.613190 |
| Maximum endpoint/authority-width ratio | 0.047159 |
| Minimum 95% interval overlap | 0.996650 |

The observed distributions are compatible by every predeclared component.
The failed exact check was therefore diagnosing independent Monte Carlo
variation, not a changed forecast target.

### 3.4 Posterior index-coordinate diagnosis

The first MCMC forecast-worker smoke exposed a second latent failure that the
old historical gate had masked. Native metric files label retained draws by
their position in the exported forecast matrix (`1, ..., nd`). Posterior
capsules additionally retain each row's original sampler index, which can be a
nonconsecutive value such as `5619` or `17219`. The original worker compared
these two coordinate systems numerically and would have rejected every MCMC
forecast even though the ordered posterior rows were aligned.

The repair now enforces three explicit contracts:

- native metric positions must be exactly `1, ..., nd`;
- capsule original sampler indices must be finite and unique; and
- balanced selection is performed in retained-position coordinates while the
  corresponding original sampler indices are retained in a separate
  provenance ledger.

This changes no draw, score, or forecast. It corrects only the identity map
used to prove that compact native metrics and posterior capsules refer to the
same ordered retained rows.

## 4. Historical compatibility contract

For each of 96 fits and each of two draw-level metrics, let `x` be the fresh
native score sample and `y` the frozen historical score sample. There are
`K = 192` comparisons. The familywise error budget is `0.01`, so each
two-sided comparison uses `alpha_K = 0.01 / 192`.

The row contract first requires equal nonzero draw counts and finite scores.
An exact pass is retained for audits and requires drawwise and summary
differences no larger than `1e-6`. Otherwise all four distributional checks
must pass:

1. **Mean compatibility.** The absolute mean difference must not exceed the
   maximum of `1e-6`, 5% of the historical mean magnitude, and the familywise
   normal critical value times the combined Monte Carlo standard error. The
   latter uses `coda::effectiveSize`, capped at the observed draw count.
2. **Empirical-distribution compatibility.** The two-sample empirical CDF
   distance must not exceed the familywise asymptotic KS threshold computed
   with the two effective sample sizes. This is more conservative under serial
   dependence than pretending every MCMC draw is independent.
3. **Interval-endpoint compatibility.** The largest absolute difference in
   the 2.5% and 97.5% endpoints must be at most 10% of the historical 95%
   interval width.
4. **Interval-overlap compatibility.** The overlap must cover at least 90% of
   the narrower 95% interval.

Passing historical compatibility does not establish estimator improvement.
It establishes only that package/version drift did not move the baseline
outside its frozen stochastic authority.

## 5. Same-run causal gate

The historical compatibility fallback must never enter the native-versus-
candidate comparison. Each fresh fit produces the native score draws, interval
summary, 1,000-target path, and lead profile once. The forecast worker:

1. hash-verifies those artifacts;
2. recomputes their summaries and requires exact agreement at `1e-6`;
3. loads the content-addressed basis and posterior capsules;
4. generates deterministic paired full-block and tail innovations;
5. evaluates only the mean-readout-state candidate; and
6. compares native and candidate results from that same reconstructed fit.

This is the strict control that identifies the effect of changing recursive
forecast state propagation.

## 6. Implementation map

The repair changes these tracked surfaces:

- `campaign_defaults.yaml`: authority commits, source version, familywise
  policy, and fixed thresholds;
- campaign R helpers: policy validation, effective sample size, empirical KS,
  exact identity, and distributional compatibility;
- materializer: verifies both authority commits resolve to exdqlm 1.0.0 and
  freezes policy/provenance into every fit config and the run manifest;
- fit worker: writes
  `historical_native_authority_compatibility.csv` and records exact versus
  distributional gate mode plus worst-case diagnostics;
- orchestrator: rejects a materialized run without the expected policy schema;
- forecast worker: verifies retained-position alignment separately from
  original sampler-index provenance and exports both coordinates;
- closeout: requires all 192 compatibility rows and reports exact and
  distributional counts separately;
- verifier: independently rechecks the policy schema, versions, row contracts,
  finite scores, gate modes, hashes, and complete surface;
- tests: exact, permuted, independent-equivalent, shifted, non-finite,
  wrong-length, multiplicity, authority provenance, and draw-coordinate
  alignment cases.

The old failed root is not modified except for an ignored recovery-diagnostic
CSV. Its statuses, configs, logs, and scientific artifacts remain untouched.

## 7. Validation sequence

The implementation is acceptable only after all of the following pass:

1. parse every changed R script;
2. focused compatibility/campaign tests;
3. package mean-readout-state tests;
4. recursion-diagnostic tests;
5. offline application to all completed failed canaries;
6. one MCMC AL and one MCMC exAL capsule forecast smoke, with finite scores,
   exact paired-innovation records, and a 1,000-target grid;
7. fresh-run materialization with 96/46/72/192 contracts;
8. production canary: 11 fits and 7 forecast evaluations;
9. release of the non-canary surface only after the canary gate passes;
10. closeout and independent verification only after 96/96 fits and 46/46
    forecasts succeed.

## 8. Fresh launch and recovery

Prelaunch implementation evidence completed before the fresh run:

| Check | Result |
|---|---:|
| Changed R files parsed | PASS |
| Campaign regression expectations | PASS |
| Mean-readout-state package expectations | 37/37 |
| Recursion-diagnostic expectations | 10/10 |
| Failed-canary historical comparisons | 16/16 compatible |
| Fresh materialization artifact hashes | 325/325 |
| Materialized fit/forecast/role rows | 96/46/72 |
| AL MCMC worker smoke | PASS, 40 draws and 1,000 targets |
| exAL MCMC worker smoke | PASS, 40 draws and 1,000 targets |
| Smoke innovation and alignment gates | PASS |

The failed run cannot be resumed because its materialized artifact manifest
freezes implementation hashes from the old gate. Production must use a new run
root from a clean, pushed branch:

```bash
validation/fitforecast_v2/scripts/launch_independent_mean_readout_state_forecast_v1.sh \
  --workers 8 --scheduler load_balanced --background
```

The launcher selects eight currently light CPUs, pins one worker to each CPU,
sets all known numerical thread variables to one, and creates a dedicated tmux
controller. It does not touch unrelated tmux sessions or processes. There is
no automatic retry after a deterministic failure.

## 9. Scientific decision and publication

The original global decision remains frozen. The candidate is accepted only
if the complete surface and provenance gates pass and:

- median interval-width ratio is at most 1.00;
- at least 50% of metric roles have a narrower interval;
- median point-score ratio is at most 1.05; and
- maximum point-score ratio is at most 1.25.

The forecast estimator must be accepted or rejected coherently over the Q-DESN
surface. It must not be selected case by case after observing scores. No
article, shared-validation, or Overleaf update is authorized until complete
closeout. The integration coordinator owns any later publication.

## 10. Storage and rollback

Fit workers remove full fitted-model binaries only after verified capsule
export. Capsules are retained through scientific closeout, then hashed and
pruned after all 96 fits, 46 forecasts, decision artifacts, and verification
checks exist. Compact CSV/JSON/PDF evidence remains.

Rollback is non-destructive: retain the failed and fresh run roots, revert the
dedicated repair commit if necessary, and leave the current article authority
unchanged. No reset, force-push, cross-lane cleanup, or modification of another
worktree is part of this plan.

## 11. Endpoint-review recovery amendment

The fresh production root later stopped after one MCMC chain passed the row,
finite, mean, familywise KS, and interval-overlap checks but missed only the
per-chain interval-endpoint threshold. The balanced three-chain source passed
the complete unchanged policy for both metrics. The campaign therefore uses a
documented recovery amendment: an endpoint-only MCMC chain may remain pending
until the forecast worker applies the original hard gate to the balanced source
pool. Core incompatibility and all VB incompatibility remain terminal.

The diagnosis, exact pooled evidence, prior-semantics audit, and next-stage
variance-attribution plan are frozen in:

```text
validation/fitforecast_v2/docs/
  INDEPENDENT_QDESN_RHS_VARIANCE_ATTRIBUTION_AND_RUN_RECOVERY_2026-09-24.md
```

The amendment archives the original materialization manifest and artifact
ledger before recording changed runtime hashes. It neither relaxes a numerical
threshold nor changes any model, prior, seed, score, or candidate forecast.
