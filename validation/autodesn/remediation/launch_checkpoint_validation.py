"""Freeze a read-only RDS/CSV/state-index validator before executing it."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('family');p.add_argument('phase')
p.add_argument('--directory',type=Path);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();r=Path('validation/autodesn/remediation')
directory=a.directory or r/'artifacts'/a.family/a.phase
assert directory.is_dir() and not a.output.exists()
files=[r/'validate_checkpoints.R',Path(__file__).resolve().relative_to(Path.cwd())]
manifest={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=r/'artifacts/checkpoint_validation_sources'/key
for f in files:
 target=snapshot/f;target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest[str(f)]
 else:shutil.copyfile(f,target);target.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
label=a.output.stem;record=r/'evidence'/f'{label}_resources.json';attempt=1
while record.exists():attempt+=1;record=r/'evidence'/f'{label}_attempt{attempt}_resources.json'
cmd=[sys.executable,str(r/'run_process.py'),'--record',str(record),'--log',str(r/'artifacts'/f'{label}_attempt{attempt}.log'),'--max-seconds','900','--max-cgroup-anon-bytes','6400000000','Rscript','--vanilla',str(snapshot/r/'validate_checkpoints.R'),a.family,a.phase,str(directory),str(a.output)]
raise SystemExit(subprocess.call(cmd,env=os.environ.copy()))
