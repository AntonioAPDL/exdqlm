"""Complete core comparators, then the same-prior auxiliary RHS recovery."""
import argparse,importlib.util,json,sys
from pathlib import Path
from execution_logging import run_measured
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('measured',HERE.parent/'standardized_rhs/execute.py')
measured=importlib.util.module_from_spec(spec);spec.loader.exec_module(measured)
def main():
 p=argparse.ArgumentParser();p.add_argument('--julia',required=True);p.add_argument('--project',type=Path,required=True);a=p.parse_args()
 b=HERE/'artifacts';state=b/'execution_status.json';records=json.loads(state.read_text())
 failed=b/'scaling_only_joint_initial'
 if not failed.exists():
  source=b/'scaling_only';p=source/'rhs/status.json'
  assert p.exists(),'Run execute_joint.py through its declared initial budgets first'
  old=json.loads(p.read_text())
  assert old['fit_complete'] and not old['qualified'] and old['selected_attempt']==4
  assert not (source/'rhs/scores.csv').exists()
  source.rename(failed)
  assert not source.exists(),'A stale source copy remains; verify its checkpoints before clearing it'
 def run(name,cmd,post=False):
  if post:
   path=b/'postprocessing_execution.json';rec=json.loads(path.read_text()) if path.exists() else {}
  else:path=state;rec=records
  result=run_measured(measured,rec,path,b,name,cmd);print(name,json.dumps(result),flush=True)
  return result['exit_code']
 def R(script,*args):return ['Rscript','--vanilla',str(HERE/script),*args]
 def screen(sc,method):
  if run(sc+'_export',R('export.R',str(b),'--scenario',sc)):raise SystemExit('Trace export failed')
  return run(sc+'_independent',[sys.executable,str(HERE/'qualify.py'),sc])
 def predict(sc,method):
  if run(sc+'_causality',R('audit_causality.R',sc)):raise SystemExit('Causality audit failed')
  if run(sc+'_forecast',R('forecast_serial.R',sc)):raise SystemExit('Forecast failed')
  if run(sc+'_sensitivity',R('sensitivity.R','--method',method,'--out',str(b/sc))):raise SystemExit('Sensitivity failed')
 # Main requested-prior case is already complete. Run the remaining two core
 # comparators before spending the additional auxiliary recovery budget.
 sc='ridge_standardized';d=b/sc/'ridge'
 if not (d/'status.json').exists() or not json.loads((d/'status.json').read_text()).get('complete'):
  for _ in range(4):
   if not (d/'posterior_checkpoint.rds').exists():
    if run(sc+'_fit',R('run.R','--scenario',sc,'--stage','fit')):raise SystemExit('Ridge fit gates failed')
   if not screen(sc,'ridge'):break
   st=json.loads((d/'status.json').read_text());attempt=st['selected_attempt']
   p=d/'independent_rejected_budgets.json';v=json.loads(p.read_text()) if p.exists() else dict(attempts=[])
   v['attempts'].append(attempt);p.write_text(json.dumps(v,indent=2))
   for name in ['posterior_checkpoint.rds','independent_screen.json','independent_diagnostics.csv']:
    source=d/name;target=d/f'rejected_attempt_{attempt}_{name}';source.rename(target)
    if source.exists():source.unlink()
   if attempt==4:raise SystemExit('Ridge independent screens exhausted')
  else:raise SystemExit('Ridge screens exhausted')
  predict(sc,'ridge')
 gp=b/'gp/status.json'
 if not gp.exists() or not json.loads(gp.read_text()).get('complete'):
  if run('gp',['env','-u','LD_LIBRARY_PATH',sys.executable,str(HERE/'run_gp.py'),'--julia',a.julia,'--project',str(a.project.resolve()),'--out',str(b)],post=True):raise SystemExit('Fresh NativeGP failed')
 sc='scaling_only';d=b/sc/'rhs'
 if not (d/'status.json').exists() or not json.loads((d/'status.json').read_text()).get('complete'):
  if not (d/'posterior_checkpoint.rds').exists():
   if run(sc+'_same_prior_recovery_fit',R('fit_control_recovery.R',sc)):raise SystemExit('Auxiliary recovery failed frozen fit gates; core comparisons preserved')
  if screen(sc,'rhs'):raise SystemExit('Auxiliary recovery failed independent screen; no auxiliary forecasts')
  predict(sc,'rhs')
 print('All four fresh-model forecasts complete; run postprocess for final audits and reporting.',flush=True)
if __name__=='__main__':main()
