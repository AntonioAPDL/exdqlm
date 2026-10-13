# Independent Q-DESN Readout and Memory v13

## Decision and Scope

Approved next stage after the completed v12 dynamic-location mechanism screen.
This is a controlled, case-specific AL-RHS experiment on Gaussian-mixture
p=0.05. It is not a nine-cell replacement or another global winner search.
The existing architecture is retained. No Article-v2, shared-validation, main,
integration, or Overleaf publication is authorized by this implementation.

v12 completed 30/30 recovered logical jobs with no remaining active work.
The moderate offset reduced average oracle MAE by 1.81%, but increased observed
forecast check loss by 1.15% and average native MAE interval width by 10.28%.
The selected weak offset did not beat the static control on observed check loss.
Consequently the old 66 conditional v12 jobs are not launched. Its evidence,
partial improvements, and failed first-attempt cache-race logs remain intact.

Independent no-refit diagnostics found:

- Supplying actual future lag observations did not repair aggregate static or
  weak-offset MAE; this is a nonpublishable diagnostic, not a forecast method.
- Oracle-informed ridge readouts on the same states recovered substantially
  more signal. Weak regularization could have excellent fit and very poor
  generalization. Oracle labels are not permitted in empirical model fitting
  or ranking. This does not prove that changing tau0 will solve the problem.
- The first-layer unsaturated linear-reference half-life was approximately
  11,053 steps. Initial-state differences remained after the 500-step washout.
  This is evidence for testing effective memory, not a nonlinear forgetting
  theorem or proof that memory alone caused the forecast problem.

The efficient next test is readout estimation and memory, not immediately
500 weights per layer, another input-noise law, or a forced narrowing of bands.

## Frozen Contrasts

Reference: n=(141,119,90), D=3, m=360, matrix seed 920001,
alpha=0.068443827906661, rho=0.99908375813834;
tau_source=0.121662529084868, slab_source=159.823274579482.

| Arm | tau_source multiplier | b_zeta multiplier | alpha | rho |
|---|---:|---:|---:|---:|
| tau_half | 0.5 | 1 | reference | reference |
| slab_quarter | 1 | 0.25 | reference | reference |
| joint_shrink | 0.5 | 0.25 | reference | reference |
| memory040 | 1 | 1 | 0.40 | 1-(1-2^(-1/80))/0.40 |
| memory099 | 1 | 1 | 0.99 | 1-(1-2^(-1/80))/0.99 |

The memory pairs use a provisional 80-step positive-eigenvalue reference, not
a claimed optimal rho. Actual layer eigenvalues and observed initialization
dependence are saved for each fit. Equal reference half-life does not imply
equal nonlinear memory or equally informative features.

RHS_NS is used, not an unrecorded change to another horseshoe variant.
For response SD s computed at each fit prefix, tau0=tau_source/s and
b_zeta=slab_source/s^2, with a_zeta=2. The global half-Cauchy scale controls
shrinkage near zero; the inverse-gamma slab variance scale controls large
coefficient regularization. A quarter variance scale is not a quarter standard
deviation and does not fix the learned slab variance to a constant.
Intercept precision remains 1e-16*s^2 and the intercept is not shrunk.
Sigma prior and normal initializer variance prior remain unchanged.
No outcome re-centering, extra predictors, dimensional reduction or hidden
state innovation is introduced. Identity Q, tanh state activation, identity
interlayer activation, exact fan-in topology, input gain and input bounds are
unchanged. Readout is intercept,L3,L1,L2, with no raw input lags. Fold z-scoring
and layer multipliers (1,0.25,1) remain fixed.

## Comparable Evaluation

| Fold | Fit source indices | Origins | End | Scored primary pairs |
|---|---|---|---:|---:|
| A | 7001:8000 | 8000:8210 by 30 | 8240 | 240 |
| B | 7001:8300 | 8300:8510 by 30 | 8540 | 240 |
| C, conditional | 7001:8600 | 8600:8810 by 30 | 8840 | 240 |
| Final, fresh DGPs | 7001:9000 | 9000:9990 by 30 | 10000 | 1000 |

Washout is 6501:7000; lag buffer is 6001:6500. Origins are every 30 observations,
not daily. Lead horizon is 30, clipped at the end. Alternate origin phases
+10/+20 are forecast-only companions with 230/220 pairs in internal folds.
Those replays reuse fits and are not additional fitted-model jobs.
Training is causal: input median/MAD uses observed history through the fitting
prefix including the buffer; readout conditioning and response SD are fitted
from the likelihood window. It is not strictly fitting-window-only input scaling.
Teacher forcing applies between origins; forecasts recurse inside each origin.
Q-DESN coefficients remain fixed between origins, while DQLM latent states are
filtered using newly available observations. This structural difference is
disclosed, not concealed as a matched adaptive-parameter model.

