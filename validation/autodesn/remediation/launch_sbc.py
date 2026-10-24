"""Immutable fixed-design calibration launch, with case-level atomic checkpoints."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('family',choices=['ridge','rhs']);p.add_argument('--cases',type=int,default=200);p.add_argument('--retained',type=int,default=24000);a=p.parse_args()
root=Path('validation/autodesn/remediation');files=sorted(Path('R').glob('*.R'))+[Path('src/autodesn_rhs.cpp'),root/'sbc.R']
manifest={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files};key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=root/'artifacts'/'sbc_sources'/key
for f in files:
 target=snapshot/f;target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest[str(f)]
 else:shutil.copyfile(f,target);target.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');env=os.environ.copy();env['AUTODESN_SOURCE_SNAPSHOT']=str(snapshot.resolve());label=f'sbc_{a.family}_{a.retained}'
record=root/'evidence'/f'{label}_resources.json';attempt=1
while record.exists():attempt+=1;record=root/'evidence'/f'{label}_attempt{attempt}_resources.json'
command=[sys.executable,str(root/'run_process.py'),'--record',str(record),'--log',str(root/'artifacts'/f'{label}_attempt{attempt}.log'),'--max-seconds','7200','Rscript','--vanilla',str(snapshot/root/'sbc.R'),a.family,str(a.cases),str(a.retained)]
print(json.dumps(dict(snapshot=key,family=a.family,cases=a.cases,retained=a.retained)),flush=True);raise SystemExit(subprocess.call(command,env=env))
