"""Observed immutable launch for the complete small depth-two grammar check."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
from large_job import single_large_job
p=argparse.ArgumentParser()
for name in ['julia','project','depot']:p.add_argument('--'+name,type=Path,required=True)
a=p.parse_args();r=Path('validation/autodesn/remediation');source=r/'test_gp_composite_reference.jl'
sha=hashlib.sha256(source.read_bytes()).hexdigest();snapshot=r/'artifacts/gp_reference_sources'/sha
snapshot.mkdir(parents=True,exist_ok=True);target=snapshot/source.name
if not target.exists():shutil.copyfile(source,target);target.chmod(0o444)
assert hashlib.sha256(target.read_bytes()).hexdigest()==sha
(snapshot/'manifest.json').write_text(json.dumps({str(source):sha},indent=2)+'\n')
assert not (r/'evidence/gp_composite_reference.toml').exists(),'Preserve completed evidence'
record=r/'evidence/gp_composite_reference_resources.json';attempt=1
while record.exists() or (r/f'artifacts/gp_composite_reference_attempt{attempt}.log').exists():
 attempt+=1;record=r/f'evidence/gp_composite_reference_attempt{attempt}_resources.json'
env=os.environ.copy();env.pop('LD_LIBRARY_PATH',None)
env.update(JULIA_DEPOT_PATH=str(a.depot.resolve()),JULIA_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1')
command=[sys.executable,str(r/'run_process.py'),'--record',str(record),'--log',str(r/f'artifacts/gp_composite_reference_attempt{attempt}.log'),'--max-seconds','300','--max-cgroup-anon-bytes','3000000000',str(a.julia.resolve()),'--startup-file=no','--project='+str(a.project.resolve()),str(target)]
(r/f'evidence/gp_composite_reference_attempt{attempt}_sources.json').write_text(json.dumps(dict(source=str(source),snapshot=str(target),sha256=sha,launcher_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),registered_before_execution=True,production_qualified=False),indent=2)+'\n')
with single_large_job(r,'small complete GP composite reference'):
 print(json.dumps(dict(source_sha256=sha,attempt=attempt,scope='Finite conditional reference, not production qualification')),flush=True)
 raise SystemExit(subprocess.call(command,env=env))
