# Bounded Gaussian screening -> AL median DESN study
Status: protocol frozen before generating the study series or inspecting validation/test scores.
Base: 18c0635be9185f29d30962dff612d68fe3f71141. New branch: feature/autodesn-al-median-small-20261124.

## Scope and estimands
One simulated monthly series, 3500 observations. Gaussian ridge screening selects one fixed DESN specification; one normalized-RHS AL median chain then fits that specification. This is two-stage model selection, not Bayesian architecture averaging. No AutoGP, SV search, multichain ladder or confirmatory replication campaign belongs to this bounded experiment. Historical studies remain unchanged. Gaussian screening uses the existing exact scaled-ridge Normal-DESN readout, explicitly distinct from the old independent-ridge AutoDESN Gibbs target.

## DGP and exact truth
Freeze seed 20261124. z_t = .88 z_(t-1) + .12 epsilon_t, epsilon iid standard Cauchy; stationary z_0 is standard Cauchy. Let g(z)=asinh(z)+.45*tanh(2.5*z), strictly increasing, and y_t=s_month(t)+g(z_t). The 12 fixed monthly effects are centered versions of [.4,1.1,.3,-.8,-.4,-.1,.7,1.6,.1,-.9,-1.2,-.8]. This is a transformed latent AR benchmark: its observed conditional dynamics are nonlinear, its conditional noise is non-Gaussian and state dependent, and y has finite moments despite the latent Cauchy tails. It is not claimed to be an unrestricted nonlinear autoregression with additive Cauchy errors on the observation scale.

At origin o and horizon h:
location=.88^h*z_o; scale=.12*(1-.88^h)/(1-.88).
Q_p(y_(o+h)|F_o)=s_month(o+h)+g(location+scale*tan(pi*(p-.5))).
Thus the exact median is s_month(o+h)+g(.88^h*z_o), at every horizon. z_o is recoverable from observed y_o-s_month(o), so truth does not condition on unavailable future states. Never recursively plug in one-step medians as a general oracle. General quantiles and median truth are evaluated independently in Python; no high-budget Monte Carlo oracle is needed.

## Frozen chronology
1:500 conditioning/washout; 501:1900 initial fitting (1400 rows); 1901:2900 validation (1000 observations); 2901:3500 test (600 observations).
Validation origins: round(seq(1900,2840,length.out=10)); H=60, 600 nonoverlapping scored pairs across the 1000-observation block. The other 400 observations can enter later observed-history updates, not issued forecasts. Test origins 2900+60*(0:9), covering 2901:3500 exactly once.
Gaussian parameters/scalers are fit once at1900; states update with observations between validation origins. Freeze selection using validation only, refit selected architecture/scalers and AL coefficients once at2900, and keep parameters fixed throughout test. Forecast paths recursively simulate unknown responses; teacher forcing is forbidden inside any issued 60-step block. DGP truth is excluded from selection.

## Preprocessing, dictionary and selection
Response/input conditioning mean/SD use observations1:500. All readout slopes, including direct lags/calendar features, are centered and unit-sample-SD scaled on fitting rows only; proper intercept is exempt. Monthly indicators are known-in-advance regressors, shared by every candidate, not fitted from test outcomes.
Reuse qdesn_fit_vb(fit_readout=FALSE) and .normal_desn_transition_engine; verify feature/state parity before running screening.
144 frozen reservoir definitions: depth{1,2,3} x width{12,24} x input lags{1,3,12} x leak{.25,.7} x spectral radius{.5,.9} x seeds{301,907}; identity bridges, tanh activation, sparsity .1, fixed input scale. Add direct y lags1,12 and 11 calendar indicators consistently in both likelihoods.
For each reservoir use Gaussian ridge precisions{.1,1,10,100}, proper intercept and IG(3,1) noise hyperprior: 576 screening configurations before documented numerical exclusions. Reject only predeclared nonfinite/failed-washout designs, not by test scores.
Coarse stage: all configurations, all ten validation origins and all60 horizons, 16 recursive predictive paths. Fine stage: the best16 coarse configurations, same origins/horizons, 256 paths. Rank by observed validation median pinball loss (equivalently half MAE); deterministic tie-breaking favors lower dimension then candidate ID. Save both stage scores and Monte Carlo budgets. This is a finite-budget shortlist search and does not establish a global optimum. No one-step-only screening shortcut.
A small seasonal-median and persistence baseline provides context; no extra MCMC comparator family. Gaussian quality is a proxy for AL performance, not a guarantee. Do not change the DGP/seed/grid after seeing results.

