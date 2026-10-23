"""Reconstruct GP rolling forecasts, score, independently audit, and plot C1."""
from pathlib import Path
import json,tomllib,time
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scoring import condition_one,mixture_score
ROOT=Path(__file__).resolve().parent
ART=ROOT/'artifacts';OUT=ART/'comparison'
COLORS={'AutoDESN':'#2166ac','AutoGP':'#b83d26','AutoARIMA':'#27927b'}
MODELS=list(COLORS)
def score_components(components,model):
    rows=[]
    for (origin,h),g in components.groupby(['origin','horizon'],sort=True):
        actual=float(g.actual.iloc[0])
        row=mixture_score(actual,g['mean'].to_numpy(),g.sd.to_numpy(),g.weight.to_numpy())
        row.update(origin=origin,horizon=h,target=origin+h,actual=actual,model=model)
        rows.append(row)
    return pd.DataFrame(rows)
def gp_forecasts(y):
    means=[];covs=[];weights=[];runids=[];status=[]
    for run in (1,2):
        d=ART/'gp'/f'run_{run}'
        s=tomllib.loads((d/'status.toml').read_text());assert s['complete']
        p=pd.read_csv(d/'particles.csv');m=pd.read_csv(d/'means.csv').to_numpy()
        assert m.shape==(500,8)
        c=np.fromfile(d/'covariances.bin',dtype='<f8').reshape((500,500,8),order='F')
        checks=pd.read_csv(d/'native_checks.csv')
        assert checks.mean_max_error.max()<1e-5 and checks.covariance_max_error.max()<1e-5
        for j in range(8):
            assert np.max(abs(c[:,:,j]-c[:,:,j].T))<1e-8
            assert np.linalg.eigvalsh(c[:,:,j]).min()>0
            means.append(m[:,j].copy());covs.append(c[:,:,j].copy())
        weights.extend(p.weight.to_numpy()/2);runids.extend([run]*8);status.append(s)
    w=np.array(weights);runids=np.array(runids);rows=[];components=[];runs=[]
    for i,origin in enumerate(range(2500,2971)):
        m=np.column_stack(means)[:30];sd=np.sqrt(np.column_stack([np.diag(c)[:30] for c in covs]))
        for h in range(30):
            actual=y[origin+h]
            row=mixture_score(actual,m[h],sd[h],w)
            row.update(origin=origin,horizon=h+1,target=origin+h+1,actual=actual,model='AutoGP')
            rows.append(row)
            for run in (1,2):
                mask=runids==run;r=mixture_score(actual,m[h,mask],sd[h,mask],w[mask]*2)
                r.update(origin=origin,horizon=h+1,target=origin+h+1,actual=actual,run=run);runs.append(r)
            for j in range(16):
                components.append((origin,h+1,j+1,w[j],m[h,j],sd[h,j]))
        # The forecast above is issued BEFORE seeing y[origin]. No subsequent
        # test response is touched by the state/mean update at this origin.
        if origin<2970:
            for j in range(16):means[j],covs[j]=condition_one(means[j],covs[j],y[origin])
        if i%50==0: print('AutoGP rolling origins',i+1,'/ 471',flush=True)
    pd.DataFrame(components,columns=['origin','horizon','component','weight','mean','sd']).to_csv(OUT/'gp_components.csv.gz',index=False)
    pd.DataFrame(runs).to_csv(OUT/'gp_run_sensitivity.csv.gz',index=False)
    return pd.DataFrame(rows),status
def aggregate(g):
    return pd.Series(dict(RMSE=np.sqrt(g.squared_error.mean()),MAE=g.absolute_error.mean(),
        CRPS=g.crps.mean(),NLL=g.negative_log_score.mean(),Coverage50=g.covered50.mean(),
        Coverage90=g.covered90.mean(),Width50=g.width50.mean(),Width90=g.width90.mean(),pairs=len(g)))
