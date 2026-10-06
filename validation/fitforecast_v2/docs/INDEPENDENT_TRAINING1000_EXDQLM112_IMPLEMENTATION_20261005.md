# Independent Validation: Training 1000 / CRAN 1.1.2

## Scope and Decision

This is a new, bounded IND scientific campaign, not article publication. It tests
whether doubling the likelihood information helps the forecast weaknesses seen
after the repaired representation and inference screens. It does not presume
that more history or a wider reservoir will improve the results.

The previous V11 campaign is incomplete, not a completed negative scientific
result: 52 jobs were materialized, with 38 successes, one implementation failure,
and 13 pending jobs at the audit. The failure involved nominal beta-system
accuracy after unconditional precision jitter. Original evidence is preserved.
This campaign records its closeout in the new run, not by altering V11 artifacts.

This branch preserves the IND repairs at `e6ec12d24be1f25ec5951f4bc1820b2ff5d9b64c`
above shared authority `5b85bb3a3894a88968e4987f330e3ec66711f9c7`.
Only dedicated IND commits may be pushed. Shared validation, Article-v2 main,
Overleaf, other lanes, and integration branches must not be changed here.

## Audited Plan and Justified Corrections

The comprehensive ignored plan is `PLAN.md` in the local implementation packet.
Its original SHA-256 is
`5b8999f3a3b8e092a22c81400f559eafb7b3317ec83e90692339f45392448b7d`.
Its descriptive audit passed 116 checks. Those checks were not executable
inference tests; the new runtime receives its own independent preflight.

Corrections made during implementation:

1. Use actual CRAN 1.1.2 for the dynamic baselines in an isolated library, not a
   package loaded from the validation branch. Q-DESN remains an explicitly named
   private IND extension; it is not represented as a stock CRAN implementation.
2. Solve the nominal SPD precision without unconditional jitter. Mean, covariance
   and log determinant use one Cholesky factor. Non-SPD systems fail explicitly;
   the allowed relative nominal-system residual is `1e-6`.
   The private normal-screen solve uses the same nominal contract; it cannot
   silently regularize a non-SPD system through its historical jitter fallback.
3. Draw exAL VB gamma and sigma from its fitted structured grid and conditional
   GIG distributions. Do not substitute its Gaussian parameter surrogate.
4. Replay compact, hash-verified VB initial states for MCMC with fresh RHS priors.
   Do not refit warm models or transfer posterior shrinkage parameters as priors.
5. Treat finite slow reservoir forgetting as a disclosed warning. It is not the
   numerical reproduction criterion, and does not silently extend the 500-row
   washout or turn a valid deterministic design into an implementation failure.
6. Account for all nested fitting calls. The previous 1412-call estimate missed
   repeated normal initializers on changed folds; the conservative ceiling is
   now 1590 calls with validated affine normal sharing, or 2742 without it.
7. Use genuinely local design perturbations, stratified capacity challenges, and
   a forecast-rank/diversity shortlist. Do not call independent random designs
   local refinements, or select the worst-scoring candidate as the diversity arm.
8. An unfavorable training-size contrast pauses broad scheduling for review.
   Neither a failed chain grade nor an arbitrary significance threshold vetoes
   a valid finite strict score improvement.
9. The broad ledger did not contain an authority-role row for either Laplace
   p=.05 model. Recover the exact archived forecast-MAE structural specification
   through the article replay registry and verified request hashes. Explicitly
   disclose its conversion to the redesigned seed/topology/reservoir-only
   readout; this is not an exact replay of the legacy input-augmented fit.
   Both priority Gaussian cases retain the repaired V10 anchor instead.
10. Article-v2's primary physical checkout currently belongs to a GloFAS task
    branch and contains an older IND table. Freeze the article summary from the
    freshly verified `origin/main` Git object, not that checkout's working file.
    Read-only Git checks verified article main at
    `e721bfddee81269864febea0eca0bbd0c5eba369` during this audit. No article
    checkout, branch, main, Overleaf or GloFAS files are modified.
11. Normalize fan-in to the declared input and smallest layer dimensions before
    computing canonical identities. Some local lag/width perturbations otherwise
    relied on the reservoir builder's silent dimensional clipping; effective
    topology must be explicit and duplicate detection must use the real design.
    Ignore the unused interlayer setting at D=1 and apply the fixed matrix seed
    before canonicalization; an effective-design audit detected three redundant
    Gaussian structures under the uncorrected identity scheme.
    Canonicalize scalar types through structured JSON rather than R object
    serialization, so integer/double metadata cannot create false distinctions
    and identities survive configuration round trips.
