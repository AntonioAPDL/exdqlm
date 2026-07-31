# Q-DESN 500-Observation Posterior-Informed RHS Refit Protocol

Date: 2026-07-30

Status: protocol and implementation plan only. This document does not authorize
computation, promotion, article modification, cleanup, commit, or push.

Current decision: this is a secondary empirical-Bayes sensitivity protocol,
not the primary next calibration screen. The topology and forecast-transport
diagnosis in
`QDESN_500OBS_MCMC_REMAINING_OBJECTIVE_AUDIT_2026-07-30.md` must govern the
next experiment. In particular, posterior-informed centering must not replace
topology-valid recurrence, independent source replication, or coherent
cell-specific MCMC confirmation.

## 1. Purpose

This protocol defines a reproducible experiment for testing whether a
coefficient center learned from an exact replay of a current cell-specific
Q-DESN or exQ-DESN winner can improve a second regularized-horseshoe readout.
The experiment covers:

- Q-DESN with the AL working likelihood and `rhs_ns`;
- exQ-DESN with the exAL working likelihood and `rhs_ns`;
- VB and MCMC as separate inference targets;
- Gaussian, Laplace, and Gaussian-mixture innovations;
- quantile levels 0.05, 0.25, and 0.50;
- the frozen 500-observation fit and rolling-origin forecast protocol.

There are 18 model/family/quantile cells and 36 method-specific parent cells
after VB and MCMC are separated. Every cell must retain its own winning DESN
specification, RHS hyperparameters, likelihood, seed contract, and inference
configuration. A global winner is neither required nor desired.

The governing rule is monotone:

> A new result may be promoted only when it produces a confirmed, material
> improvement over the currently frozen value for the exact same
> model/family/quantile/method/protocol/metric. A result that does not improve
> the current metric cannot replace it.

Beating the matched DQLM/exDQLM comparator remains the scientific objective.
It is not, however, sufficient for replacing a stronger existing Q-DESN or
exQ-DESN value.

## 2. Scope Exclusions

This protocol does not cover:

- ridge readouts;
- DQLM or exDQLM calibration;
- the 5000-observation stage;
- joint-QDESN;
- GloFAS, PriceFM, or another application;
- modification of the exdqlm 1.0.0 MCMC kernel;
- article changes before a completed confirmation closeout;
- silent presentation of a data-adaptive prior as an ordinary Bayesian RHS
  fit.

No unrelated process, report tree, handoff store, worktree, or article
repository may be altered by this work.

## 3. Frozen Validation Contract

The read-only audit for this plan confirmed:

| Field | Frozen value |
|---|---|
| Worktree | `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0` |
| Branch | `validation/shared-fitforecast-v2-1.0.0` |
| Audited HEAD | `b24cb53f34863f1ca7a6df95c8508d341de5692d` |
| Package | `exdqlm` 1.0.0 |
| Source-registry hash field | `source_registry_sha256` |
| Source-registry SHA-256 | `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275` |
| Fit source indices | 8501--9000 |
| Forecast source indices | 9001--10000 |
| Forecast-window length | 1000 |
| Rolling-origin maximum lead | 30 |
| Rolling-origin stride | 30 |
| Forecast refitting | none |

The frozen article-facing MCMC numerical envelope is:

```text
validation/fitforecast_v2/promotions/
  qdesn_dqlm_500obs_mcmc_metric_envelope_20260727/
  qdesn_dqlm_500obs_mcmc_metric_envelope_20260727_article_envelope.csv
```

Its SHA-256 is:

```text
aa4399576453ec0e9eeb21fa2166a1aaeed977c976064b13c4dc27f963cbb9a1
```

The final-origin evidence freeze is:

```text
validation/fitforecast_v2/promotions/
  qdesn_500obs_mcmc_nested_final_origin9000_v1_evidence_freeze_20260730/
  evidence_freeze_manifest.json
```

It records `NO_CONFIRMED_COHERENT_ARTICLE_REFRESH`, zero coherent promotion
cells, and origin 9000 as exposed. The valid scientific run tag is:

```text
qdesn-500obs-mcmc-nested-final-o9000-v1-full-20260730__git-bd4da62
```

The following run tag is permanently rejected and may not be consumed:

```text
qdesn-500obs-mcmc-nested-final-o9000-v1-full-20260730__git-6582f87
```

### 3.1 Article-facing table synchronization

Before implementation of this protocol, the independent-validation table was
audited in the authoritative article repository:

