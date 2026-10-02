# Independent Q-DESN corrected-design replay v7

## Objective and audited justification

Reduce the remaining Normal AL p=0.05 and Normal exAL p=0.25 internal
forecast gaps after correcting the coupled quantile-beta update and
weakening excessive RHS shrinkage. This phase is a bounded architecture
replay, not a global winning specification, all-family rerun, normal-VB
selection campaign, MCMC campaign, or article promotion.

v6 at 1b40f7dfef7cc2b65ed39e389af51bfea9d50871 completed 8/8 fits,
two replay controls and a successful numerical 1,201-column benchmark.
All 433 source/input/materialization/final artifact hashes passed at closeout.
v7 materialization independently rechecks these immutable inputs.

| Case | v6 full-coupled 1x MAE | Best v6 MAE | Matched comparator | Remaining ratio |
| --- | ---: | ---: | ---: | ---: |
| Normal AL, p=0.05 | 19.9312 | 4.2777 | DQLM 2.0503 | 2.09 |
| Normal exAL, p=0.25 | 17.2257 | 6.4955 | exDQLM 1.7054 | 3.81 |

Signal recovery improved strongly with larger tau0. The 30x-to-300x
forecast gains were only about 0.99% and 0.30%, so another tau-only ladder
on those same designs is not the preferred next use of compute. AL's
remaining error is already present at lead 1; exAL additionally loses
performance at longer leads. Test alternate representations against actual
internal H30 forecasts, rather than selecting from normal-VB fit alone.

These findings are restricted to two cases and one development trajectory.
They do not prove a universal tau0 or rule out later direct MCMC improvements.
Historical diagonal quantile scores cannot reject an architecture under
the corrected full-coupled operator. Reusing an old design here is a declared
operator/prior replay, not an unnoticed repeat of the same scientific fit.

## Exact design surface

Keep the six source configurations and full-precision numeric values in
their frozen v4 JSON files. The table is descriptive; never reconstruct
configs from its rounded numbers.

| Case | Frozen source candidate | D / layer widths | m | alpha | rho | Input gain |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| AL p=0.05 | iqcb4_normal_al_p005_acc5a4e1a159 | 1 / 20 | 75 | 0.5144502 | 0.3562243 | 3.0 |
| AL p=0.05 | iqcb4_normal_al_p005_3ed9396c0484 | 4 / 20;20;20;20 | 120 | 0.7458787 | 0.7604242 | 0.3 |
| AL p=0.05 | iqcb4_normal_al_p005_462ef9273443 | 1 / 400 | 120 | 0.9322732 | 0.9915876 | 0.3 |
| exAL p=0.25 | iqcb4_normal_exal_p025_7ab7e7c72b85 | 1 / 40 | 150 | 0.7772289 | 0.6584444 | 3.0 |
| exAL p=0.25 | iqcb4_normal_exal_p025_f52df3dcb74e | 2 / 40;20 | 240 | 0.4718933 | 0.9866270 | 1.0 |
| exAL p=0.25 | iqcb4_normal_exal_p025_ad5e720aaf0d | 1 / 400 | 120 | 0.9322732 | 0.9915876 | 0.3 |

Two explicit model-scale tau0 values per design:
0.0998613997947909 and 0.998613997947909. Both retain slab s2=1 and an
unshrunk intercept. Source-scale tau0 is recomputed from the frozen,
training-only response SD. Original multiplier labels remain audit metadata,
not the rule defining the new prior. These are tested starting brackets;
their suitability for every width is not presumed.

This gives 12 new scientific jobs. Reuse the four v6 30x/300x results as
case-matched controls, without refitting them or the DQLM/exDQLM comparators.
Names such as current_article_authority or ridge_forecast_best identify
historical proposal provenance, not a freshly audited article winner and
not a ridge model to refit. All new readouts use quantile RHS inference.

## Invariants and deliberate changes

- Exact same per-case source trajectory, target level, training/development
  windows, origin grid, horizons, quantile-VB budget and scoring rules as v6.
