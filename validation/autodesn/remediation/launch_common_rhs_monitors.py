"""Freeze both extract/check stages and execute without changing a sampler."""
import hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
r=Path('validation/autodesn/remediation');phase=sys.argv[1]
files=[r/'common_rhs_monitors.R',r/'check_common_rhs_monitors.py',Path(__file__).resolve().relative_to(Path.cwd().resolve()),r.parent/'standardized_rhs/diagnostics.py']
manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files};key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=r/'artifacts/common_monitor_sources'/key
if not snapshot.exists():
 for p in files:
  target=snapshot/p;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target);target.chmod(0o444)
 (snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for p,sha in manifest.items():assert hashlib.sha256((snapshot/p).read_bytes()).hexdigest()==sha
env=dict(os.environ,AUTODESN_SOURCE_SNAPSHOT=str(snapshot.resolve()))
commands=[['Rscript','--vanilla',str(snapshot/r/'common_rhs_monitors.R'),phase],[os.environ['AUTODESN_SCIENTIFIC_PYTHON'],str(snapshot/r/'check_common_rhs_monitors.py'),phase]]
for name,cmd in zip(['extract','check'],commands):
 record=r/'evidence'/f'F1_{phase}_common_rhs_{name}_resources.json';assert not record.exists()
 result=subprocess.call([sys.executable,str(r/'run_process.py'),'--record',str(record),'--log',str(r/'artifacts'/f'F1_{phase}_common_rhs_{name}_attempt1.log'),'--max-seconds','600','--max-cgroup-anon-bytes','6400000000']+cmd,env=env)
 if result:raise SystemExit(result)
