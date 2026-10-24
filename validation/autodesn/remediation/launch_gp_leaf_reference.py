"""Immutable observed launch for the small complete native leaf grammar."""
import argparse, hashlib, json, os, shutil, subprocess, sys
from pathlib import Path
p=argparse.ArgumentParser()
for name in ['julia','project','depot']:p.add_argument('--'+name,type=Path,required=True)
a=p.parse_args();root=Path('validation/autodesn/remediation');source=root/'gp_leaf_mcmc.jl'
sha=hashlib.sha256(source.read_bytes()).hexdigest();snapshot=root/'artifacts/gp_reference_sources'/sha
snapshot.mkdir(parents=True,exist_ok=True);target=snapshot/source.name
if not target.exists():shutil.copyfile(source,target);target.chmod(0o444)
assert hashlib.sha256(target.read_bytes()).hexdigest()==sha
(snapshot/'manifest.json').write_text(json.dumps({str(source):sha},indent=2)+'\n')
record=root/'evidence/gp_leaf_reference_resources.json';attempt=1
while record.exists():
 attempt+=1;record=root/'evidence'/f'gp_leaf_reference_attempt{attempt}_resources.json'
assert not list((root/'artifacts/gp_leaf_reference').glob('trace_*.csv')), 'Preserve completed chains; use a separately registered target for a new study'
env=os.environ.copy();env.pop('LD_LIBRARY_PATH',None)
env.update(JULIA_DEPOT_PATH=str(a.depot.resolve()),JULIA_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1')
cmd=[sys.executable,str(root/'run_process.py'),'--record',str(record),'--log',str(root/'artifacts'/('gp_leaf_reference.log' if attempt==1 else f'gp_leaf_reference_attempt{attempt}.log')),'--max-seconds','1800','--max-cgroup-anon-bytes','6100000000',str(a.julia.resolve()),'--startup-file=no','--project='+str(a.project.resolve()),str(target)]
print(json.dumps(dict(snapshot=sha,scope='Complete small native depth-one grammar; no production qualification')),flush=True)
raise SystemExit(subprocess.call(cmd,env=env))
