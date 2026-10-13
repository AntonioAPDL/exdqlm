# Independent Q-DESN Dynamic Location v12

## Decision and Scope

This is an explicitly new scientific model variant, not a correction to the
historical static Q-DESN equations. The completed v11 pilot (26/26, no failures)
has been preserved at 770d57619be85a5a9068e74a716e1749351d7e13. Its retained
layer-scale intervention improves forecast MAE against its anchor on both
fresh trajectories, but still underperforms DQLM on F2 by 13.37%. Late F2
mean-path oracle error is systematically negative and already present at lead
one. Correct causal teacher forcing has been independently verified.

The useful next experiment tests changing location directly, not another
reservoir architecture factorial or an intercept shrinkage presumed to reduce
uncertainty. The static intercept accounts for only 2-4% of the audited
one-step covariance allocation. The evolving offset is intended to address
missing location adaptation, not that variance allocation.

Older v5 dynamic readout experiments used covariance discounting of the whole
readout, with exAL ADF initialization. Here a scalar offset is fitted jointly
under AL, with fixed static RHS coefficients and a separate state evolution
variance. Those are materially different fitting targets and mechanisms.
Success is not guaranteed; a failed internal screen closes this hypothesis.

## Frozen Representation

Gaussian-mixture p=0.05, AL only, gamma=0. This stage does not test exAL M0.
CRAN exdqlm 1.1.2 and R 4.6.0 are reused, with separately hashed private study
extensions. The library and package hashes come from the completed pilot.

Retain D=3, n=(141,119,90), m=360, alpha=0.06844383,
rho=0.999083758, reservoir seed, gains and sparse wiring from the exact
v11 template. Identity Q throughout, tanh state activation, identity
interlayer mapping, intercept plus all reservoir layers at readout, no raw
input coefficients. Fold-standardized readout layer scales are (1,0.25,1).
Global tau and slab settings remain fixed at the retained v11 values.

Response scale is the training-prefix SD. The inherited lag centering/MAD
uses observations available through that prefix, including earlier buffer
history. This is causal history-based preprocessing, not strictly fitting-
window-only preprocessing. Readout centering/scaling uses the fitting window.
This distinction corrects the previous plan's shorthand without changing the
frozen static control. No future-window normalization is allowed.

## Model and Exact Training Target

    q_p,t = beta_0 + h_t' beta + a_t
    a_t = a_(t-1) + eta_t, eta_t ~ N(0, omega^2)
    a_(7000) = 0

The static intercept prior and reservoir RHS-NS prior remain unchanged.
Anchoring the offset identifies its level relative to beta_0; practical
state/readout confounding is checked in retained traces, not assumed absent.
omega/source_training_SD is fixed at 0, 0.001, 0.005 or 0.020. The zero arm
dispatches the unchanged static sampler and forecast backend.

For each observation, with A=(1-2p)/(p(1-p)) and B=2/(p(1-p)):

    v ~ Exp(rate=1/sigma)
    y | beta,a,v,sigma ~ N(X beta + a + A v, B sigma v)
    v | rest ~ GIG(1/2, chi=residual^2/(B sigma), psi=(A^2/B+2)/sigma)
    sigma | rest ~ IG(a_sigma+3N/2,
      b_sigma + sum((y-X beta-a-A v)^2/(2B v)+v))

Gaussian beta conditionals use the existing precision-Cholesky helper,
without jitter or clipping. Existing RHS-NS conditionals update the prior
scales. A small serial R-RNG-controlled scalar FFBS helper updates the whole
offset path conditional on beta, v and sigma. All retained coefficient,
offset and sigma samples preserve their iteration pairing. The AL target is
not replaced with a Gaussian mean-residual correction.

## Online Forecast Contract

After fitting, training parameter samples are held fixed; new observations
update the offset conditionally, without reweighting beta/sigma draws. The
single-step Gaussian-prior times AL-likelihood update is an exact mixture of
two truncated normals. Its mean/variance are checked against quadrature.
Repeated updates project this mixture to a Gaussian: this is a Gaussian ADF
approximation, not an exact full joint posterior given all later data.

Gaussian ensemble transport keeps the same outer-draw identity between
origins and retains state uncertainty. It is not sample shuffling, a
deterministic residual correction, or an exact particle filter. The starting
state for each draw is its paired sampled terminal training offset.

Between forecast origins, use only observations available through the new
origin for the reservoir and offset. Within each horizon, recursively
simulate unknown future outcomes under AL and random-walk offset innovations.
Antithetic offset innovations keep the inner lead-one mean exactly equal to
the current conditional readout, providing an executable 1e-6 guard.

The primary quantity is the inner-path average of conditional quantile
locations for each outer posterior draw. It is not the p-quantile of a
predictive mixture. Native metric intervals are quantiles of draw-wise
scores. Q-DESN's shared coefficient/state coupling differs from the inherited
DQLM latent-marginal product coupling; widths are not like-for-like estimates
of joint posterior-functional precision. No cosmetic manipulation to make
their aggregate intervals match is permitted.

## Leakage-Free Selection and Compute

