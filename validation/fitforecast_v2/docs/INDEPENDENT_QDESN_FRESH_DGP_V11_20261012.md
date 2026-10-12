# Independent Q-DESN fresh-DGP sentinel pilot v11

## Decision and scope

This is a bounded confirmation pilot, not another DESN screen and not an
article replacement. The user approved implementation on 2026-10-12 after
the v10 health audit. The aim is to determine whether the modest retained
layerwise gain transfers to new DGP paths while retaining competitive mean
forecast performance. Native score intervals are reported, not forced to
resemble DQLM intervals.

The scientific base is the clean, frozen IND v10 commit
`73b37c28c06eeaef71d05c959ccf8a80bd96c454`. The shared-validation remote
was fetched before branching and was its ancestor, with 60 IND commits
not yet integrated. Starting from v10 preserves the audited scientific
runtime; merging into shared validation or article main is not authorized.

## What the audit established

- v10 completed 73/73 jobs without an implementation failure. The retained
  Layer-2 multiplier .25 achieved mean draw-wise forecast MAE 2.93528 versus
  concurrent anchor 2.98533 and DQLM 3.13652. The 1.68% improvement versus
  anchor is real in that record, but window-dependent: the DQLM ratios were
  .762 and 1.080. It does not establish general superiority.
- The retained metric interval width was 1.93314 versus anchor 2.00129,
  a modest 3.41% contraction. Mean-path MAE was nearly tied with DQLM.
- Q-DESN uses a common coefficient draw over its score surface; the DQLM
  comparator currently uses latent marginal draws with product coupling.
  Coherent loss covariance can therefore give different aggregate interval
  widths even when Q-DESN pointwise quantile intervals are narrower.
  This contract difference was already documented in the August coupling
  audit. It is not proof of an interval implementation error.
- Shuffling draws, pooling across unrelated DGP replicates, averaging
  interval endpoints and labeling them a pooled credible interval, or
  suppressing posterior uncertainty would not fix the model. None is used.
- More unrestricted tau0 or architecture exploration on the same trajectory
  has diminishing evidential value. A frozen independent-data pilot is the
  next informative step, though two replicates remain a feasibility pilot,
  not a definitive population-level simulation study.

## Frozen scientific contract

| Component | Specification |
|---|---|
| Sentinel | Gaussian mixture, p=.05, AL likelihood |
| Arms | DQLM; Q-DESN anchor g1=1,g2=1; retained g1=1,g2=.25 |
| Replicates | F1 latent/noise seeds 81112001/81112002; F2 81113001/81113002 |
| DGP length | 12,000 latent steps; discard 2,000; keep 10,000 |
| Training | source indices 7001:9000 (2,000 observations) |
| Reservoir washout | 6501:7000 (500 observations), plus complete lag buffer |
| Held-out block | 9001:10000 (1,000 observations) |
| Origins | 9000,9030,...,9990 (34 origins; final horizon truncated to 10) |
| Leads | 1:30; 1,000 scored origin-lead pairs, each target exactly once |
| Main chains | 3,000 burn-in + 10,000 retained per arm/replicate/chain |
| Forecast sampling | 300 outer draws; 128 inner recursive trajectories |
| Initialization | six train-only VB initializers, max 800 iterations |
| Computational smoke | two small MCMC jobs; excluded from scientific summaries |
| Explicit job total | 2 smoke + 6 warm + 18 confirmation = 26 |
| Scheduling | maximum 30 verified idle physical cores; one numerical thread/job |

The DGP is unchanged except its independent seeds. Use the existing
`tools/merge_reports/20260305_dynamic_dgp_model_helpers.R`, the original
generator present at historical commit `1417a82`. Its model-composition
call is adapted from historical `combineMods()` to the
current public `+` API; historical source reconstruction must pass before
launch, so this compatibility change cannot silently change the DGP.
The deterministic initial
state has level 45, slope .014, seasonal amplitudes (32,12), phases
(.85,-1.25), period 90, harmonics (1,2), and state innovation SDs
(.005,.00002,.004,.004,.003,.003). The Gaussian mixture has weights
(.1,.9), means (0,1), and SDs (.5,15). Its .05 quantile is computed by
CDF root finding, then subtracted from observation noise. Consequently the
latent location is the exact target conditional quantile given the DGP
latent state. This is an oracle benchmark, not an observation-only filter.
No oracle path is supplied to model fitting or recursive future inputs.

Both Q-DESN arms retain D=3, n=(141,119,90), m=360, shared alpha
.06844383, rho .9990838, the fixed reservoir seed, input scaling/topology,
identity Q matrices, tanh transition, identity interlayer projection,
train-only median/MAD preprocessing and bounded inputs. Readout order is
intercept, Layer 3, Layer 1, Layer 2, with no direct raw-input readout.
Exact architecture and original-unit RHS prior values are copied from the
frozen v10 configuration, not re-estimated from the new oracle or holdout.
Fold-zscore conditioning is re-estimated on each replicate's training data.
The fixed prior is v9 tau multiplier 2 and slab multiplier .5. Layer 3 and
intercept multipliers stay 1. The .25 intervention is a relative Layer-2
prior scale through post-zscore readout scaling, not a reservoir change.

The DQLM configuration retains its calibrated period, discounts, initial
state covariance, and origin-state update contract. Its latent clock is
aligned to the new training start. All model arms use the same data and
forecast pairs. Parameters are fitted once; real observations teacher-force
the reservoir or update DQLM states between origins. Within an origin,
Q-DESN propagates recursively with no future observed lag access.

This pilot is AL only. No exAL sampler, gamma setting, or exAL row is changed.
CRAN exdqlm 1.1.2 and the previously audited private study R extensions are
pinned separately and honestly identified. It is not a claim that all
Q-DESN functionality comes from the unmodified CRAN namespace.

