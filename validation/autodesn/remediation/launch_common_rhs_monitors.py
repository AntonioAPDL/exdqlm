"""Freeze both extract/check stages and execute without changing a sampler."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('phase');p.add_argument('--family',default='F1');p.add_argument('--artifact-root',type=Path);p.add_argument('--evidence-root',type=Path);a=p.parse_args()
r=Path('validation/autodesn/remediation');phase=a.phase;artifacts=a.artifact_root or r/'artifacts';evidence=a.evidence_root or r/'evidence';evidence.mkdir(parents=True,exist_ok=True)
directory=artifacts/a.family/phase
output=artifacts/'common_rhs_monitors';output=output/phase if a.family=='F1' else output/a.family/phase
assert not (output/'status.json').exists(),'Preserve earlier complete common-coordinate records'
files=[r/'common_rhs_monitors.R',r/'check_common_rhs_monitors.py',Path(__file__).resolve().relative_to(Path.cwd().resolve()),r.parent/'standardized_rhs/diagnostics.py']
manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files};key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=r/'artifacts/common_monitor_sources'/key
if not snapshot.exists():
 for p in files:
  target=snapshot/p;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target);target.chmod(0o444)
 (snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for p,sha in manifest.items():assert hashlib.sha256((snapshot/p).read_bytes()).hexdigest()==sha
env=dict(os.environ,AUTODESN_SOURCE_SNAPSHOT=str(snapshot.resolve()))
commands=[['Rscript','--vanilla',str(snapshot/r/'common_rhs_monitors.R'),phase,a.family,str(directory),str(output)],[os.environ['AUTODESN_SCIENTIFIC_PYTHON'],str(snapshot/r/'check_common_rhs_monitors.py'),phase,'--family',a.family,'--directory',str(output),'--evidence-root',str(evidence)]]
for name,cmd in zip(['extract','check'],commands):
 label=f'{a.family}_{phase}_common_rhs_{name}';record=evidence/f'{label}_resources.json';attempt=1
 while record.exists():attempt+=1;record=evidence/f'{label}_attempt{attempt}_resources.json'
 result=subprocess.call([sys.executable,str(r/'run_process.py'),'--record',str(record),'--log',str(output/f'{name}_attempt{attempt}.log'),'--max-seconds','600','--max-cgroup-anon-bytes','6400000000']+cmd,env=env)
 if result:raise SystemExit(result)
