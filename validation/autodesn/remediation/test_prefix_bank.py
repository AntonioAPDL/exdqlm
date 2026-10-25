"""Small causal fold-build check using the verified original builder files."""
import hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
r=Path('validation/autodesn/remediation').resolve();builder=r/'artifacts/frozen_bank_builder'
frozen=json.loads((builder/'source_manifest.json').read_text())
assert frozen['revision']=='fea371fbfa73c425a6f98407095194c1e8098a24'
for path,sha in frozen['files'].items():assert hashlib.sha256((builder/path).read_bytes()).hexdigest()==sha
files=[r/'prefix_bank.R',r/'test_prefix_bank.R',Path(__file__).resolve(),Path('R/qdesn_normal.R').resolve()]
manifest={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
manifest['original_builder_manifest_sha256']=hashlib.sha256((builder/'source_manifest.json').read_bytes()).hexdigest()
key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=r/'artifacts/prefix_sources'/key
snapshot.mkdir(parents=True,exist_ok=True)
for p in files:
 q=snapshot/p.name
 if q.exists():assert hashlib.sha256(q.read_bytes()).hexdigest()==manifest[p.name]
 else:shutil.copyfile(p,q);q.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
out=r/'artifacts/prefix_fold_fixture'/key;assert not out.exists(),'Preserve executed fixtures'
attempt=1;record=r/'evidence/prefix_fold_fixture_resources.json'
while record.exists() or (r/f'artifacts/prefix_fold_fixture_attempt{attempt}.log').exists():
 attempt+=1;record=r/f'evidence/prefix_fold_fixture_attempt{attempt}_resources.json'
cmd=[sys.executable,str(r/'run_process.py'),'--record',str(record),'--log',str(r/f'artifacts/prefix_fold_fixture_attempt{attempt}.log'),'--max-seconds','300','--max-cgroup-anon-bytes','6400000000','Rscript','--vanilla',str(snapshot/'test_prefix_bank.R'),str(snapshot/'prefix_bank.R'),str(out),str(snapshot/'qdesn_normal.R')]
(r/f'evidence/prefix_fold_fixture_attempt{attempt}_sources.json').write_text(json.dumps(dict(snapshot=str(snapshot),source_hashes=manifest,registered_before_execution=True,production_qualified=False),indent=2)+'\n')
code=subprocess.call(cmd,cwd=builder,env=os.environ.copy())
if code==0:
 result=json.loads((out/'result.json').read_text());result['source_snapshot']=key
 (r/'evidence/prefix_fold_fixture.json').write_text(json.dumps(result,indent=2)+'\n')
raise SystemExit(code)
