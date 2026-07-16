# RQR-DESN Pre-Simulation Audit, Diagnosis, And Readiness Plan

Date: 2026-07-16

Repository: `/data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

Branch: `feature/rqr-desn-readout-20260716`

Implementation commit: `e1a1c86c02d6e8a7615a0afa1c9b35741b399549`

Purpose: define the rigorous, reproducible gate sequence that should happen
after the RQR-DESN readout implementation and before any broad simulation study.

This is a planning and audit document. It does not launch simulations and does
not modify article, PriceFM, GloFAS, joint-validation, or promoted evidence
assets.

Readiness implementation note: the follow-up implementation of this plan adds
the missing target-argument guard, installed-namespace contract tests, a tiny
deterministic readiness harness, a broad-simulation specification template, and
a reference-source inventory. It also rejects all-zero Q-DESN design shells
before fitting the RQR readout, because that failure mode produces degenerate
zero-width intervals rather than a useful simulation signal. Future simulation
manifests should pin the final readiness commit, not only the original backend
commit above.

## 1. Executive Decision

Do not move directly from the current RQR-DESN implementation to a broad
simulation campaign. The optimal next step is a narrow simulation-readiness
phase with explicit package hygiene, mathematical, design-parity, configuration,
serialization, and tiny-calibration gates.

Reason:

- The RQR-DESN backend is committed, pushed, and focused tests passed.
- The implementation is new enough that a large study would mostly test many
  surrounding assumptions at once.
- The package worktree contains historical reports, results, and compiled
  native artifacts that make raw-directory package checks noisy and expensive.
- The direct API is implemented, but there is not yet a normalized pipeline
  route, resolved-config schema, or simulation artifact contract for RQR-DESN.
- VB exists as a fast approximation but is explicitly uncalibrated; it should
  not be a headline simulation backend until a calibration/diagnostic layer is
  defined.

Therefore the next phase should answer one question:

> Is the committed RQR-DESN backend stable, reproducible, and sufficiently wired
> to support a scientifically interpretable simulation campaign?

Only after that answer is yes should we design and launch the broad simulation.

## 2. Current State Audit

### 2.1 Git And Remote State

The RQR-DESN implementation is committed and pushed:

```text
local branch:  feature/rqr-desn-readout-20260716
remote branch: origin/feature/rqr-desn-readout-20260716
commit:        e1a1c86c02d6e8a7615a0afa1c9b35741b399549
message:       Add RQR-DESN interval readout backend
```

The only local untracked file observed during the audit was:

```text
docs/QDESN_REPOSITORY_THEORY_IMPLEMENTATION_HANDOFF_20260716.md
```

That file predates this pre-simulation plan and is not part of the RQR commit.

### 2.2 What The Commit Adds

The implementation commit adds the following public surface:

- `rqr_mcmc_fit()`: fixed-design exact Gibbs MCMC for the two-root RQR
  generalized posterior.
- `rqr_vb_fit()`: coordinate-Gaussian VB approximation, explicitly marked as
  uncalibrated.
- `rqr_desn_fit()`: DESN shell integration that reuses
  `qdesn_fit_vb(..., fit_readout = FALSE)`.
- `predict_interval()`: S3 interval endpoint prediction generic for RQR fits.
- `forecast_paths.rqr_desn_fit()`: explicit future-design/plugin forecast
  contract that refuses silent recursive response sampling.
- RQR algebra helpers: constants, check loss, residual product, pseudo residual,
  endpoint ordering, and GIG parameters.
- Manual Rd files and NAMESPACE exports.
- Focused testthat files covering algebra, MCMC, RHS_NS, DESN design parity, VB,
  and forecast refusal.

### 2.3 Validation Already Passed

The following checks passed after implementation:

```text
R source parse:                       passed
new Rd syntax checks:                 passed
temporary package install:            passed
installed-namespace RQR test slice:   passed
remote branch push:                   passed
```

The installed-namespace RQR test slice covered:

- exact pseudo-residual/product identity;
- endpoint invariance to root-label swapping;
- GIG convention checks under the package sampler convention;
- conditional root Gaussian update moment check;
- finite fixed-design MCMC;
- intercept-only MCMC versus a dense-grid reference;
- DESN shell design parity;
- explicit rejection of invalid weight premultiplication;
- RHS_NS tiny MCMC fit;
- finite VB approximation with no calibration claim;
- explicit refusal to recursively sample future responses from RQR.

### 2.4 Package Hygiene Diagnosis

The implementation passed a temporary package install, but broad package checks
are still polluted by repository hygiene issues that are not specific to RQR.

Observed source-tree size:

```text
repo root: 3.0G
results/: 2.0G
reports/: 921M
src/:     100M
```

Compiled native artifacts exist in `src/`:

```text
src/*.o
src/exdqlm.so
```

These are ignored by git but still present in the working directory. A raw
`R CMD check <source-dir>` therefore reports source-package warnings and spends
time scanning historical reports/results. This is not the right gate for RQR
simulation readiness.

Current tracked artifact issue:

- Some report/result files are tracked historically.
- `.Rbuildignore` excludes several heavy roots, but not all current historical
  report paths.
- The cleanest future gate is a clean package build/check from a sanitized
  source tree or tarball, not a raw-directory check of the 3GB worktree.

### 2.5 Handoff Contract Diagnosis

The external RQR-DESN handoff explicitly said not to launch a broad simulation
in the first implementation. It called for exact tiny audits and a tiny
deterministic smoke example only.

The committed implementation intentionally went beyond the first handoff in one
place: it added an initial VB backend. That is acceptable because the code marks
VB uncertainty as uncalibrated and the tests avoid pretending VB endpoint
uncertainty matches MCMC. For simulation design, MCMC should remain the
reference backend. VB should be a sidecar for speed, initialization, or future
screening only after additional calibration checks.

## 3. Methodological Contract For The Simulation Phase

RQR-DESN is not a response-likelihood model. It is a generalized-Bayes interval
readout over a fixed DESN design.

For a feature row `x_t`, the model computes:

```text
eta_1t = x_t' beta_1
eta_2t = x_t' beta_2
L_t    = min(eta_1t, eta_2t)
U_t    = max(eta_1t, eta_2t)
```

The loss target is:

```text
rho_alpha((y_t - eta_1t) * (y_t - eta_2t))
```

where `coverage_level = alpha`.

Simulation reports must therefore avoid:

- calling `coverage_level` a quantile level;
- claiming RQR has a response predictive density;
- sampling future `y` from the pseudo-AL augmentation;
- mixing RQR with AL/exAL posterior predictive draws;
- treating VB credible bands as calibrated without evidence.

Simulation reports should emphasize:

- empirical interval coverage;
- interval score;
- interval width;
- center/midpoint accuracy when a true center is known;
- endpoint/root stability;
- sensitivity to learning rate `omega`;
- DESN design parity and reproducibility;
- MCMC convergence and effective sample diagnostics;
- VB approximation quality only as a secondary diagnostic.

## 4. Why A Broad Simulation Now Is Not Optimal

### Option A: Launch Broad Simulation Immediately

Diagnosis: not recommended.

Failure modes:

- Any failure could come from package build hygiene, RQR math, DESN design
  construction, output schema, storage, or launch orchestration.
- No normalized RQR simulation output manifest exists yet.
- No policy exists for `learning_rate` grids or calibration.
- VB is uncalibrated and should not be treated as comparable to MCMC yet.
- Recursive forecasting remains intentionally unsupported without an explicit
  driver.

Decision: reject as premature.

### Option B: Only Run More Unit Tests

Diagnosis: necessary but insufficient.

The focused tests are good, but they do not yet test:

- serialization/save-load contract;
- direct API versus future pipeline/config route;
- repeated-seed reproducibility across a tiny scenario manifest;
- learning-rate sensitivity;
- interval coverage over repeated generated datasets;
- output schema and provenance fields for a simulation table.

Decision: use unit tests as a gate, but add tiny simulation-readiness audits.

### Option C: Build A Full Pipeline Route Before Any More Tests

Diagnosis: useful later, but too much too soon.

The direct API should first be proven stable in a deterministic tiny calibration
suite. Pipeline work should then encode the already-stable contract rather than
be the place where the contract is discovered.

Decision: defer broad pipeline routing until after the tiny calibration suite.

### Option D: Simulation-Readiness Phase

Diagnosis: recommended.

This isolates risks in the right order:

1. package/source hygiene;
2. exact RQR math;
3. DESN shell parity;
4. deterministic tiny calibration;
5. output schema and provenance;
6. simulation design freeze.

Decision: proceed with this plan.

## 5. Readiness Gate Plan

### Gate 0: Pin And Reproduce The Implementation

Objective: ensure all future simulation artifacts can cite a specific code
state.

Required checks:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration
git status --short --branch
git rev-parse HEAD
git ls-remote --heads origin feature/rqr-desn-readout-20260716
```

Pass criteria:

- HEAD equals the selected readiness commit recorded in the run manifest.
- The selected readiness commit descends from
  `e1a1c86c02d6e8a7615a0afa1c9b35741b399549`.
- Remote branch points to the same SHA.
- No unintended model-code or test changes are present.

Action if failed:

- Do not launch simulations.
- Commit/push or explicitly pin the correct branch before continuing.

### Gate 1: Clean Package Build/Install Gate

Objective: simulation should not depend on a dirty 3GB development tree.

Recommended implementation:

1. Build from a clean export or temporary source copy.
2. Exclude historical reports/results and compiled objects.
3. Install to a temporary library.
4. Load `exdqlm` from that temporary library.

Reproducible command sketch:

```bash
R_BIN=/data/jaguir26/local/opt/R/4.6.0/bin/R
TMP_LIB=/tmp/exdqlm-rqr-lib
rm -rf "$TMP_LIB"
mkdir -p "$TMP_LIB"
"$R_BIN" CMD INSTALL --library="$TMP_LIB" \
  --no-multiarch --with-keep.source \
  /data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration
```

Additional package-hygiene follow-up:

- Add or verify `.Rbuildignore` coverage for `reports/`.
- Never include `src/*.o` or `src/*.so` in a source package.
- Prefer checking an `R CMD build` tarball or clean worktree over checking the
  raw development directory.

Pass criteria:

- Temporary install succeeds.
- Loading `exdqlm` from the temporary library succeeds.
- Known old Rd warnings are separated from RQR-specific documentation.

Action if failed:

- Fix package metadata/build hygiene first.
- Do not run simulation code from a partially loaded source tree.

### Gate 2: RQR Installed-Namespace Regression Tests

Objective: prove the committed API works as a package, not only through sourced
files.

Reproducible command sketch:

```r
.libPaths(c("/tmp/exdqlm-rqr-lib", .libPaths()))
files <- c(
  "tests/testthat/test-rqr-algebra.R",
  "tests/testthat/test-rqr-mcmc-fixed-design.R",
  "tests/testthat/test-rqr-desn-design-parity.R",
  "tests/testthat/test-rqr-rhs-ns.R",
  "tests/testthat/test-rqr-vb-fixed-design.R",
  "tests/testthat/test-rqr-forecast-contract.R",
  "tests/testthat/test-rqr-contracts.R"
)
for (f in files) testthat::test_file(f, reporter = "summary")
```

Pass criteria:

- All RQR test files pass against the installed namespace.
- Tests do not rely on the source tree being attached by `pkgload`.

Action if failed:

- Fix tests or implementation before any simulation.

### Gate 3: Missing Contract Tests Before Simulation

Objective: add the minimum tests that are not yet covered by the first RQR
commit.

Recommended tests to add before broad simulation:

1. Save/load round trip:
   - fit tiny `rqr_mcmc_fit`;
   - save with `saveRDS`;
   - reload;
   - confirm `model_spec`, `misc$constants`, coefficient draws, and interval
     predictions are preserved.

2. Explicit `target_p` rejection or non-acceptance:
   - direct RQR APIs must not silently treat `target_p` as `coverage_level`.

3. Learning-rate sensitivity smoke:
   - same data, same prior, two `learning_rate` values;
   - confirm model spec stores `omega` and `sigma = 1 / omega`;
   - confirm loss/posterior summaries remain finite.

4. Response/design transformation guard:
   - verify observation weights still fail before Q-DESN premultiplication;
   - if response standardization is later added, prove endpoint back-transform
     semantics.

5. Label diagnostics:
   - root labels may switch;
   - reported `lower` and `upper` must remain invariant and finite.

Pass criteria:

- These tests pass in the installed-namespace test slice.

Action if failed:

- Fix the direct API and object contract before moving to calibration.

### Gate 4: Tiny Deterministic Calibration Suite

Objective: run a tiny simulation-like suite that is small enough to inspect
manually but broad enough to test the scientific output contract.

Proposed scenarios:

| Scenario | Purpose |
|---|---|
| intercept-only symmetric normal | checks coverage, width, midpoint around the true center |
| intercept-only asymmetric noise | checks RQR behavior under skewness and mean-balance caveat |
| fixed linear design | checks endpoint slopes and conditional interval behavior |
| small DESN with deterministic sinusoid/noise | checks design shell, seed reproducibility, washout alignment |
| small DESN with RHS_NS | checks shrinkage-prior path under real reservoir features |

Backends:

- MCMC is mandatory.
- VB is optional sidecar only.

Metrics:

- empirical coverage;
- mean interval width;
- interval score;
- midpoint MAE if truth is known;
- endpoint RMSE if oracle endpoints are analytically available;
- root-label switch diagnostic;
- runtime and memory;
- effective sample/convergence summaries where available;
- failure/error messages.

Pass criteria:

- All scenarios complete with deterministic seeds.
- MCMC intervals are finite and ordered.
- Coverage is directionally sensible for the declared `coverage_level`.
- Outputs are written to a single timestamped directory with manifest and seeds.
- VB, if run, is reported as approximate/uncalibrated.

Action if failed:

- Diagnose the smallest failing scenario before expanding.

### Gate 5: Output Schema And Provenance Freeze

Objective: make the future broad simulation reproducible and comparable.

Required outputs:

```text
manifest.json or manifest.csv
scenario_manifest.csv
fit_summary.csv
interval_metrics.csv
mcmc_diagnostics.csv
vb_diagnostics.csv, if VB is run
session_info.txt
git_state.txt
README.md
```

Required manifest fields:

- implementation commit;
- branch;
- R version and binary;
- package library path;
- seed;
- scenario id;
- DESN configuration;
- coverage level;
- learning rate;
- prior type and hyperparameters;
- backend;
- MCMC control;
- output file hashes.

Pass criteria:

- A fresh user can identify exactly which code, seeds, scenarios, and fit
  controls produced each row.

Action if failed:

- Do not run broad simulation until output schema is fixed.

### Gate 6: Simulation Design Freeze

Objective: decide the actual scientific simulation before launching it.

The broad study should specify:

- estimands: interval endpoints, coverage, width, and interval score;
- DGPs: symmetric, asymmetric, heavy-tailed, heteroskedastic, nonlinear/dynamic;
- sample sizes;
- train/test split;
- coverage levels, likely one per model object;
- DESN architecture grid;
- priors: ridge and RHS_NS;
- learning-rate grid or calibration rule;
- MCMC iteration budget and diagnostics;
- VB role, if any;
- comparison baselines;
- promotion criteria;
- storage budget and cleanup policy.

Important decision:

Do not compare RQR-DESN as if it were a quantile-grid model. Its native object
is an interval at one coverage level. If comparing against Q-DESN/exQDESN, use
matched intervals derived from lower/upper quantile fits and score interval
coverage/width/interval score.

Pass criteria:

- One written simulation spec exists before launch.
- No ambiguous terms such as `target_p` are used for RQR.
- The simulation can be reproduced from its spec and manifest.

## 6. Recommended Implementation Tasks Before Simulation

Priority order:

1. Create a clean package-build/check workflow.
   - Add missing `.Rbuildignore` exclusions if needed.
   - Avoid raw 3GB worktree checks.
   - Confirm temporary install and RQR installed tests.

2. Add the missing RQR contract tests.
   - Save/load.
   - `target_p` non-acceptance.
   - learning-rate storage/sensitivity.
   - root-label diagnostics.

3. Create a tiny deterministic calibration script.
   - Keep it separate from existing validation campaigns.
   - Write to a local, timestamped output directory.
   - No article updates.

4. Materialize and inspect tiny calibration outputs.
   - Build compact CSV/Markdown summaries.
   - Confirm every result is interpretable under the generalized-Bayes interval
     contract.

5. Write the broad simulation study spec.
   - Only after the tiny suite passes.

6. Launch broad simulation.
   - Only after the spec is frozen and output schema is validated.

## 7. What Not To Do Yet

Do not:

- launch a large RQR-DESN simulation immediately;
- update the article;
- add RQR tables or figures to Overleaf;
- modify PriceFM, GloFAS, joint-validation, or existing Q-DESN validation
  campaign scripts;
- treat VB as calibrated;
- use RQR pseudo-AL augmentation for response predictive sampling;
- route RQR through AL/exAL likelihood-family switches;
- silently accept `target_p` as a coverage level;
- run raw `R CMD check` on the full 3GB development tree and interpret the
  result as an RQR failure.

## 8. Final Recommendation

The current RQR-DESN implementation is good enough to enter a pre-simulation
readiness phase, but not yet good enough to justify a broad simulation campaign.

The optimal path is:

```text
committed backend
  -> clean package install/check workflow
  -> missing contract tests
  -> tiny deterministic calibration suite
  -> frozen output schema and simulation spec
  -> broad simulation launch
```

This sequence is slower than launching immediately, but it is much less likely
to create ambiguous results. It also respects the model's generalized-Bayes
status and keeps the article/application repositories insulated until there is
validated evidence worth promoting.
