# Frozen NHS1 data-generating process

This is a custom benchmark, not a reproduction of a published named dataset.
One seed, 1766021, is fixed before any fitting or model test-score inspection.
There is no search over seeds or DGP coefficients.

Let \(p_t=((t-1)\bmod60)/60\),
\(d(p,a)=\min\{|p-a|,1-|p-a|\}\), and
\(P_{a,b}(t)=\max\{0,1-d(p_t,a)/b\}\). Define
\(B_t=1\) when \((t-1)\bmod12<4\), and \(-1/2\) otherwise. The seasonal offset is

\[
\widetilde s_t=P_{.18,.10}(t)-.8P_{.64,.18}(t)
                  +.35(2p_t-1)+.18B_t,
\qquad s_t=\widetilde s_t-\frac1{60}\sum_{j=1}^{60}\widetilde s_j.
\]

The observed series is \(y_t=s_t+x_t\). With \(a(x)=.58\) for \(x<0\)
and \(.22\) otherwise, its residual dynamics are

\[
\begin{aligned}
f_t={}&a(x_{t-1})x_{t-1}+.28\tanh(1.4x_{t-2})
       -.25\tanh(x_{t-12})+.22\tanh(x_{t-60})\\
     &+.20\tanh(1.5x_{t-1}x_{t-2}),\\
x_t={}&f_t+\epsilon_t,\qquad \epsilon_t=\sqrt{h_t}\,z_t,
\qquad z_t\stackrel{\mathrm{iid}}\sim N(0,1),\\
\omega_t={}&.008+.018P_{.18,.10}(t)+.012P_{.64,.18}(t)
                     +.008\tanh^2(x_{t-1}),\\
h_t={}&\omega_t+.06\epsilon_{t-1}^2
       +.10\epsilon_{t-1}^2\mathbf1\{\epsilon_{t-1}<0\}
       +.82h_{t-1}.
\end{aligned}
\]

Seasonal forcing is nonsinusoidal, and the threshold and lag interaction give
nonlinear stochastic dynamics even after removing the deterministic season.
The conditional variance changes with season, past residual state, shock size
and shock sign. No linear or stochastic trend component is included.

## Moment control and initialization

The coarse bound \(.008\le\omega_t\le.046\) is deterministic. Since innovations
are conditionally symmetric Gaussian,

\[
E(h_t)\le .046+(.06+.10/2+.82)E(h_{t-1})
              =.046+.93E(h_{t-1}).
\]

Thus innovation second moments are bounded. Also
\(|f_t|\le.58|x_{t-1}|+.95\). Young's inequality gives
\(f_t^2\le.5046x_{t-1}^2+2.7075\); conditional zero-mean innovations then imply
a finite uniform second-moment bound for the residual process. These are
moment bounds, not a claim that the observed seasonal series is covariance
stationary or a proof of a particular mixing rate.

Initialization uses sixty zero residual lags, previous innovation zero and
variance .2. Simulate 6,000 steps, then retain 3,000. The burn-in is a multiple
of 60, so the retained season starts at phase one. This simulation burn-in is
distinct from the first 500 **retained** observations used for reservoir
washout and the existing response-preprocessing convention. None of the
discarded simulation history is supplied to a fitted model.

The seed uses R's Mersenne-Twister, Inversion normal generator and Rejection
sampling mode. Generating a longer series leaves its common prefix unchanged;
the simulator restores the caller's RNG state. Values are not subsequently
centered using the full observed series or chosen by their test behavior.

## Observation interface and evaluation

Models receive only `input/series.csv` (time,y). Exact seasonal offsets,
residuals, conditional means, conditional innovation SDs and Gaussian
innovations are in a separate truth file used for reporting only. One-step
volatility plots refer to the generator's conditional innovation variance;
they do not substitute a future realized variance for a multi-step marginal
predictive variance.

The 500/2,000/500 split, 471 origins2500:2970, 30 leads and fit-once rule match
the frozen C1 protocol. Reservoir definitions and priors are shared across the
three new AutoDESN cases; the same washout-admission rule is applied to this
new series. Native AutoGP is fitted fresh using its pinned native grammar,
priors and inference schedule. The fitted models retain constant conditional
observation-variance parameters, so this experiment measures their robustness
to heteroscedastic misspecification. It does not claim that an explicit
heteroscedastic likelihood has been implemented.

There is one DGP realization. Overlapping rolling forecasts and the independent
computational MCMC/SMC runs are not additional independent DGP replications.
