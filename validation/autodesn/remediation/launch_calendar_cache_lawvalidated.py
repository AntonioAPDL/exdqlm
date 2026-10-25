"""Freeze benchmark sources, then run a bounded full-bank computational audit."""
import hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
r=Path('validation/autodesn/remediation')
files=list(Path('R').glob('*.R'))+[Path('src/autodesn_rhs.cpp'),r/'benchmark_calendar_cache_lawvalidated.R',Path(__file__).resolve().relative_to(Path.cwd().resolve())]
manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=r/'artifacts/calendar_cache_sources'/key
for p in files:
 t=snapshot/p;t.parent.mkdir(parents=True,exist_ok=True)
 if t.exists():assert hashlib.sha256(t.read_bytes()).hexdigest()==manifest[str(p)]
 else:shutil.copyfile(p,t);t.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
env=dict(os.environ,AUTODESN_SOURCE_SNAPSHOT=str(snapshot.resolve()))
raise SystemExit(subprocess.call([sys.executable,str(r/'run_process.py'),'--record',str(r/'evidence/calendar_cache_benchmark_lawvalidated_resources.json'),'--log',str(r/'artifacts/calendar_cache_benchmark_lawvalidated_attempt1.log'),'--max-seconds','1800','--max-cgroup-anon-bytes','6400000000','Rscript','--vanilla',str(snapshot/r/'benchmark_calendar_cache_lawvalidated.R')],env=env))
