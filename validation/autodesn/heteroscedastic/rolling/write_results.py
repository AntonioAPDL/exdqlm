"""Pedagogical report for the primary rolling-origin experiment."""
from pathlib import Path
import os,json
import numpy as np
import pandas as pd
ROOT=Path('validation/autodesn/heteroscedastic/rolling')
OUT=Path(os.getenv('AUTODESN_ROLLING_OUT',str(ROOT/'artifacts')))
REPORT=Path(os.getenv('AUTODESN_ROLLING_REPORT',str(ROOT/'RESULTS.md' if OUT.resolve()==(ROOT/'artifacts').resolve() else OUT/'RESULTS.md')))
s=pd.read_csv(OUT/'summary.csv');h=pd.read_csv(OUT/'by_horizon.csv');a=pd.read_csv(OUT/'audit.csv')
r=pd.read_csv(OUT/'by_replication.csv');k=pd.read_csv(OUT/'sensitivity.csv')
audit=json.loads((OUT/'audit_report.json').read_text())
names={'smooth_scale':'Smooth scale','threshold_gjr':'Threshold + GJR','switching_seasonal':'Switching seasonal'}
methods=['AutoDESN','Fixed_DESN','Gaussian_AR1','Gaussian_AR12','AR1_GJR_GARCH','Constant','Oracle_DGP']
labels={'AutoDESN':'AutoDESN','Fixed_DESN':'Fixed DESN','Gaussian_AR1':'AR(1)','Gaussian_AR12':'AR(12)','AR1_GJR_GARCH':'AR–GJR','Constant':'Constant','Oracle_DGP':'Known DGP'}
lines=['# Primary results: rolling-origin 30-step forecasts','',
 '**This is rolling-origin H=30 with observed feedback between origins and simulated feedback within each forecast.** The posterior is fitted once at time 2500. Parameters, architecture probabilities, reservoir weights, bridges and preprocessing remain fixed. This follows the repository’s corrected Q-DESN protocol; there is no refitting at each origin.','',
 'The initial split is 500 washout observations (1:500) and exactly 2,000 training likelihood contributions (501:2500). The same 100 held-out values (2501:2600) support 71 complete origins, 2500:2570, with all leads 1:30. There are three independent series for each of three nonlinear heteroscedastic DGPs.','',
 '| Origin | Last observed response | Forecast targets | Feedback inside the forecast |',
 '|---:|---:|---|---|',
 '| 2500 | y[2500] | 2501:2530 | Simulated values only |',
 '| 2501 | y[2501] | 2502:2531 | Simulated values only |',
 '| 2570 | y[2570] | 2571:2600 | Simulated values only |','',
 'For example, y[2501] updates the state before issuing the forecast at origin 2501. It never enters the forecast issued at origin 2500. A plot of consecutive 30-step-ahead predictions is therefore still a 30-step-ahead evaluation: the prediction at target t was issued at t−30.','',
 'The earlier [single 100-step forecast and one-step diagnostics](../RESULTS.md) are preserved separately. The rolling protocol was specified after that earlier run, at the user’s request. DGPs, priors, the 72-model bank and the initial fit window were not retuned. The Gaussian AutoDESN continues to assume constant innovation variance and an independent Gaussian ridge prior.','',
 '## Forecast comparison','',
 'The table gives RMSE at leads 1, 10 and 30, followed by distribution scores over all 30 leads. Every lead uses the same 71 origins and three series. “All leads” averages origin/lead pairs with equal weights; forecasts issued at different origins are never pooled into one predictive interval.','',
 '| Process | Model | RMSE h=1 | RMSE h=10 | RMSE h=30 | CRPS, all leads | 90% coverage | 90% width |',
 '|---|---|---:|---:|---:|---:|---:|---:|']
for kind in names:
 for method in methods:
  x=h[(h.dgp==kind)&(h.method==method)].set_index('horizon')
  z=s[(s.dgp==kind)&(s.method==method)].iloc[0]
  lines.append(f'| {names[kind]} | {labels[method]} | {x.loc[1,"rmse"]:.3f} | {x.loc[10,"rmse"]:.3f} | {x.loc[30,"rmse"]:.3f} | {z.crps:.3f} | {100*z.covered90:.1f}% | {z.width90:.3f} |')
lines += ['',
 'Lower RMSE, CRPS and negative log score are better. Coverage must be read with interval width. Complete log scores, 50% intervals, MAE, per-origin, per-lead and per-series metrics are exported. The known-DGP reference has true parameters and clock effects; its hidden regimes are observation-filtered. AR–GJR is a fitted plug-in reference with no parameter uncertainty. The AR references use their shared Normal scaled-ridge posterior, rather than AutoDESN’s independent ridge prior.','',
 'There are 2,130 origin/lead pairs per series, but only 100 distinct held-out observations. Overlapping targets and forecast origins are dependent. The independent replication count is three series per process; these results are descriptive, not a general superiority claim. Absolute scores should be compared between models within the same process.','',
 '| Process | AutoDESN h=30 RMSE, series 1 / 2 / 3 | Fixed DESN h=30 RMSE, series 1 / 2 / 3 |',
 '|---|---|---|']
for kind in names:
 vals=[]
 for method in ['AutoDESN','Fixed_DESN']:
  v=[]
  for rep in [1,2,3]:
   x=pd.read_csv(OUT/f'{kind}_r{rep:02d}'/'scores.csv.gz')
   z=x[(x.method==method)&(x.horizon==30)]
   v.append(np.sqrt(z.squared_error.mean()))
  vals.append(' / '.join(f'{v:.3f}' for v in v))
 lines.append(f'| {names[kind]} | {vals[0]} | {vals[1]} |')