| Stage | Fitting indices | Forecast indices |
|---|---|---|
| A selection | 7001:8000 | 8001:8240 |
| B selection | 7001:8300 | 8301:8540 |
| C confirmation | 7001:8600 | 8601:8840 |
| Fresh confirmation | 7001:9000 | 9001:10000 |

Keep washout 6501:7000 and lag buffer 6001:6500. Eight primary internal
origins at stride 30 give 240 scored pairs. Secondary shifts 10 and 20 use
230 and 220 pairs and remain separately reported. The final block has 34
origins, 1,000 pairs, and a truncated final 10-step horizon.

Two development trajectories are F1/F2 from v11. Their exposed external
holdouts are never used to rank candidates. The only selection criterion is
observed forecast check loss averaged equally over four matched internal
fold/trajectory cells. Oracle metrics are diagnostics only. No mixing grade
or minimum practical gain excludes an otherwise finite strict improvement.
Tradeoffs are reported, not hidden. Four new seed pairs are predeclared:
N1=81411001/81411002, N2=81412001/81412002,
N3=81413001/81413002, N4=81414001/81414002.

| Tranche | Smoke | VB warm starts | MCMC | Total |
|---|---:|---:|---:|---:|
| Selection | 2 | 8 | 20 | 30 |
| Internal confirmation | 0 | 4 | 18 | 22 |
| Fresh confirmation | 0 | 8 | 36 | 44 |
| Conditional maximum | 2 | 20 | 74 | 96 |

Each prefix shares one static quantile VB initializer across Q-DESN arms;
DQLM has its own initializer. VB outputs are not new article VB results.
Discovery uses 1,500 burn-in/5,000 retained; confirmation uses
3,000/10,000 and three chains. All MCMC forecasts use 300 outer/128 inner
samples from the start, a justified simplification removing low-budget
screen/replay ambiguity for small gains. Secondary phase replays reuse fits.

The first scheduler tranche stops after 30 jobs for review. The full
implementation includes explicit continuation commands for the other 66,
but they are not automatically scheduled. A strict check-loss gain over the
static arm is required to continue each mechanism-confirmation stage, not to
discard other recorded metric improvements. This is a compute-allocation
rule, not an article metric exclusion policy.

Up to 30 available physical cores on muscat, one model/numerical thread per
core, are rechecked at each stage. Keep a 128 GiB available-memory floor.
Resource allocation never terminates another lane's jobs.

## Reproduction and Operations

The dedicated branch starts from frozen v11. A fresh CLI Git fetch verified
shared validation is an ancestor, with 62 pending IND commits before v12.
None are discarded or merged by this lane. The coordinator owns integration.

CLI: `validation/fitforecast_v2/scripts/independent_qdesn_dynamic_location_v12.R`
with commands `materialize`, `worker`, `health`, `verify`, `advance`,
`continue`, `pending`, `resources`, and `exit`.
Scheduler: `scripts/run_independent_qdesn_dynamic_location_v12.sh`
arguments `<repo> <run> <maximum_workers> <selection|confirmation|fresh>`.

1. Run the focused test file in a clean R process with one numerical thread.
2. Commit/push the dedicated IND branch, keeping its worktree clean.
3. Materialize from the frozen v11 run plus the immutable preflight log.
4. Launch the selection tranche under a dedicated tmux session.
5. Review `selection_review.json`, phase sensitivities and per-cell scores.
6. After explicit review, `continue <repo> <run> confirmation_warm`, then
   launch the confirmation tranche. Review `confirmation_review.json`.
7. After review, `continue <repo> <run> fresh_warm`, then launch fresh.

The immutable campaign/source/package/input manifests and per-stage plans
are checked before scheduling. Failures stop new scheduling and drain active
workers. `STOP_NEW_SCHEDULING` also drains. Resume the same tranche only for
truly pending jobs; RUNNING/FAILED states require an explicit audited recovery,
not silent overwriting. Successful artifacts are never rerun to fix metadata.

## Outputs and Publication

Save paired coefficient/offset draws, sigma/state traces, fit/forecast
quantile draws, means and native 95% intervals for fit RMSE, fit MAE,
forecast MAE/RMSE/check loss, mean-path scores, pointwise bands, oracle
inclusion, covariance attribution, phase sensitivity, first-step guards,
and origin/lead profiles. Confirmation PDFs contain metric intervals,
quantile-path comparisons, origin/lead profiles and common-scale heatmaps.
Pool chains only within trajectory/arm, never different DGPs.

No full fitted RDS/RDA/RData payload is required. Existing useful v11 outputs
remain intact. Runtime draws/cache/PDFs stay ignored. No article/Overleaf
change or shared-validation merge is performed. A successful new model
requires explicit article equations/caption changes and a later case-specific
VB/exAL extension; it cannot silently replace static model results.

The final handoff must state exact source HEAD, upstream synchronization,
full pending ancestry, hashes, tests, seeds, job counts, failed/active jobs,
filter approximation and interval coupling, gains and tradeoffs, and whether
the mechanism merits propagation. A sentinel gain is not an all-family win.
