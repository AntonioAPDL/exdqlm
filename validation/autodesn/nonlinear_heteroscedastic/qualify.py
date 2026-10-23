"""Independent retained-chain screen, required before test forecasting."""
import argparse,json,sys
from pathlib import Path
import numpy as np
import pandas as pd
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'standardized_rhs'))
from diagnostics import diagnostics

def main():
 p=argparse.ArgumentParser();p.add_argument('scenario');a=p.parse_args()
 study=json.loads((HERE/'study.json').read_text());sc=next(x for x in study['scenarios'] if x['id']==a.scenario)
 d=HERE/'artifacts'/a.scenario/sc['method'];status=json.loads((d/'status.json').read_text())
 assert status['fit_complete'] and status['qualified']
 trace=pd.read_csv(d/'traces.csv.gz');models=pd.read_csv(d/'model_probabilities.csv')
 params=['variance','ridge_precision'] if sc['method']=='ridge' else ['variance','log_global','log_slab','mean_log_local','intercept','fitted_rms','effective_slopes_diagonal']
 rows=[]
 for name in params:
  x=np.array([g[name].to_numpy() for _,g in trace.groupby('chain')]);rows.append(dict(parameter=name,**diagnostics(x)))
 for model in models.loc[models.posterior_probability>=.01,'model']:
  x=np.array([(g.model.to_numpy()==model).astype(float) for _,g in trace.groupby('chain')]);rows.append(dict(parameter=f'model_{model}',**diagnostics(x)))
 checks=pd.DataFrame(rows);checks.to_csv(d/'independent_diagnostics.csv',index=False)
 passed=bool(np.isfinite(checks[['rhat','bulk_ess','tail_ess']]).all().all() and (checks.rhat<=1.01).all() and (checks.bulk_ess>=400).all() and (checks.tail_ess>=400).all())
 record=dict(complete=True,passed=passed,checked_before_forecasting=not (d/'scores.csv').exists(),maximum_rhat=float(checks.rhat.max()),minimum_bulk_ess=float(checks.bulk_ess.min()),minimum_tail_frequency_ess=float(checks.tail_ess.min()))
 (d/'independent_screen.json').write_text(json.dumps(record,indent=2))
 print(json.dumps(record),flush=True)
 if not passed:
  status['qualified']=False;status['independent_screen_failed']=True
  (d/'status.json').write_text(json.dumps(status,indent=2))
  raise SystemExit('Independent posterior screen failed; no test forecasts authorized')
if __name__=='__main__':main()
