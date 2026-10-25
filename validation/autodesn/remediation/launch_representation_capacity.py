"""Stream a training-span diagnostic without loading a construction bank."""
import hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
r=Path('validation/autodesn/remediation')
files=sorted(Path('R').glob('*.R'))+[r/'representation_capacity.R',r/'evidence/representation_capacity_registration.json',Path(__file__)]
manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=r/'artifacts/capacity_sources'/key
for p in files:
 q=snapshot/p;q.parent.mkdir(parents=True,exist_ok=True)
 if q.exists():assert hashlib.sha256(q.read_bytes()).hexdigest()==manifest[str(p)]
 else:shutil.copyfile(p,q);q.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
attempt=1;record=r/'evidence/representation_capacity_resources.json'
while record.exists() or (r/f'artifacts/representation_capacity_attempt{attempt}.log').exists():
 attempt+=1;record=r/f'evidence/representation_capacity_attempt{attempt}_resources.json'
env=os.environ.copy();env['AUTODESN_SOURCE_SNAPSHOT']=str(snapshot.resolve())
print(json.dumps(dict(snapshot=key,scope='Privileged training-span bound; no forecasting or selection')),flush=True)
raise SystemExit(subprocess.call([sys.executable,str(r/'run_process.py'),'--record',str(record),'--log',str(r/f'artifacts/representation_capacity_attempt{attempt}.log'),'--max-seconds','900','--max-cgroup-anon-bytes','6400000000','Rscript','--vanilla',str(snapshot/r/'representation_capacity.R')],env=env))
