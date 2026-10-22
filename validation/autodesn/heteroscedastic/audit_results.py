"""Independent checks of frozen exported evidence (run before plotting)."""
from pathlib import Path
import hashlib
import json
import os
import numpy as np
import pandas as pd

OUT = Path(os.getenv('AUTODESN_HETERO_OUT', 'validation/autodesn/heteroscedastic/artifacts'))
checks=[]
def check(name, condition):
    checks.append({'check':name,'passed':bool(condition)})
    if not condition: raise AssertionError(name)
def close(name,a,b,tol=2e-10):
    check(name,np.allclose(a,b,atol=tol,rtol=tol,equal_nan=True))

s=pd.read_csv(OUT/'scores.csv'); o=pd.read_csv(OUT/'observed.csv')
a=pd.read_csv(OUT/'audit.csv'); dg=pd.read_csv(OUT/'diagnostics.csv')
p=pd.read_csv(OUT/'probability.csv'); specs=pd.read_csv(OUT/'specifications.csv')
summary=pd.read_csv(OUT/'summary.csv')
keys=['dgp','repetition','mode','method','horizon']
check('12600 complete unique score rows',len(s)==12600 and not s.duplicated(keys).any())
check('9 cases',len(a)==9 and not a.duplicated(['dgp','repetition']).any())
check('23400 unique observed rows',len(o)==23400 and not o.duplicated(['dgp','repetition','time']).any())
check('72 frozen specifications',len(specs)==72)
for field,value in [('fit_start',501),('fit_end',2500),('n_train',2000),('forecast_origin',2500),
                    ('horizon',100),('conditioning_end',500),('outer_draws',192),('inner_paths',64),('total_paths',12288)]:
    check(f'exact {field}',(a[field]==value).all())