```text
/data/jaguir26/local/src/Article-Q-DESN---Version-2
```

The audited article state is:

| Field | Verified value |
|---|---|
| Branch | `main` |
| Local HEAD | `befa756c0f684cc27e39fc3a1a9dc68e2b6576e7` |
| `origin/main` | `befa756c0f684cc27e39fc3a1a9dc68e2b6576e7` |
| `overleaf-direct/main` | `befa756c0f684cc27e39fc3a1a9dc68e2b6576e7` |
| Commit subject | `Close independent validation article authority` |
| Overleaf tracking-ref evidence | updated by push on 2026-07-30 at 19:56:56 EDT |

`main.tex` includes:

```text
tables/qdesn_validation_tt500_final_mcmc_tables.tex
```

That wrapper includes the Gaussian, Laplace, and Gaussian-mixture MCMC tables.
The committed artifact hashes are:

| Article artifact | SHA-256 |
|---|---|
| `qdesn_validation_tt500_final_mcmc_normal.tex` | `312c957d45fe5d3727873728d4d94019fe360ede8176f917365a6b5b8a713785` |
| `qdesn_validation_tt500_final_mcmc_laplace.tex` | `741f74123e7d7626f68c82c12ad9e09330391360709f613a21e7a39e2ae7f7e2` |
| `qdesn_validation_tt500_final_mcmc_gausmix.tex` | `4be9e9f24768da45ec88037f90c73dbdabd6d663edbe1520db2e9520b866c5c0` |
| `qdesn_validation_tt500_final_mcmc_tables.tex` | `cc6e6d59855fbdaeaeb7081c9d83e81ca0c17926f55c4d1982e2f70ef82c1d14` |
| `qdesn_validation_tt500_mcmc_current_best_manifest.txt` | `cbf6ecf19f0f8b4360235633231fd988eae8b8021155e7beeb506e8caecc793d` |

The article-side checker:

```text
scripts/check_qdesn_mcmc_current_best_validation_tables.R
```

verified four authority inputs, four article artifacts, and all 108 displayed
values against the 36-row validation authority. It returned `PASS` with
`article_numeric_update: FALSE`. A fresh `pdflatex`, `bibtex`, `pdflatex`,
`pdflatex` build produced a 38-page PDF with no unresolved references,
undefined citations, multiply defined labels, overfull boxes, fatal errors,
or package warnings. Visual inspection confirmed that Tables 5--7 are
present, legible, and contain the three family-specific MCMC comparisons.

The article worktree contains an unrelated modification to
`application/R/latent_path_design.R`. It is outside this protocol and was not
modified. The article table files, wrapper, manifest, `main.tex`, and checking
script are clean relative to `main`.

The direct Overleaf fetch requires interactive credentials and could not be
refreshed in the noninteractive audit shell. The existing remote-tracking ref
is nevertheless tied to the confirmed push above and is byte-identical to
local `main` and `origin/main` for `main.tex`, all four table artifacts, and
the article manifest.

## 4. Current MCMC Promotion Thresholds

The following values are immutable inputs to this experiment. They are
metric-wise minima and not necessarily values from one coherent fit.

| Model | Family | Tau | Fit RMSE | Forecast MAE | Forecast check loss | Source form |
|---|---|---:|---:|---:|---:|---|
| Q-DESN AL-RHS | Gaussian mixture | 0.05 | 3.132003 | 2.571018 | 1.509858 | mixed |
| Q-DESN AL-RHS | Gaussian mixture | 0.25 | 1.954568 | 1.433798 | 4.505759 | coherent |
| Q-DESN AL-RHS | Gaussian mixture | 0.50 | 1.229260 | 2.779351 | 5.630450 | mixed |
| Q-DESN AL-RHS | Laplace | 0.05 | 5.322601 | 4.703657 | 1.887768 | coherent |
| Q-DESN AL-RHS | Laplace | 0.25 | 2.253207 | 1.535760 | 4.390124 | mixed |
| Q-DESN AL-RHS | Laplace | 0.50 | 1.216571 | 1.098431 | 4.980221 | mixed |
| Q-DESN AL-RHS | Gaussian | 0.05 | 2.838512 | 7.479031 | 1.221411 | mixed |
| Q-DESN AL-RHS | Gaussian | 0.25 | 2.238495 | 2.559260 | 3.342507 | mixed |
| Q-DESN AL-RHS | Gaussian | 0.50 | 1.517605 | 2.561628 | 4.124856 | mixed |
| exQ-DESN exAL-RHS | Gaussian mixture | 0.05 | 3.606842 | 2.028191 | 1.506921 | mixed |
| exQ-DESN exAL-RHS | Gaussian mixture | 0.25 | 1.964056 | 3.974210 | 4.658963 | mixed |
| exQ-DESN exAL-RHS | Gaussian mixture | 0.50 | 1.317303 | 2.776571 | 5.632443 | coherent |
| exQ-DESN exAL-RHS | Laplace | 0.05 | 6.446461 | 2.143007 | 1.856392 | mixed |
| exQ-DESN exAL-RHS | Laplace | 0.25 | 1.727325 | 1.355324 | 4.378391 | mixed |
| exQ-DESN exAL-RHS | Laplace | 0.50 | 1.262725 | 1.115724 | 4.986135 | mixed |
| exQ-DESN exAL-RHS | Gaussian | 0.05 | 2.481001 | 2.651934 | 1.076381 | mixed |
| exQ-DESN exAL-RHS | Gaussian | 0.25 | 1.758852 | 3.117967 | 3.366673 | coherent |
| exQ-DESN exAL-RHS | Gaussian | 0.50 | 1.516444 | 2.525932 | 4.124292 | mixed |

