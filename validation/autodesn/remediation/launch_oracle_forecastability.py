"""Freeze a training-only privileged predictability audit before simulations."""
import hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
r=Path('validation/autodesn/remediation')
files=[r.parent/'nonlinear_heteroscedastic/dgp.R',r/'oracle_forecastability.R',r/'run_oracle_forecastability.R',Path(__file__).resolve().relative_to(Path.cwd())]
registration=r/'evidence/oracle_forecastability_registration.json';assert registration.exists()
manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files+[registration]}
key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=r/'artifacts/oracle_forecastability_sources'/key
for f in files:
 target=snapshot/f.name;target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest[str(f)]
 else:shutil.copyfile(f,target);target.chmod(0o444)
shutil.copyfile(registration,snapshot/'registration.json')
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
out=r/'artifacts/oracle_forecastability'/key;assert not out.exists()
record=r/'evidence/oracle_forecastability_resources.json';attempt=1
while record.exists():attempt+=1;record=r/'evidence'/f'oracle_forecastability_attempt{attempt}_resources.json'
cmd=[sys.executable,str(r/'run_process.py'),'--record',str(record),'--log',str(r/'artifacts'/f'oracle_forecastability_attempt{attempt}.log'),'--max-seconds','900','--max-cgroup-anon-bytes','6400000000','Rscript','--vanilla',str(snapshot/'run_oracle_forecastability.R'),str(snapshot),str(out)]
raise SystemExit(subprocess.call(cmd,env=os.environ.copy()))
