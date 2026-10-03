# Independent Q-DESN MCMC Bridge v9

## Decision and Scientific Scope

Implement a bounded inference-transfer experiment, not another broad screen.
The completed v8 paired VB campaign supports two exact challengers relative
to their case-specific v6 controls, but does not yet close the comparator gap.
The immediate question is whether these fixed designs retain their gains
under direct MCMC with the corrected design and forecast operators.

This is IND QDESN VAL only. Article-v2, Overleaf, integration branches, shared
validation, unrelated applications and their jobs remain untouched. Only this
dedicated task branch may be committed and pushed; the integration coordinator
alone may merge or publish. No fitted-model cleanup is required for v8's small,
useful evidence. The held legacy v2 launcher and its 168 unstarted jobs are not
part of this campaign and must not be resumed or signaled.

## Audit Basis and Limits

Scientific base: validation/independent-qdesn-paired-forecast-v8-20261002,
HEAD da74bb370edfb3f7e1c5c0c07332be1f9d7c220b.
Fresh fetch shows this is a 27-commit descendant of the shared-validation
authority, with no commits unique to shared validation. Preserve this tested
source base; do not merge unrelated main/package changes into a frozen run.

Frozen v8 evidence:

```
/data/jaguir26/local/src/exdqlm__wt__independent_qdesn_paired_forecast_v8_20261002/validation/fitforecast_v2/local_trackers/independent_qdesn_paired_forecast_v8_20261002__git-da74bb37
```

The last complete audit verified 20/20 successful jobs, 1,172 source/input/
materialization/final-manifest rows, 180 exact fitted-state checks, and 24
same-seed score replays. Independent origin/lead recalculation agreed within
6.6e-14. The focused suite passed 289 expectations; six VB smokes passed.
No v8 jobs remain. Storage is about 13 MiB allocated, with no model binaries.
These are source-runtime VB results, not new CRAN-only fits or MCMC evidence.

| Normal Case | Control MAE | Challenger MAE | Relative Gain | VB Comparator |
|---|---:|---:|---:|---:|
| AL p=0.05 | 4.363935 | 3.993730 | 8.48% | DQLM 2.050253 |
| exAL p=0.25 | 6.637913 | 3.272953 | 50.69% | exDQLM 1.705392 |

All three forecast seeds and all thirty lead averages favor challenger MAE.
The AL challenger slightly worsens conditional check loss (1.290702 versus
1.288142) and fails in a localized origin block. The exAL challenger still
has negative location bias. Narrower draw-score bands alone do not establish
posterior calibration, mixing, or superiority over matched MCMC comparators.
The three v8 repetitions reuse the same fitted VB distribution; they are
forecast Monte Carlo replications, not independent chains or DGP replicates.

Additional saved audit and numerical ledgers:

```
<v8 worktree>/validation/fitforecast_v2/local_trackers/paired_forecast_v8_health_20261003_PDT
```

## Exact Fixed Designs

The materializer copies the four v8 `paired_confirmation`, seed-index-one
configs. Candidate objects, source trajectories, full-precision parameters,
normal initializers, preprocessing and fit RNG are copied, never reconstructed
from rounded prose. These are two Q-DESN challenger/control pairs, not four
different model classes.

| Case | Role | D | n | m | Readout Columns |
|---|---|---:|---|---:|---:|
| Normal AL p=.05 | challenger | 4 | 20;20;20;20 | 120 | 81 |
| Normal AL p=.05 | control | 2 | 40;20 | 240 | 61 |
| Normal exAL p=.25 | challenger | 2 | 40;20 | 240 | 61 |
| Normal exAL p=.25 | control | 1 | 20 | 30 | 21 |

All four retain tau0=0.998613997947909, s2=1, RHS-NS, and an unshrunk intercept.
The AL challenger has alpha=.745878723354877, rho=.760424185339073 and input
gain=.3. The exAL challenger has alpha=.471893317068923,
rho=.986627020238116 and input gain=1. All other values come from frozen
configs. Q matrices remain identity; n_tilde equal to the previous layer width
is an identity dimension, not evidence of reduction. Readout is intercept
plus every reservoir layer, with no direct input-lag columns.

## Initialization: Root Correction

Do not call the old v2 MCMC worker. Its implicit 100-iteration diagonal VB
warm start and older score aggregation do not match the corrected v8 protocol.

Each v9 worker instead:

1. Verifies frozen inputs, source/native hashes, configs and run HEAD.
2. Restores the original normal initializer and its recorded RNG state.
3. Replays v8 full-coupled quantile VB with the same 750-iteration ceiling,
   tolerances 1e-4, xi sample count 400 and structured scale-shape operator.
