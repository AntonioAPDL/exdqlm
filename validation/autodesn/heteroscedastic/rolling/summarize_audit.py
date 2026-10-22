"""Audit the rolling lattice against raw targets and frozen replay evidence."""
from pathlib import Path
import os,json,hashlib
import numpy as np
import pandas as pd
ROOT=Path('validation/autodesn/heteroscedastic/rolling')
OUT=Path(os.getenv('AUTODESN_ROLLING_OUT',str(ROOT/'artifacts')))
checks=[]
def check(name,condition):
    checks.append({'check':name,'passed':bool(condition)})
    if not condition:raise AssertionError(name)
def close(name,a,b,tol=2e-10):check(name,np.allclose(a,b,atol=tol,rtol=tol,equal_nan=False))
cases=pd.read_csv(OUT/'cases.csv')
frames=[];audits=[];sensitivity=[]
methods={'AutoDESN','Fixed_DESN','Gaussian_AR1','Gaussian_AR12','Constant','AR1_GJR_GARCH','Oracle_DGP'}
observed=pd.read_csv('validation/autodesn/heteroscedastic/artifacts/observed.csv')
for row in cases.itertuples():
    ident=f'{row.dgp}_r{row.repetition:02d}';folder=OUT/ident
    check(ident+' complete',json.loads((folder/'complete.json').read_text())['complete'])
    x=pd.read_csv(folder/'scores.csv.gz');frames.append(x)
    a=pd.read_csv(folder/'audit.csv');audits.append(a)
    k=pd.read_csv(folder/'sensitivity.csv');k['dgp']=row.dgp;k['repetition']=row.repetition;sensitivity.append(k)
    keys=['method','origin','horizon']
    check(ident+' 14910 unique origin-lead scores',len(x)==71*30*7 and not x.duplicated(keys).any())
    check(ident+' seven methods',set(x.method)==methods)
    for field,value in [('fit_start',501),('fit_end',2500),('n_train',2000),('washout',500),('first_origin',2500),('last_origin',2570),('origins',71),('H',30),('total_paths',3072)]:
        check(ident+'/'+field,(a[field]==value).all())
    for field in ['refit_per_origin','posterior_model_weights_updated','preprocessing_updated','future_values_within_origin']:
        check(ident+'/'+field,not a[field].any())
    check(ident+' original model mass replay',a.posterior_probability_replay_max_abs.max()<1e-12)
    check(ident+' original path replay',a.original_path_replay_max_abs.max()<1e-10)
    check(ident+' final Rhat',a.max_rhat.max()<=1.01)
    check(ident+' final ESS',a.min_ess.min()>=400)
    check(ident+' model chain range',a.auto_model_chain_range.max()<=.05)
    check(ident+' target lattice',((x.target_index==x.origin+x.horizon)&x.origin.between(2500,2570)&x.horizon.between(1,30)&x.target_index.between(2501,2600)).all())
    actual=observed[(observed.dgp==row.dgp)&(observed.repetition==row.repetition)].set_index('time').y
    close(ident+' targets are actual observed values',x.actual,actual.reindex(x.target_index).to_numpy())
    close(ident+' squared errors',x.squared_error,(x['mean']-x.actual)**2)
    close(ident+' absolute errors',x.absolute_error,abs(x['mean']-x.actual))
    close(ident+' 90% widths',x.width90,x.upper90-x.lower90)
    close(ident+' 50% widths',x.width50,x.upper50-x.lower50)
    check(ident+' 90% coverage',np.array_equal(x.covered90,(x.actual>=x.lower90)&(x.actual<=x.upper90)))
    check(ident+' 50% coverage',np.array_equal(x.covered50,(x.actual>=x.lower50)&(x.actual<=x.upper50)))
    check(ident+' ordered quantiles',((x.lower90<=x.lower50)&(x.lower50<=x['median'])&(x['median']<=x.upper50)&(x.upper50<=x.upper90)).all())
    check(ident+' positive predictive SD',((x.predictive_sd>0)&(x.innovation_sd>0)).all())
    check(ident+' finite scores',np.isfinite(x[['mean','crps','negative_log_score','predictive_sd']]).all().all())
    check(ident+' nonnegative CRPS',(x.crps>=-1e-12).all())
    for method,z in x.groupby('method'):
        count=z.groupby('horizon').size()
        check(ident+'/'+method+' same 71 origins at every lead',len(count)==30 and (count==71).all())
        if method in ['AutoDESN','Fixed_DESN']:
            close(ident+'/'+method+' fixed innovation variance across origins/leads',z.innovation_sd,np.repeat(z.innovation_sd.iloc[0],len(z)))
    for file in ['auto_checkpoint.rds','fixed_checkpoint.rds']:
        check(ident+'/'+file+' compact forecast checkpoint',0<(folder/file).stat().st_size<5e6)
all_scores=pd.concat(frames,ignore_index=True)
audit=pd.concat(audits,ignore_index=True)
check('all nine cases',len(audit)==9)
check('134190 scored rows',len(all_scores)==134190)
fields=['squared_error','absolute_error','crps','covered90','width90','covered50','width50','negative_log_score','predictive_sd','innovation_sd']
def aggregate(groups):
    grouped=all_scores.groupby(groups,sort=True)
    x=grouped[fields].mean();x['rmse']=np.sqrt(x.squared_error);x['count']=grouped.size()
    return x.reset_index()
aggregate(['dgp','method']).to_csv(OUT/'summary.csv',index=False)
aggregate(['dgp','method','horizon']).to_csv(OUT/'by_horizon.csv',index=False)
aggregate(['dgp','method','origin']).to_csv(OUT/'by_origin.csv',index=False)
aggregate(['dgp','method','repetition']).to_csv(OUT/'by_replication.csv',index=False)
audit.to_csv(OUT/'audit.csv',index=False)
pd.concat(sensitivity,ignore_index=True).to_csv(OUT/'sensitivity.csv',index=False)
replay=pd.read_csv(OUT/'checkpoint_path_replay.csv')
check('17280 restored checkpoint path values',len(replay)==9*64*30)
close('restored on-disk checkpoints reproduce original paths',replay.reference,replay.replay,1e-10)
q=pd.read_csv(OUT/'posterior_model_probabilities.csv')
old=pd.read_csv('validation/autodesn/heteroscedastic/artifacts/probability.csv')
paired=q.merge(old,on=['dgp','repetition','candidate'],suffixes=('_replay','_original'),validate='one_to_one')
check('all 648 model probabilities replayed',len(paired)==648)
close('exact posterior model probability replay',paired.posterior_probability_replay,paired.posterior_probability_original,1e-12)
draws=pd.read_csv(OUT/'posterior_joint_draws.csv')
check('3456 retained joint draws',len(draws)==9*2*192)
check('positive variance/precision',((draws.variance>0)&(draws.ridge_precision>0)).all())
for keys,x in draws.groupby(['dgp','repetition','method']):
    check(str(keys)+' complete outer IDs',sorted(x.outer_draw.tolist())==list(range(1,193)))
manifest=pd.read_csv(OUT/'launch_source_manifest.csv')
for row in manifest.itertuples():check('frozen rolling source '+row.path,hashlib.md5(Path(row.path).read_bytes()).hexdigest()==row.md5)
result={'passed':len(checks),'failed':0,'origins_per_series':71,'horizon':30,'refit_per_origin':False,
        'score_rows':len(all_scores),'independent_series_per_dgp':3,'checks':checks}
(OUT/'audit_report.json').write_text(json.dumps(result,indent=2)+'\n')
print(f'{len(checks)} rolling evidence checks passed; {len(all_scores):,} origin/lead scores.')
