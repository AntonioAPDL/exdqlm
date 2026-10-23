"""Every primary plotted prediction is issued exactly 30 observations earlier."""
from pathlib import Path
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path('validation/autodesn/heteroscedastic/rolling')
OUT=Path(os.getenv('AUTODESN_ROLLING_OUT',str(ROOT/'artifacts')))
obs=pd.read_csv('validation/autodesn/heteroscedastic/artifacts/observed.csv')
by_h=pd.read_csv(OUT/'by_horizon.csv')
names={'smooth_scale':'Smooth nonlinear mean + state-dependent scale','threshold_gjr':'Threshold dynamics + asymmetric GJR volatility','switching_seasonal':'Hidden regimes + nonlinear seasonal memory'}
colors={'AutoDESN':'#126da6','Fixed_DESN':'#bc713a','Gaussian_AR12':'#6c9677','AR1_GJR_GARCH':'#9466b0','Oracle_DGP':'#263746'}
labels={'AutoDESN':'AutoDESN','Fixed_DESN':'Fixed DESN','Gaussian_AR12':'AR(12)','AR1_GJR_GARCH':'AR–GJR','Oracle_DGP':'Known DGP'}
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'pdf.fonttype':42,'axes.spines.top':False,'axes.spines.right':False,'axes.titleweight':'bold','text.color':'#263746','axes.labelcolor':'#263746'})
def save(fig,name):
    fig.savefig(OUT/f'{name}.png',dpi=180,bbox_inches='tight')
    fig.savefig(OUT/f'{name}.pdf',bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None})
    plt.close(fig)
def case(kind):return pd.read_csv(OUT/f'{kind}_r01'/'scores.csv.gz')

fig,axes=plt.subplots(3,1,figsize=(12.3,9.8),sharex=True)
for ax,kind in zip(axes,names):
    x=case(kind);x=x[x.horizon==30]
    y=obs[(obs.dgp==kind)&(obs.repetition==1)&(obs.time>=2490)]
    ax.plot(y.time,y.y,lw=.9,color='#718391',label='Observed')
    a=x[x.method=='AutoDESN'].sort_values('target_index');t=a.target_index.to_numpy()
    ax.fill_between(t,a.lower90.to_numpy(),a.upper90.to_numpy(),color=colors['AutoDESN'],alpha=.14,label='AutoDESN 90%')
    ax.fill_between(t,a.lower50.to_numpy(),a.upper50.to_numpy(),color=colors['AutoDESN'],alpha=.25,label='AutoDESN 50%')
    for method in ['AutoDESN','Fixed_DESN','Oracle_DGP']:
        z=x[x.method==method].sort_values('target_index')
        ax.plot(z.target_index,z['mean'],color=colors[method],lw=1.8 if method=='AutoDESN' else 1.2,ls='-' if method=='AutoDESN' else '--',label=labels[method]+' mean')
    ax.axvline(2530,color='#667886',ls=':',lw=1)
    ax.set_title(names[kind],loc='left',fontsize=11);ax.set_ylabel('Response');ax.grid(axis='y',alpha=.15)
axes[-1].set_xlabel('Target index · prediction at target t was issued at origin t − 30')
fig.suptitle('Rolling-origin forecasts · exactly 30 steps ahead',x=.07,ha='left',fontsize=16,weight='bold')
fig.text(.07,.942,'71 origins: 2500–2570. 500 washout + 2,000 training. Posterior fitted once; observed states update between origins.',fontsize=9.5,color='#607181')
fig.text(.07,.919,'Forecast targets: 2530–2600. The dotted line marks the first target with a complete 30-step forecast.',fontsize=9.3,color='#607181')
fig.legend(*axes[0].get_legend_handles_labels(),loc='lower center',ncol=3,frameon=False,bbox_to_anchor=(.5,.005))
fig.subplots_adjust(top=.885,bottom=.12,hspace=.37)
save(fig,'rolling_exactly_30_steps')

