"""Freeze and execute the privileged, training-only readout-function audit."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
from large_job import single_large_job

root=Path('validation/autodesn/remediation')
parser=argparse.ArgumentParser();parser.add_argument('phase',nargs='?',default='production_256000_joint128_recoverable');parser.add_argument('--include-shrinkage',action='store_true');args=parser.parse_args()
phase=args.phase
assert '/' not in phase and phase.startswith('production_')
for suffix in ['training_function.json']+(['shrinkage.json'] if args.include_shrinkage else []):
 assert not (root/'evidence'/f'F1_{phase}_{suffix}').exists(),'Preserve completed evidence'
files=sorted(Path('R').glob('*.R'))+[root/'training_function_audit.R',root/'shrinkage_summary.R',root/'large_job.py',root/'run_process.py',Path(__file__).resolve().relative_to(Path.cwd().resolve())]
manifest={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest()
snapshot=root/'artifacts/fit_audit_sources'/key
assert not snapshot.exists()
for p in files:
 target=snapshot/p;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target);target.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
env=dict(os.environ,AUTODESN_SOURCE_SNAPSHOT=str(snapshot.resolve()))
record=root/'evidence'/f'F1_{phase}_training_function_resources.json'
assert not record.exists()
with single_large_job(root,'training function audit'):
 result=subprocess.call([sys.executable,str(root/'run_process.py'),'--record',str(record),
  '--log',str(root/'artifacts'/f'F1_{phase}_training_function_attempt1.log'),'--max-seconds','600',
  '--max-cgroup-anon-bytes','6400000000','Rscript','--vanilla',str(snapshot/root/'training_function_audit.R'),phase],env=env)
 if result:raise SystemExit(result)
 if args.include_shrinkage:
  result=subprocess.call([sys.executable,str(snapshot/root/'run_process.py'),'--record',str(root/'evidence'/f'F1_{phase}_shrinkage_resources.json'),'--log',str(root/'artifacts'/f'F1_{phase}_shrinkage.log'),'--max-seconds','600','--max-cgroup-anon-bytes','6400000000','Rscript','--vanilla',str(snapshot/root/'shrinkage_summary.R'),phase],env=env)
 raise SystemExit(result)
