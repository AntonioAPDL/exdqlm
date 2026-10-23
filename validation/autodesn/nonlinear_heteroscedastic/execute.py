"""Sequential measured fits; full-support training-only recovery, then forecasts."""
import importlib.util,json,shutil,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('measured',HERE.parent/'standardized_rhs/execute.py')
measured=importlib.util.module_from_spec(spec);spec.loader.exec_module(measured)

def main():
 b=HERE/'artifacts';b.mkdir(exist_ok=True);records={}
 state=b/'execution_status.json'
 if state.exists():records=json.loads(state.read_text())
 def run(name,cmd):
  result=measured.run(cmd,b/(name+'.log'),b/(name+'_memory.json'));records[name]=result
  state.write_text(json.dumps(records,indent=2));print(name,json.dumps(result),flush=True)
  return result['exit_code']
 def R(script,*args):return ['Rscript','--vanilla',str(HERE/script),*args]
 for sc,method in [('requested','rhs'),('scaling_only','rhs'),('ridge_standardized','ridge')]:
  d=b/sc/method
  # Every long inference invocation remains bounded to one declared attempt.
  if not (d/'posterior_checkpoint.rds').exists():
   run(sc+'_fit',R('run.R','--scenario',sc,'--stage','fit'))
  status=json.loads((d/'status.json').read_text())
  if status['qualified']:
   if run(sc+'_export',R('export.R',str(b),'--scenario',sc))!=0:raise SystemExit('Trace export failed')
   run(sc+'_independent',[sys.executable,str(HERE/'qualify.py'),sc])
   status=json.loads((d/'status.json').read_text())
  if not status['qualified']:
   complete=all((d/f'attempt_{i}/status.json').exists() and json.loads((d/f'attempt_{i}/status.json').read_text())['complete'] for i in range(1,5))
   if method!='rhs' or not complete:raise SystemExit('Fit failed without a complete eligible training source; inspect logs')
   previous=b/(sc+'_initial_proposal')
   if previous.exists():raise SystemExit('The single declared recovery is exhausted')
   (b/sc).rename(previous)
   if run(sc+'_rebalanced_fit',R('run_rebalanced.R',sc))!=0:raise SystemExit('Training-only recovery did not qualify')
   if run(sc+'_rebalanced_export',R('export.R',str(b),'--scenario',sc))!=0:raise SystemExit('Trace export failed')
   if run(sc+'_rebalanced_independent',[sys.executable,str(HERE/'qualify.py'),sc])!=0:raise SystemExit('Recovered posterior failed independent screen')
  if run(sc+'_causality',R('audit_causality.R',sc))!=0:raise SystemExit('Future perturbation audit failed')
  if run(sc+'_forecast',R('forecast_serial.R',sc))!=0:raise SystemExit('Forecast stage failed; atomic checkpoints remain')
  if run(sc+'_sensitivity',R('sensitivity.R','--method',method,'--out',str(b/sc)))!=0:raise SystemExit('Predictive sensitivity failed')
 print('All three AutoDESN cases complete. Native AutoGP is a separately measured fresh stage.',flush=True)
if __name__=='__main__':main()