These thresholds must be copied, with the envelope hash, into every
materialized experiment manifest. A later script must read them from the
frozen CSV rather than duplicating the numbers in executable code.

## 5. Why an Exact Coherent Parent Is Required

The frozen MCMC evidence contains 111 successful Q-DESN/exQ-DESN candidate
rows across all 18 target cells. Their diagnostic grades are 21 PASS, 58 WARN,
and 32 FAIL. Four article-envelope rows are coherent; 14 combine metrics from
different candidates.

It is invalid to create one posterior-informed prior from the fit-RMSE winner,
forecast-MAE winner, and check-loss winner. A posterior center must come from
one actual fitted model with:

- one atomic specification;
- one design matrix and feature ordering;
- one reservoir seed contract;
- one likelihood and RHS prior;
- one inference implementation;
- one set of posterior draws or variational moments.

For each MCMC cell, the provisional parent is therefore the coherent candidate
that minimizes:

```text
max(
  candidate_fit_rmse / current_fit_envelope,
  candidate_forecast_mae / current_forecast_mae_envelope,
  candidate_check_loss / current_check_loss_envelope
)
```

Ties are broken by the sum of the three ratios and then candidate ID. This is
a deterministic minimum-worst-regret rule. It selects the one coherent fit
closest to the three current metric-wise minima.

## 6. Provisional Coherent MCMC Parent Map

This table is an audited planning input, not yet a materialized authority.
FAIL/WARN parents remain provisional until exact replay and stability checks
pass.

| Model | Family | Tau | Provisional parent | Source run tag | Grade | Worst/envelope |
|---|---|---:|---|---|---|---:|
| Q-DESN AL-RHS | Gaussian mixture | 0.05 | `mcvbc_004_al` | `qdesn-tt500-mcmc-vbcandidate-full-20260716-025532__git-abe3439` | PASS | 1.011 |
| Q-DESN AL-RHS | Gaussian mixture | 0.25 | `mcvbc_014_al` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | FAIL | 1.000 |
| Q-DESN AL-RHS | Gaussian mixture | 0.50 | `mcvbc_022_al` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | PASS | 1.074 |
| Q-DESN AL-RHS | Laplace | 0.05 | `mcvbc_030_al` | `qdesn-tt500-mcmc-vbcandidate-full-20260716-025532__git-abe3439` | WARN | 1.000 |
| Q-DESN AL-RHS | Laplace | 0.25 | `mcvbc_041_al` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | PASS | 1.007 |
| Q-DESN AL-RHS | Laplace | 0.50 | `mcvbc_049_al` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | PASS | 1.133 |
| Q-DESN AL-RHS | Gaussian | 0.05 | `mcvbc_057_al` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | WARN | 1.161 |
| Q-DESN AL-RHS | Gaussian | 0.25 | `mcvbc_060_al` | `qdesn-tt500-mcmc-vbcandidate-full-20260716-025532__git-abe3439` | PASS | 1.060 |
| Q-DESN AL-RHS | Gaussian | 0.50 | `mcvbc_067_al` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | WARN | 1.098 |
| exQ-DESN exAL-RHS | Gaussian mixture | 0.05 | `mcvbc_009_exal` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | FAIL | 1.157 |
| exQ-DESN exAL-RHS | Gaussian mixture | 0.25 | `mcvbc_018_exal` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | FAIL | 1.005 |
| exQ-DESN exAL-RHS | Gaussian mixture | 0.50 | `mcvbc_027_exal` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | PASS | 1.000 |
| exQ-DESN exAL-RHS | Laplace | 0.05 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | `qdesn-tt500-mcmc-vbwin-rescue-fail5-full-20260630__git-c051364` | WARN | 1.035 |
| exQ-DESN exAL-RHS | Laplace | 0.25 | `mcvbc_045_exal` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | WARN | 1.010 |
| exQ-DESN exAL-RHS | Laplace | 0.50 | `mcvbc_052_exal` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | WARN | 1.072 |
| exQ-DESN exAL-RHS | Gaussian | 0.05 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | `qdesn-tt500-mcmc-vbwin-rescue-fail5-full-20260630__git-c051364` | WARN | 1.124 |
| exQ-DESN exAL-RHS | Gaussian | 0.25 | `mcvbc_065_exal` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | FAIL | 1.000 |
| exQ-DESN exAL-RHS | Gaussian | 0.50 | `mcvbc_070_exal` | `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c` | WARN | 1.097 |

