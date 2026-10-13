# Independent Q-DESN coupled-beta tau0 experiment v6

## Scientific question and evidence

Can weaker RHS global shrinkage restore the dynamic quantile signal and
improve internal forecasts after the coupled beta update has removed the
v4 numerical explosions? The experiment is specific to two Normal-family
controls; no global DESN specification or universal tau0 is selected.

Completed v5 reference at 7cd8477267b3abb4cab11eb9e47f57b754a911f8:

| Case | Full forecast MAE | Constant baseline | Matched comparator | Fitted / true fit-path SD |
| --- | ---: | ---: | ---: | ---: |
| Normal AL, p=0.05 | 19.9312 | 20.0695 | DQLM 2.0503 | 0.007056 |
| Normal exAL, p=0.25 | 17.2257 | 17.2991 | exDQLM 1.7054 | 0.00008123 |

Both diagonal controls exactly reproduced their historical explosions.
Coupled solves were numerically accurate and stable, but the learned
nonintercept coefficients remained tiny with median expected precisions
approximately 78,457 and 88,665. Deterministic feature reconstruction and
training-oracle projection showed available training signal. Oracle
projection was diagnostic only, not model selection or a forecast.

This supports testing less shrinkage before combining it with increased
depth or width. It does not prove that tau0 is the only problem. exAL VB
reached its 750-iteration limit with small late scale/shape fluctuations;
that flag is disclosed and does not exclude a finite forecast improvement.
VB convergence is not MCMC mixing.

## Frozen comparison

| Case / source candidate | D | n | m | alpha | rho | Input gain |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| iqcb4_normal_al_p005_36b501b2c57e | 2 | 40;20 | 240 | 0.471893317068923 | 0.986627020238116 | 1 |
| iqcb4_normal_exal_p025_4e36250372e6 | 1 | 20 | 30 | 0.2 | 0.8 | 0.1 |

All Q matrices remain identity, with no layer reduction. The readout
contains an unshrunk intercept and all reservoir layers, without direct
output-lag readout terms. The source configs retain exact sparsity,
activation, scaling, reservoir seeds, priors, and likelihood definitions.

Model-scale tau0 arms:

| Multiplier | tau0 | Role |
| --- | ---: | --- |
| 1 | 0.00332871332649303 | Frozen-init replay control |
| 3.5 | 0.0116504966427256 | Continuity with the v4 bridge, using full beta |
| 30 | 0.0998613997947909 | Intermediate weaker shrinkage |
| 300 | 0.998613997947909 | Broad weaker-shrinkage sentinel |

Each case selects independently. Source-scale values are recomputed using
that case's frozen response transport; model and source scales stay labeled.
Slab s2 is 1 and is unchanged. Learned posterior scale need not equal tau0.

Eight fit/forecast jobs: two 1x replay controls plus six new tau arms. The
controls run first and must reproduce all six scalar fit/forecast scores
for every estimator and inner-path row within absolute tolerance 1e-6.
Only then are the six new arms scheduled. This adds two replay jobs to the
previous six-job sketch because a new frozen-initializer path is introduced.
It prevents initialization changes from being confused with tau effects.

## Initialization and causal interpretation

The existing qdesn_normal_to_vb_init implementation transfers beta mean,
beta covariance, and sigma. It does not transfer beta_state. The quantile
engine initializes RHS factors separately with the requested prior scale.

Reproduce the reference Normal initializer once per case, using only its
training observations and the original 1x Normal prior. Freeze its beta
mean/covariance, sigma, and post-initialization RNG state in compact JSON.
Every arm starts from those same transferred components. Fresh RHS state
is created by the existing engine at that arm's tau0, with no posterior
prior recycling. No model binary is retained.

Explicitly validate both initializer hashes and the reconstructed design.
The initializer digest hashes its frozen JSON representation. Serialization
error in transferred numeric components must not exceed 1e-12; scientific
reference replay uses the agreed absolute score tolerance of 1e-6.
Record expected initial precision and tau2 for each arm. RHS initialization
at tau0 squared is part of the declared prior intervention; it is not an
unreported transfer from a differently regularized Normal fit.

The only allowed scientific changes from each reference config are tau0
and derived tau labels/identifiers. All other candidate, source, seed,
likelihood, budget, preprocessing, and forecast fields are checked.
The beta approximation is explicitly full in every arm. Historical worker
behavior is preserved when the frozen-initializer field is absent.

## Training and evaluation

- Fit: 8501:8750; internal development: 8751:9000.
- 45 origins: 8750:8970, stride 5; leads 1:30; 1,350 scored pairs.
- Teacher forcing updates observed history between origins. Within each
  origin, future outcome lags are generated recursively.
- Preprocessing and response transport use fitting rows only.
- Quantile VB: 750 iterations maximum, original tol=1e-4 and xi budget=400.
- Forecast: 16 outer posterior draws and 128 inner predictive paths.
- Primary diagnostic ranking: mean conditional-location oracle MAE.
- Also retain pooled posterior-predictive quantile check loss, all other
  estimator scores, draw intervals, and origin-block intervals separately.
- Retain analytic coefficient-mean fit RMSE and mean draw-level fit RMSE
  separately. The former is used for comparisons to point-path comparators.

Sixteen outer draws provide a controlled screen, not publication-quality
interval-tail certification. The same seeds and noise-bank rules are used
within each case. Exogenous variables are absent for these source designs.

The original matched internal DQLM and exDQLM comparator outputs are reused;
they are not refitted. Their sources/configs and outputs are hashed through
the input manifest. Current article MCMC tables use a different fitting
window and external forecast block and are not replaced by these scores.

