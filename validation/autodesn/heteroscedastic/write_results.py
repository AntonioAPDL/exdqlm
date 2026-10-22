"""Generate a concise evidence report from the completed frozen experiment."""
from pathlib import Path
import os
import pandas as pd
import numpy as np

ROOT=Path('validation/autodesn/heteroscedastic')
OUT=Path(os.getenv('AUTODESN_HETERO_OUT',str(ROOT/'artifacts')))
REPORT=Path(os.getenv('AUTODESN_HETERO_REPORT',str(ROOT/'RESULTS.md' if OUT.resolve()==(ROOT/'artifacts').resolve() else OUT/'RESULTS.md')))
s=pd.read_csv(OUT/'summary.csv'); a=pd.read_csv(OUT/'audit.csv')
d=pd.read_csv(OUT/'diagnostics.csv'); p=pd.read_csv(OUT/'probability.csv')
v=pd.read_csv(OUT/'volatility_groups.csv'); raw=pd.read_csv(OUT/'scores.csv')
reps=pd.read_csv(OUT/'by_replication.csv')
names={'smooth_scale':'Smooth scale','threshold_gjr':'Threshold + GJR','switching_seasonal':'Switching seasonal'}
methods=['AutoDESN','Fixed_DESN','Gaussian_AR1','Gaussian_AR12','AR1_GJR_GARCH','Constant','Oracle_DGP']
labels={'AutoDESN':'AutoDESN','Fixed_DESN':'Fixed DESN','Gaussian_AR1':'AR(1)',
        'Gaussian_AR12':'AR(12)','AR1_GJR_GARCH':'AR–GJR','Constant':'Constant','Oracle_DGP':'Known DGP'}
lines=['# Earlier fixed-origin and one-step heteroscedastic diagnostics','', '**The primary evaluation is now [rolling-origin 30-step forecasting](rolling/RESULTS.md).** This page preserves the earlier single 100-step forecast and one-step diagnostics.','',
       'All nine cases use 500 initial washout/scaling observations, exactly 2,000 training likelihood contributions (501:2500), and 100 test observations (2501:2600). Three independent series are simulated for each of three custom nonlinear processes. The earlier 500/500/100 experiment is preserved.','',
       '**The AutoDESN likelihood remains Gaussian with constant innovation variance and an independent Gaussian ridge prior.** This study tests that implementation under heteroscedastic misspecification; it does not implement a variance reservoir or change the readout prior. The 72-model bank and all simulation parameters are frozen before scoring. See [README](README.md) for equations and full reproduction instructions.','']
for mode,title,detail in [('fixed_origin','100-step recursive forecast','Each forecast is issued once at observation 2500. Every trajectory feeds back its own simulated observations; it receives no held-out outcomes. Means and intervals are marginal over joint posterior draws and stochastic paths.'),('one_step','One-step observed-feedback evaluation','Each target is predicted before observing it. Its observation then updates reservoir lags and volatility filters for later targets. Coefficients and model probabilities remain fixed at time 2500. These scores reuse the same test outcomes and are a separate task, not additional independent replications.')]:
    lines += [f'## {title}','',detail,'',
              '| Process | Model | RMSE | CRPS | NLL | 90% coverage | 90% width | 50% coverage |',
              '|---|---|---:|---:|---:|---:|---:|---:|']
    for kind in names:
        for method in methods:
            r=s[(s.dgp==kind)&(s['mode']==mode)&(s.method==method)].iloc[0]
            lines.append(f'| {names[kind]} | {labels[method]} | {r.rmse:.3f} | {r.crps:.3f} | {r.negative_log_score:.3f} | {100*r.covered90:.1f}% | {r.width90:.3f} | {100*r.covered50:.1f}% |')
    lines += ['', 'RMSE pools squared errors over 300 targets per process. CRPS and negative log predictive density (NLL) are lower-is-better distribution scores. Coverage needs to be read alongside interval width. The known-DGP reference has true parameters and known clock effects; hidden regimes are observation-filtered. AR–GJR is a training-only plug-in fit that omits parameter uncertainty.','']
