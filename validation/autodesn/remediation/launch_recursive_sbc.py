"""Immutable, atomic-case, resource-capped frozen-map recursive SBC."""
import argparse, hashlib, json, os, shutil, subprocess, sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('variance',choices=['constant','sv']);p.add_argument('--cases',type=int,default=200);p.add_argument('--retained',type=int,default=24000);p.add_argument('--workers',type=int,choices=[1,2],default=1);p.add_argument('--snapshot');p.add_argument('--case-set',default='',help='Scheduling subset only; all declared cases remain required for calibration');a=p.parse_args()
root=Path('validation/autodesn/remediation');files=sorted(Path('R').glob('*.R'))+[Path('src/autodesn_rhs.cpp'),root/'recursive_sbc.R']
if a.snapshot:
 key=a.snapshot;snapshot=root/'artifacts/recursive_sbc_sources'/key;manifest=json.loads((snapshot/'manifest.json').read_text())
 for path,sha in manifest.items():assert hashlib.sha256((snapshot/path).read_bytes()).hexdigest()==sha
else:
 manifest={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files};key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=root/'artifacts/recursive_sbc_sources'/key
 for f in files:
  target=snapshot/f;target.parent.mkdir(parents=True,exist_ok=True)
  if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest[str(f)]
  else:shutil.copyfile(f,target);target.chmod(0o444)
 (snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
env=os.environ.copy();env['AUTODESN_SOURCE_SNAPSHOT']=str(snapshot.resolve());label=f'recursive_sbc_{a.variance}_n{a.cases}_k{a.retained}';record=root/'evidence'/f'{label}_resources.json';attempt=1
env['AUTODESN_RECURSIVE_CASE_SET']=a.case_set
out=root/'artifacts'/label
while record.exists() or (root/'artifacts'/f'{label}_attempt{attempt}.log').exists() or (out/f'invocation_{attempt}.json').exists():
 attempt+=1;record=root/'evidence'/f'{label}_attempt{attempt}_resources.json'
out.mkdir(parents=True,exist_ok=True)
invocation=dict(snapshot=key,workers=a.workers,selected_cases=a.case_set or 'all',all_declared_cases_required=True,launcher_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),resource_runner_sha256=hashlib.sha256((root/'run_process.py').read_bytes()).hexdigest())
with (out/f'invocation_{attempt}.json').open('x') as f:f.write(json.dumps(invocation,indent=2)+'\n')
cmd=[sys.executable,str(root/'run_process.py'),'--record',str(record),'--log',str(root/'artifacts'/f'{label}_attempt{attempt}.log'),'--max-seconds','7200','--max-cgroup-anon-bytes','6100000000','Rscript','--vanilla',str(snapshot/root/'recursive_sbc.R'),str(a.cases),str(a.retained),a.variance,str(a.workers)]
print(json.dumps(dict(snapshot=key,variance=a.variance,cases=a.cases,retained=a.retained,workers=a.workers)),flush=True);raise SystemExit(subprocess.call(cmd,env=env))
