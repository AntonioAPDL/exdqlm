"""Run the small full-SV numerical reference from an immutable complete source."""
import hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
root=Path('validation/autodesn/remediation');files=sorted(Path('R').glob('*.R'))+[Path('src/autodesn_rhs.cpp'),root/'sv_joint_mcmc.R'];m={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files};key=hashlib.sha256(json.dumps(m,sort_keys=True).encode()).hexdigest();d=root/'artifacts/sv_reference_sources'/key
for p in files:
 q=d/p;q.parent.mkdir(parents=True,exist_ok=True)
 if q.exists():assert hashlib.sha256(q.read_bytes()).hexdigest()==m[str(p)]
 else:shutil.copyfile(p,q);q.chmod(0o444)
(d/'manifest.json').write_text(json.dumps(m,indent=2)+'\n');env=os.environ.copy();env['AUTODESN_SOURCE_SNAPSHOT']=str(d.resolve())
command=[sys.executable,str(root/'run_process.py'),'--record',str(root/'evidence/sv_joint_mcmc_resources.json'),'--log',str(root/'artifacts/sv_joint_mcmc.log'),'--max-seconds','1800','Rscript','--vanilla',str(d/root/'sv_joint_mcmc.R')]
print(json.dumps(dict(snapshot=key,scope='small_full_SV_reference')),flush=True);raise SystemExit(subprocess.call(command,env=env))
