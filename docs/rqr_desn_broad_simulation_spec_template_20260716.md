# RQR-DESN Broad Simulation Specification Template

Date: 2026-07-16

Repository: `/data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

Branch: `feature/rqr-desn-readout-20260716`

Status: template only. Do not treat this file as a launch authorization.

## 1. Scientific Question

The broad study should evaluate whether the RQR-DESN interval readout produces
stable and useful conditional prediction intervals when coupled to the existing
Q-DESN reservoir/design machinery.

The native estimand is an interval at coverage level `coverage_level`, not a
single quantile and not a response predictive density. All downstream tables
should be written in interval language.

## 2. Required Implementation Pin

Before launch, fill these fields from git and the installed package library:

```text
implementation_commit:
branch:
remote_branch:
R_binary:
package_library:
package_install_log:
readiness_output_dir:
```

Launch is allowed only after the readiness harness has passed and produced:

```text
manifest.csv
scenario_manifest.csv
fit_summary.csv
interval_metrics.csv
mcmc_diagnostics.csv
vb_diagnostics.csv
session_info.txt
git_state.txt
output_hashes.csv
```

## 3. Model Backends

### 3.1 Reference Backend

Use MCMC as the reference backend:

```text
backend: rqr_desn_mcmc
inference: mcmc
primary: yes
```

MCMC must report:

- empirical interval coverage;
- mean interval width;
- interval score;
- midpoint accuracy when a true center is defined;
- endpoint accuracy when oracle endpoints are known;
- root-label stability through ordered `lower` and `upper`;
- loss-trace summaries;
- precision-strategy summaries;
- runtime and failure state.

### 3.2 VB Backend

Use VB only as a sidecar until it is separately calibrated:

```text
backend: rqr_desn_vb
inference: vb
primary: no
calibrated_uncertainty: no
```

VB may be useful for screening, initialization, or sensitivity diagnostics, but
its interval uncertainty should not be described as calibrated unless a separate
calibration study proves it.

## 4. Estimands And Scores

For feature row `x_t`, each posterior draw gives two roots:

```text
eta_1t = x_t' beta_1
eta_2t = x_t' beta_2
L_t    = min(eta_1t, eta_2t)
U_t    = max(eta_1t, eta_2t)
```

Report interval summaries:

```text
lower_mean
upper_mean
midpoint_mean
width_mean
```

Primary scores:

- empirical coverage: `mean(L_t <= y_t <= U_t)`;
- mean interval width: `mean(U_t - L_t)`;
- interval score for nominal coverage `1 - alpha`;
- midpoint MAE/RMSE when a location truth is meaningful;
- endpoint MAE/RMSE when true interval endpoints are known.

Do not report posterior predictive response samples. RQR-DESN does not define a
response likelihood.

## 5. Data-Generating Designs

Fill the final study with small, medium, and dynamic cases. Recommended DGP
families:

| DGP id | Purpose | Required truth |
|---|---|---|
| symmetric_linear | baseline interval calibration | true center and endpoints |
| skewed_linear | asymmetric noise robustness | empirical/oracle endpoints |
| heavy_tail_linear | tail robustness | empirical/oracle endpoints |
| heteroskedastic_linear | width adaptation | conditional endpoints |
| nonlinear_dynamic | reservoir feature value | oracle simulation endpoints |
| regime_dynamic | stability under breaks | held-out interval scores |

Each DGP row should declare:

```text
scenario_id
n_train
n_test
replicate_id
seed
coverage_level
learning_rate
reservoir_config_id
prior_type
backend
```

## 6. Coverage Levels And Learning Rates

Recommended starting grid:

```text
coverage_level: 0.50, 0.80, 0.90
learning_rate: 0.50, 1.00, 1.50
```

If the grid is reduced, keep at least one central interval and one high-coverage
interval. Learning-rate selection must be reported as either:

- fixed by design;
- validation-selected using only training/validation data;
- calibrated by a declared empirical-coverage target.

Never call `coverage_level` a quantile level.

## 7. DESN Design Grid

Use a controlled grid before expanding:

```text
D: 1, 2
n: small and moderate reservoir sizes
m: short and moderate lag embedding
washout: declared per design
seed: fixed per replicate/design
state standardization: inherited Q-DESN default
```

The first broad run should avoid a large Cartesian product. Prefer a factorial
screen followed by a focused confirmation run.

## 8. Priors

Required:

- ridge prior as baseline;
- RHS_NS prior as sparse-readout candidate.

RHS_NS must retain the no-intercept-shrink policy already used in the Q-DESN
codebase. Report the prior hyperparameters in the scenario manifest.

## 9. Baselines

Use interval-compatible baselines:

- empirical rolling interval;
- linear fixed-design RQR;
- Q-DESN/exQDESN matched lower/upper quantile pair, scored as an interval;
- optional conformalized baseline if a validation split is declared.

Do not compare RQR-DESN to a quantile-grid model using quantile scores unless
the comparison is explicitly converted into an interval target.

## 10. Output Contract

Every broad run should write:

```text
manifest.csv
scenario_manifest.csv
fit_summary.csv
interval_metrics.csv
mcmc_diagnostics.csv
vb_diagnostics.csv
failure_log.csv
session_info.txt
git_state.txt
output_hashes.csv
README.md
```

Required manifest fields:

```text
implementation_commit
branch
remote_branch
R_binary
package_library
scenario_id
replicate_id
seed
coverage_level
learning_rate
prior_type
prior_hyperparameters
DESN_D
DESN_n
DESN_m
washout
backend
inference
mcmc_control
vb_control
output_file
output_hash
```

## 11. Promotion Gates

A result can be promoted only if:

- all scenario outputs are finite and ordered;
- failures are documented, not silently dropped;
- MCMC diagnostics pass the declared thresholds;
- interval coverage/width/score improve over relevant baselines for the target
  DGP family;
- VB is either clearly labeled as sidecar or separately calibrated;
- no article or application repository is modified by the simulation launcher.

## 12. Stop Conditions

Stop and diagnose before continuing if:

- the temporary package install fails;
- any RQR contract test fails;
- readiness artifacts do not reproduce under the same seed;
- `target_p` or `p0` appears in an RQR launch configuration;
- a launch path tries to sample future responses from RQR;
- output manifests lack git commit, seed, coverage level, learning rate, or
  prior metadata.

## 13. First Launch Recommendation

The first real broad simulation should be modest:

```text
DGP families:       symmetric_linear, skewed_linear, nonlinear_dynamic
replicates:         20 per DGP family
coverage levels:    0.80 and 0.90
learning rates:     0.50, 1.00, 1.50
priors:             ridge, RHS_NS
backends:           MCMC primary, VB sidecar
DESN designs:       2 to 4 controlled designs
```

After this run, freeze a separate confirmation spec before scaling to larger
replicate counts or application-facing tables.
