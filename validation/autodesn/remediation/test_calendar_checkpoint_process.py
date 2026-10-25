"""Freeze source once, then test recovery in independent OS processes."""
import hashlib,json,os,shutil,subprocess
from pathlib import Path
r=Path('validation/autodesn/remediation')
files=sorted(Path('R').glob('*.R'))+[Path('src/autodesn_rhs.cpp'),r/'test_calendar_checkpoint_process.R']
manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest()
snapshot=r/'artifacts/calendar_checkpoint_sources'/key
for p in files:
 target=snapshot/p;target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest[str(p)]
 else:shutil.copyfile(p,target);target.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
directory=r/'artifacts/checkpoint_calendar_fresh_process'/key
assert not directory.exists(),'Preserve executed results; use a new source snapshot for another attempt'
env=os.environ.copy();env['AUTODESN_SOURCE_SNAPSHOT']=str(snapshot.resolve())
for phase in ['start','resume','reference','compare']:
 subprocess.run(['Rscript','--vanilla',str(snapshot/r/'test_calendar_checkpoint_process.R'),phase,str(directory)],env=env,check=True)