- Full coupled quantile-beta update; no diagonal fallback and no package
  inference-default changes. Runtime is validation-source exdqlm 1.1.1 with
  R 4.6.0, not an unmodified CRAN binary.
- Identity Q at every layer transition, no dimension reduction, frozen
  topology/activation/scaling/weight distribution/reservoir seeds from each
  source design. Intercept plus all reservoir layers at the readout, with
  no direct lag readout terms. No exogenous variables in these cases.
- Reproduce and freeze one original normal-VB initializer per design.
  Both tau arms share its beta mean/covariance and sigma. The quantile RHS
  state is fresh at each arm's prior; no posterior-to-prior recycling.
- Use the existing v6 case forecast seed for all new designs in that case.
  Original v4 job seeds differ and are explicitly recorded alongside the
  paired seeds in design_provenance.csv. This changes historical forecast
  seeds intentionally, not the reservoir or data seeds.
- Scientific changes are the declared DESN design and model-scale tau0.
  Worker checks protect every other scientific field and candidate field.

The same normal initializer does not identify a unique VB optimum or
separate hyperprior effects from fresh-state initialization. Those are
limitations to report, not reasons to exclude a finite strict improvement.

## Evaluation contract

Fit 8501:8750; internal development 8751:9000. Use 45 origins at stride 5,
leads 1-30, and 1,350 scored origin/lead pairs. Teacher forcing updates
observed history between origins; forecast future inputs recursively
within each origin. Do not refit per origin or feed future observations
into an origin's forecast. Learned preprocessing uses fitting observations.

Quantile VB: maximum 750 iterations, tol=1e-4, n_samp_xi=400. Forecast:
16 outer posterior draws, 128 inner paths. Primary internal criterion is
oracle MAE of the posterior-mean conditional-location path. Also rank
pooled posterior-predictive quantile check loss separately. Retain all
other estimators and draw-level metrics without conflating their estimands.

Maintain fit point RMSE, draw-wise fit metrics, amplitude/bias, convergence
flags, coefficient precision and origin/lead granular outputs. A VB
convergence flag is not MCMC mixing. The 16-draw ranges are screening
summaries, not certified article interval tails. Overlapping origins are
not independent observations; do not impose significance gates on them.

## Engineering checks and efficient execution

Before production, run two cost-only smokes on the actual 401-column
designs, one per likelihood. Each uses the original 250-row fit, eight
quantile-VB iterations, xi budget 64, two origins, H30, four outer draws
and 32 inner paths. These tiny budgets are explicit and excluded from
every scientific comparison and winner list.

Record elapsed quantile fitting and recursive-forecast/artifact time.
Conservative projection: fitting time / 8 * 750 plus forecasting time
* (45/2) * (16/4) * (128/32). This is a sizing estimate, not an exact runtime
guarantee. Include a factor of two headroom within a six-hour job timeout.
If either smoke fails numerically or exceeds this cap, hold all production
scheduling for investigation; do not silently drop the wide design or
reduce its scientific budget. No full-budget ranking mixes with the smokes.

The earlier v6 single unit-weight solve was not an end-to-end cost test;
these cost smokes are the specific improvement to the previous plan.
Focused tests verify field protection, cost-stage exclusion, projection,
exit handling and scheduling. Actual mock-worker executions cover a successful
pool, a failed cost gate, and a failed worker with clean draining of active
jobs. The scheduler uses per-PID polling and wait, compatible with this
server's Bash without the unavailable wait -p option. Four synthetic
AL/exAL smoke jobs verify the
actual initializer, full-coupled fit, recursive forecast, telemetry and hashes.

Use up to six verified idle CPUs, one assigned core per worker, with BLAS,
OpenMP and related numerical threading set to one. Six is a bounded resource
choice for this 12-job replay, not a demand to occupy all available cores.
Launch longest/widest jobs first and refill each CPU slot immediately on
completion. This avoids waiting for the slowest job in a fixed wave.

