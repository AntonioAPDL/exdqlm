"""Figures from frozen CSVs; no fitting, tuning, or case selection."""
from pathlib import Path
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

OUT = Path(os.getenv('AUTODESN_HETERO_OUT', 'validation/autodesn/heteroscedastic/artifacts'))
scores = pd.read_csv(OUT / 'scores.csv')
obs = pd.read_csv(OUT / 'observed.csv')
summary = pd.read_csv(OUT / 'summary.csv')
prob = pd.read_csv(OUT / 'probability.csv')
names = {'smooth_scale': 'Smooth nonlinear mean + state-dependent scale',
         'threshold_gjr': 'Threshold dynamics + asymmetric GJR volatility',
         'switching_seasonal': 'Hidden regimes + nonlinear seasonal memory'}
colors = {'AutoDESN': '#126da6', 'Fixed_DESN': '#bc713a', 'AR1_GJR_GARCH': '#9466b0',
          'Gaussian_AR1': '#6e987e', 'Gaussian_AR12': '#c28f29', 'Constant': '#929da6', 'Oracle_DGP': '#263746'}
labels = {'AutoDESN': 'AutoDESN', 'Fixed_DESN': 'Fixed DESN', 'AR1_GJR_GARCH': 'AR–GJR',
          'Gaussian_AR1': 'AR(1)', 'Gaussian_AR12': 'AR(12)', 'Constant': 'Constant', 'Oracle_DGP': 'Known DGP'}
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10, 'pdf.fonttype': 42,
                     'axes.spines.top': False, 'axes.spines.right': False,
                     'text.color': '#263746', 'axes.labelcolor': '#263746', 'axes.titleweight': 'bold'})

def save(fig, name):
    fig.savefig(OUT / f'{name}.png', dpi=180, bbox_inches='tight')
    fig.savefig(OUT / f'{name}.pdf', bbox_inches='tight')
    plt.close(fig)

def select(frame, kind, rep=1, mode=None, method=None):
    x = frame[(frame.dgp == kind) & (frame.repetition == rep)]
    if mode: x = x[x['mode'] == mode]
    if method: x = x[x.method == method]
    return x

fig, axes = plt.subplots(3, 1, figsize=(12.4, 10), sharex=True)
for ax, kind in zip(axes, names):
    y = select(obs, kind).query('time >= 2350')
    a = select(scores, kind, mode='fixed_origin', method='AutoDESN')
    t = 2500 + a.horizon.to_numpy()
    ax.plot(y.time, y.y, lw=.85, color='#718391', label='Observed')
    ax.fill_between(t, a.lower90.to_numpy(), a.upper90.to_numpy(), color=colors['AutoDESN'], alpha=.14, label='AutoDESN 90%')
    ax.fill_between(t, a.lower50.to_numpy(), a.upper50.to_numpy(), color=colors['AutoDESN'], alpha=.25, label='AutoDESN 50%')
    for method in ['AutoDESN', 'Fixed_DESN', 'Oracle_DGP']:
        z = select(scores, kind, mode='fixed_origin', method=method)
        ax.plot(2500 + z.horizon, z['mean'], color=colors[method], lw=1.8 if method == 'AutoDESN' else 1.2,
                ls='-' if method == 'AutoDESN' else '--', label=labels[method] + ' mean')
    ax.axvline(2500.5, ls=':', color='#536576', lw=1)
    ax.set_title(names[kind], loc='left', fontsize=11)
    ax.set_ylabel('Response'); ax.grid(axis='y', alpha=.15)
axes[-1].set_xlabel('Observation index · forecast issued once at 2500, with simulated feedback for all 100 leads')
fig.suptitle('500 washout + 2,000 training + 100 recursive forecast', x=.075, ha='left', fontsize=16, weight='bold')
fig.text(.075, .942, 'Prespecified replication 1 of each process. Gaussian AutoDESN retains constant innovation variance.', color='#607181')
fig.legend(*axes[0].get_legend_handles_labels(), loc='lower center', ncol=3, frameon=False, bbox_to_anchor=(.5,.005))
fig.subplots_adjust(top=.89, bottom=.12, hspace=.36)
save(fig, 'forecast_examples_500_2000_100')

