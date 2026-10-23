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
Expected volatility persistence is .93; the baseline is bounded above by.046.
Thus innovation second moments are bounded. The residual linear coefficient
has magnitude <=.58 and all other location terms are bounded. A 6,000-step
burn-in precedes the retained 3,000 observations. This is a periodic process,
not a claim of covariance stationarity for the seasonal observed series.

Seed1766021 is used once, without inspecting model test scores or selecting
among realizations. All models read only `input/series.csv` (time,y).
`input/dgp_truth.csv` is used only for reporting. There is no full-series
centering or selection on held-out outcomes.

The C1 temporal protocol is preserved:500 washout,2,000 training,500 test;
471 origins2500:2970; leads1:30; fitting once; frozen model weights; observed
states between origins and simulated responses within each forecast. The same
456 reservoir definitions and washout-admission rule are used for every new
AutoDESN case. Readout columns are standardized on rows501:2500 only, with
`standardize_features=TRUE, normalize_features=FALSE`; the proper intercept is
unscaled. Three AutoDESN cases (requested RHS .001/1/4, scaling-only RHS1/2/4,
standardized ridge) and freshly fitted pinned Native AutoGP are compared.
Existing C1 scores are not reused for the new DGP.

`study.json` freezes chain/predictive budgets and seeds. A single training-only
proposal recovery is permitted after failed RHS architecture diagnostics;
all architectures retain positive proposal mass and the exact Hastings ratio.
Unqualified chains issue no forecasts. Independent rank/ESS checks are run
before primary forecasting. Full predictive sensitivity uses three fixed
origins and the same 192/384 x4/8/16/32 budgets as before.

This is one DGP realization. Its rolling forecast pairs are dependent and are
not independent simulation replications. No general superiority claim follows.