## Audit and efficiency improvements

1. Canonical arm IDs hash typed numerical values serialized as JSON, making
   IDs stable across integer/double representations and JSON round trips.
2. Source manifests include every loaded study/core R file, the DGP helper,
   this protocol, tests, CLI, and scheduler; package files have a separate
   manifest. Every worker verifies these manifests before computation.
3. The inherited first-step reporter now recognizes the actual v10 guard
   schema. It records measured current/shared-state readout errors rather
   than taking max() of absent columns or asserting untested feature guards.
4. Warm initializers are fit on training data only. A one-step, tiny-draw
   execution check is retained as a non-selection warm diagnostic. No full
   1,000-point VB forecast is required, and warm scores are not ranked.
5. Common MCMC/forecast seed schedules are frozen by replicate and chain.
   Matching seeds for Q-DESN arms aid reproducibility but do not guarantee
   perfectly paired MCMC trajectories. Three chains are pooled only within
   arm and replicate; replicates are compared as independent experiments.
6. The scheduler checks idle physical cores and affinity, caps one process
   per selected core, leaves 128 GiB available RAM, and stops scheduling on
   any failure. It drains existing workers cleanly and never kills another
   lane's job. It can resume pending work, not silently overwrite failures.
   Core availability is checked again at each stage: 2 smoke slots, 6 warm
   slots, and up to 18 confirmation slots, under the maximum of 30. When
   fewer idle cores are available the queue uses only those verified cores.
7. Compact CSV/GZ draws, JSON initializers, metadata and manifests are kept.
   No fitted .rds/.rda/.RData payloads or old-source deletion are needed.
8. Active DQLM configs contain only frozen scientific model parameters and
   the current training clock, not historical operational paths or obsolete
   runtime settings. The untouched parent template remains provenance only.

## Required evidence and interpretation

The final report contains chain-level and within-replicate pooled score
means and 95% equal-tail intervals (quantile type 8), fit RMSE, fit check
loss, forecast MAE/RMSE/check loss, mean-path companion scores, pointwise
quantile bands and their oracle coverage/interval score, lead profiles,
early/middle/late origin profiles, origin-by-lead surfaces, nuisance mixing
diagnostics, first-step guards and hashes. The ignored review PDF includes
score intervals, fit and forecast oracle path recovery, lead and origin
profiles, and heatmaps on common scales within each replicate.

Main comparisons are retained/anchor and each Q-DESN/DQLM, per replicate,
for forecast MAE and check loss. Report every finite strict improvement,
however small, with fit and interval-score tradeoffs and diagnostics; no
mixing grade excludes an observed score. A narrow score interval alone is
not success, especially under different cross-origin coupling contracts.
Mean of draw-wise errors and error of the posterior mean path are distinct
estimands and must both be named. Do not pool replicates into one posterior.

If gains transfer on both fresh streams, consider a larger predeclared DGP
replication campaign and then the remaining cases. If not, close this local
intervention without further tweaking these new holdouts. This result cannot
promise the user's desired performance and cannot justify changing all
article families or likelihoods. Neither partial nor full pilot evidence is
automatically promoted. Integration remains the coordinator's responsibility.

## Reproduction and gates

The CLI is `scripts/independent_qdesn_fresh_dgp_v11.R`. Run focused tests,
commit code, then `materialize <repo> <run> <pinned-library> <parent-run>`.
Materialization verifies the completed parent, reconstructs the original
source with its historical seeds to tolerance 1e-6, freezes new seeds and
arm specifications, loads the exact runtime, records the environment and
full hash closure, and creates smoke/warm plans. No main fit is scheduled
unless two smoke jobs and six warm jobs finish and verify.

Run `bash scripts/run_independent_qdesn_fresh_dgp_v11.sh <repo> <run> 30`
under a dedicated tmux session. Use CLI `health` and `verify` for monitoring.
Create `STOP_NEW_SCHEDULING` to drain cleanly. After all 18 confirmations,
`advance confirmation` automatically validates metrics to 1e-6, produces
the report and review PDF, and freezes closeout hashes. A failed run stays
paused for investigation; completed evidence is never silently overwritten.

Before integration: audit all manifests, runtime/source pins, focused tests,
all 26 statuses, storage and active processes; prepare a dedicated-branch
handoff. Runtime directories and review PDFs remain ignored. Do not merge
or push main, shared validation, an integration branch or Overleaf.

## Executed prelaunch evidence

- Historical source reconstruction under CRAN 1.1.2: maximum absolute
  error `5.115907697472721e-13`, passing tolerance `1e-6`.
- New focused tests cover canonical IDs, exact windows, guard reporting,
  frozen priors/design, DGP repeatability/centering, future/oracle isolation,
  full source closure, and an end-to-end synthetic 26-job closeout/PDF.
- Inherited v8 uncertainty, v9 RHS, and v10 layerwise regression scripts pass.
- Bash syntax and `git diff --check` pass. A resource-only test identified
  30 idle physical cores on muscat; no other lane's process was stopped.
- The diagnostic rendering fixture is 16 pages. It is synthetic software
  test data, not campaign evidence or an article asset.
- The first unlaunched packet at source commit `92b258a7` exposed lost
  numeric-vector names in JSON stage counts. This was caught by prelaunch
  verification before any models ran. Stage counts now use a named list;
  a partial-plan health regression verifies all 26 planned jobs, including
  confirmations that are not yet materialized. The unlaunched packet is
  retained as superseded preflight evidence, not reused for model scheduling.

Exact shell/R commands are the CLI and test entry points committed alongside
this protocol. Materialization records the final clean source HEAD; stage
workers reverify the actual code/package/data hashes before fitting.