fig, axes = plt.subplots(3, 1, figsize=(12.4, 7.8), sharex=True)
for ax, kind in zip(axes, names):
    y = select(obs, kind)
    ax.plot(y.time, y.y, lw=.45, color='#607b8e')
    ax.axvspan(1, 500, color='#c3cdd5', alpha=.6)
    ax.axvspan(501, 2500, color='#cfdfed', alpha=.3)
    ax.axvspan(2501, 2600, color='#f4d8aa', alpha=.5)
    ax.axvline(2500.5, color='#b78534', lw=1)
    ax.set_title(names[kind], loc='left', fontsize=11)
    ax.set_ylabel('Response'); ax.grid(axis='y', alpha=.12)
axes[-1].set_xlabel('Observation index · grey = 500 washout; blue = 2,000 training; orange = 100 test')
fig.suptitle('Three nonlinear, heteroscedastic examples', x=.075, ha='left', fontsize=16, weight='bold')
fig.text(.075,.93,'All 2,600 observations shown; replication 1. Other independent replications are retained in observed.csv.',color='#607181')
fig.subplots_adjust(top=.86,hspace=.4,bottom=.10)
save(fig,'full_series_split')

fig, axes = plt.subplots(3, 1, figsize=(12.1, 9.0), sharex=True)
for ax, kind in zip(axes, names):
    for method in ['AutoDESN', 'Fixed_DESN', 'AR1_GJR_GARCH', 'Oracle_DGP']:
        x = select(scores, kind, mode='one_step', method=method)
        scale = x.oracle_one_step_sd if method == 'Oracle_DGP' else x.predictive_sd
        ax.plot(2500+x.horizon, scale, color=colors[method], lw=2 if method in ('AutoDESN','Oracle_DGP') else 1.1,
                ls='--' if method=='Fixed_DESN' else '-', label=labels[method])
    ax.set_title(names[kind], loc='left', fontsize=11)
    ax.set_ylabel('Predictive SD'); ax.grid(axis='y',alpha=.15)
axes[-1].set_xlabel('Target index · each forecast uses observations only through the previous target')
fig.suptitle('One-step volatility tracking', x=.075, ha='left', fontsize=16, weight='bold')
fig.text(.075,.94,'Replication 1. Known-DGP SD integrates hidden regime uncertainty; fitted posteriors stay fixed at time 2500.',color='#607181',fontsize=9.6)
fig.legend(*axes[0].get_legend_handles_labels(),loc='lower center',ncol=4,frameon=False,bbox_to_anchor=(.5,.005))
fig.subplots_adjust(top=.88,bottom=.10,hspace=.4)
save(fig,'one_step_volatility')

methods = list(colors)
fig, axes = plt.subplots(3, 3, figsize=(12.7, 11.8))
for i, kind in enumerate(names):
    for j, (metric,title) in enumerate([('rmse','RMSE ↓'),('crps','CRPS ↓'),('covered90','90% coverage')]):
        ax = axes[i,j]
        for k, method in enumerate(methods):
            for mode, offset, marker in [('fixed_origin',-.12,'o'),('one_step',.12,'s')]:
                x = summary[(summary.dgp==kind)&(summary.method==method)&(summary['mode']==mode)]
                value = float(x[metric].iloc[0]) * (100 if metric=='covered90' else 1)
                ax.scatter(value,k+offset,color=colors[method],marker=marker,s=35)
        if metric=='covered90': ax.axvline(90,color='#7a8791',ls=':',lw=1); ax.set_xlim(0,101)
        ax.set_yticks(range(len(methods)),[labels[m] for m in methods] if j==0 else [])
        ax.invert_yaxis();ax.grid(axis='x',alpha=.15);ax.set_title(title,loc='left',fontsize=11)
        if j==0: ax.set_ylabel(names[kind].replace(' + ','\n+ '),fontsize=10)
