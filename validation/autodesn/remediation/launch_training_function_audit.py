"""Freeze and execute the privileged, training-only readout-function audit."""
import hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
from large_job import single_large_job

root=Path('validation/autodesn/remediation')
phase='production_256000_joint128_recoverable'
files=sorted(Path('R').glob('*.R'))+[root/'training_function_audit.R',Path(__file__).resolve().relative_to(Path.cwd().resolve())]
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
 raise SystemExit(subprocess.call([sys.executable,str(root/'run_process.py'),'--record',str(record),
  '--log',str(root/'artifacts/F1_training_function_attempt1.log'),'--max-seconds','600',
  '--max-cgroup-anon-bytes','6400000000','Rscript','--vanilla',str(snapshot/root/'training_function_audit.R'),phase],env=env))