check('all final diagnostic screens pass',a.auto_diagnostic_pass.all() and a.fixed_diagnostic_pass.all())
check('all GJR fits converged',a.gjr_converged.all())
check('finite scores and positive SD',np.isfinite(s[['mean','crps','negative_log_score','predictive_sd']]).all().all() and (s.predictive_sd>0).all())
close('squared errors',(s['mean']-s.actual)**2,s.squared_error)
close('absolute errors',abs(s['mean']-s.actual),s.absolute_error)
close('90% width',s.upper90-s.lower90,s.width90)
close('50% width',s.upper50-s.lower50,s.width50)
check('ordered predictive quantiles',((s.lower90<=s.lower50)&(s.lower50<=s['median'])&(s['median']<=s.upper50)&(s.upper50<=s.upper90)).all())
check('90% coverage recomputed',((s.actual>=s.lower90)&(s.actual<=s.upper90)).equals(s.covered90))
check('50% coverage recomputed',((s.actual>=s.lower50)&(s.actual<=s.upper50)).equals(s.covered50))
check('CRPS nonnegative',(s.crps>=-1e-12).all())
for (kind,r),case in o.groupby(['dgp','repetition']):
    tag=f'{kind}/r{r}'
    check(tag+' split counts',case.split.value_counts().to_dict()=={'training':2000,'washout':500,'forecast':100})
    warm=case[case.time<=500]; row=a[(a.dgp==kind)&(a.repetition==r)].iloc[0]
    close(tag+' prefix center',warm.y.mean(),row.center)
    close(tag+' prefix scale',warm.y.std(ddof=1),row.scale)
    check(tag+' heteroscedastic realized SD',case.realized_innovation_sd.max()/case.realized_innovation_sd.min()>2)
    z=s[(s.dgp==kind)&(s.repetition==r)]
    for (mode,method),part in z.groupby(['mode','method']):
        part=part.sort_values('horizon')
        check(tag+'/'+mode+'/'+method+' all leads',part.horizon.tolist()==list(range(1,101)))
        close(tag+'/'+mode+'/'+method+' actuals',part.actual,case[case.time>2500].y)
    # No current target is available at lead one in either evaluation mode.
    x=z.pivot(index=['method','horizon'],columns='mode',values='mean')
    lead1=x.loc[(slice(None),1),:]
    lead1=lead1.loc[lead1.index.get_level_values('method')!='Oracle_DGP']
    close(tag+' first lead modes agree',lead1.fixed_origin,lead1.one_step)
    q=p[(p.dgp==kind)&(p.repetition==r)]
    close(tag+' probabilities sum to one',q.posterior_probability.sum(),1)
    check(tag+' posterior probabilities nonnegative',(q.posterior_probability>=0).all())
    check(tag+' all candidates reported',len(q)==72)
    close(tag+' normalized model prior',q.prior_probability.sum(),1)
    close(tag+' uniform depth prior',q.groupby('D').prior_probability.sum(),np.repeat(1/3,3))
    one=z[z['mode']=='one_step']
    expected=np.select([one.oracle_one_step_sd<=row.volatility_q25,one.oracle_one_step_sd<=row.volatility_q75],['low','middle'],default='high')
    check(tag+' training-boundary volatility groups',np.array_equal(expected,one.volatility_group))
    paths=pd.read_csv(OUT/f'{kind}_r{r:02d}_paths.csv')
    ids=pd.read_csv(OUT/f'{kind}_r{r:02d}_path_indices.csv')
    check(tag+' complete illustrative trajectories',paths.shape==(100,65) and len(ids)==64 and np.isfinite(paths.to_numpy()).all())
    check(tag+' nested indices',((ids.column-1)//64+1==ids.outer_draw).all() and ((ids.column-1)%64+1==ids.inner_path).all())
    means=pd.read_csv(OUT/f'{kind}_r{r:02d}_mean_location_by_draw.csv')
    auto=z[(z['mode']=='fixed_origin')&(z.method=='AutoDESN')].sort_values('horizon')
    close(tag+' equal outer-draw averaging',means.iloc[:,1:].mean(axis=1),auto['mean'])
    for method in ['AutoDESN','Fixed_DESN']:
        part=one[one.method==method]
        close(tag+'/'+method+' innovation SD constant over time',part.innovation_sd,np.repeat(part.innovation_sd.iloc[0],100))
for (kind,mode,method),x in s.groupby(['dgp','mode','method']):
    row=summary[(summary.dgp==kind)&(summary['mode']==mode)&(summary.method==method)].iloc[0]
    close(f'{kind}/{mode}/{method} RMSE',np.sqrt(x.squared_error.mean()),row.rmse)
    for field in ['crps','covered90','covered50','negative_log_score','width90']:
        close(f'{kind}/{mode}/{method} {field}',x[field].mean(),row[field])
    check(f'{kind}/{mode}/{method} count',row['count']==300)
for (_,_,_),x in dg.groupby(['dgp','repetition','method']):
    for attempt,part in x.groupby('attempt'):
        burn,retained={1:(2000,6000),2:(4000,16000),3:(6000,32000)}[int(attempt)]
        check('prespecified sampler duration',(part.n_burn==burn).all() and (part.retained_per_chain==retained).all())
        if attempt>1:
            previous=x[x.attempt==attempt-1]
            check('retry triggered only by failed diagnostics',len(previous)>0 and not previous.diagnostic_screen_pass.any())
    final=x[x.attempt==x.attempt.max()]
    check('final parameter Rhat screen',final.rhat.max()<=1.01)
    check('final parameter ESS screen',final.ess_spectral.min()>=400)
    check('final model probability screen',final.max_model_chain_range.max()<=.05)
gjr=pd.read_csv(OUT/'gjr_fits.csv')
check('GJR parameter constraints',((gjr.omega>0)&(gjr.alpha>0)&(gjr.gamma>0)&(gjr.beta>0)&(abs(gjr.phi)<.98)&(gjr.alpha+gjr.gamma/2+gjr.beta<.995)).all())
check('GJR training objective finite',np.isfinite(gjr.objective).all())
manifest=pd.read_csv(OUT/'launch_source_manifest.csv')
for row in manifest.itertuples():
    check('frozen source '+row.path,hashlib.md5(Path(row.path).read_bytes()).hexdigest()==row.md5)
initial_path=OUT/'initial_first_case_scores.csv'
initial_paths=OUT/'initial_first_case_paths.csv'
resource_parity_checked=False
if initial_path.exists() and initial_paths.exists():
    initial=pd.read_csv(initial_path)
    paired=initial.merge(s,on=keys,suffixes=('_initial','_final'),validate='one_to_one')
    for method in ['AutoDESN','Fixed_DESN']:
        part=paired[paired.method==method]
        for field in ['mean','lower90','upper90','negative_log_score']:
            check('resource recovery exact score parity '+method+'/'+field,
                  np.array_equal(part[field+'_initial'],part[field+'_final']))
    check('resource recovery exact illustrative path parity',
          np.array_equal(pd.read_csv(initial_paths).to_numpy(),
                         pd.read_csv(OUT/'smooth_scale_r01_paths.csv').to_numpy()))
    resource_parity_checked=True
    recovery=json.loads((OUT/'resource_recovery.json').read_text())
    for snapshot in recovery['initial_source_snapshots']:
        check('archived computational source '+snapshot['artifact'],
              hashlib.sha256((OUT/snapshot['artifact']).read_bytes()).hexdigest()==snapshot['sha256'])
elif initial_path.exists() or initial_paths.exists():
    raise AssertionError('Incomplete optional resource-recovery ledger')
result={'passed':len(checks),'failed':0,'historical_resource_parity_checked':resource_parity_checked,'note':'Descriptive simulation evidence; no forecast ranking is required.','checks':checks}
(OUT/'audit_report.json').write_text(json.dumps(result,indent=2)+'\n')
print(f'{len(checks)} independent export checks passed.')