Selection uses F1 (81112001,81112002) and F2 (81113001,81113002) trajectories.
Internal A/B models exclude the later training observations and the inspected
9001:10000 block. No draws fitted at time 9000 initialize earlier prefix fits.
The seeds match v12 within each cell across contrasts for controlled comparison;
shared seeds do not constitute identical posterior draws between models.
The current historical test block is not a pristine research-process holdout.

## Screening, Review and Confirmation

The initial tranche is 42 new logical jobs:
2 real-data technical smokes (joint_shrink and memory099),
20 normal-RHS-VB then quantile-VB initializer jobs,
20 direct AL quantile-MCMC selection fits (5 arms x 2 replicas x 2 folds).
A Q-DESN initializer has two inference calls inside one logical job; it is not
being represented as a single inference fit. Initializers are candidate- and
prefix-specific, with no prior-state transfer into MCMC. MCMC uses 1,500 burn-in
plus 5,000 retained draws, 300 outer draws and 128 inner paths. VB rank is not a
performance gate. Every changed candidate gets a newly fitted initializer.

Eight completed matched controls (4 DQLM and 4 static Q-DESN) are imported as
read-only evidence, not refitted. Import requires matching executed parameters,
window, source hashes, seeds, budgets, draw counts, numerical source hashes,
installed package closure and scoring code. Paths and obsolete labels are not
scientific identities. Manifests include the referenced original evidence, so
compaction of those controls must be forbidden until closeout and handoff.

Before launch, inspect archived IND config directories and compute typed
signatures from executed fields rather than inherited descriptive strings.
Record the audited root/config inventory and all same-regime hits. A discovered
exact repeat fails materialization pending explicit evidence-reuse design.
Historical normal-VB ranks and pre-M0 exAL failures are not exclusions for an
AL quantile-MCMC contrast. This novelty claim is bounded by the saved inventory,
not a claim to have rediscovered every undocumented run on the server.

Rank by average observed internal forecast check loss across matched A/B cells.
Report every finite strict metric gain, however small, per cell and as averages,
and all width, coverage and mean-path tradeoffs. Diagnostic flags are disclosure,
not exclusions. Do not pick a different architecture by realized DGP seed or
individual internal fold and call it a family/quantile winner.
The scheduler stops for scientific review after selection; it does not
automatically spend the conditional budget or promote favorable partial scores.

Conditional pipeline is fully wired, but needs an explicit continue command
and a strict observed check-loss gain over static (no minimum effect cutoff):
6 initializer jobs + 18 three-chain MCMC jobs for disjoint fold C, then
12 initializer jobs + 36 three-chain MCMC jobs for four newly seeded final DGPs.
That is at most 72 additional logical jobs, not the old dynamic 66-job budget.
Review must consider both forecast accuracy and uncertainty, not check loss
alone; retain secondary MAE improvements even if the primary contrast fails.
Fresh seeds are N1=(81511001,81511002), N2=(81512001,81512002),
N3=(81513001,81513002), N4=(81514001,81514002).
Fresh models use 2,000 likelihood observations, 500 washout and a 1,000-target
forecast block. Canonical confirmation uses 3,000 burn-in plus 10,000 retained
draws, 300 outer draws and 128 inner paths. No chain-health promotion threshold.

## Metrics and Uncertainty

For draw j and known oracle q_t, fit RMSE is
sqrt(mean_t((qhat_t,j-q_t)^2)); forecast MAE is
mean_(origin,lead)(abs(qhat_origin,lead,j-q_target)).
Forecast RMSE and observed fit/forecast check loss are also retained.
Check loss is r*(p-I(r<0)), r=y-qhat, averaged over the relevant rows.
Each metric's mean and type-8 equal-tail 2.5%/97.5% endpoints use draw-level
scores. Score of the posterior mean path is a distinct diagnostic.
The forecasted quantity is an inner average of conditional location paths,
not the p-quantile of a posterior predictive mixture or an observation interval.
Numerical reproduction tolerance is 1e-6. No score rounding before comparisons.