12. The maximum-capacity smoke caught an interlayer fan-in shape error for
    depth 3/4. Pass the shared fan-in as a scalar, matching the builder's
    layerwise expansion API. Add explicit depth-3/4 construction regressions
    before any candidate work is dispatched.
13. The first eight production cost probes stopped on worker artifact/runtime
    wiring, not scientific failure: numeric/MCMC summary classes were not JSON
    serializable, and AL/VB rolling updates lacked the telemetry scalar helper.
    Use plain named numeric summary lists, load the existing telemetry utilities,
    exercise AL and exAL rolling forecasts under both engines, and require a
    complete eight-worker artifact smoke before the replacement production run.
    Preserve the first failed run unchanged; no broad jobs were launched from it.

## Information and Evaluation Contract

The existing DGP files already contain 10000 post-DGP-warmup observations and
exact conditional quantile paths. No new DGP simulation or quantile approximation
is needed to obtain the extra training history.

| Fold | Likelihood N | Likelihood rows | Reservoir washout | Development targets |
| --- | ---: | --- | --- | --- |
| A | 500 | 8001:8500 | 7501:8000 | 8501:8750 |
| A | 1000 | 7501:8500 | 7001:7500 | 8501:8750 |
| B | 500 | 8251:8750 | 7751:8250 | 8751:9000 |
| B | 1000 | 7751:8750 | 7251:7750 | 8751:9000 |
| Final | 1000 | 8001:9000 | 7501:8000 | 9001:10000 |

A complete 390-observation lag buffer precedes washout. No zero-padded rows
count toward likelihood or washout. State initialization is zero at the
declared washout start. Initialization dependence is measured separately.
Response scaling is scale-only; input preprocessing uses only the observed
prefix available through the fitting origin, never later outcomes.
The N500/N1000 contrast includes changed history, washout start and learned
preprocessing. It measures the complete longer-history protocol, not a pure
causal effect of likelihood sample size in isolation.

A and B have origins every 5 observations, 45 origins each, with leads 1:30
and 1350 scored lead-target pairs. Final evaluation has 34 origins every 30
observations, with 30 leads except the last origin's 10 available leads:
1000 pairs on exactly the original 9001:10000 block.

Moving origins are teacher forced: all new observed outcomes through the
origin update lag buffers and reservoir states. Unknown outcomes within each
origin's horizon are recursive. Static Q-DESN coefficients are not refitted
at every origin. DQLM uses observed-data filtered state updates, not future
smoothing. These are different model architectures, not an omission of
teacher forcing for DQLM.

Fold A can guide the declared search. Fold-B nominees are frozen before its
scores are opened. Final winners are frozen before the final block is scored.
Past research decisions have already used that final block: it is familiar,
not a pristine independent test. Fresh DGP replicate confirmation is a future,
separately authorized study. The p-specific series share shifted noise paths
within family and are not independent simulation replicates.

## Models, Priors and Inference

All four model classes are fit for three families and three p levels: DQLM AL,
exDQLM exAL, Q-DESN AL-RHS-NS, and Q-DESN exAL-RHS-NS. There are 18 quantile
DESN cases and 18 matched baseline cases, each with final VB and MCMC summaries.
No global winning reservoir specification is sought.

Identity Q matrices preserve every layer. Reservoir activation is tanh, lower
readout state transformation is identity, and readout contains an intercept
plus all layer states only. Outcome lags enter the input, not an extra raw-lag
readout. Exogenous lag count is zero because these DGPs have no exogenous inputs.
Matrix seed is fixed at 920001; nonzero weights are uniform on [-1,1], exact
fan-in is row-normalized, and extra reservoir state noise is zero.

RHS tau0 and slab scales are transported in source response units. The three
arms are 0.1, 1, and 10 around case-specific tau0 references. No posterior is
silently used as a new prior. The intercept is not RHS-shrunk. Gaussian normal
screening uses full covariance at small width and explicitly labeled Woodbury
exact-marginal/diagonal storage above 500 coefficients; quantile VB always
uses full covariance. The screening covariance approximation is not promoted
as final full posterior uncertainty.

