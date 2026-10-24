"""Restore checksum-verified audit evidence, optionally rerun aggregation."""
from pathlib import Path,PurePosixPath
import argparse,hashlib,json,subprocess,sys,zipfile
HERE=Path(__file__).resolve().parent
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=HERE/'restored');p.add_argument('--verify-reanalysis',action='store_true');a=p.parse_args()
 spec=json.loads((HERE/'audit_manifest.json').read_text());archive=HERE/spec['archive']
 if not archive.exists() or digest(archive)!=spec['sha256']:
  temporary=archive.with_suffix('.assembling')
  with temporary.open('wb') as out:
   for part in spec['parts']:
    q=HERE/part['path'];assert q.stat().st_size==part['bytes'] and digest(q)==part['sha256'],q
    out.write(q.read_bytes())
  assert digest(temporary)==spec['sha256'];temporary.replace(archive)
 assert archive.stat().st_size==spec['bytes'] and digest(archive)==spec['sha256']
 a.output.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  contents=json.loads(z.read('CONTENTS_SHA256.json'))
  assert len(contents)==spec['members']
  assert set(z.namelist())==set(contents)|{'CONTENTS_SHA256.json'}
  for rel,item in contents.items():
   path=PurePosixPath(rel);assert not path.is_absolute() and '..' not in path.parts
   data=z.read(rel);assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256'],rel
   target=a.output/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
 if a.verify_reanalysis:
  names=['pooled_comparison.csv','horizon_comparison.csv','conditional_risk.csv','simple_baselines.csv','mean_variance_ablation.csv','residual_dependence.csv','periodogram_peaks.csv','native_gp_kernel_audit.json','analysis_status.json']
  before={name:digest(a.output/name) for name in names}
  subprocess.run([sys.executable,str(HERE.parent/'analyze.py'),'--data',str(a.output)],check=True)
  for name in names:assert before[name]==digest(a.output/name),name
 result=dict(complete=True,archive_sha256=spec['sha256'],verified_members=len(contents),reanalysis_verified=a.verify_reanalysis,byte_identical_recomputed_summaries=9 if a.verify_reanalysis else 0)
 (HERE/'restore_validation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