The materializer must resolve every provisional parent to its `spec_id`,
`root_id`, profile CSV, atomic fit request, package commit, source hash,
reservoir seed, MCMC seed, burn-in, retained iterations, posterior predictive
draw count, and output evidence. A row with an unresolved field must hard-fail
materialization.

## 7. VB Parent Audit

The VB state is less complete and must not be inferred from the MCMC map.

The active VB calibration freeze is:

```text
validation/fitforecast_v2/docs/
  qdesn_tt500_vb_active_baseline_freeze_20260715.csv
```

It identifies `qvbm1` as a calibration-only reference: 192/192 roots,
5,760 forecast-lead rows, and no article or MCMC promotion. Its winner table
covers only eight cells.

The historical handoff is:

```text
validation/fitforecast_v2/docs/
  qdesn_tt500_vb_historical_winner_handoff_manifest_20260709.json
```

It records 5,298 candidate rows, 517 historical all-primary wins, 40 selected
assignments, and 27 selected unique profiles across nine family/quantile
cells. However, that handoff was materialized with exAL as the default and its
selected-design table does not carry a likelihood field. It cannot serve as a
complete 18-cell AL/exAL parent registry.

Before a VB posterior-informed run, a new materializer must:

1. read every committed historical VB dominance summary and profile source;
2. restore likelihood identity from the original defaults, root requests, and
   run manifests;
3. standardize the current protocol and metric names;
4. create separate AL and exAL candidate pools;
5. apply the same coherent minimum-worst-regret rule within each
   model/family/quantile cell;
6. resolve all 18 cells to exact atomic specifications;
7. report missing or ambiguous likelihood provenance as a hard failure.

The MCMC parent and VB parent for a cell may differ. They must never be
substituted silently.

## 8. Parent Replay Contract

No surviving Q-DESN coefficient handoff or fitted posterior object was found
under the Q-DESN report and result trees. The retained `.rds` files are compact
simulation-source fixtures, not fitted Q-DESN posterior payloads. Therefore
the parent fits must be reproduced from their recorded specifications.

Large `.ffv2handoff` objects under the 2026-07-08 exDQLM/DQLM VB calibration
tree belong to a different model task. They are excluded and must not be read,
modified, or cleaned by this experiment.

For every parent replay:

1. load package code from the exact validation worktree;
2. verify `DESCRIPTION` version 1.0.0 and record its hash;
3. verify the source-registry hash and source window;
4. resolve and hash the atomic specification;
5. rebuild the exact reservoir using the recorded topology and seed;
6. use the recorded inference controls and random seeds;
7. reproduce the fit and forecast metrics;
8. compare replayed metrics with recorded parent metrics;
9. extract the compact posterior center only after replay verification.

The VB replay tolerance is:

```text
max(1e-8, 0.001 * abs(recorded_metric))
```

The MCMC replay tolerance is:

```text
max(0.01 * abs(recorded_metric), 2 * estimated_metric_MCSE)
```

All three primary metrics must satisfy the replay tolerance. A FAIL/WARN
parent whose posterior center is unstable across chains or repeated seeds may
remain in the diagnostic ledger, but it cannot supply an authoritative prior
center. The parent selector must then advance to the next coherent candidate
for that cell.

## 9. Posterior Information to Retain

