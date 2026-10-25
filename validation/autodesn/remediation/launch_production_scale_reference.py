"""Independent small posterior reference at tau0=.001, slab_scale=1, df=4."""
import hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
r=Path('validation/autodesn/remediation')
names=['production_scale_reference.R','production_scale_prior_integration.py','extract_production_scale_reference.R','check_production_scale_reference.py']
files=sorted(Path('R').glob('*.R'))+[Path('src/autodesn_rhs.cpp')]+[r/n for n in names]+[Path(__file__),r/'evidence/production_scale_reference_registration.json']
manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=r/'artifacts/production_scale_sources'/key
for p in files:
 q=snapshot/p;q.parent.mkdir(parents=True,exist_ok=True)
 if q.exists():assert hashlib.sha256(q.read_bytes()).hexdigest()==manifest[str(p)]
 else:shutil.copyfile(p,q);q.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
env=os.environ.copy();env['AUTODESN_SOURCE_SNAPSHOT']=str(snapshot.resolve())
python=Path('/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3')
steps=[('fixture',['Rscript','--vanilla',str(snapshot/r/names[0]),'fixture']),
 ('integration',[str(python),str(snapshot/r/names[1])]),
 ('mcmc',['Rscript','--vanilla',str(snapshot/r/names[0]),'mcmc']),
 ('extract',['Rscript','--vanilla',str(snapshot/r/names[2])]),
 ('check',[str(python),str(snapshot/r/names[3])])]
print(json.dumps(dict(snapshot=key,steps=[n for n,_ in steps],production_qualified=False)),flush=True)
for name,command in steps:
 record=r/f'evidence/production_scale_{name}_resources.json';attempt=1
 while record.exists() or (r/f'artifacts/production_scale_{name}_attempt{attempt}.log').exists():
  attempt+=1;record=r/f'evidence/production_scale_{name}_attempt{attempt}_resources.json'
 code=subprocess.call([sys.executable,str(r/'run_process.py'),'--record',str(record),'--log',str(r/f'artifacts/production_scale_{name}_attempt{attempt}.log'),'--max-seconds','900','--max-cgroup-anon-bytes','6400000000',*command],env=env)
 if code:raise SystemExit(code)