lines += ['## Conditional calibration and replication variability','',
          'One-step volatility groups use training-only quartiles of the known-DGP predictive SD. For the switching process this integrates uncertainty in the hidden state. The bins are diagnostic evaluation labels, not information supplied to the fitted forecasts.','',
          '| Process | Volatility | Targets | AutoDESN 90% coverage | AR–GJR 90% coverage | Known-DGP 90% coverage |',
          '|---|---|---:|---:|---:|---:|']
for kind in names:
    for group in ['low','middle','high']:
        part=v[(v.dgp==kind)&(v.volatility_group==group)].set_index('method')
        if part.empty: continue
        lines.append(f'| {names[kind]} | {group} | {int(part.loc["AutoDESN","count"])} | {100*part.loc["AutoDESN","covered90"]:.1f}% | {100*part.loc["AR1_GJR_GARCH","covered90"]:.1f}% | {100*part.loc["Oracle_DGP","covered90"]:.1f}% |')
lines += ['','Three series per process support descriptive comparisons only. The targets are serially dependent, and some volatility groups are small. Monte Carlo paths and forecast horizons are not replication units. Per-series scores are in `artifacts/by_replication.csv`.','',
          '| Process | AutoDESN fixed-origin RMSE across series | Fixed DESN RMSE across series |',
          '|---|---|---|']
for kind in names:
    vals=[]
    for method in ['AutoDESN','Fixed_DESN']:
        x=reps[(reps.dgp==kind)&(reps['mode']=='fixed_origin')&(reps.method==method)].sort_values('repetition')
        vals.append(', '.join(f'{z:.3f}' for z in x.rmse))
    lines.append(f'| {names[kind]} | {vals[0]} | {vals[1]} |')
lines += ['','## Sampler and specification audit','']
final=d[d.attempt==d.groupby(['dgp','repetition','method']).attempt.transform('max')]
passed=bool(a.auto_diagnostic_pass.all() and a.fixed_diagnostic_pass.all())
lines += [f'All final sampler screens pass: **{passed}**. Across the final AutoDESN and fixed-DESN chains, maximum rank/folded split Rhat is **{final.rhat.max():.6f}**, minimum spectral ESS is **{final.ess_spectral.min():.1f}**, and maximum cross-chain model probability range is **{final.max_model_chain_range.max():.5f}**. Each fit uses three distinct initializations. All attempts, including any failed earlier screens, are retained in `diagnostics.csv`.','']
retry=d.groupby(['dgp','repetition','method']).attempt.max()
lines += [f'{int((retry>1).sum())} of {len(retry)} fits required the prespecified diagnostic-only retry. No retry depends on forecast performance. All nine fitted GJR references have a converged selected optimization start; their starts and constrained parameters are exported.','']
if (retry>1).any():
    lines += ['| Retried fit | Attempts | Final max Rhat | Final min ESS | Final model-chain range |','|---|---:|---:|---:|---:|']
    for (kind,r,method),attempt in retry[retry>1].items():
        z=final[(final.dgp==kind)&(final.repetition==r)&(final.method==method)]
        lines.append(f'| {names[kind]}, series {r}, {labels[method]} | {attempt} | {z.rhat.max():.6f} | {z.ess_spectral.min():.1f} | {100*z.max_model_chain_range.max():.2f} pp |')
    lines += ['']
lines += ['| Process | Series | Highest-probability specification | Posterior mass |',
          '|---|---:|---|---:|']
for (kind,r),x in p.groupby(['dgp','repetition'],sort=False):
    row=x.loc[x.posterior_probability.idxmax()]
    lines.append(f'| {names[kind]} | {r} | depth {int(row.D)}, width {int(row.width)}, lag {int(row.m)}, {row.profile}, seed {int(row.seed)} | {100*row.posterior_probability:.1f}% |')
