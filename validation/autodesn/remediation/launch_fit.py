"""Content-addressed, immutable source launch; checkpoints never share a live driver."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('family',choices=['F1','F2','SV','F2flat','SVseasonal','F1ridge','F2ridge']);p.add_argument('phase',choices=['pilot','production']);p.add_argument('budget',type=int,nargs='?',default=32000);p.add_argument('--workers',type=int,choices=[1,2,4],default=1);p.add_argument('--snapshot',help='Existing immutable snapshot key, required to resume its contract');p.add_argument('--cache',action='store_true');p.add_argument('--run-label',default='');p.add_argument('--chains',default='1,2,3,4');p.add_argument('--local-proposal',default='',help='Frozen training-only optional exact local proposal checkpoint');a=p.parse_args()
root=Path('validation/autodesn/remediation');files=sorted(Path('R').glob('*.R'))+[Path('src/autodesn_rhs.cpp'),Path('src/RcppExports.cpp'),root/'fit.R']
if a.snapshot:
 key=a.snapshot;snapshot=root/'artifacts'/'source_snapshots'/key
 manifest=json.loads((snapshot/'manifest.json').read_text())
 for path,sha in manifest.items():assert hashlib.sha256((snapshot/path).read_bytes()).hexdigest()==sha
else:
 manifest={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files};key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=root/'artifacts'/'source_snapshots'/key
 for f in files:
  target=snapshot/f;target.parent.mkdir(parents=True,exist_ok=True)
  if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest[str(f)]
  else:shutil.copyfile(f,target);target.chmod(0o444)
 (snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
env=os.environ.copy();env['AUTODESN_SOURCE_SNAPSHOT']=str(snapshot.resolve());env['AUTODESN_CHAIN_WORKERS']=str(a.workers);env['AUTODESN_INFERENCE_CACHE']='1' if a.cache else '0';env['AUTODESN_RUN_LABEL']=a.run_label;env['AUTODESN_CHAINS']=a.chains
env['AUTODESN_LOCAL_PROPOSAL']=a.local_proposal
if a.local_proposal:assert 'AUTODESN_LOCAL_PROPOSAL' in (snapshot/root/'fit.R').read_text()
if a.cache:assert 'AUTODESN_INFERENCE_CACHE' in (snapshot/root/'fit.R').read_text()
label=f'{a.family}_{a.phase}_{a.budget}'+('_'+a.run_label if a.run_label else '')
record=root/'evidence'/f'{label}_resources.json';attempt=1
while record.exists():
 attempt+=1;record=root/'evidence'/f'{label}_attempt{attempt}_resources.json'
command=[sys.executable,str(root/'run_process.py'),'--record',str(record),'--log',str(root/'artifacts'/f'{label}_attempt{attempt}.log'),'--max-seconds','7200','--max-cgroup-anon-bytes','6400000000','Rscript','--vanilla',str(snapshot/root/'fit.R'),a.family,a.phase,str(a.budget)]
print(json.dumps(dict(snapshot=key,workers=a.workers,family=a.family,phase=a.phase,budget=a.budget)),flush=True)
raise SystemExit(subprocess.call(command,env=env))
