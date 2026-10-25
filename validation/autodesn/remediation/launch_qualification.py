"""Immutable source launch for completed-chain diagnostics at any study fold."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('family');p.add_argument('phase')
p.add_argument('--directory',type=Path);p.add_argument('--evidence-root',type=Path)
p.add_argument('--python',required=True,type=Path);a=p.parse_args()
r=Path('validation/autodesn/remediation');evidence=a.evidence_root or r/'evidence';evidence.mkdir(parents=True,exist_ok=True)
directory=a.directory or r/'artifacts'/a.family/a.phase
assert json.loads((directory/'status.json').read_text())['complete']
assert not (directory/'qualification.json').exists(),'Preserve earlier diagnostic evidence'
files=[r/'qualify.py',r.parent/'standardized_rhs/diagnostics.py',Path(__file__).resolve().relative_to(Path.cwd())]
manifest={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=r/'artifacts/qualification_sources'/key
for f in files:
 target=snapshot/f;target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest[str(f)]
 else:shutil.copyfile(f,target);target.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
label=f'{a.family}_{a.phase}_qualification';record=evidence/f'{label}_resources.json';assert not record.exists()
cmd=[sys.executable,str(r/'run_process.py'),'--record',str(record),'--log',str(directory/'qualification_attempt1.log'),'--max-seconds','1800','--max-cgroup-anon-bytes','6400000000',str(a.python.resolve()),str(snapshot/r/'qualify.py'),a.family,a.phase,'--directory',str(directory.resolve()),'--evidence-root',str(evidence.resolve())]
raise SystemExit(subprocess.call(cmd,env=os.environ.copy()))