The primary center is the coefficient posterior mean because the current
Q-DESN fitted path is produced from the posterior or variational coefficient
mean.

For VB:

```text
beta_center = qbeta mean
```

For MCMC:

```text
beta_center = mean of retained beta draws after burn-in and thinning
```

The compact handoff must contain:

- `beta_center.csv`, with feature index, feature name, and center value;
- optional diagonal coefficient uncertainty;
- coefficient dimension and intercept policy;
- design-matrix hash and ordered feature-name hash;
- reservoir topology, realized nonzero counts, and reservoir seed;
- source-registry hash and source indices;
- parent candidate, spec, root, run tag, and commit;
- inference controls and random seeds;
- recorded and replayed parent metrics;
- handoff file hashes;
- replay-gate result.

Full covariance matrices and posterior draws are transient by default. They
may be held in memory during a parent/refit pair but are not routine retained
artifacts.

## 10. Statistical Mechanism

The existing package provides exported low-level `exal_ldvb_fit()` and
`exal_mcmc_fit()` functions. `qdesn_fit_mcmc()` already builds the Q-DESN
design through `qdesn_fit_vb(..., fit_readout = FALSE)` and sends the resulting
`X` and `y` to the low-level MCMC readout.

The package has a `gaussian_natural` coefficient prior for VB, but the MCMC
kernel accepts only `ridge`, `rhs`, or `rhs_ns`. Replacing RHS with a Gaussian
posterior prior would therefore:

- change the prior family;
- create an asymmetric VB/MCMC experiment;
- require an exdqlm kernel modification;
- defeat the stated goal of retaining RHS.

The package warm-start mechanism can initialize beta, sigma, gamma, and RHS
state. A warm start changes initialization, not the stationary posterior
target. It is a necessary target-preserving control but is not expected to
produce a durable metric improvement after adequate convergence.

The recommended validation-only mechanism is a shifted RHS:

```text
beta = kappa * beta_center + delta
delta ~ RHS
```

For the original design `X` and response `y`, fit:

```text
y_star = y - X %*% (kappa * beta_center)
y_star = X %*% delta + error
```

Reconstruct fit and forecast quantiles as:

```text
qhat_original = X_new %*% (kappa * beta_center) + qhat_delta
```

The reservoir design must always be built from the original response. Calling
a complete Q-DESN fit on `y_star` would rebuild response-derived reservoir
states and would define a different DESN. The adapter must instead build the
original design once and call only the low-level readout on `y_star`.

This mechanism:

- preserves the original coherent DESN specification;
- preserves AL or exAL;
- preserves the RHS distribution around the shifted center;
- works symmetrically for VB and MCMC;
- requires no package-kernel change;
- isolates prior centering from topology, tau0, and likelihood changes.

## 11. Data-Reuse Lanes

Three lanes must be distinguished.

### 11.1 Target-preserving control

Use the exact parent specification with:

- `kappa = 0`;
- ordinary RHS;
- optional posterior-derived warm start.

This lane verifies replay, adapter equivalence, and whether initialization
alone affects finite-chain computation.

### 11.2 Independent-calibration center

This is the preferred article-eligible experiment.

1. Freeze an independent simulation replicate from the same DGP.
2. Fit the exact cell-specific parent on the calibration replicate.
3. extract and hash `beta_center`;
4. fit the shifted-RHS model on the existing target replicate;
5. evaluate on the target fit and forecast windows.

The calibration replicate must have its own source-registry identity, seed,
and hash. Its seed must be committed before fitting. The existing target
replicate and origin 9000 remain exposed, so final confirmation requires a new
predeclared simulation replicate.

### 11.3 Same-data posterior center

The exact parent may also be replayed on the target data and its center reused
on the same target data. This is an empirical-Bayes, data-adaptive diagnostic.
It is not an ordinary RHS fit.

Using a full posterior as the next prior would reuse the likelihood directly.
The shifted-center approach does not literally square the likelihood because
it transfers only a center and retains an RHS distribution, but the center is
still learned from the same observations.

Therefore:

- same-data results may diagnose whether centering can improve the numerical
  surface;
- they may not silently replace ordinary RHS article rows;
- article use requires explicit methodological disclosure or independent
  calibration/confirmation evidence;
- an internal metric gain alone does not waive this requirement.

## 12. Experimental Arms

Every cell begins with the exact same parent specification and RHS `tau0`.
Topology, width, depth, lags, alpha, rho, sparsity, likelihood, gamma handling,
and sigma prior remain fixed during this experiment.