## Implementation, verification, and resources

Implementation:

- R/independent_qdesn_coupled_tau_v6.R: immutable initialization, manifests,
  configs, worker validation, replay gate, case-specific comparison and
  internal selection, numerical wide-design benchmark.
- R/independent_qdesn_corrected_forecast_v3_campaign.R: narrow optional
  frozen-initializer hook; original code path otherwise remains available.
- scripts/independent_qdesn_coupled_tau_v6.R: explicit CLI actions.
- scripts/run_independent_qdesn_coupled_tau_v6.sh: bounded background pipeline.
- Focused tests and four tiny AL/exAL frozen-initializer forecast smoke jobs.

Before production: compile the source package once; test full coupled
solutions and existing forecast contracts; verify initializer covariance,
RNG restoration, fresh prior state, protected scientific fields, replay
failure behavior, and the complete synthetic fit/forecast artifact path.
Commit the dedicated branch before freezing configs and launching workers.

Runtime: R 4.6.0, validation source exdqlm version 1.1.1. The environment
records pkgload_source_not_unmodified_CRAN_binary. This controlled source
runtime must not be described as an unmodified CRAN binary or used to claim
a defect in CRAN defaults. No package inference defaults are changed.

Use six verified available CPUs, one assigned CPU per worker, with BLAS,
OpenMP, and other numerical thread variables fixed to 1. Two reference
replays run concurrently, followed by six parallel tau arms. Each fit and
forecast has a two-hour timeout. The launcher has an exclusive lock, exact
exit-code records, and signals only its own workers if interrupted.
Completed hash-valid jobs can be reused. A stale or failed status never
counts as a successful result. Every worker verifies source/config/input
hashes and the frozen branch HEAD before work.

## Decisions and bounded continuation

Select forecast MAE and pooled check-loss winners separately within each
case, including the 1x control. Record every strict finite gain regardless
of its size and keep convergence flags. Selection does not require one
specification to dominate all cases or all metrics.

If any new arm improves forecast MAE, perform one bounded numerical cost
benchmark of an existing identity-Q design wider than the 250-row sample.
The design is selected by width from the frozen v4 bank before seeing v6
scores. The benchmark uses observed training response, unit data weights,
and an arm prior to test the existing coupled solver's residual, covariance,
time, and memory. It is not a quantile fit, forecast, new candidate screen,
or performance claim. Timeout: 30 minutes, one CPU. Store only its report.
The benchmark result supports sizing a later corrected replay, not automatic
expansion. Its failure is recorded separately from the eight model jobs.

If the tau arms restore dynamics and improve internal forecasts, prepare a
limited per-case replay of promising prior DESN designs with full updates.
If fitting improves without forecasting, refine internal forecast selection.
If collapse persists, inspect RHS/VB feedback and initialization, then
prepare a bounded direct-MCMC or prior-reference comparison for the same
design. Neither an inferior VB score nor an imperfect convergence flag
alone should eliminate plausible MCMC candidates.

No automatic broad replay, MCMC campaign, or article promotion is scheduled.
Those choices depend on the completed v6 evidence and numerical cost report.
The prior plan's downstream confirmation/publication steps remain the
roadmap: freeze internal selection; fit finalists on the full 500-row
window; evaluate the external protocol; retain mean/95% score intervals;
prepare the coordinator handoff for finite strict gains with diagnostics
and provenance. Later fresh DGP replicates address the repeatedly used
external block's research-process selection bias.

## Evidence and storage

The run includes plan.csv, input_hashes.csv, source_hashes.csv,
materialization_hashes.csv, environment.json, two initializer JSON files,
per-job status/config hashes and score/fit/trace artifacts,
reference_replay_audit.csv, comparison.csv, per_case_internal_winners.csv,
decision.json, conditional wide_benchmark_status.json, worker exit codes,
and a final artifact manifest written after terminal pipeline status.

All runtime outputs remain under ignored validation/fitforecast_v2/local_trackers.
Only CSV/CSV.gz, JSON, and text are retained. No RDS/RDA/RData models are
written, and no old artifacts are removed. Completed v5 evidence remains
frozen in its worktree. Commit and push only the dedicated IND branch.
Article-v2, Overleaf, shared validation, integration branches, other lanes,
and unrelated processes remain coordinator- or lane-owned.

## Reproduction commands

From the v6 worktree, with the pinned R executable and single-thread variables:

```bash
Rscript --vanilla validation/fitforecast_v2/scripts/test_independent_qdesn_coupled_tau_v6.R "$PWD" "$TEST_ROOT"
Rscript --vanilla validation/fitforecast_v2/scripts/smoke_independent_qdesn_coupled_tau_v6.R "$PWD" "$SMOKE_ROOT"
Rscript --vanilla validation/fitforecast_v2/scripts/independent_qdesn_coupled_tau_v6.R "$PWD" materialize "$RUN_ROOT" "$V5_RUN"
REPO_ROOT="$PWD" RUN_ROOT="$RUN_ROOT" CPU_LIST="48,49,50,51,52,53" bash validation/fitforecast_v2/scripts/run_independent_qdesn_coupled_tau_v6.sh
Rscript --vanilla validation/fitforecast_v2/scripts/independent_qdesn_coupled_tau_v6.R "$PWD" health "$RUN_ROOT"
```

The example CPU list is not a reservation. Verify availability immediately
before launch. Tests and smoke paths expected by the materializer are
local_trackers/coupled_tau_v6_tests_20261001 and
local_trackers/coupled_tau_v6_smoke_20261001 beneath validation/fitforecast_v2.