4. Compares design/response hashes, iteration count, beta moments/full
   covariance, gamma/sigma means and point-fit metrics against v8 at 1e-6.
5. Maps beta, gamma, sigma and positive latent summaries into explicit MCMC
   initial values. Sets `init_from_vb=FALSE`; no second hidden VB warm start.
6. Constructs fresh RHS state from unchanged priors. No learned posterior
   distribution is reused as a new prior and no likelihood data are counted
   twice. Reusing a state for initialization alone leaves the target unchanged.
7. Reuses the verified design directly in the canonical exal_mcmc_fit readout
   API, checks its hash, prior hyperparameters and actual recorded kernel.

Prelaunch smoke found the generic MCMC control normalizer discards rng_seed.
The validation adapter pins this field after normalization and asserts the
returned fit's control seed. No shared package/API change is needed. Smokes
check same-seed exact replay AND different-seed nonidentical draws; otherwise
nominally independent chains could silently repeat the same stream.

Final preflight passed 386 regression expectations and six AL/exAL replay/
independent-seed smokes with no failures or test warnings. Resource sampling
verified cores 25--30 and their SMT siblings were 98.7--100% idle, with about
482 GiB available memory and 382 GiB free disk. The launcher rechecks all six
physical cores before each stage; resource availability is not assumed fixed.

Explicit exAL kernel is `m0_v_collapsed_support_logit`. AL uses
`sigma_then_gamma`, gamma fixed at zero and no gamma refresh. This Q-DESN
readout interface is distinct from exDQLM's `mh.proposal="collapsed_slice"`.
Actual returned fit diagnostics, not just requested arguments, must pass.

## Forecast and Score Contract

Keep fit 8501:8750 and development 8751:9000. There are 45 origins,
8750:8970 at stride 5, horizon 1:30, and 1,350 scored lead-target pairs.
No 9001:10000 score enters this bounded experiment. Model parameters are not
refit at each origin. Observed history updates the input and reservoir state
between origins; unknown future lags recurse within each origin's paths.
Training-only response transport and input scaling are identical to v8.

Use the corrected v3 nested-lattice operator, inverse-transform before scoring,
and retain distinct channels:

- Primary: oracle MAE of the posterior-mean conditional-location forecast.
- Secondary: oracle RMSE and realized-observation check loss for that path.
- Sensitivity: check loss of the pooled posterior predictive quantile.
- Uncertainty: per-posterior-draw fit and forecast scores and quantile paths.

The mean of draw-specific errors is not the error of the posterior mean.
Do not change either estimator's name or silently interchange them. Preserve
uniform origin/lead weights, bad-origin rows and diagnostic disclosure.
Granular means must reconstruct primary scalar scores within 1e-6. Intervals
reflect posterior score variation conditional on the data and design; they
are not confidence intervals for population generalization performance.
Finite inner-path/outer-draw Monte Carlo error remains; full confirmations
increase outer draws rather than claiming an exact integral.

## Bounded Stages and Scheduling

| Stage | Jobs | Burn | Retained | Scored Draws | Inner Paths | Origins |
|---|---:|---:|---:|---:|---:|---:|
| Tiny synthetic engineering | 6 | 5 | 12 | 4 | 4 | 2, H=3 |
| Actual-design cost/warm checks | 4 | 100 | 200 | 8 | 32 | 2, H=30 |
| Scientific paired pilots | 4 | 1,000 | 4,000 | 120 | 128 | 45 |
| Conditional three-chain confirmation | 0, 6 or 12 | 5,000 | 20,000 | 300 | 128 | 45 |

All chains thin 1. Engineering smokes verify AL/exAL modes and exact seeded
parameter/score replay. Cost jobs use all four actual designs and full verified
VB initialization. Project MCMC iterations and forecast draw/path/pair cost
separately. Require a twofold safety margin below six hours per pilot and
twelve hours per confirmation. Recompute confirmation cost from actual pilots.
These are explicit spending limits, not validated runtime predictions.

Pre-materialize all twenty configs, hashes and seeds, so confirmation cannot
silently alter architecture, chain budget, priors or score weights. Chain seeds
are distinct across cases/stages/chain indices; matched roles share the same
seed and forecast-noise stream. Independent chains are seeded separately,
but use a common verified starting state within each design. Record this fact.

