# Independent exQ-DESN M0 MCMC relaunch v1

## Decision

This campaign re-estimates every distinct exQ-DESN--exAL--RHS MCMC design
that supplies the authoritative 500-observation simulation table. It changes
the exAL scale-shape transition only. It does not search for one global DESN
specification, alter the data-generating process, change the regularized
horseshoe prior, update the article automatically, or modify the package's
legacy MCMC default.

The production method under evaluation is the exact
`M0_v_collapsed_support_logit` transition established by Article-Q-DESN
Phase170. In the package-facing configuration it is named
`m0_v_collapsed_support_logit` and remains explicitly opt-in and exAL-only.

## Frozen authority

| Item | Frozen value |
|---|---|
| Package | `exdqlm` 1.0.0 |
| Validation base | `58ad24dee1204f23f7b0df5efc32b388dd8638b3` |
| Branch | `validation/independent-exal-m0-relaunch-v1-1.0.0` |
| Authoritative table interface | `validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_trainonly_article_v3_20260807/qdesn_dqlm_500obs_trainonly_article_v3_20260807_interface.csv` |
| Interface SHA-256 | `90744fae79f8af79c6e844e5862c90330ea14d9bbd2df69f630440887fed1393` |
| Source registry SHA-256 identity | `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275` |
| Phase170 reference commit | `e7073b6982caf2ed4abbcee04c78cfde9cb8a983` |
| Article update | Manual review only; never automatic |

The authority contains nine exQ-DESN MCMC family/quantile cells and 27
displayed metric roles. Those roles are supplied by 15 distinct historical
candidate designs. The campaign freezes and reruns all 15, because a cell's
fit RMSE, forecast MAE, and forecast check loss may currently come from
different case-specific designs.

Exact anchor identity, source requests, source hashes, DESN specifications,
and assigned metric roles are in:

```text
config/validation/qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_relaunch_v1_anchor_registry.csv
config/validation/qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_relaunch_v1_metric_contract.csv
```

## Statistical transition

Conditional on the latent `v` and `s` variables and the current readout, M0:

1. reduces the gamma-dependent scale target to exact sufficient statistics;
2. integrates sigma out of the gamma target through the GIG normalizing
   integral;
3. samples gamma on the native-support logit coordinate, including the
   Jacobian;
4. redraws sigma from its exact GIG conditional.

The local implementation includes a stable large-order log-Bessel expansion
for the GIG normalizer. This is important for the roughly 500 effective fit
observations, where direct `besselK` evaluation can otherwise overflow. Tests
compare the decomposition with the expanded joint kernel and direct numerical
integration, including large GIG orders representative of this campaign.

The Phase170 transition contract uses:

```text
core_update_mode = m0_v_collapsed_support_logit
width_gamma = 4
core_extra_passes = 0
```

The historical validation priors remain unchanged, including
`sigma ~ IG(1, 1)` and the existing gamma prior. The article helper's separate
scale-prior defaults are not imported.

## Frozen evaluation protocol

| Quantity | Value |
|---|---:|
| Warmup source length | 2,000 |
| Main source length | 10,000 |
| Total source length | 12,000 |
| Training target indices | 8,501--9,000 |
| Forecast origin | 9,000 |
| Forecast block | 9,001--10,000 |
| Maximum forecast lead | 30 |
| Origin stride | 30 |
| Refit at each origin | No |
| Observed-lag state update | Yes |
| Preprocessing | Fit on training data only |

Each anchor preserves its exact DESN depth, width, memory, alpha, rho,
sparsity, reservoir seed, RHS `tau0`, covariates, lag structure, and VB warm
start configuration. Fresh MCMC seeds provide three chains per full-budget
anchor; the first full chain retains the historical sampler seed when
available.

## Staged execution

| Stage | Jobs | Parallelism | Budget | Hard gate |
|---|---:|---:|---|---|
| Static verification | 60 configs | 1 | no fit | hashes, source, prior, model, method, storage |
| Prepare-only | 60 manifests | 1 | no fit | no model process or binary payload |
| Smoke | 6 | 6 | 25 burn + 50 retained | finite fit/forecast outputs, 1,000 rolling rows, 30 lead summaries, exact method, no binaries |
| Canary | 9 | 9 | 500 burn + 1,000 retained | three chains for three representative anchors; finite outputs and sampler gate |
| Full confirmation | 45 | 20 | 5,000 burn + 20,000 retained | 15 anchors x 3 chains; article-comparable budget |
| Closeout | 1 | 1 | no fit | pooled paths, diagnostics, metric comparison, storage audit |

