# C1: unit-variance readout and RHS sensitivity

The previous comparison z-scored the response on observations 1:500 and used
H/sqrt(d) readout features. It did **not** z-score each reservoir readout
column. Q-DESN's model-selection wrappers can use `readout_scale_fit`; the
reservoir builder's `standardize_inputs` flag is a different operation.

AutoDESN now reuses `readout_scale_fit`, `readout_scale_apply`, and
`readout_unscale_beta`. `standardize_features=TRUE` estimates column means and
sample SDs only on scored training rows (501:2500 in C1), saves them, and freezes
them for every new row and recursive forecast. Constant columns with training
SD <=1e-8 are excluded with a frozen mask. The proper intercept is not
standardized. Its coefficient shift during transport back to raw reservoir
coordinates is retained exactly.

`normalize_features=FALSE` is explicit in this study: the actual prior-input
columns have unit sample variance. Enabling both options would divide those
unit-variance columns by sqrt(d), giving variance 1/d, not one. Existing API
defaults retain their historical behavior.

Three predeclared scenarios use the same frozen C1 series and 428 admitted
architectures:

| Scenario | Prior | tau0 | slab_scale | slab_df |
|---|---|---:|---:|---:|
| requested | normalized RHS | 0.001 | 1 | 4 |
| scaling_only | normalized RHS | 1 | 2 | 4 |
| ridge_standardized | Gaussian ridge | - | - | - |

The requested slab prior is c^2 ~ IG(2,2). Global/local/slab scales are sampled;
tau0 and slab hyperparameters are fixed. The scaling-only scenario separates
feature scaling from changing hyperparameters. The standardized ridge is a
matched feature-basis comparator. AutoGP remains the frozen completed native
reference. No Gaussian model is replaced by a quantile likelihood.

These are **exploratory sensitivity analyses** because the original C1 test
outcomes have already been inspected. Neither lower test errors nor this one
series establish general superiority. No additional search over tau0/slab
values is performed. Fresh independent series would be needed for a new
confirmatory comparison.

From the repository root, run large-bank jobs sequentially:

```bash
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
Rscript validation/autodesn/standardized_rhs/run.R --scenario requested
Rscript validation/autodesn/standardized_rhs/run.R --scenario scaling_only
Rscript validation/autodesn/standardized_rhs/run.R --scenario ridge_standardized
```

The runner rebuilds the original causal raw bank once, fits the shared scaling
map once, checks every admitted architecture's column moments, and saves a
restartable standardized bank. Three training-only pilots inform a fixed
full-support proposal with exact Hastings correction. Actual completed pilot
and MCMC costs are reported separately. The frozen attempts and gates are in
`configuration.json`; budgets can increase only in response to those training
posterior diagnostics. Unqualified attempts never issue forecasts.

The forecasting protocol stays 500/2000/500, 471 daily origins (2500:2970),
leads 1:30 and 192 joint draws x8 innovation paths. Fits and weights stay fixed;
observations update reservoir states only between origins. A transport parity
check compares the production standardized forecast API with the raw-basis
rolling adapter before any test scoring.