def figures(scores,y,summary):
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,
        'axes.spines.right':False,'axes.titleweight':'semibold','savefig.facecolor':'white'})
    fig,ax=plt.subplots(4,1,figsize=(14,12),layout='constrained',height_ratios=[1,1.4,1.4,1.4])
    x=np.arange(1,3001);ax[0].plot(x,y,color='#303846',lw=.65)
    ax[0].axvspan(1,500,color='#cdd2d8',alpha=.6);ax[0].axvspan(2500,3000,color='#f8dba9',alpha=.5)
    ax[0].set_title('C1 · Switching seasonal series | 500 washout + 2,000 training + 500 test days',loc='left')
    ax[0].set_xlim(1,3000);ax[0].set_ylabel('Value');ax[0].set_xlabel('Time')
    for axis,model in zip(ax[1:],MODELS):
        g=scores[(scores.model==model)&(scores.horizon==30)]
        axis.plot(np.arange(2501,3001),y[2500:],color='#333a44',lw=.8,label='Observed')
        axis.fill_between(g.target,g.lower90,g.upper90,color=COLORS[model],alpha=.18,label='90% interval')
        axis.plot(g.target,g['mean'],color=COLORS[model],lw=1.1,label='30-step forecast mean')
        axis.set_title(model+' · rolling forecasts issued 30 days earlier',loc='left');axis.set_xlim(2501,3000);axis.set_ylabel('Value')
        axis.legend(loc='upper right',ncol=3,fontsize=8,frameon=False)
    ax[-1].set_xlabel('Target day; each forecast uses observations only through target − 30')
    fig.savefig(OUT/'C1_rolling_30_step_forecasts.png',dpi=160);plt.close(fig)
    leads=scores.groupby(['model','horizon']).apply(aggregate,include_groups=False).reset_index()
    leads.to_csv(OUT/'metrics_by_horizon.csv',index=False)
    fig,axes=plt.subplots(2,2,figsize=(12,8),layout='constrained')
    for axis,metric,title in zip(axes.flat,['RMSE','CRPS','Coverage90','Width90'],
        ['Mean forecast error · RMSE ↓','Predictive distribution error · CRPS ↓','90% interval coverage · target 0.90','Mean 90% interval width']):
        for model in MODELS:
            g=leads[leads.model==model];axis.plot(g.horizon,g[metric],label=model,color=COLORS[model],lw=2)
        if metric=='Coverage90':axis.axhline(.9,color='#777',ls='--',lw=1);axis.set_ylim(0,1)
        axis.set_title(title,loc='left');axis.set_xlabel('Forecast lead (days)');axis.set_xlim(1,30);axis.grid(alpha=.15)
    axes[0,0].legend(frameon=False);fig.suptitle('C1 · Same 471 rolling origins for all three methods',fontsize=15)
    fig.savefig(OUT/'C1_performance_by_horizon.png',dpi=170);plt.close(fig)
    fig,axes=plt.subplots(3,3,figsize=(14,9),layout='constrained',sharex='col')
    for col,origin in enumerate((2500,2735,2970)):
        for row,model in enumerate(MODELS):
            axis=axes[row,col];g=scores[(scores.model==model)&(scores.origin==origin)]
            axis.plot(np.arange(origin-29,origin+31),y[origin-30:origin+30],color='#333a44',lw=1)
            axis.fill_between(g.target,g.lower90,g.upper90,color=COLORS[model],alpha=.15)
            axis.fill_between(g.target,g.lower50,g.upper50,color=COLORS[model],alpha=.3)
            axis.plot(g.target,g['mean'],color=COLORS[model],lw=1.7);axis.axvline(origin,color='#777',ls='--',lw=.8)
            axis.set_title(f'{model} · origin {origin}',loc='left',fontsize=10)
            if row==2:axis.set_xlabel('Time')
    fig.suptitle('C1 · Recursive / joint 30-day forecasts at three fixed origins\nDark band 50%; light band 90%; grey line observations',fontsize=14)
    fig.savefig(OUT/'C1_forecast_windows.png',dpi=160);plt.close(fig)
def main():
    started=time.time();OUT.mkdir(parents=True,exist_ok=True)
    y=pd.read_csv(ROOT/'input/C1.csv').y.to_numpy()
    statuses={m:json.loads((ART/d/'status.json').read_text()) for m,d in [('AutoDESN','desn'),('AutoARIMA','arima')]}
    assert all(s['complete'] for s in statuses.values()) and statuses['AutoDESN']['qualified']
    gp,gpstatus=gp_forecasts(y)
    arima=score_components(pd.read_csv(ART/'arima/components.csv'),'AutoARIMA')
    desn=pd.read_csv(ART/'desn/scores.csv')
    columns=['origin','horizon','target','actual','model','mean','predictive_sd','lower90','lower50','median','upper50','upper90',
        'squared_error','absolute_error','crps','negative_log_score','covered50','covered90','width50','width90']
    scores=pd.concat([desn[columns],gp[columns],arima[columns]],ignore_index=True)
    for model,g in scores.groupby('model'):
        assert len(g)==471*30 and not g.duplicated(['origin','horizon']).any()
        assert set(g.origin)==set(range(2500,2971)) and set(g.horizon)==set(range(1,31))
        np.testing.assert_array_equal(g.target,g.origin+g.horizon)
        np.testing.assert_allclose(g.actual,y[g.target.to_numpy()-1],rtol=0,atol=1e-12)
        assert np.isfinite(g.select_dtypes(include='number')).all().all()
        assert (g.lower90<=g.lower50).all() and (g.lower50<=g['median']).all() and (g['median']<=g.upper50).all() and (g.upper50<=g.upper90).all()
        np.testing.assert_allclose(g.squared_error,(g['mean']-g.actual)**2,rtol=1e-10,atol=1e-10)
        np.testing.assert_array_equal(g.covered90,(g.actual>=g.lower90)&(g.actual<=g.upper90))
        np.testing.assert_array_equal(g.covered50,(g.actual>=g.lower50)&(g.actual<=g.upper50))
        np.testing.assert_allclose(g.width90,g.upper90-g.lower90,rtol=1e-10,atol=1e-10)
    scores.to_csv(OUT/'all_scores.csv.gz',index=False)
    summaries=[]
    for label,g in [('all leads, all test days',scores),('lead 1',scores[scores.horizon==1]),
        ('lead 30',scores[scores.horizon==30]),('targets 2501–2600',scores[scores.target<=2600]),('targets 2601–3000',scores[scores.target>2600])]:
        s=g.groupby('model').apply(aggregate,include_groups=False).reset_index();s.insert(0,'scope',label);summaries.append(s)
    summary=pd.concat(summaries,ignore_index=True);summary.to_csv(OUT/'metrics.csv',index=False)
    figures(scores,y,summary)
    sensitivity=pd.read_csv(ART/'desn/mc_sensitivity.csv')
    sensitivity.groupby(['origin','outer_draws','inner_paths']).apply(aggregate,include_groups=False).to_csv(OUT/'desn_mc_sensitivity_summary.csv')
    (OUT/'audit.json').write_text(json.dumps(dict(complete=True,models=MODELS,origins=471,leads=30,pairs_per_model=14130,
        target_range=[2501,3000],native_gp_checks=True,frozen_model_weights=True,desn_convergence=True,
        elapsed_seconds=time.time()-started,model_status=statuses,gp_runs=gpstatus),indent=2))
    print(summary[summary.scope=='all leads, all test days'].to_string(index=False),flush=True)
if __name__=='__main__':main()