After all four pilots finish successfully, select a case for confirmation if
the challenger has any finite strict improvement in primary MAE, conditional
check loss, or pooled predictive check loss, and its measured cost fits the cap.
No minimum gain magnitude or diagnostic-grade veto applies. Fit-only gain does
not trigger forecast confirmation. A selected case confirms both roles with
three fresh chains. Nonselected confirmation configs are `NOT_SELECTED`, not
stalled jobs. Numerical/contracts failures stop new scheduling and drain active
lane workers; they are not ignored as if they were mere mixing warnings.

At most six freshly checked idle physical cores, one process and one numerical
thread per core. Cost and pilot stages have four workers; confirmation has up
to six concurrently. Check sibling topology, active affinities, memory and disk
immediately before detached tmux launch. Exclusive flock prevents duplicate
launchers. Atomic worker statuses, hashed artifacts, per-worker logs, exit
codes and timeouts support honest health reporting and safe reruns of failures.
Never signal another lane or restart the held legacy campaign.

## Outputs, Validation and Closeout

Keep source/input/materialization/final manifests; full configs and seeds;
VB warm-replay contracts; MCMC initial-state records; actual kernel and prior
diagnostics; all retained beta/gamma/sigma draws as compressed CSV; ESS and
traces; selected fit/forecast quantile paths; score draws; origin/lead profiles;
chain-specific scores; equal-weight three-chain summaries; classical R-hat
with constant AL gamma explicitly marked. No favorable-chain cherry-picking.
R-hat is descriptive, not a guarantee or silent exclusion rule.

Runtime is pinned R 4.6.0 and validation-source exdqlm 1.1.1 using pkgload,
including the corrected coupled-beta source and unchanged native library.
It is NOT described as an unmodified CRAN binary. Native SHA-256:
fbccca63f606e30ecc93aea84d10168b34e5b914ce81dc20509372fab897df8b.
All source/native/config hashes and session/thread/compiler details are saved.
Run directories and tests/smoke artifacts remain Git-ignored. Fitted RDS/RDA/
RData files are neither needed nor generated. Do not remove current evidence.

Before launch, run new adapter tests plus v8/v7/v6/solver/corrected-forecast
regressions; check shell syntax and synthetic seeded replay. Materialization
refuses dirty branches, failed tests, overwritten runs and invalid v8 evidence.

This implementation deliberately stops at internal matched MCMC evidence.
No broad refinement grid or article evaluation is justified before results.
Cached DQLM/exDQLM development references are VB. They may contextualize but
cannot establish MCMC superiority. Reuse a matched cached MCMC comparator only
if data/windows/origins/leads/scoring match; otherwise propose only missing
two-case comparators later. Do not automatically refit all baseline models.

Article promotion requires a separately frozen 500-observation evaluation and
complete matched reporting evidence. Do not insert internal 250-observation
results into article MCMC tables. Keep every finite gain in the ledger, including
tiny gains, but retain better sources for regressing criteria and disclose
diagnostic caveats. Fresh DGP replication remains the strongest later unbiased
check after the final protocol is fixed.

When complete, prepare coordinator handoff: branch/upstream/full HEAD, ancestry,
exact task-owned files, counts, tests, run tag, manifest hashes, storage status,
excluded runtime paths, interpretation and article decision. While jobs are
active the lane is NOT_READY_FOR_INTEGRATION. No main/shared/Overleaf write.

## Reproduction Commands

From the new dedicated worktree, with R 4.6.0:

```
Rscript validation/fitforecast_v2/scripts/test_independent_qdesn_mcmc_bridge_v9.R "$PWD" TEST_DIR
Rscript validation/fitforecast_v2/scripts/smoke_independent_qdesn_mcmc_bridge_v9.R "$PWD" SMOKE_DIR
# Commit and push only the dedicated task branch before materialization.
Rscript validation/fitforecast_v2/scripts/independent_qdesn_mcmc_bridge_v9.R "$PWD" materialize RUN_DIR V8_RUN TEST_DIR/test_results.csv SMOKE_DIR/smoke_summary.csv
REPO_ROOT="$PWD" RUN_ROOT=RUN_DIR CPU_LIST=VERIFIED_SIX_CPUS bash validation/fitforecast_v2/scripts/run_independent_qdesn_mcmc_bridge_v9.sh
Rscript validation/fitforecast_v2/scripts/independent_qdesn_mcmc_bridge_v9.R "$PWD" health RUN_DIR
```

The shell launcher owns cost gating, paired pilots, conditional confirmation
and final audit; do not run a second launcher on the same directory. Review
pipeline.status, launcher_exit_codes.csv and progress before any recovery.