Q-DESN exAL MCMC uses explicit `m0_v_collapsed_support_logit`; AL uses its
gamma-fixed transition. Official exDQLM uses `collapsed_slice`; official DQLM
uses its conjugate gamma-fixed path. These are recorded as separate methods.
Official compiled MCMC runs in declared fast mode with one worker thread;
bounded smoke tests verify serial-RNG thread invariance.

## Bounded Stages and Scheduling

| Stage | Maximum explicit jobs | Purpose |
| --- | ---: | --- |
| Cost | 8 | Both priority cases, both architectures and engines |
| Diagnosis | 72 | Fixed-design N500/N1000 VB contrast, all four models |
| Size pilot | 8 | Paired MCMC on the two priority cases |
| Normal waves | 576 | 64 structures/family, 3 tau arms, 24/20/20 waves |
| Quantile A | 216 | At most 12 complete design/prior pairs per case |
| Quantile B | 72 | At most four pre-frozen nominees per case |
| MCMC bridge | 90 | Up to 72 Q candidates and 18 baselines |
| Final VB | 36 | Coherent per-case VB winners and baselines |
| Final warm | 18 | Only when the MCMC winner differs from the VB winner |
| Final MCMC | 108 | Three chains for each of 36 model cases |

Maximum explicit jobs: 1204; underlying normal/VB/MCMC fitting calls: 1590.
These are conditional ceilings, not currently scheduled jobs or a promise that
every stage will pass its scientific or cost gate. A separately reviewed
no-sharing alternative would need 1728 normal jobs and 2742 total calls;
this launch requires the passed affine-sharing preflight and stops if it fails.
The present preflight verifies within-family sharing for all three families.
It never shares fits across different families.

Design bounds: D 1:4 plus exact historical D5; layer widths 64,128,200,300,500
plus selected historical 600/800; total states <=2000. Lag choices are
30,60,90,120,180,240,300,360,390. Alpha covers .05:.99, including .4:.99;
rho includes .50,.70,.90,.97,.995. Input gain covers .05,.2,.5,1,2;
input fan fractions .1,.25,.5,1; recurrent/interlayer indegrees 10,20,40.
The pool has 8 historical structures, 24 local refinements, and 32 stratified
structures per family, including at least 8 explicit capacity challenges.
All candidates have fresh canonical identities; historical replays are labeled.
Recovered Laplace anchors deliberately retain historical m=1/15, widths=6/30,
alpha=.0035/.02 and rho=.45 outside the fresh-design ranges above.

The normal top 50 is a retained ledger, not a quantile inference gate. At most
8 ranked/diverse normal pairs plus 4 anchor/capacity bypass pairs enter each
quantile case. At least 6 distinct structures are preserved. Fold B nominates
the anchor, MAE leader, check-loss leader and a capacity/diversity candidate.
VB and MCMC may choose different case-specific winners. Tie-breaking is MAE,
check loss, fit RMSE, fitted width, then canonical ID.
Quantile selection is explicitly oracle-assisted simulation calibration: it
uses the known conditional path on development folds, not a deployable real-data
tuning criterion. Baseline specifications remain fixed while DESN is calibrated;
this is not an equal-compute-budget comparison of two hyperparameter searches.

Pilot MCMC has 1000 burn and 4000 retained draws. Final MCMC has 5000 burn and
20000 retained draws per chain, three chains. Forecast outer/inner budgets are
16/32 for normal screening, 32/32 for quantile A, 120/128 for B and bridge,
900/128 for final VB, and 300/128 per final MCMC chain. One predeclared
Gaussian exAL p=.25 case in each engine receives a no-refit nested 128/256
inner-path audit using the same outer draws and prefix-coupled noise bank.

The scheduler selects at most 15 initially idle physical cores, one hardware
sibling per core, and reserves 24 GiB RAM plus a conservative 12 GiB/worker
envelope. Every worker is CPU-pinned and all BLAS/OpenMP thread variables are 1.
No other lane's process is killed or modified. A failure or exhausted resource
gate stops new dispatch and drains already active IND workers. Timeouts apply
only to newly launched workers under this campaign's declared limits.

Resource guards: 1200 cumulative worker-hours, 48-hour stage dispatch envelope,
40 GiB run-output ceiling, and at least 20 GiB disk free. Intermediate jobs
have a 12-hour worker timeout; final jobs 48 hours. These are safety ceilings,
not estimated duration. Reaching the dispatch envelope drains active workers;
it does not kill them, so total stage elapsed time can exceed 48 hours.
The cost gate uses measured fitting/forecast time and
memory to project final budgets before scheduling the diagnosis.

