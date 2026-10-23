"""Measured fresh Native GP, audits and compact evidence after AutoDESN finishes."""
import argparse,importlib.util,json,sys,shutil
import pandas as pd
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('measured',HERE.parent/'standardized_rhs/execute.py')
measured=importlib.util.module_from_spec(spec);spec.loader.exec_module(measured)
def main():
 p=argparse.ArgumentParser();p.add_argument('--julia',required=True);p.add_argument('--project',type=Path,required=True);a=p.parse_args()
 b=HERE/'artifacts';records={};record_path=b/'postprocessing_execution.json'
 if record_path.exists():records=json.loads(record_path.read_text())
 def run(name,command):
  if name in records:
   i=1
   while f'{name}_previous_{i}' in records:i+=1
   previous=f'{name}_previous_{i}';records[previous]=records[name]
   for suffix in ['.log','_memory.json']:
    src=b/(name+suffix)
    if src.exists():shutil.copyfile(src,b/(previous+suffix))
  result=measured.run(command,b/(name+'.log'),b/(name+'_memory.json'));records[name]=result
  record_path.write_text(json.dumps(records,indent=2));print(name,json.dumps(result),flush=True)
  if result['exit_code']:raise SystemExit(f'{name} failed; evidence and checkpoints retained')
 def R(script,*args):return ['Rscript','--vanilla',str(HERE/script),*args]
 for case,method in [('requested','rhs'),('scaling_only','rhs'),('ridge_standardized','ridge')]:
  st=json.loads((b/case/method/'status.json').read_text());assert st['complete'] and st['qualified']
 gpstatus=b/'gp/status.json'
 if not gpstatus.exists() or not json.loads(gpstatus.read_text()).get('complete'):
  run('gp',['env','-u','LD_LIBRARY_PATH',sys.executable,str(HERE/'run_gp.py'),'--julia',a.julia,'--project',str(a.project.resolve()),'--out',str(b)])
 for case in ['requested','scaling_only','ridge_standardized']:run(case+'_causality',R('audit_causality.R',case))
 run('export',R('export.R',str(b)))
 run('archive_checkpoints',R('archive.R',str(b)))
 run('replay',R('replay.R'))
 run('backend_benchmark',R('benchmark.R'))
 run('analysis',[sys.executable,str(HERE/'analysis.py')])
 # Fresh production regressions and independent oracles bind to this source.
 reference=json.loads((b/'validation/current_validation_reference.json').read_text())
 current=json.loads((b/'requested/rhs/provenance.json').read_text())['production_source']
 assert {x['path']:x['sha256'] for x in current}=={x['path']:x['sha256'] for x in reference['production_source']},'Production source changed after current validation'
 validation=reference['validation']
 assert validation['complete'] and validation['installed_regression']['passed']==652
 bench=pd.read_csv(b/'validation/standardized_backend_benchmark.csv').groupby('backend').elapsed_seconds.median()
 parity=pd.read_csv(b/'validation/standardized_backend_parity.csv')
 validation['fresh_computational_backend_benchmark']=dict(median_R_seconds=float(bench['R']),median_cpp_seconds=float(bench['cpp']),ratio=float(bench['R']/bench['cpp']),max_coupled_draw_error=float(parity.max_paired_draw_error.max()),identical_model_paths=bool(parity.identical_model_path.all()),short_synthetic_designs_not_convergence_evidence=True)
 (b/'validation/validation_status.json').write_text(json.dumps(validation,indent=2))
 execution=json.loads((b/'execution_status.json').read_text())
 for case in ['requested','scaling_only','ridge_standardized']:
  measured_cases={k:v for k,v in execution.items() if k.startswith(case+'_')}
  peak=max(v.get('process_peak_rss_kib') or 0 for v in measured_cases.values())
  (b/case/'process_memory.json').write_text(json.dumps(dict(complete=True,process_peak_rss_kib=peak,measured_invocations=measured_cases),indent=2))
 env=b/'validation/julia_environment';env.mkdir(exist_ok=True)
 for name in ['Project.toml','Manifest.toml']:shutil.copyfile(a.project/name,env/name)
 print('Audited numeric evidence is ready for final report generation and visual review.',flush=True)
if __name__=='__main__':main()
