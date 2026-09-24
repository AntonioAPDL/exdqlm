# Independent Q-DESN mean-readout-state forecast implementation

> **2026-09-24 recovery amendment.** The historical `1e-6` reproduction gate
> described below was found to conflate independent Monte Carlo samples across
> exdqlm 1.0.0 and 1.1.2. It is superseded by
> `INDEPENDENT_QDESN_MEAN_READOUT_STATE_FORECAST_V1_PARITY_RECOVERY_2026-09-24.md`.
> Same-run native-artifact consistency remains exact at `1e-6`; historical
> authority is now checked with a frozen, familywise-controlled stochastic
> compatibility policy.

## Scope

This implementation evaluates one forecast-estimator change for the frozen
independent single-quantile Q-DESN validation surface. It does not recalibrate
models, alter the data-generating process, change priors, modify DQLM/exDQLM
rows, or update the article. The integration coordinator remains the only lane
permitted to merge or publish a scientifically accepted result.

The candidate follows the advisor-requested recursion:

1. propagate one candidate reservoir state for every posterior predictive
   input particle;
2. average the complete post-transform readout feature across particles;
3. apply every posterior coefficient draw to that common feature;
4. generate the next posterior predictive response draws; and
5. recurse those response draws into the next lead's candidate states.

This isolates uncertainty in the readout posterior after integrating the
particle-specific reservoir state. It is distinct from a deterministic
conditional-mean plug-in forecast.

## Frozen execution surface

| Item | Count or contract |
|---|---:|
| Fit reconstructions | 96 |
| Basis forecast evaluations | 46 |
| Source identities | 44 |
| Article metric roles | 72 |
| Inference methods | VB and MCMC |
| Working likelihoods | AL and exAL |
| Simulation families | Gaussian, Laplace, Gaussian mixture |
| Quantile levels | 0.05, 0.25, 0.50 |
| Scored forecast targets | 1,000 |
| Maximum lead | 30 |
| Origin stride | 30 |
| Production concurrency | 8 one-core workers |

All case-specific winning DESN specifications, priors, seeds, chain lengths,
posterior draw counts, source trajectories, preprocessing, and scoring rules
are inherited from their frozen authority requests. Three historical chains
whose random-feature bases differ are evaluated separately and combined only
after scoring. Compatible repeated chains are pooled with equal chain weight
only after their feature-basis hashes agree.

## Scientific comparison

Each reconstruction produces the historical native posterior-predictive
forecast once and exports:

- compact native score draws;
- its interval summary;
- the 1,000-target rolling-origin point path;
- lead summaries; and
- content-addressed basis and posterior capsules.

The materializer also stages the compact, hash-verified native metric draws
from each source's prior authority. Every reconstructed native fit must pass a
predeclared historical stochastic-compatibility policy. Exact draw identity is
recorded when it occurs but is not required across package versions. This
prevents a material baseline change from being mistaken for an estimator
effect without demanding numerical identity from independent Monte Carlo
samples.

The forecast worker verifies those native artifacts and recomputes their
summaries within `1e-6`; it does not repeat the native recursion. It then runs
only the mean-readout-state candidate with deterministic paired innovations.
Pairing preserves the pipeline's two RNG streams exactly: complete 30-step
blocks use the frozen forecast seed and the truncated tail block uses seed plus
31. When balancing selects posterior rows, the worker generates the original
stream before selecting the corresponding innovation columns.
The official interval criteria are forecast MAE and forecast check loss.
Forecast RMSE is retained as a point/path diagnostic because the frozen native
authority does not contain draw-level RMSE for every source.

Retained historical score/path files alone cannot replace the same-run native
gate: fitted posterior and reservoir objects were intentionally compacted.
Pairing old native scores with newly reconstructed posterior objects would
confound the estimator comparison. The implemented design therefore performs
one reconstruction and one native pass per frozen fit, then avoids all further
native duplication.