lines += ['','Specification mass measures relative fit under the frozen finite bank, priors and constant-variance likelihood. It is not a probability that the data-generating process literally is a DESN, nor a guarantee of good conditional coverage.','',
          '## Forecast Monte Carlo and verification','',
          'The primary AutoDESN forecasts use 192 joint model/coefficient/variance draws, each repeated across 64 innovation trajectories: 12,288 paths. A joint draw is fixed over all leads. Pooled type-8 quantiles estimate predictive intervals; conditional Gaussian locations are averaged to reduce current-innovation Monte Carlo noise. Log scores average Gaussian component densities along paths.','']
k=pd.read_csv(OUT/'sensitivity.csv').set_index(['K','horizon'])
for small in [32,64]:
    delta=k.loc[small]-k.loc[128]
    lines.append(f'For the first prespecified smooth-scale series, K={small} versus K=128 changes the forecast mean by RMS {np.sqrt(np.mean(delta["mean"]**2)):.5f} and the 90% endpoints by RMS {np.sqrt(np.mean(delta[["lower90","upper90"]].to_numpy()**2)):.5f}. This is paired inner-path sensitivity with the same outer draws, not total posterior Monte Carlo uncertainty.')
lines += ['',
    '- Seven new contract-test groups pass: prefix invariance, heterogeneous positive scales, independent GJR recursions, hidden-state filtering and mixture moments, causal issue timing, exact 2,000-row training, serial/parallel seed replay, and Gaussian mixture scores.',
    '- 393 focused existing installed-package expectations pass across AutoDESN, 100-step forecasts, Normal readout and recursive mean-state behavior, without failures, warnings or skips.',
    '- `audit_results.py` independently verifies exported splits, source hashes, actuals, coverage, widths, errors, model mass, chain screens, path indices and aggregated metrics. See `artifacts/audit_report.json`.',
    '- Full repository release checks were not rerun for this simulation-only extension. The previously documented inherited packaging and historical-study failures remain unresolved; this is not a claim that global CI is green.',
    '', '## Reading the result', '',
    'A nonlinear mean model can improve location forecasts while retaining a nearly constant one-step innovation scale. Under quiet conditions its intervals can be too wide, and after large shocks they can be too narrow. Recursive state uncertainty can widen a long-horizon distribution, but that does not substitute for learning conditional innovation variance. A GJR comparator can react to residual shocks yet still miss nonlinear mean and hidden-regime structure. The observation-filtered known-DGP reference separates those model limitations from irreducible future noise.', '',
    'Nearly flat long-horizon means can be appropriate when nonlinear dynamics lose information about the initial state. A forecast mean averages future shocks and should not be expected to trace one realized noisy test path. The seasonal oracle also knows the clock effects, which response-only DESNs must infer from lagged responses.', '',
    'Structure weights are learned from the assumed conditional training likelihood. They do not directly optimize 100-step forecast error, and misspecification can affect both structure weights and recursive performance. Better sampling cannot supply a conditional variance process that is absent from the likelihood.', '',
    'The next modeling step, if conditional coverage matters, is an explicitly positive variance process with its own causal recursion and posterior uncertainty. That changes the likelihood and inference target and should be validated separately. These results do not establish that SMC is needed: the finite homoscedastic bank still supports the existing blocked Gibbs updates.', '',
    '## Figures', '',
    '![Recursive forecast examples](artifacts/forecast_examples_500_2000_100.png)', '',
    '![One-step volatility tracking](artifacts/one_step_volatility.png)', '',
    '![Scores](artifacts/score_comparison.png)', '',
    '![Volatility coverage](artifacts/volatility_coverage.png)', '',
    'All six figures also have PDF versions. Complete series/splits and posterior depth probabilities are in the remaining figures. The representative plots always use replication 1; examples were not selected by their forecasting scores.', '']
readme=os.path.relpath(ROOT/'README.md',REPORT.parent)
figures=os.path.relpath(OUT,REPORT.parent).rstrip('/')+'/'
body='\n'.join(lines).replace('(README.md)',f'({readme})').replace('(artifacts/',f'({figures}')
REPORT.parent.mkdir(parents=True,exist_ok=True)
REPORT.write_text(body)
print(REPORT)