The representative gates cover Gaussian-mixture `p=0.05`, Normal `p=0.25`,
and Laplace `p=0.05`, including both a compact and a larger historical DESN
design. The canary hard gate requires, for gamma and sigma, maximum rank or
folded-rank split R-hat no greater than 1.25, bulk ESS at least 50, and tail
ESS at least 25. Full closeout reports stricter PASS/WARN/FAIL diagnostics but
does not suppress finite metrics based on diagnostic grade.

## Chain diagnostics and comparison

Full closeout reports rank-normalized split R-hat, folded-rank split R-hat,
bulk ESS, tail ESS, MCSE relative to posterior SD, and between-chain fit and
forecast path dispersion. Three chain-level posterior mean paths are averaged
before recomputing:

- fit-window quantile RMSE against the true quantile;
- rolling-origin forecast quantile MAE for source indices 9,001--9,100 and
  9,001--10,000;
- rolling-origin forecast check loss for the same windows.

Every M0 result is compared only with the authoritative value for the exact
family, quantile, model, and metric role assigned to that anchor. A result is
a manual promotion candidate only when its raw metric is strictly lower than
the current value. Diagnostic grade is always retained alongside the metric,
but it is not a metric-exclusion rule.

## Storage and failure policy

Successful and failed jobs retain CSV path summaries, scalar summaries,
progress evidence, logs, requests, status, hashes, and manifests. They do not
retain `.rds`, `.rda`, or `.RData` model payloads. Any transient binary created
by the pipeline is hashed in the job-local prune manifest and removed before
the job is declared complete. Full progress traces are retained until
cross-chain closeout and then compacted to the first, final, and every 50th
row.

A nonzero worker does not erase successful peers. Relaunching the same run tag
skips successful jobs with matching config hashes and runs only failed or
missing jobs. A 30-minute orchestration heartbeat and 30-minute stale threshold
support non-disruptive health checks.

## Reproducible commands

Materialize and verify without compute:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/materialize_independent_exal_m0_relaunch_v1.R

/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/verify_independent_exal_m0_relaunch_v1.R \
  --budget static

/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/prepare_independent_exal_m0_relaunch_v1.R
```

Launch the gated detached workflow only from a clean, pushed branch:

```bash
bash validation/fitforecast_v2/scripts/launch_independent_exal_m0_relaunch_v1.sh
```

Check a running stage:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/healthcheck_independent_exal_m0_relaunch_v1.R \
  --run-tag RUN_TAG --budget full
```

## Prelaunch verification evidence

The implementation was verified under R 4.6.0 before publication of the
launch branch. The passing focused suite covers package load/version, the M0
kernel decomposition and direct integration, large-order GIG stability,
source windows, forecast horizons, storage-light retention, launcher filters,
rolling-origin lead export, interface schema, no-leakage behavior, frozen
campaign contracts, and all five health lifecycle states.

Static verification and prepare-only evidence are written under:

```text
reports/shared_fitforecast_v2_orchestration/independent_exal_m0_relaunch_v1_prelaunch_final/
```

The prepare-only gate resolves all 60 jobs without starting a model fit or
creating a binary payload. Materialization is byte-stable; its final file
manifest SHA-256 is
`9c6a1068f712d37e3917eaf8ba771a5a6e731fb6bc8dd1d972c43b28feed35c3`.

A real frozen-input worker integration used run tag
`dev-m0-worker-integration3-20260809`. It completed successfully, wrote the
standard fit summary, 1,000 rolling-origin path rows and 30 lead summaries,
marked compact retention ready, pruned the transient forecast object, and
left zero `.rds`, `.rda`, or `.RData` files.

The repository-wide historical test suite was also run as an audit. It is not
globally green: unrelated synthesized-benchmark and old path-dependent tests
report failures or warnings because their optional engines or historical
run roots are unavailable. These failures do not exercise the M0 sampler or
this campaign. They are recorded as residual repository risk and are not
silently relabeled as passing tests.

## Invalid launch record

Run tag `ind-exal-m0-v1-20260809_160325__git-1ac48bd` is aborted and must not
be consumed. Its controller passed materialization, focused tests, static
verification, prepare-only, and the resource gate, then stopped before the
first smoke worker because a strict-mode Bash function expanded a dependent
local variable within the same declaration. No chain was started and no model
artifact was produced. The launcher now initializes those locals on separate
lines, and a focused regression test protects that contract. Production uses
a fresh run tag rather than resuming this invalid attempt.

## Publication boundary

This campaign does not touch Article-Q-DESN Version 2 or Version 3. A complete
closeout writes `manual_promotion_candidates.csv`; promotion requires a
separate evidence audit, explicit article-table regeneration, compilation,
and publication decision. Incomplete smoke, canary, or full runs are never
article-facing evidence.
