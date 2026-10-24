"""Package executed audit outputs; do not rerun numerical experiments."""
from pathlib import Path
import hashlib,json,platform,re,shutil,subprocess,sys,zipfile
import numpy,pandas,scipy

HERE=Path(__file__).resolve().parent
DATA=HERE/'artifacts';EVIDENCE=HERE/'evidence'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
 EVIDENCE.mkdir(exist_ok=True)
 shutil.copyfile(HERE.parent/'artifacts/comparison/all_scores.csv.gz',DATA/'benchmark_scores.csv.gz')
 for run in (1,2):shutil.copyfile(HERE.parent/f'artifacts/gp/run_{run}/particles.csv',DATA/f'native_run{run}_particles.csv')
 source_hashes={str(p.relative_to(HERE)):digest(p) for p in sorted(HERE.iterdir()) if p.is_file() and p.suffix in ('.py','.R','.jl','.md','.json')}
 source_hashes['evidence/restore_audit.py']=digest(EVIDENCE/'restore_audit.py')
 provenance=dict(original_benchmark_commit='e726533322bb5625a995dc78ac6cbd09d4dcb977',python=sys.version,platform=platform.platform(),numpy=numpy.__version__,pandas=pandas.__version__,scipy=scipy.__version__,source_sha256=source_hashes,truth_sha256=digest(HERE.parent/'input/dgp_truth.csv'),report_sha256=digest(EVIDENCE/'NHS1_Diagnostic_Audit.pdf'),executed_validation=json.loads((DATA/'audit_validation.json').read_text()),report_validation=json.loads((DATA/'validation/report_validation.json').read_text()),interpretation='Post-hoc diagnostic of one DGP realization. New GP fits and lag references are plug-ins, not replacement Bayesian posterior fits.')
 (DATA/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
 files={}
 for p in sorted(DATA.rglob('*')):
  rel=str(p.relative_to(DATA))
  if not p.is_file() or p.suffix=='.png' or 'report_render' in p.parts or re.fullmatch(r'(?:oracle|half)_\d+\.csv',p.name) or p.name=='initial_render_hashes.json':continue
  files[rel]=p
 for p in sorted(HERE.glob('*.log')):files['logs/'+p.name]=p
 manifest={k:dict(bytes=p.stat().st_size,sha256=digest(p)) for k,p in files.items()}
 archive=EVIDENCE/'Audit_numeric_evidence.zip'
 with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for rel,p in files.items():z.write(p,rel)
  z.writestr('CONTENTS_SHA256.json',json.dumps(manifest,indent=2)+'\n')
 parts=[]
 with archive.open('rb') as f:
  i=0
  while block:=f.read(7_000_000):
   i+=1;p=EVIDENCE/f'Audit_numeric_evidence.zip.part{i:03d}';p.write_bytes(block);parts.append(dict(path=p.name,bytes=len(block),sha256=digest(p)))
 result=dict(archive=archive.name,bytes=archive.stat().st_size,sha256=digest(archive),parts=parts,members=len(manifest),provenance=provenance)
 (EVIDENCE/'audit_manifest.json').write_text(json.dumps(result,indent=2)+'\n')
 summary={name:json.loads((DATA/name).read_text()) for name in ['analysis_status.json','audit_validation.json','capacity_status.json','gp_audit_status.json','quasiperiodic_gp_status.json','validation/report_validation.json']}
 (EVIDENCE/'audit_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
 print(json.dumps({k:v for k,v in result.items() if k!='provenance'},indent=2))
if __name__=='__main__':main()
