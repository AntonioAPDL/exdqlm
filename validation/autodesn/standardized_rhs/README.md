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

The first standardized requested-prior run used the historical prefix local
embedding. All four budgets failed the architecture gates, including three
chains with 64,000 retained draws each; no forecasts were issued from those
fits. They are retained as `legacy_prefix_requested` evidence. Continuous
global-scale diagnostics alone would have accepted the last budget, which
demonstrates why architecture diagnostics are also necessary.

The final protocol uses two optional exact sampler improvements:
`local_layout="layerwise"` and `interweave_global=TRUE`. Layer/readout-index
slots avoid reassigning deepest-layer scales to shallow-layer features on a
depth change. Inactive half-Cauchy auxiliaries integrate to one. A second
global/local update holds products u*lambda fixed and samples their exact
prior conditional, then restores the augmentation conditionals. Neither
change alters the normalized RHS marginal target. Both are checked
independently; derivations are in `docs/autodesn/RHS.md`. This sampler revision
uses training diagnostics only, before any requested-prior test forecasts.

The layerwise run's four original budgets also failed the absolute
architecture-frequency range gate (0.07016 at 64,000 draws, despite acceptable
R-hat/ESS). Those attempts are preserved as `requested_initial_proposal`.
`run_rebalanced.R` is an explicit training-only computational extension: it
freezes `q=0.2*model_prior+0.8*attempt_4_occupancy` before a fresh three-chain
10,000-burn/64,000-draw fit. It uses fresh predeclared seeds separate from the
proposal-training chains and retains all
428 candidates, the exact Hastings correction, the same normalized RHS target
and unchanged forecast budgets. No requested-prior test forecasts had been
issued when this decision was made. Prior training cost is reported separately.

These are **exploratory sensitivity analyses** because the original C1 test
outcomes have already been inspected. Neither lower test errors nor this one
series establish general superiority. No additional search over tau0/slab
values is performed. Fresh independent series would be needed for a new
confirmatory comparison.

From the repository root, run large-bank jobs sequentially:

```bash
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
Rscript validation/autodesn/standardized_rhs/run.R --scenario requested --stage fit
# This first fit is expected to exit nonzero at the documented diagnostic gate.
# Preserve it before the fresh, training-only rebalanced production fit:
mv validation/autodesn/standardized_rhs/artifacts/requested validation/autodesn/standardized_rhs/artifacts/requested_initial_proposal
Rscript validation/autodesn/standardized_rhs/run_rebalanced.R
Rscript validation/autodesn/standardized_rhs/forecast_serial.R requested
Rscript validation/autodesn/standardized_rhs/run.R --scenario scaling_only
Rscript validation/autodesn/standardized_rhs/run.R --scenario ridge_standardized
# Repeat for scaling_only and ridge_standardized (using --method ridge):
Rscript validation/autodesn/rhs_comparison/sensitivity.R --method rhs --out validation/autodesn/standardized_rhs/artifacts/requested
Rscript validation/autodesn/standardized_rhs/export.R
Rscript validation/autodesn/standardized_rhs/archive.R
Rscript validation/autodesn/standardized_rhs/replay.R requested scaling_only ridge_standardized
python validation/autodesn/standardized_rhs/analysis.py
python validation/autodesn/standardized_rhs/report.py
python validation/autodesn/standardized_rhs/archive.py
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

Forecasts now default to one worker. `forecast_serial.R <scenario>` resumes
using only the qualified compact checkpoint and verifies frozen statistical
settings and production hashes. It avoids loading inference designs. The
driver requires every expected atomic checkpoint before reporting progress;
an undelivered fork result can no longer be mistaken for a completed batch.
For bounded fitting invocations, `run.R --stage fit --max-attempt N` stops at
the Nth predeclared diagnostic budget; a later invocation reuses saved chains.
The full attempt table stays in the contract and no unqualified forecast is
issued. Current runs embed the full study and executed harness hashes.
Actual pilot controls are exported from saved chains. The early scaling-only
run's inherited `configuration.pilot` field was unused; the effective controls
are three chains of 1,000 burn +2,000 retained draws, as its saved fits confirm.

`execute.py` runs all three cases and their predictive-MC sensitivities
sequentially and records measured exit codes, wall time and parent peak RSS.
`archive.R` retains the 384 joint predictive draws and required reservoir
templates; `archive.py` packs numeric evidence with SHA256 verification.

The commands above describe a fresh checkout with no local inference outputs.
An existing artifact directory is guarded by its original source and harness
hashes; use the saved checkpoints or a fresh output directory rather than
overwriting their contracts. Restored compact forecast checkpoints can be
replayed without rebuilding the multi-gigabyte inference bank. The historical
prefix-layout development attempts are archived evidence and are not required
to reproduce the final layerwise fit.

`export.R` requires the standard `gzip` executable and publishes compressed
traces atomically from closed regular CSV files. All compressed evidence is
read to EOF and hash checked before delivery. This fixed two truncated CSV
exports; their original RDS chain files were intact and were re-exported.
