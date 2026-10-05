# Targeted repaired-protocol forecast continuation v11

## Evidence and objective

Improve independent Q-DESN forecast recovery without restarting all families
or selecting by training fit alone. This is a two-case internal-development
campaign, not an article replacement campaign.

V10 completed fourteen compatibility replays with 147 numerical checks at
1e-6. The repaired exAL Gaussian p=0.25 challenger improved all four point
criteria in each of three paired chains: mean forecast oracle MAE 3.049042
versus control 8.601532. The retained exDQLM VB reference was 1.705392,
not a matched MCMC comparator. Later origins showed underprediction and
longer-lead errors. AL Gaussian p=0.05 improved fit but worsened MCMC
forecast MAE and check loss. Therefore retain exAL's challenger and AL's
control as independently frozen case anchors. Their structures happen to
match (D=2, n=40;20, m=240); this is not a global specification rule.

Repairing the input basis did not solve all forecast underperformance.
Wide score intervals do not prove a variance-only problem. Score-of-mean
path and posterior mean loss are distinct.

## Critical decisions

| Choice | Evidence / rationale | Limitation |
| --- | --- | --- |
| Freeze repair before fitting | Training draws, feature prefixes and H1 verified | Compatibility repair is not forecast remediation |
| Internal forecast selection | AL fit rank failed to transfer | Reused internal development is not untouched confirmation |
| Separate MAE and check loss | Existing metric tradeoffs | Oracle-assisted simulation selection is not deployable empirical selection |
| Same-structure tau sensitivity | Isolates shrinkage from representation | Smaller tau can lose signal; it does not directly set forecast variance |
| Archived and richer structures | Tests broader learning capacity | Multi-parameter architecture arms do not isolate alpha/rho individually |
| Full quantile VB covariance | Repaired coupled solver verified | Normal/VB ranking remains an imperfect MCMC proxy |
| Paired MCMC pilots | Observed VB/MCMC rank reversal | Two nominees per case cannot guarantee the global optimum |
| Explicit exAL M0 | Avoid historical transition ambiguity | Improved mixing does not ensure improved scores |
| Measured cost gate | Prevent unaffordable expansion | Linear runtime extrapolation is approximate |

This is a bounded, informative continuation, not proof of an optimal
hyperparameter space. Mixing grades are disclosed, not used to veto finite
gains. Implementation validity, manifests and finite numerical outputs are
mandatory. Do not call tiny gains statistically significant.

## Fixed contract

- Fit 8501:8750; internal development 8751:9000. Source begins 8111; washout
  390 gives 250 training / 500 rollout design rows.
- Forty-five origins 8750:5:8970, leads 1:30, 1,350 scored pairs.
- Teacher forcing updates observed lag history and origin reservoir states.
  Unknown outcomes recurse within each origin. No readout refit or latent
  filtering is secretly introduced.
- Affine response transport uses fitting rows only. Input preprocessing uses
  the observed prefix through 8750 including warmup, explicitly frozen for
  every extended design. This preserves the verified historical basis.
- Output lags only; mx=0. Identity Q transitions, tanh recurrent activation,
  identity layer-transition activation. Readout is intercept plus all layer
  states; no raw lags, new time trends or exogenous features in the readout.
- Seed 920001, uniform [-1,1] weights, exact fanin, row-normalized inputs,
  zero state noise, unshrunk intercept.
- RHS-NS s2=1 and case-specific tau0. Fresh RHS prior state for each fit.
  Posterior information provides initialization only, not empirical priors.
- Full quantile VB covariance; structured exAL gamma/sigma VB. Explicit
  m0_v_collapsed_support_logit exAL MCMC; sigma_then_gamma AL, gamma=0.
- Primary forecast estimator mean_conditional_location. Retain four estimator
  sensitivities, but do not retrospectively switch the ranking estimator.
- Runtime exdqlm 1.1.1 validation source with the factory repair, NOT unmodified
  CRAN. Hash compiled runtime and source; record compiler/R/BLAS/session.

## Candidate design

Each case has 18 candidates and seven structures:

1. Anchor structure at tau0 ratios 1, .1, .01, .001, .0001, 3. Current
   standardized-response tau0 is about .998614; source-scale values are
   recorded separately.
2. Three archived structures at ratios 1 and .1. AL: article structure,
   ridge-forecast structure, diverse RHS structure. exAL: article structure,
   ridge-forecast structure, diverse three-layer structure. Refit all as
   RHS quantile models; ridge fits are not final requested models.
3. Three novel structures at ratios 1 and .1:

| Case | D | n | m | alpha | rho | Input gain |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| AL .05 | 2 | 120;80 | 120 | .70 | .950 | .50 |
| AL .05 | 3 | 200;100;100 | 240 | .90 | .995 | .30 |
| AL .05 | 4 | 200;150;100;50 | 300 | .97 | .980 | .70 |
| exAL .25 | 2 | 150;150 | 150 | .60 | .950 | .30 |
| exAL .25 | 3 | 300;150;50 | 300 | .85 | .995 | .50 |
| exAL .25 | 4 | 200;150;100;50 | 240 | .98 | .990 | .25 |

