"""Independent rank/bulk/tail screens for completed four-chain training runs."""
import argparse,hashlib,json,sys
from pathlib import Path
import numpy as np,pandas as pd
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'standardized_rhs'))
from diagnostics import diagnostics
p=argparse.ArgumentParser();p.add_argument('family');p.add_argument('phase');p.add_argument('--directory',type=Path);p.add_argument('--output',type=Path);p.add_argument('--evidence-root',type=Path);a=p.parse_args()
d=a.directory or HERE/'artifacts'/a.family/a.phase
cfg=json.loads((d/'configuration.json').read_text());status=json.loads((d/'status.json').read_text());assert status['complete']
traces=[pd.read_csv(d/f'trace_{k}.csv') for k in range(1,5)];assert len({len(t) for t in traces})==1
for k in range(1,5):assert json.loads((d/f'chain_{k}_status.json').read_text())['target_id']==status['target_id']
fields=['variance','intercept','fitted_rms','edf']+[x for x in traces[0].columns if x.startswith(('log_global_','fitted_probe_','norm_','edf_','volatility_','terminal_'))]+[x for x in ['log_slab','log_likelihood','ridge_precision'] if x in traces[0]]
if a.family.startswith('SV'):fields+=['phi','omega']
fields=[field for field in fields if np.var(np.concatenate([t[field].to_numpy() for t in traces]))>0]
metadata=d/'model_metadata.csv'
category_fields=['model','period_index']
if metadata.exists():
 meta=pd.read_csv(metadata).set_index('model')
 for column,label in [('D','depth'),('m','reservoir_lag')]:
  if column in meta:
   for t in traces:t[label]=t.model.map(meta[column])
   category_fields.append(label)
rows=[]
for field in fields:
 x=np.array([t[field].to_numpy() for t in traces]);rows.append(dict(parameter=field,**diagnostics(x)))
for field in category_fields:
 values=np.concatenate([t[field].to_numpy() for t in traces]);unique,counts=np.unique(values,return_counts=True)
 for value,count in zip(unique,counts):
  if count/len(values)<.01 or len(unique)==1:continue
  x=np.array([(t[field].to_numpy()==value).astype(float) for t in traces]);dg=diagnostics(x);se=np.sqrt((x.mean()*(1-x.mean()))/dg['bulk_ess']) if dg['bulk_ess']>0 else np.inf
  rows.append(dict(parameter=f'{field}_{value}',probability_mcse=se,**dg))
checks=pd.DataFrame(rows);checks.to_csv(d/'independent_diagnostics.csv',index=False)
finite=np.isfinite(checks[['rhat','bulk_ess','tail_ess']]).all().all()
passed=bool(finite and (checks.rhat<=1.01).all() and (checks.bulk_ess>=400).all() and (checks.tail_ess>=400).all())
freq_ranges={}
for field in category_fields:
 values=np.unique(np.concatenate([t[field].to_numpy() for t in traces]));freq=np.array([[(t[field]==v).mean() for v in values] for t in traces]);active=freq.mean(0)>=.01
 freq_ranges[field]=float(np.ptp(freq[:,active],axis=0).max()) if active.any() else 0.
probability_mcse=checks.probability_mcse.dropna() if 'probability_mcse' in checks else pd.Series(dtype=float)
maximum_probability_mcse=float(probability_mcse.max()) if len(probability_mcse) else 0.
passed=passed and max(freq_ranges.values())<=.03 and maximum_probability_mcse<=.01
record=dict(complete=True,screen_passed=passed,qualified=False,cross_budget_qualification_pending=True,forecast_allowed=False,phase=a.phase,family=a.family,
 maximum_probability_mcse=maximum_probability_mcse,maximum_rhat=float(checks.rhat.max()),minimum_bulk_ess=float(checks.bulk_ess.min()),minimum_tail_ess=float(checks.tail_ess.min()),frequency_ranges=freq_ranges,
 visited_architectures=len(set(np.concatenate([t.model.to_numpy() for t in traces]))),visited_periods=len(set(np.concatenate([t.period_index.to_numpy() for t in traces]))),
 trace_sha256={f'trace_{k}.csv':hashlib.sha256((d/f'trace_{k}.csv').read_bytes()).hexdigest() for k in range(1,5)},target_id=status['target_id'],
 note='Passing this screen is necessary; independent references, mode/cross-budget and predictive Monte Carlo stability are still required.')
if a.output:
 assert not a.output.exists(),'Preserve earlier diagnostic evidence'
 a.output.write_text(json.dumps(record,indent=2)+'\n')
else:
 evidence=a.evidence_root or HERE/'evidence';evidence.mkdir(parents=True,exist_ok=True)
 (d/'qualification.json').write_text(json.dumps(record,indent=2)+'\n');(evidence/f'{a.family}_{a.phase}_qualification.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