The reconstruction explicitly uses pipeline forecast mode `mixture`. The
required rolling-origin lattice is constructed before the pipeline's forecast
mode branch and is identical to the lattice used by historical interval
exports. This setting omits only the later, separate 1,000-origin lead-one pass,
which does not contribute to this campaign's score draws, point path, profiles,
or decision. Historical stochastic compatibility and same-run native-artifact
reproduction at tolerance `1e-6` are separate hard gates for this optimization.

Because the fixed protocol uses horizon 30 and origin stride 30, the full and
tail rolling-origin blocks form a nonoverlapping tiling of the 1,000 held-out
targets. The campaign joins those already-computed blocks only for the
pipeline's generic forecast summary. It fails if a target is missing or
duplicated; no forecast is recomputed and no block enters twice.

The model input file intentionally omits the original simulation clock. During
materialization, its response column is checked against the hash-verified
source/truth file and that file's exact `source_index`/`t` vector is embedded
in each immutable fit request. Capsule export therefore preserves source
coordinates explicitly instead of treating local row numbers as simulation
indices.

## Software and evidence

The package implementation is in:

- `R/qdesn_mean_readout_state_forecast.R`;
- `R/qdesn_vb.R`; and
- `scripts/pipeline_real_main.R`.

The campaign implementation is in:

- `config/validation/independent_mean_readout_state_forecast_v1/`;
- `validation/fitforecast_v2/R/independent_mean_readout_state_forecast_v1.R`;
- the `*independent_mean_readout_state_forecast_v1*` materializer, worker,
  orchestrator, health, closeout, verification, and launch scripts; and
- focused package and campaign tests.

Runtime evidence is written beneath the ignored directory
`reports/shared_fitforecast_v2_orchestration/<run_id>/`. It includes immutable
configs and manifests, atomic status files, logs, resource reports, compact
score/path evidence, a local diagnostic PDF, the scientific decision, and the
integration handoff. Fitted-model `.rds`, `.rda`, and `.RData` payloads are not
retained after verified capsule export; the transient capsules are pruned only
after complete verified closeout.

## Gates and decision

The launcher refuses to run unless the host is `muscat.be.ucsc.edu`, the
dedicated branch is clean and synchronized with its upstream, all focused
tests pass, at least eight CPUs and the declared memory/disk reserves are
available, and no campaign controller already exists. It pins eight workers to
eight selected CPUs and sets all known numerical thread variables to one.

Canary fits and their dependent forecasts must all succeed before non-canary
jobs are released. There is no automatic retry after a deterministic failure.
Closeout requires all 96 fits, all 46 forecast evaluations, all 72 role rows,
finite metrics, valid hashes, all 192 historical compatibility rows,
native-artifact consistency, and integration stability evidence. It then
either accepts the candidate for the complete
Q-DESN forecast surface or retains the current native authority. Article edits
remain a separate coordinator decision.

## Prelaunch canary evidence

A full 10,000-draw reconstruction and candidate forecast was completed for the
representative VB, AL, Gaussian, `p = 0.05` source before production launch.
The fit took 1,747.9 seconds and the candidate forecast took 788.2 seconds;
observed maximum resident memory was approximately 2.2 GiB and 2.64 GiB,
respectively. The reconstructed native forecast MAE and check-loss summaries
matched their historical authority exactly at the recorded precision (maximum
absolute difference zero), and native lattice reconstruction differed only at
floating-point scale (maximum absolute difference `4.44e-14`).

For this canary only, the candidate reduced the posterior forecast-MAE interval
width from 9.4635 to 8.6707 and the check-loss interval width from 0.4429 to
0.3243. Its point forecast MAE changed from 6.2959 to 6.0979 and point check
loss from 1.1939 to 1.1868. These values are engineering evidence, not a
scientific decision: acceptance still requires the complete 72-role surface
and all predeclared gates. A separate latest-code 40-draw integration smoke
verified the final innovation ledger, including the exact full-block seed,
tail seed offset of 31, 33 complete origins, one truncated origin, and selected
posterior-index hash.