Primary arms:

| Arm | Center source | Kappa | Purpose |
|---|---|---:|---|
| `ordinary_replay` | none | 0.00 | target-equivalence control |
| `warm_start_only` | parent | 0.00 | initialization-only control |
| `center_025` | parent | 0.25 | conservative center transfer |
| `center_050` | parent | 0.50 | moderate center transfer |
| `center_100` | parent | 1.00 | full center transfer |

The first experiment must not also retune `tau0`, topology, gamma, or sigma.
Changing multiple mechanisms would make any gain uninterpretable. A later
stage may retune `tau0` only if centering shows a transferable benefit and the
need is documented cell by cell.

## 13. Staged Implementation Plan

### Stage 0: Authority snapshot

Create a machine-readable baseline manifest containing:

- validation branch and commit;
- package version and file hashes;
- source-registry identity and hash;
- frozen envelope path and hash;
- all 18 MCMC metric thresholds;
- current VB baseline evidence paths;
- exposed and reserved source replicates;
- valid, invalid, and diagnostic-only run tags.

No model code runs in this stage.

### Stage 1: Parent registries

Materialize:

```text
qdesn_500obs_posterior_informed_rhs_mcmc_parent_registry.csv
qdesn_500obs_posterior_informed_rhs_vb_parent_registry.csv
qdesn_500obs_posterior_informed_rhs_parent_manifest.json
```

Required columns include:

```text
model_variant, likelihood_family, family, tau, inference_method,
parent_candidate_id, parent_spec_id, parent_root_id, parent_run_tag,
parent_run_stamp, parent_git_sha, parent_profile_path,
parent_atomic_spec_path, parent_atomic_spec_sha256,
D, n_each, n_tilde_each, m, readout_y_lags, reservoir_lags,
alpha, rho, pi_w, pi_in, washout, add_bias,
rhs_tau0, reservoir_seed, inference_seed,
n_burn, n_keep, thin, posterior_draw_count,
fit_source_start, fit_source_end, forecast_start, forecast_end,
source_registry_sha256, recorded_fit_rmse,
recorded_forecast_mae, recorded_forecast_check_loss,
selection_rule, selection_rank, provisional_signoff_grade
```

All 36 method-specific cells must resolve exactly before Stage 2.

### Stage 2: Replay-only validation

Replay parents without posterior-informed refitting. Produce:

- replay metrics;
- metric deltas from recorded parents;
- feature/design hashes;
- realized reservoir diagnostics;
- chain/VB diagnostics;
- terminal statuses;
- replay eligibility.

A failed replay blocks only its cell. It does not block unrelated cells.

### Stage 3: Compact handoff extraction

For each eligible replay:

1. extract `beta_center`;
2. validate dimensions and feature order;
3. hash the handoff;
4. write the compact manifest;
5. verify that the handoff can be read independently;
6. delete or release the transient full fit only after verification.

### Stage 4: Adapter implementation and tests

Implement the shifted-RHS adapter in validation-only scripts. Do not alter the
exdqlm 1.0.0 package kernel.

Required tests:

- shifted-response algebra;
- reconstructed prediction equality;
- `kappa = 0` equivalence;
- original-response design invariance;
- intercept handling;
- feature-order and design-hash hard failures;
- AL and exAL;
- VB and MCMC;
- independent-calibration and same-data lane labels;
- no future leakage;
- unchanged rolling-origin grid;
- compact handoff round trip;
- restart/resume behavior;
- atomic status markers;
- storage-policy enforcement;
- monotone metric promotion;
- coherent-promotion no-regression rule;
- rejection of the permanently invalid run tag.

### Stage 5: Sentinel pilot

Run only:

| Cell | Diagnostic role |
|---|---|
| Q-DESN AL, Gaussian, tau 0.05 | broad fit and forecast failure |
| exQ-DESN exAL, Laplace, tau 0.05 | large fit gap but strong forecast |
| exQ-DESN exAL, Gaussian mixture, tau 0.25 | forecast-transport failure |
| exQ-DESN exAL, Laplace, tau 0.25 | resolved negative control |

Exercise both VB and direct MCMC. VB may help explain the mechanism, but it
must not be a hard gate for MCMC because historical VB and MCMC rankings do
not transfer reliably.

### Stage 6: Sentinel decision

Stop the experiment if:

- only same-data fit RMSE improves;
- forecast MAE or check loss materially regresses;
- independent-calibration performance does not improve;
- gains depend on one reservoir or MCMC seed;
- `kappa = 0` fails replay equivalence;
- the centered effect disappears at a second development origin or replicate.