fig.suptitle('Forecast comparison · three independent series per process',x=.06,ha='left',fontsize=15,weight='bold')
fig.text(.06,.94,'Circles: 100-step fixed origin. Squares: one step with observed feedback. Results pool 300 targets per process/mode.',color='#607181',fontsize=9.6)
fig.subplots_adjust(top=.89,bottom=.06,left=.18,hspace=.40,wspace=.18)
save(fig,'score_comparison')

v = pd.read_csv(OUT/'volatility_groups.csv')
fig, axes = plt.subplots(1,3,figsize=(13,4.8),sharey=True)
for ax,kind in zip(axes,names):
    for method in ['AutoDESN','Fixed_DESN','AR1_GJR_GARCH','Oracle_DGP']:
        x = v[(v.dgp==kind)&(v.method==method)].set_index('volatility_group').reindex(['low','middle','high'])
        ax.plot(range(3),100*x.covered90,marker='o',ms=4,lw=1.4,color=colors[method],label=labels[method])
    counts = v[(v.dgp==kind)&(v.method=='AutoDESN')].set_index('volatility_group').reindex(['low','middle','high'])['count'].fillna(0)
    ax.set_xticks(range(3),[f'{g}\n(n={int(n)})' for g,n in zip(['Low','Middle','High'],counts)])
    ax.set_title(names[kind].replace(' + ','\n+ '),loc='left',fontsize=10)
    ax.axhline(90,color='#7a8791',ls=':',lw=1);ax.grid(axis='y',alpha=.15)
    ax.set_ylim(0,102)
axes[0].set_ylabel('One-step 90% interval coverage (%)')
fig.suptitle('Conditional calibration by volatility',x=.065,ha='left',fontsize=15,weight='bold')
fig.text(.065,.88,'Groups use training-only known-DGP SD quartiles. Counts are dependent targets, not independent replications.',fontsize=9.5,color='#607181')
fig.legend(*axes[0].get_legend_handles_labels(),loc='lower center',ncol=4,frameon=False)
fig.subplots_adjust(top=.73,bottom=.19,wspace=.2)
save(fig,'volatility_coverage')

fig,axes=plt.subplots(1,3,figsize=(12.3,4.3),sharey=True)
for ax,kind in zip(axes,names):
    x=prob[prob.dgp==kind]
    for r,offset in [(1,-.23),(2,0),(3,.23)]:
        p=x[x.repetition==r].groupby('D').posterior_probability.sum().reindex([1,2,3],fill_value=0)
        ax.bar(np.array([1,2,3])+offset,p,width=.22,color=['#126da6','#5597bb','#94b9cc'][r-1],label=f'Series {r}')
    ax.set_title(names[kind].replace(' + ','\n+ '),loc='left',fontsize=10)
    ax.set_xticks([1,2,3]);ax.set_xlabel('Reservoir depth');ax.grid(axis='y',alpha=.15)
    ax.axhline(1/3,color='#8a979f',ls=':',lw=1)
axes[0].set_ylabel('Posterior probability');axes[0].set_ylim(0,1.05)
fig.suptitle('Automatic specification selection',x=.065,ha='left',fontsize=15,weight='bold')
fig.text(.065,.88,'The dotted line is the prior probability of each depth: 1/3. Other architecture choices are marginalized.',fontsize=9.5,color='#607181')
fig.legend(*axes[0].get_legend_handles_labels(),loc='lower center',ncol=3,frameon=False)
fig.subplots_adjust(top=.74,bottom=.22,wspace=.2)
save(fig,'selected_depth')
print('Rendered 6 figures in PNG and PDF.')
