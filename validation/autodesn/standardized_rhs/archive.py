"""Bundle auditable numeric evidence, excluding reconstructible large designs."""
import gzip,hashlib,io,json,zipfile
from pathlib import Path
HERE=Path(__file__).resolve().parent
base=HERE/'artifacts';out=HERE/'evidence';out.mkdir(exist_ok=True)
manifest={}
def sha(b):return hashlib.sha256(b).hexdigest()
archive=out/'Standardized_C1_numeric_evidence.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 def add(name,b):z.writestr(name,b);manifest[name]=sha(b)
 for p in sorted(base.rglob('*')):
  if not p.is_file():continue
  rel=p.relative_to(base);parts=rel.parts
  if 'cpp_cache' in parts or 'parts' in parts:continue
  if p.suffix=='.rds' and not p.name in ['contract.rds','chain_metadata.rds','pilot_metadata.rds']:continue
  if p.name in ['all_scores.csv.gz'] or 'figures' in parts:continue
  if p.suffix not in ['.json','.csv','.gz','.log','.txt','.rds']:continue
  data=p.read_bytes();name=str(rel)
  if p.suffix=='.csv':name+='.gz';data=gzip.compress(data,mtime=0)
  add(name,data)
 add('SHA256.json',json.dumps(manifest,indent=2,sort_keys=True).encode())
whole=archive.read_bytes();partbytes=7_000_000;parts=[]
for i,start in enumerate(range(0,len(whole),partbytes),1):
 p=out/f'{archive.name}.part-{i:02}';b=whole[start:start+partbytes];p.write_bytes(b)
 parts.append(dict(name=p.name,bytes=len(b),sha256=sha(b)))
(out/'archive_manifest.json').write_text(json.dumps(dict(archive=archive.name,archive_bytes=len(whole),archive_sha256=sha(whole),parts=parts,numeric_files=len(manifest)-1),indent=2))
print('Archived',len(manifest)-1,'numeric files;',len(whole),'bytes;',len(parts),'parts')