Continue only when at least one sentinel shows a transferable, coherent gain.

### Stage 7: Cell-specific VB mapping

Evaluate all eligible VB parents with the frozen arm set. Select `kappa`
separately for every cell. Retain all finite candidate evidence, but promote
nothing at this stage.

### Stage 8: Direct MCMC evaluation

For every MCMC cell:

- run the ordinary replay;
- run warm-start-only;
- run the best one or two cell-specific `kappa` values;
- use at least two independent MCMC seeds;
- keep one worker thread per fit;
- preserve the full MCMC budget only for candidates surviving the sentinel
  mechanism gate.

Do not assume that the VB winner is the MCMC winner.

### Stage 9: Fresh confirmation

Any apparent gain at the exposed target source is development evidence only.
Final confirmation must use a simulation replicate whose source seed and hash
were frozen before candidate evaluation.

Confirmation uses:

- exact selected parent and `kappa`;
- full MCMC budget;
- multiple MCMC seeds;
- paired fit-path and forecast-path comparisons;
- block-aware uncertainty for time-indexed metrics;
- no further tuning after the confirmation source is opened.

### Stage 10: Closeout and promotion

Produce:

- complete candidate ledger;
- per-metric delta table;
- coherent candidate table;
- paired confirmation summary;
- chain/VB diagnostic summary;
- failure ledger;
- storage audit;
- retained-file manifest with hashes;
- invalid-run-tag list;
- machine-readable promotion decision;
- readable decision report.

No article update is automatic.

## 14. Promotion Rules

Let `B_j` be the current frozen value and `C_j` a confirmed candidate value for
metric `j`. Define:

```text
delta_j = max(
  0.005 * abs(B_j),
  2 * estimated_MCSE_j,
  1e-10
)
```

A metric improves only when:

```text
C_j <= B_j - delta_j
```

For discovery triage, a candidate should ordinarily improve a metric by at
least 1% and remain within 1% of the other current metrics.

### 14.1 Candidate ledger

Every finite result is retained as diagnostic evidence. Inclusion does not
mean promotion.

### 14.2 Monotone metric envelope

Only an improved metric is replaced. A candidate that improves fit RMSE but
worsens forecast metrics may update only fit RMSE after confirmation. It may
not overwrite the other two values.

The envelope must retain:

- source candidate and run tag per metric;
- metric-specific hash;
- mixed-source flag;
- prior-center lane;
- empirical-Bayes disclosure status.

### 14.3 Coherent result promotion

A coherent fit may replace a complete row only if:

1. at least one primary metric materially improves;
2. no primary metric regresses by more than 1%;
3. replay, source, design, and handoff hashes pass;
4. multiseed and fresh-source confirmation pass;
5. the method label accurately describes posterior-informed centering.

### 14.4 Failure status

A finite FAIL/WARN result may nominate a design for replay. It cannot become
authoritative until the metric gain reproduces and the posterior center is
stable enough to define a reproducible handoff.

### 14.5 No-improvement outcome

If no candidate clears the material-improvement threshold:

- the July 27 authority remains unchanged;
- no article value changes;
- the negative experiment is documented;
- no additional heavy objects are retained;
- the method is not adopted merely because it was expensive to evaluate.

## 15. Storage-Light and Cleanup Contract

The experiment must use a task-specific run root and scratch directory. It
must never reuse or clean another campaign's directories.

Retain:

- scalar fit metrics;
- H=100 and H=1000 scalar forecast metrics;
- compact rolling-origin and lead summaries;
- `beta_center.csv` and optional diagonal uncertainty;
- configs, atomic specs, manifests, hashes, logs, statuses, and failures;
- compact chain and convergence summaries;
- promotion and cleanup reports.

Do not routinely retain:

- full VB fit objects;
- MCMC draw arrays;
- reservoir-state arrays;
- full covariance matrices;
- `.rds`, `.rda`, `.RData`, or `.ffv2handoff` model payloads;
- duplicate design matrices.

Preferred lifecycle:

1. reproduce parent in memory;
2. extract and validate the compact handoff;
3. run the paired posterior-informed child when practical;
4. write compact child evidence;
5. verify hashes and terminal markers;
6. prune only task-owned transient payloads;
7. write a cleanup manifest listing removed files and recovered bytes.

If process boundaries require a temporary fit payload, it must live under:

```text
reports/qdesn_mcmc_validation/
  qdesn_500obs_posterior_informed_rhs/<run_tag>/scratch/
```

The scratch manifest must declare its owner, parent cell, expected lifetime,
and cleanup state. Failure-debug payload retention is limited to a
predeclared tiny subset and a fixed byte cap. Authoritative evidence is never
deleted during automatic cleanup.

## 16. Failure and Resume Policy

Every root receives:

- immutable atomic specification;
- `PLANNED`, `RUNNING`, `SUCCESS`, `FAILED`, or `BLOCKED` status;
- 30-minute heartbeat;
- MCMC iteration progress every 50 iterations;
- independent parent-replay and child-fit statuses;
- explicit failure phase and message;
- atomic terminal marker.

Resume rules:

- a verified parent handoff may be reused by its own child arms;
- a completed child may not be recomputed unless explicitly requested;
- a failed child does not invalidate the verified parent;
- a failed parent blocks all child arms for that parent;
- source/design/handoff hash mismatch is a hard failure;
- resume selects only missing or failed roots;
- cleanup runs only after all consumers of a transient handoff are terminal.

## 17. Planned Reproducibility Artifacts

Implementation should add:

```text
validation/fitforecast_v2/scripts/
  materialize_qdesn_500obs_posterior_informed_rhs_parents.R
  verify_qdesn_500obs_posterior_informed_rhs_parents.R
  orchestrate_qdesn_500obs_posterior_informed_rhs.R
  closeout_qdesn_500obs_posterior_informed_rhs.R

validation/fitforecast_v2/tests/testthat/
  test-qdesn-posterior-informed-rhs-design.R
  test-qdesn-posterior-informed-rhs-promotion.R
  test-qdesn-posterior-informed-rhs-storage.R

config/validation/
  qdesn_dynamic_fitforecast_v2_500obs_posterior_informed_rhs_defaults.yaml
  qdesn_dynamic_fitforecast_v2_500obs_posterior_informed_rhs_parents.csv
  qdesn_dynamic_fitforecast_v2_500obs_posterior_informed_rhs_grid.csv
```

Each generated file must appear in a file manifest with SHA-256, size, and
role. Run tags must include the stage, date, and short git SHA.

## 18. Decision Gates

| Gate | Required evidence | Failure action |
|---|---|---|
| Authority freeze | exact current hashes and thresholds | stop |
| Parent resolution | 36/36 exact atomic parents | block unresolved cells |
| Parent replay | all metrics within replay tolerance | advance to next parent |
| Handoff | feature/design/source hashes pass | stop cell |
| Adapter tests | all targeted and regression tests pass | no compute |
| Sentinel | transferable coherent gain in at least one difficult cell | stop experiment |
| Full mapping | complete terminal evidence, no silent missing rows | close out failures |
| Confirmation | fresh source, multiseed, material improvement | no promotion |
| Promotion | monotone metric or coherent no-regression gate | retain old authority |
| Cleanup | compact evidence verified before pruning | defer cleanup |

## 19. Why This Is a Valid Secondary Plan

This design is a defensible secondary sensitivity experiment because:

1. the previous searches already covered depth 1--4, width 4--300, lags
   1--150, broad alpha/rho ranges, and RHS `tau0` from `2e-8` to `1e-3`;
2. the latest nested screen failed through source-window transfer rather than
   missing output or insufficient chain length;
3. the proposed experiment changes one previously untested mechanism while
   holding the current winning specification fixed;
4. it uses exact parent provenance rather than approximating a past winner;
5. it supports AL/exAL and VB/MCMC without modifying exdqlm 1.0.0;
6. it prevents a mixed metric envelope from being mistaken for one posterior;
7. it makes improvements monotone and leaves current authority untouched when
   no improvement occurs;
8. it separates internal same-data diagnostics from article-eligible
   confirmation;
9. it remains storage-light even though historical posterior objects were
   pruned;
10. it supports cell-level replay, failure recovery, and targeted MCMC without
    rerunning unrelated cells.

## 20. Final Readiness Decision

The scientific idea makes sense as a controlled posterior-centering
experiment. It does not justify immediately adopting the resulting numbers.

Implementation may begin only with authority freezing, parent-registry
materialization, replay verification, and tests. The sentinel pilot must
precede a full campaign. A result is used only if it materially improves a
current metric under the confirmation contract. A complete row is replaced
only when the coherent no-regression gate also passes.

No model run, promotion, article update, cleanup, commit, or push is authorized
by this document alone.