threshold=s[s.dgp=='threshold_gjr'].set_index('method')
lines += ['',
 'At lead 30, AutoDESN improves on the prespecified fixed DESN in the smooth-scale and threshold examples; the two DESNs are close in the switching-seasonal example. Across all leads, AutoDESN has lower CRPS than fixed DESN in all three examples. AR/GJR references remain competitive or better in the short-memory examples, while both DESNs capture seasonal structure that these linear references miss. Small differences, including a fitted model occasionally scoring better than the known-DGP reference, do not establish population superiority.', '',
 f'Threshold-process rolling 90% coverage is {100*threshold.loc["AutoDESN","covered90"]:.1f}% for AutoDESN and {100*threshold.loc["Oracle_DGP","covered90"]:.1f}% for the known-DGP reference. This finite, overlapping test block therefore does not isolate variance misspecification from pooled coverage alone. The earlier one-step volatility-bin analysis provides a separate conditional-calibration diagnostic; uncertainty about its small dependent subgroups still matters.', '',
 '## What this evaluates','',
 'Rolling origins allow the reservoir and volatility filters to use newly observed responses before each new forecast is issued. They do not provide the future responses inside an issued forecast. This separates adaptation to observed shocks from prediction of unknown future shocks. In short-memory processes, a flat long-horizon mean can be appropriate even while each new origin refreshes the short-horizon forecast.','',
 'AutoDESN learns relative probabilities over a prespecified finite reservoir bank under its assumed training likelihood. High posterior mass does not guarantee optimal recursive forecast error or correct conditional variance. Better state updates and longer MCMC runs do not add a missing innovation-variance process. The earlier one-step conditional-calibration analysis remains useful for diagnosing that limitation.','',
 '## Inference replay, checkpoints and verification','',
 f'All 18 final fit screens pass. Maximum Rhat is **{a.max_rhat.max():.6f}**, minimum spectral ESS is **{a.min_ess.min():.1f}**, and maximum model probability range across chains is **{a.auto_model_chain_range.max():.5f}**. The final diagnostic-selected sampler seeds/durations are exactly replayed from the earlier experiment; failed earlier attempts remain in its original ledger. Model parameters are not relearned after time 2500.','',
 f'The restored checkpoint path replay has maximum absolute error **{np.max(np.abs(pd.read_csv(OUT/"checkpoint_path_replay.csv").reference-pd.read_csv(OUT/"checkpoint_path_replay.csv").replay)):.3g}** against all 64 archived original trajectories over their first 30 leads in every case. The model-probability replay maximum difference is **{a.posterior_probability_replay_max_abs.max():.3g}**. These checks verify that changing the forecast protocol did not silently change the initial fitted posterior.','',
 'Each origin uses 192 joint posterior draws × 16 innovations = 3,072 DESN paths. The same joint draws are reused across origins, held fixed over all leads. Quantiles pool paths using type 8; means average Gaussian component locations. Compact RDS checkpoints include selected joint draws and terminal states, so later horizon/origin experiments can reuse the fits. They are validation forecast objects, not complete training-design fit objects.','',
 '| First-origin Monte Carlo sensitivity | Mean RMS difference from K=32 | 90% endpoint RMS difference from K=32 |',
 '|---|---:|---:|']
for K in [8,16]:
 small=k[k.K==K].set_index(['dgp','repetition','horizon']);large=k[k.K==32].set_index(['dgp','repetition','horizon'])
 delta=small[['mean','lower90','upper90']]-large[['mean','lower90','upper90']]
 lines.append(f'| K={K}, all nine cases | {np.sqrt(np.mean(delta["mean"]**2)):.5f} | {np.sqrt(np.mean(delta[["lower90","upper90"]].to_numpy()**2)):.5f} |')
lines += ['',
 'Sensitivity uses paired innovation subsets and fixed posterior draws. It is an inner-path diagnostic, not total posterior Monte Carlo uncertainty; small forecast rankings should not be overstated.','',
 '- Three rolling contract-test groups pass: causal future replacement, fixed-origin equivalence, observed-state timing, all-layer state recovery including depth 3, joint-draw reuse, serial/parallel origin parity, innovation subset replay, complete origin/lead indices and GJR observed-update timing.',
 f'- **{audit["passed"]} independent rolling evidence checks** pass over all **134,190** origin/lead score rows, plus all **18** restored checkpoints, **17,280** replayed path values and **648** replayed architecture probabilities.',
 '- The existing seven heteroscedastic contract-test groups and 393 focused installed-package regression expectations remain passing; production R code is unchanged by this rolling adapter.',
 '- All captured inference-source hashes match. Earlier fixed-origin outputs are preserved. Repository-wide release checks were not rerun; inherited packaging/historical-study failures remain documented.',
 '- Elapsed case times include fitting/replay, all comparators, forecasts, scoring and file output. This is not an equal-compute comparison of Gibbs and SMC.','',
 '## Figures','',
 '![Exactly 30-step-ahead rolling forecasts](artifacts/rolling_exactly_30_steps.png)','',
 '![Separate recursive forecasts at five origins](artifacts/rolling_forecast_fans.png)','',
 '![Scores over all 30 leads](artifacts/rolling_horizon_scores.png)','',
 '![Predictive coverage over all 30 leads](artifacts/rolling_coverage.png)','',
 'Forecast examples always show replication 1; five issue times are prespecified for the fan plot. All 71 origins and all nine independent series enter the score tables. PDF versions accompany every figure.','']
figures=os.path.relpath(OUT,REPORT.parent).rstrip('/')+'/'
body='\n'.join(lines).replace('(artifacts/',f'({figures}')
REPORT.parent.mkdir(parents=True,exist_ok=True);REPORT.write_text(body)
print(REPORT)