The launcher owns an exclusive lock, records job-id-based exit codes, and
signals only its own timeout processes if interrupted. A job failure stops
new scheduling while already active jobs finish. Cost jobs have 30-minute
timeouts; production jobs have six-hour timeouts. Source, native library,
input, config, initializer, test and smoke hashes plus the exact committed
HEAD must match before each worker starts. Materialization validates the
scientific contract after JSON round-trip as well as before serialization;
integer-valued cost budgets use canonical integer types. Persist terminal status before
writing the final artifact manifest. Hash-valid completed jobs can be reused.

## Decisions and bounded continuation

When all 12 scientific jobs finish, compare their scores with the four
cached controls and the frozen matched comparators. Select separately
within each likelihood/quantile case and metric. Preserve every strict
finite gain, however small. Do not require one design to dominate both
cases, all criteria, or a convergence threshold. Numerical/data/hash
contract failures remain distinct from diagnostic grades.

Write comparison.csv, per_case_internal_winners.csv,
internal_confirmation_candidates.csv and decision.json. If there is no
new strict gain, retain v6. If gains exist, freeze the selected configs
and prepare repeated-seed/larger-draw internal confirmation. Do not
automatically launch it with an unbudgeted draw count, refit all four
model classes, expand to the other 16 cells, or launch MCMC.

This implementation covers freeze, materialization, tests, smokes,
cost-gated production, metric-specific audit and finalist preparation.
Later confirmation/MCMC/article stages are evidence-dependent roadmap
steps, not permission to run unrelated or automatically expensive work.

For later article replacement, confirm case-specific finalists on the
500-row training window and full external forecast protocol, with explicit
exact M0 for exAL MCMC and the frozen AL transition. VB rankings are not
guaranteed MCMC rankings. Preserve clearly labeled posterior score summaries;
fresh DGP replicates later address repeated development/external-block reuse.
Only the coordinator integrates and publishes article-safe outputs.

## Ownership, storage and reproducibility

Create a dedicated IND continuation worktree from the frozen v6 commit,
which has not yet been integrated. Commit and push only its task branch
using command-line Git. No shared-validation, integration, article-main
or Overleaf merges or pushes. Do not edit another lane or interrupt jobs.

All runtime outputs stay in ignored validation/fitforecast_v2/local_trackers.
Keep source/config/environment/provenance/hash manifests and compact
JSON/CSV/CSV.gz score, fit, trace and timing artifacts. Retain the small
initializer JSON needed to replay the paired priors. No fitted-model
RDS/RDA/RData outputs, no old artifact deletion, and no cleanup of ambiguous
ownership. The completed v6 run and worktree stay immutable.

Commands, using /data/jaguir26/local/opt/R/4.6.0/bin/Rscript --vanilla:

```bash
Rscript --vanilla validation/fitforecast_v2/scripts/test_independent_qdesn_coupled_design_v7.R "$PWD" "$TEST_ROOT"
Rscript --vanilla validation/fitforecast_v2/scripts/smoke_independent_qdesn_coupled_design_v7.R "$PWD" "$SMOKE_ROOT"
Rscript --vanilla validation/fitforecast_v2/scripts/independent_qdesn_coupled_design_v7.R "$PWD" materialize "$RUN_ROOT" "$V6_RUN"
REPO_ROOT="$PWD" RUN_ROOT="$RUN_ROOT" CPU_LIST="48,49,50,51,52,53" bash validation/fitforecast_v2/scripts/run_independent_qdesn_coupled_design_v7.sh
Rscript --vanilla validation/fitforecast_v2/scripts/independent_qdesn_coupled_design_v7.R "$PWD" health "$RUN_ROOT"
```

Verify the example CPU list immediately before launch. Expected preflight
paths are local_trackers/coupled_design_v7_tests_20261002 and
local_trackers/coupled_design_v7_smoke_20261002 beneath validation/fitforecast_v2.
