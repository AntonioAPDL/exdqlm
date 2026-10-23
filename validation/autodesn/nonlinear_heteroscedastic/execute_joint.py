"""Sequential full-size study with exact joint MH recovery and strict screens.

The failed model-only fits are proposal-training evidence, never forecasts.
Every independent-screen rejection excludes that budget on resume, without
changing the target or bypassing diagnostics.
"""
import importlib.util,json,shutil,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('measured',HERE.parent/'standardized_rhs/execute.py')
measured=importlib.util.module_from_spec(spec);spec.loader.exec_module(measured)
def main():
 b=HERE/'artifacts';b.mkdir(exist_ok=True);state=b/'execution_status.json'
 records=json.loads(state.read_text()) if state.exists() else {}
 def run(name,cmd):
  if name in records:
   i=1
   while f'{name}_previous_{i}' in records:i+=1
   previous=f'{name}_previous_{i}';records[previous]=records[name]
   for suffix in ['.log','_memory.json']:
    src=b/(name+suffix)
    if src.exists():shutil.copyfile(src,b/(previous+suffix))
  result=measured.run(cmd,b/(name+'.log'),b/(name+'_memory.json'));records[name]=result
  state.write_text(json.dumps(records,indent=2));print(name,json.dumps(result),flush=True)
  return result['exit_code']
 def R(script,*args):return ['Rscript','--vanilla',str(HERE/script),*args]
 # A clean reproduction first recreates the two documented failed training
 # proposals. Never silently substitute old-DGP training chains.
 prior=b/'requested_initial_proposal/rhs/status.json'
 recovered=b/'requested_rebalanced_64k'
 if not prior.exists():run('model_only_training',[sys.executable,str(HERE/'execute.py')])
 if not recovered.exists():
  source=b/'requested';s=json.loads((source/'rhs/status.json').read_text())
  assert s['fit_complete'] and not s['qualified'] and not (source/'rhs/scores.csv').exists()
  config=json.loads((source/'configuration.json').read_text())
  assert 'training_proposal' in config and 'joint_training_proposal' not in config
  source.rename(recovered)
 for sc,method in [('requested','rhs'),('scaling_only','rhs'),('ridge_standardized','ridge')]:
  d=b/sc/method
  for _ in range(4):
   if not (d/'posterior_checkpoint.rds').exists():
    cmd=R('fit_joint.R',sc) if method=='rhs' else R('run.R','--scenario',sc,'--stage','fit')
    if run(sc+'_joint_fit' if method=='rhs' else sc+'_fit',cmd):raise SystemExit('Frozen full-size fit gates failed; no forecasts issued')
   if run(sc+'_export',R('export.R',str(b),'--scenario',sc)):raise SystemExit('Trace export failed')
   if not run(sc+'_independent',[sys.executable,str(HERE/'qualify.py'),sc]):break
   if method!='rhs':raise SystemExit('Ridge independent screen failed; preserve evidence and investigate')
   status=json.loads((d/'status.json').read_text());attempt=status['selected_attempt']
   config=json.loads((b/sc/'configuration.json').read_text())
   # JSON data.frames are rows under the study writer.
   budgets=config['attempts'];retained=budgets[attempt-1]['n_mcmc']
   ledger=d/'independent_rejected_budgets.json'
   rejected=json.loads(ledger.read_text()) if ledger.exists() else dict(retained=[],attempts=[])
   rejected['retained'].append(retained);rejected['attempts'].append(attempt)
   ledger.write_text(json.dumps(rejected,indent=2))
   for name in ['posterior_checkpoint.rds','independent_screen.json','independent_diagnostics.csv']:
    (d/name).rename(d/f'rejected_attempt_{attempt}_{name}')
   if attempt==4:raise SystemExit('All joint MH budgets failed independent checks; no forecasts issued')
  else:raise SystemExit('Independent screening exhausted')
  if run(sc+'_causality',R('audit_causality.R',sc)):raise SystemExit('Future perturbation audit failed')
  if run(sc+'_forecast',R('forecast_serial.R',sc)):raise SystemExit('Forecast failed; atomic checkpoints retained')
  if run(sc+'_sensitivity',R('sensitivity.R','--method',method,'--out',str(b/sc))):raise SystemExit('Predictive sensitivity failed')
 print('All three AutoDESN cases complete. Native AutoGP is the next separately measured stage.',flush=True)
if __name__=='__main__':main()