Novel input fan fraction .25, recurrent indegree 20, interlayer fanin 10.
Archived structures keep exact topology/scaling. Maximum width 501 readout
coefficients, no dimension reduction. Spectral assertions check achieved
support and leaky radius. High alpha/rho are tested, not assumed superior.

Deduplicate within-case structures and campaign candidate signatures. Novel
signatures must be absent from the supplied v4 bank. This does not claim
deduplication against every historical run. Archived repeats are explicit
rechecks under repaired preprocessing and M0. Pre-M0 or basis-defective
negative results are not valid exclusions.

## Stages and budgets

| Stage | Jobs | Role |
| --- | ---: | --- |
| Largest-design cost / kernel | 2 | Real fits and runtime measurements; no selection |
| Normal RHS initializers | 14 | One per case/structure, not a ranking gate |
| Quantile VB discovery | 36 | All internal origins; 16 outer draws / 32 inner paths |
| Paired MCMC pilot | Up to 6 | Two distinct nominees plus anchor per case |
| Three-chain confirmation | Up to 18 | Strict pilot forecast gains plus paired anchors |
| Total | Up to 76 | Conditional work is not queued until selected |

Cost workers: 80 VB iterations, two origins, H30, four outer/eight inner
paths; real MCMC 40 burn/160 retained. Estimated discovery per largest
design must be under six hours; confirmation under twelve hours. Failure
stops expansion, not silently simplifying models.

Normal VB: 200 iterations, Woodbury diagonal covariance only as an initializer.
Quantile VB: 750 iterations maximum, tolerance 1e-4, 400 xi samples, full
covariance. Serialization and source/design hashes prevent incompatible
initialization. Save compact explicit VB state for MCMC, avoiding a second
VB refit.

Pilot: 1,000 burn/4,000 retained, 120 outer/128 inner paths.
Confirmation: 5,000 burn/20,000 retained, 300 outer/128 inner paths.
Seeds/noise schedules match across case/stage/chain comparisons; this is
RNG-schedule coupling, not identical model-dependent realized trajectories.

Discovery nominates minimum MAE and minimum check-loss candidates, excluding
anchor and deduplicating. No VB improvement gate. Pilot requires strict
MCMC improvement on either criterion over its matched anchor. Confirmation
compares three-chain mean point scores. Retain every finite gain, however
small, and disclose other-criterion deterioration and chain variation.
These repeated-chain results still use the same internal development data.

## Outputs and diagnoses

Store point metrics, fit paths/draws, forecast location draws, per-draw
fit/forecast losses, origin-by-lead records, all-estimator profiles,
prefix/H1 checks and timings. VB stores moments/covariance/solver diagnostics.
MCMC stores compressed numeric parameter draws, scale/gamma traces, ESS,
kernel, seeds and priors. No fitted-object RDS/RDA/RData or latent dumps.

Closeout: all primary scores, repeated-chain means, equal-tail per-draw
score ranges, every strict criterion gain and an ignored local review PDF.
Intervals describe fixed-data posterior score functionals, not confidence
intervals of the repeated-chain average or frequentist coverage guarantees.

Inspect H1 versus H1:30, early/middle/late origins and signed errors.
Poor H1 suggests conditional transfer; good H1 but drifting longer leads
suggests recursive dynamics. Evaluate a dynamic-readout extension explicitly
only after these contrasts; do not hide it inside forecasting.

## Execution and reproduction

At most six idle physical cores on muscat, initially CPUs 25:30; one
computational thread per model, no interference with other scientific lanes.
Resource checks require unique physical cores and >=90% idle sibling threads.
Wait at most one hour; per-worker timeout twelve hours. Lock attempts,
refuse overwrites, reap all completed peers before replacements, stop new
dispatch on failure, drain active workers and record truthful exit states.

Entry point: validation/fitforecast_v2/scripts/independent_qdesn_targeted_forecast_v11.R
Modes: materialize, dispatch, worker, advance, health, closeout.
Run the dedicated test script first. Materialization arguments:
REPO materialize V10_RUN V4_CANDIDATE_CSV NEW_RUN TEST_DIR.
Launch the dedicated shell script with REPO_ROOT, RUN_ROOT, CPU_LIST.
Plans/configs freeze before dispatch; conditional stages materialize only
after complete upstream validation. Record actual Git HEAD and file hashes.
Preserve failed attempts; no reset or overwrite.

Ignored runtime root:
validation/fitforecast_v2/local_trackers/independent_qdesn_targeted_forecast_v11_*.
No cleanup, unrelated job stop, main merge or Overleaf push.

## Integration and next decision

The branch extends the frozen v10 fix rather than older shared authority,
so required unintegrated repairs are not discarded. Record this dependency.
Commit/push dedicated IND branches only.

Internal winners cannot replace official article scores. After closeout,
freeze candidates and plan selected external confirmation on 8501:9000 /
9001:10000 with matched definitions. Fresh DGP replicates provide stronger
final confirmation; historical external data influenced past decisions.
Do not blanket-refit every family or DQLM comparator.

Only the coordinator integrates shared validation, Article-v2 and Overleaf.
While active: NOT_READY_FOR_INTEGRATION. Frozen handoff must give full
branch/upstream/HEAD, exact files, dependencies, tests, counts, hashes,
storage exclusions, risks and remaining active jobs.