Q-DESN couples scores through the same coefficient draw over forecast rows.
Current DQLM tools have latent-marginal/product coupling. Native aggregate score
bands are not directly interchangeable joint-functional precision estimates.
Save native bands unchanged, pointwise quantile bands, oracle inclusion,
interval score and covariance attribution. Do not shuffle draws, truncate tails,
pool across DGP replicas or silently change estimands to manufacture narrow bands.
Pool confirmation chains within a replica only. R-hat/ESS of nuisance parameters
are descriptive. Randomly selected posterior path draws are not chronological
traces suitable for parameter ESS calculations.

## Artifacts and Execution

New study-local module, CLI, scheduler, tests and this protocol only; private
package/runtime functions and all previous phase scripts remain byte-identical.
Pinned CRAN exdqlm 1.1.2 and R 4.6.0 environment, package hashes, compiler flags,
BLAS/LAPACK, RNG and thread variables are recorded. This AL sentinel fixes gamma
to zero; it neither replaces nor retests exact exAL M0.
No new C++ helper is required. No worker calls sourceCpp or writes its shared
cache, retaining the root correction from the v12 cache-race recovery.

Scheduler is fail-closed, single-owner flock, no automatic retries, and drains
active jobs after a failure or STOP_NEW_SCHEDULING. One worker per free physical
core, one numerical thread, maximum 30 cores, memory floor 128 GiB. The largest
selection stage has 20 jobs, so it uses at most 20 cores, not 30 idle processes.
Use a separate tmux session on muscat and leave all other lanes untouched.
This inherited resource probe checks load and pinned R/Python affinities; it is
not an operating-system-wide reservation service for other users' future jobs.

Run outputs stay in ignored validation/fitforecast_v2/local_trackers:
CSV/GZ posterior locations, selected parameters, chronological nuisance traces,
metric draws, phase summaries, origin/lead profiles, covariance attribution,
first-step guards, actual raw tanh/memory diagnostics and hash manifests.
No fitted RDS/RDA/RData payloads. No old output deletion is authorized here.
Review PDFs include all seven arms' scores and selected-versus-control fit and
forecast paths, origin/lead profiles and common-scale heatmaps.
Full article replacement requires a later frozen coordinator handoff; this
single-cell screen is NOT_READY_FOR_INTEGRATION while compute/review remain.

## Reproduction Commands

```bash
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
R=/data/jaguir26/local/opt/R/4.6.0/bin/Rscript
CLI="$REPO/validation/fitforecast_v2/scripts/independent_qdesn_readout_memory_v13.R"
export IRM13_REPO="$REPO" IRM13_TEST_EVIDENCE="$TEST_EVIDENCE"
"$R" "$CLI" history-roots "$REPO" "$HISTORY_ROOTS"
"$R" "$REPO/validation/fitforecast_v2/tests/test_independent_qdesn_readout_memory_v13.R"
"$R" "$CLI" materialize "$REPO" "$RUN" "$PARENT" "$TEST_EVIDENCE" "$HISTORY_ROOTS"
bash "$REPO/validation/fitforecast_v2/scripts/run_independent_qdesn_readout_memory_v13.sh" "$REPO" "$RUN" 30 selection
"$R" "$CLI" health "$REPO" "$RUN"
"$R" "$CLI" verify "$REPO" "$RUN"
# Explicit review/authorization before either conditional tranche:
"$R" "$CLI" continue "$REPO" "$RUN" confirmation_warm
bash "$REPO/validation/fitforecast_v2/scripts/run_independent_qdesn_readout_memory_v13.sh" "$REPO" "$RUN" 30 confirmation
"$R" "$CLI" continue "$REPO" "$RUN" fresh_warm
bash "$REPO/validation/fitforecast_v2/scripts/run_independent_qdesn_readout_memory_v13.sh" "$REPO" "$RUN" 30 fresh
```

The source worktree must be clean before materialization. Commit/push only the
dedicated IND branch using command-line Git. Preserve its pending v11/v12
ancestry; do not rebase or discard it to appear synchronized with shared main.

## Scientific Basis and Limits

The distinction between sparsity/global shrinkage and regularization of large
coefficients motivates separate contrasts, not guaranteed improvement:
[Piironen and Vehtari, regularized horseshoe](https://arxiv.org/abs/1707.01694).
Sequential prefix validation estimates multi-step forecast behavior without
using future observations in fitting:
[Forecasting: Principles and Practice, time-series cross-validation](https://otexts.com/fpp3/toolbox.html#time-series-cross-validation).
The precise prior contrasts and 80-step memory target are empirical hypotheses
from the local audit, not recommendations established by these references.
