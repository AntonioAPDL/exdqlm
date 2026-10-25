"""Full chronological fold preparation through the original verified builder."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
from large_job import single_large_job
p=argparse.ArgumentParser();p.add_argument('cutoff',type=int,choices=[1500,2000]);p.add_argument('--preflight',action='store_true');a=p.parse_args()
repository=Path.cwd().resolve();r=Path('validation/autodesn/remediation');builder=(r/'artifacts/frozen_bank_builder').resolve()
original=json.loads((builder/'source_manifest.json').read_text())
assert original['revision']=='fea371fbfa73c425a6f98407095194c1e8098a24'
for path,sha in original['files'].items():assert hashlib.sha256((builder/path).read_bytes()).hexdigest()==sha
for path in ['validation/autodesn/nonlinear_heteroscedastic/input/specifications.rds',str(r/'artifacts/prefix_reference_maps/maps.rds')]:assert Path(path).is_file(),path
files=list(Path('R').glob('*.R'))+[r/'prefix_bank.R',r/'prepare_prefix_bank.R',Path(__file__).resolve().relative_to(repository)]
manifest={str(q):hashlib.sha256(q.read_bytes()).hexdigest() for q in files};manifest['original_builder_manifest_sha256']=hashlib.sha256((builder/'source_manifest.json').read_bytes()).hexdigest()
manifest['specifications_sha256']=hashlib.sha256(Path('validation/autodesn/nonlinear_heteroscedastic/input/specifications.rds').read_bytes()).hexdigest()
manifest['frozen_configuration_sha256']=hashlib.sha256(Path('validation/autodesn/nonlinear_heteroscedastic/configuration.json').read_bytes()).hexdigest()
manifest['static_reference_maps_sha256']=hashlib.sha256((r/'artifacts/prefix_reference_maps/maps.rds').read_bytes()).hexdigest()
key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=r/'artifacts/full_prefix_sources'/key
for q in files:
 target=snapshot/q;target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest[str(q)]
 else:shutil.copyfile(q,target);target.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
out=(r/'artifacts/prefix_banks'/f'cutoff{a.cutoff}_{key}').resolve()
registration=dict(complete_preflight=True,cutoff=a.cutoff,source_snapshot=key,output=str(out),original_builder_revision=original['revision'],full_bank_executed=False,posterior_qualified=False)
if a.preflight:
 (r/'evidence'/f'prefix_bank_{a.cutoff}_preflight.json').write_text(json.dumps(registration,indent=2)+'\n');print(json.dumps(registration));raise SystemExit(0)
attempt=1;record=r/'evidence'/f'prefix_bank_{a.cutoff}_resources.json'
while record.exists():
 attempt+=1;record=r/'evidence'/f'prefix_bank_{a.cutoff}_attempt{attempt}_resources.json'
with single_large_job(r,f'Full prefix preparation {a.cutoff}'):
 cmd=[sys.executable,str((r/'run_process.py').resolve()),'--record',str(record.resolve()),'--log',str((r/'artifacts'/f'prefix_bank_{a.cutoff}_attempt{attempt}.log').resolve()),'--max-seconds','1800','--max-cgroup-anon-bytes','6400000000','Rscript','--vanilla',str((snapshot/r/'prepare_prefix_bank.R').resolve()),str(a.cutoff),str(snapshot.resolve()),str(repository),str(out)]
 raise SystemExit(subprocess.call(cmd,cwd=builder,env=os.environ.copy()))