After diagnosis and the MCMC size pilot, broad work proceeds only if at least
half the fixed-design Q cases improve fold-A MAE and its median N1000/N500
ratio is <=1. Otherwise it pauses with all contrasts for investigator review.
This is a resource-allocation rule, not a score promotion threshold.

## Scores, Intervals and Review

For each outer quantile-path draw, calculate fit RMSE versus the known
conditional quantile, forecast oracle MAE/RMSE over the scored pair lattice,
and fit/forecast pinball loss against realized observations. Report means of
draw-specific scores with equal-tailed 95% intervals. This is not the loss of
the posterior mean path. Final chains contribute equally.

Primary Q forecasts average inner conditional-location paths after recursive
propagation for each outer draw. This is not a posterior-predictive mixture
quantile at multi-step horizons. The conditional-mean recursive plug-in is a
separately retained companion. Official baseline intervals retain the declared
filtered-state Gaussian latent forecast approximation. Uncertainty comparisons
must disclose this difference, finite inner Monte Carlo, and chain variation.
Wide intervals are not automatically considered errors.

No aCRPS or cross-quantile crossings are silently synthesized from the three
p-specific shifted observed series. Conditional oracle MAE zero is an ideal
reference, not an attainable finite-data forecast risk. Black dashed references
retain the existing analytic DGP expected pinball risks (verified against
numerical integration), and zero conditional-path recovery errors. Expected
pinball risk is not a lower bound on a particular realized-sample score.

Exports include compact metric draws, conditional path draws, selected Q
parameters, fit/forecast profiles, gamma/sigma/ESS diagnostics, source/runtime
hashes and compact VB initializers. No fitted-model RDS/RDA/RData is retained.
Review output contains all-family VB/MCMC interval plots, fit/forecast path
plots, lead/origin profiles, early/late and H1 comparisons, a matched-baseline
gap ledger and a clearly descriptive comparison with frozen N500 authority.
Compact interval TeX assets are generated under ignored review output only.

All finite strict gains are retained without minimum-size thresholds. Diagnostic
grades are disclosed, not metric vetoes. Nonfinite scores, leakage, inconsistent
estimands, broken manifests or failed numerical contracts cannot be promoted
as valid results. Completion alone does not authorize article substitution.
The coordinator receives a reviewed, frozen branch and evidence handoff only.

## Reproduce and Inspect

Preflight packets cover official package defaults, structured VB sampling,
nominal-system solves, all-family affine sharing, causal forecasting, compact
initialization, depth-3/4 identity-Q construction and OMP1/OMP4 RNG equality.
The latest executed checks, focused regression results, maximum-capacity smoke
and production manifests are recorded in the ignored implementation packet.
Neither smoke results nor descriptive plan checks imply campaign completion.

Run from this worktree with R 4.6.0 and isolated CRAN library:

```bash
env OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 \
  /data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/preflight_independent_qdesn_training1000_v1.R \
  "$PWD" "$PWD/validation/fitforecast_v2/local_trackers/PREFLIGHT_NEW"

env OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 \
  /data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e \
  'testthat::test_file("validation/fitforecast_v2/tests/test_independent_qdesn_training1000_v1.R", reporter="summary", stop_on_failure=TRUE)'

/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/independent_qdesn_training1000_v1.R health "$PWD" "$RUN"
```

Materialize arguments are `materialize REPO RUN PLAN_PACKET BROAD_RUN V11_RUN
PREFLIGHT_PACKET`. The run path must not exist. Launch the scheduler with
`bash validation/fitforecast_v2/scripts/run_independent_qdesn_training1000_v1.sh
REPO RUN` in a detached tmux session. Only frozen stages are dispatched.
No automatic retries or unrecorded replacement candidates are allowed.

For a complete worker-to-artifact smoke, set `IQT12_STOP_AFTER_STAGE=cost` on
the scheduler. It drains eight probes and exits before any stage advancement.
After all eight verified SUCCESS manifests, restart the same frozen run without
that environment variable. Completed probes are reused without refitting;
normal cost/scientific gates then control the remaining pipeline. Do not reuse
the failed first run or change its statuses.

References: [official CRAN exdqlm](https://cran.r-project.org/package=exdqlm);
[rolling-origin validation](https://otexts.com/fpp3/tscv.html).
