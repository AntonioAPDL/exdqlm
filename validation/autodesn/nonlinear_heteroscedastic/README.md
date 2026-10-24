# NHS1: nonlinear seasonal dynamics and heteroscedastic innovations

This fresh DGP and seed are fixed before fitting. The models retain their
Gaussian likelihoods and constant observation-variance parameters, so this is
also a predictive-calibration stress test under likelihood misspecification.
No time trend is present. A centered 60-step seasonal pattern combines
asymmetric triangular pulses, a ramp and a 12-step block pattern. Residual
location uses a threshold coefficient (.58 below zero, .22 otherwise), tanh
terms at lags 2,12,60 and a nonlinear lag interaction. Conditional variance
uses a positive periodic/state-dependent baseline and GJR coefficients .06,
.10 (negative-innovation term), .82. Innovations are standard Gaussian.
Expected volatility persistence is .93; the baseline is bounded above by 0.046.
Thus innovation second moments are bounded. The residual linear coefficient
has magnitude <=.58 and all other location terms are bounded. A 6,000-step
burn-in precedes the retained 3,000 observations. This is a periodic process,
not a claim of covariance stationarity for the seasonal observed series.

Seed 1766021 is used once, without inspecting model test scores or selecting
among realizations. All models read only `input/series.csv` (time,y).
`input/dgp_truth.csv` is used only for reporting. There is no full-series
centering or selection on held-out outcomes.

The C1 temporal protocol is preserved: 500 washout, 2,000 training, 500 test;
471 origins 2500:2970; leads 1:30; fitting once; frozen model weights; observed
states between origins and simulated responses within each forecast. The same
456 reservoir definitions and washout-admission rule are used for every new
AutoDESN case. Readout columns are standardized on rows 501:2500 only, with
`standardize_features=TRUE, normalize_features=FALSE`; the proper intercept is
unscaled. Three AutoDESN cases (requested RHS .001/1/4, scaling-only RHS 1/2/4,
standardized ridge) and freshly fitted pinned Native AutoGP are compared.
Existing C1 scores are not reused for the new DGP.

`study.json` records the original chain/predictive budgets and seeds.
`fit_joint.R` declares the subsequent joint-kernel budget extension; each saved
configuration and provenance file records the controls actually executed. The initial model-only proposals failed their training diagnostics. A full-support joint
architecture/log-scale independence proposal is fitted to those training chains,
frozen, and used in fresh production chains with the exact MH correction;
all architectures retain positive proposal mass and the exact Hastings ratio.
Unqualified chains issue no forecasts. Independent rank/ESS checks are run
before primary forecasting. Full predictive sensitivity uses three fixed
origins and the same 192/384 x4/8/16/32 budgets as before.

This is one DGP realization. Its rolling forecast pairs are dependent and are
not independent simulation replications. No general superiority claim follows.


See ENVIRONMENT.md for executed versions, binary checksums and runtime reconstruction.
Run from the repository root with project-local R and Julia on PATH:

```bash
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
R CMD INSTALL .
Rscript validation/autodesn/nonlinear_heteroscedastic/test_joint.R
python validation/autodesn/nonlinear_heteroscedastic/test_joint.py
Rscript validation/autodesn/nonlinear_heteroscedastic/test_joint_local.R
python validation/autodesn/nonlinear_heteroscedastic/test_joint_local.py
Rscript validation/autodesn/nonlinear_heteroscedastic/test_dgp.R
Rscript validation/autodesn/nonlinear_heteroscedastic/test_workflow.R
Rscript validation/autodesn/nonlinear_heteroscedastic/run.R --stage build
python validation/autodesn/nonlinear_heteroscedastic/execute_joint.py
# The recorded scaling-control architecture-range failure stops that stage.
# This next stage fits ridge/NativeGP and declares a same-prior control recovery:
python validation/autodesn/nonlinear_heteroscedastic/execute_remaining.py --julia /path/to/julia --project /path/to/AutoGP.jl
# With all model forecasts complete, audit and package the study:
python validation/autodesn/nonlinear_heteroscedastic/postprocess.py --julia /path/to/julia --project /path/to/AutoGP.jl
python validation/autodesn/nonlinear_heteroscedastic/report.py
python validation/autodesn/nonlinear_heteroscedastic/validate_report.py
# Inspect every rendered page, then record that review:
python validation/autodesn/nonlinear_heteroscedastic/validate_report.py --confirm-visual-review
# Split large checkpoints, archive, restore, rerun analysis and require exact table parity:
python validation/autodesn/nonlinear_heteroscedastic/finalize.py
```

For an existing committed delivery, run `evidence/restore_evidence.py`, followed
by `analysis.py --data validation/autodesn/nonlinear_heteroscedastic/evidence/restored`.
This verifies all part, archive and internal checksums and rebuilds the summary
tables without rerunning inference.

The committed input is frozen; `generate.R` is for explicitly regenerating it,
not selecting another realization. `execute_joint.py` resumes guarded per-chain and
per-origin checkpoints. Large inference jobs run sequentially. Every failed
sampling attempt remains available and no failed screen is waived. Both failed model-only proposals are recorded as separate training stages.
The subsequent joint MH recovery uses three fresh chains and declares budgets
of 4,000/16,000, 8,000/32,000, 12,000/64,000 and 16,000/128,000 burn/retained
iterations per chain before any test forecasting. The original four model-only
MH proposals per sweep are retained, with two additional joint proposals.
The fitted proposal has full support; all priors and conditional updates retain
their exact normalized target. The scaling-only case transports proposal centers,
then uses its own exact target. This changes computation, not the model.
Any failed independent screen rejects that retained budget and advances to the
next declared budget. Shared proposal-training costs are reported separately.
Pure parameter/architecture tests and independent rank/ESS checks precede test
forecasting. Postprocessing additionally perturbs unavailable future responses
and replays compact archived checkpoints at the first, middle and last origins.
Native GP inference and its own save/reload/conditioning checks run fresh on
this dataset. Its finite-particle SMC diagnostics are reported separately from
AutoDESN MCMC diagnostics.

The optional joint sampler is checked against independent normalized densities,
acceptance ratios and small-posterior integration; disabled-option draws match
the previous source exactly. Focused production regressions and posterior
oracles are rerun for this source. `evidence/production_validation_reference.json`
is a historical C1 reference, not proof for changed production code. Fresh
DGP/workflow tests and full-size posterior screens are separate requirements. Package-wide inherited release-check issues
remain documented; a clean repository-wide R CMD check is not claimed.

Large compressed predictive checkpoints, when needed, are split into 7 MB Git
objects with `checkpoint_parts.json`; smaller ones are committed whole.
`evidence/restore_evidence.py` reconstructs and verifies all complete checkpoints
before restoring the numeric archive. Every one of the 384 predictive joint
draws is retained. `prepare_delivery.py` prepares these objects after the
completed forecast checkpoints have been pruned and losslessly compressed.

The first scaling-only joint fit exhausted its 128k budget with a 9.8-point
between-chain architecture-frequency range (the frozen limit is 5 points),
even though its continuous-parameter screens passed. It issued no forecasts.
`fit_control_recovery.R` freezes a new full-support model/three-scale proposal
from those same-prior training chains and declares a single fresh three-chain
16k burn +128k retained recovery, with fresh base seed 8266020. This changes
only the computational proposal. The exact posterior, prior controls,
reservoirs and forecast protocol are retained. All failed training costs and
any interrupted invocation observations remain part of the execution record.