fan_colors=['#126da6','#2c9677','#9b62ab','#c2852c','#c0565b']
fig,axes=plt.subplots(3,1,figsize=(12.3,9.8),sharex=True)
for ax,kind in zip(axes,names):
    x=case(kind);x=x[x.method=='AutoDESN']
    y=obs[(obs.dgp==kind)&(obs.repetition==1)&(obs.time>=2490)]
    ax.plot(y.time,y.y,lw=.9,color='#718391',label='Observed')
    for origin,color in zip([2500,2520,2540,2560,2570],fan_colors):
        z=x[x.origin==origin].sort_values('horizon');t=z.target_index.to_numpy()
        ax.fill_between(t,z.lower90.to_numpy(),z.upper90.to_numpy(),color=color,alpha=.075)
        ax.plot(t,z['mean'],color=color,lw=1.5,label=f'Origin {origin}')
        actual=float(y.loc[y.time==origin,'y'].iloc[0]);ax.scatter(origin,actual,color=color,s=22,zorder=4)
    ax.set_title(names[kind],loc='left',fontsize=11);ax.set_ylabel('Response');ax.grid(axis='y',alpha=.15)
axes[-1].set_xlabel('Target index · each colored line is a separate 30-step recursive forecast')
fig.suptitle('Rolling forecast fans · five issue times shown',x=.07,ha='left',fontsize=16,weight='bold')
fig.text(.07,.942,'All 71 origins are scored. Colored dots mark the last observation available at each displayed issue time. Bands: 90%.',fontsize=9.6,color='#607181')
fig.legend(*axes[0].get_legend_handles_labels(),loc='lower center',ncol=3,frameon=False,bbox_to_anchor=(.5,.005))
fig.subplots_adjust(top=.885,bottom=.12,hspace=.37)
save(fig,'rolling_forecast_fans')

fig,axes=plt.subplots(3,2,figsize=(12.1,9.8))
for i,kind in enumerate(names):
    for j,(metric,title) in enumerate([('rmse','RMSE ↓'),('crps','CRPS ↓')]):
        ax=axes[i,j]
        for method in colors:
            z=by_h[(by_h.dgp==kind)&(by_h.method==method)].sort_values('horizon')
            ax.plot(z.horizon,z[metric],lw=1.8 if method=='AutoDESN' else 1.2,color=colors[method],label=labels[method])
        ax.set_title(title+' · '+names[kind].split(' + ')[0],loc='left',fontsize=10)
        ax.set_xlabel('Lead within each rolling forecast');ax.grid(alpha=.15)
fig.suptitle('Rolling-origin accuracy over leads 1–30',x=.07,ha='left',fontsize=16,weight='bold')
fig.text(.07,.94,'Each lead uses 71 origins × 3 independent series per process. Overlapping targets are dependent.',color='#607181',fontsize=10)
fig.legend(*axes[0,0].get_legend_handles_labels(),loc='lower center',ncol=5,frameon=False,bbox_to_anchor=(.5,.005))
fig.subplots_adjust(top=.88,bottom=.12,hspace=.50,wspace=.20)
save(fig,'rolling_horizon_scores')

fig,axes=plt.subplots(1,3,figsize=(12.8,4.7),sharey=True)
for ax,kind in zip(axes,names):
    for method in colors:
        z=by_h[(by_h.dgp==kind)&(by_h.method==method)].sort_values('horizon')
        ax.plot(z.horizon,100*z.covered90,lw=1.8 if method=='AutoDESN' else 1.2,color=colors[method],label=labels[method])
    ax.axhline(90,ls=':',lw=1,color='#718391');ax.grid(alpha=.15)
    ax.set_title(names[kind].replace(' + ','\n+ '),loc='left',fontsize=10);ax.set_xlabel('Lead')
axes[0].set_ylabel('90% predictive coverage (%)');axes[0].set_ylim(0,102)
fig.suptitle('Rolling predictive calibration',x=.07,ha='left',fontsize=16,weight='bold')
fig.text(.07,.88,'Coverage pools the same 71 origins and three independent series at every lead; read alongside interval widths.',fontsize=9.5,color='#607181')
fig.legend(*axes[0].get_legend_handles_labels(),loc='lower center',ncol=5,frameon=False)
fig.subplots_adjust(top=.72,bottom=.19,wspace=.15)
save(fig,'rolling_coverage')
print('Rendered four rolling figures in PNG and PDF.')