## AL target and bounded computation
p=.5; likelihood_family='al', al_fixed_gamma=0; normalized beta_prior_type='rhs' (never accept the wrapper's exal/rhs_ns defaults). Reuse exal_mcmc_fit with the selected design and existing sampler. tau0=.001, slab_df=4, slab_scale=1; sampled local/global/slab scales; proper intercept variance10 and noise scale IG(3,1). This retains the previously requested RHS controls while removing architecture MCMC entirely.
Production: ONE chain, 3000 burn-in and5000 retained sweeps, thin1. No automatic burn-in beyond5000, no extra chain, no escalation to hundreds of thousands of sweeps. A separate small computational smoke test is not an independent production chain. If diagnostics fail, report failure/limitations rather than relaxing criteria or launching a large repair campaign.
Use a transient selected Gaussian readout for initialization if basis hashes agree. Do not save Gaussian fits.
Monitor sigma, global/slab scales, representative coefficients, log target and fixed-design median probes. Report trace/ACF, spectral ESS, batch MCSE and first/second-half drift. Single-chain R-hat is unavailable; do not manufacture it by splitting one chain. Flag ESS<100 or probe MCSE>.05 training-response SD. These are limited within-chain screens, not proof of convergence.

## Forecasts, figures and precision
AL future errors are sampled under its working likelihood; the DGP is not AL. Calculate predictive medians from full recursive posterior-predictive paths, not posterior averages of location paths.
Use2048 paths per issued forecast in bounded chunks. Check nested1024/2048 precision on validation origins before test; report it honestly. A single registered increase to4096 paths is allowed for forecast-MC precision if necessary; the MCMC budget is unchanged.
Keep fitted conditional-median credible bands distinct from model predictive intervals. Main figure: observed series and fitted/true one-step conditional medians; all ten test blocks with forecast/true multi-step medians and clearly labeled predictive bands; selected origin closeups. Add trace+ACF diagnostics and horizon-wise median error. Scores: pinball/MAE against observations, error against true medians, by-horizon/pooled, plus model predictive coverage/widths where useful. No statistical superiority claim from this one development series.

## Tests and gates
Before screening: analytic quantile/median checks (h1,2,60); independent Cauchy-sum simulation checks; scale and chronology assertions; independent dense Gaussian posterior/evidence reference; reservoir builder/transition parity; scalar/batched forecast agreement with fixed noise; future-perturbation invariance; exact600-pair test tiling; selection exclusion of truth/test outcomes.
Before reporting: AL parameterization/prior assertions; existing small-target sampler tests where applicable; finite complete retained draws; unchanged source/config hashes; single-chain diagnostics; predictive-MC sensitivity; saved-output policy test. Python independently recomputes DGP truth, losses and reported summaries.
Do not call test code presence an executed test. Preserve failed attempts with their source/version and actual exit status. Do not modify immutable executed snapshots.

## Resources and storage
One numerical job; BLAS/OpenMP1 thread; C++ compilation at most2 jobs. Profile time/memory first. Cap a study stage at30min and full study at90min; pause/report a stage that cannot complete rather than silently expanding budgets. Target numerical memory<3GiB and persisted new study outputs<30MiB. Existing large historical artifacts are neither restored nor duplicated.
Retain only Gaussian score tables, specifications/seeds, preprocessing definitions/hashes, stage times/failure reasons. No Gaussian posterior, coefficient arrays, paths or reservoir banks on disk.
Retain compact selected AL beta/sigma/global/slab draws, full scalar diagnostics needed for trace plots, one exact final sampler state where supported, data/truth CSVs,600 test summaries, configuration/source hashes, tests and resource records. Do not retain latent n-by-draw arrays or predictive path cubes. Do not claim exact resumability unless tested.
R is installed project-locally if missing; record exact runtime and native dependencies. Do not change public package defaults.

## Deliverables and completion
PLAN.md and PRO_PROMPT.txt; configuration; reusable R/Python study code and focused tests; executed scores/specification; selected AL posterior/diagnostics; main PNG/PDF figures; compact PDF report and README; source-bound execution status; committed branch and draft PR.
First publish this plan before viewing outcomes. Then implement, test, profile, screen, fit, forecast, independently audit, visually inspect the PDF, and commit/push only verified outputs. If blocked, preserve checkpoints and state precisely what remains. Never imply unfinished jobs are running.
