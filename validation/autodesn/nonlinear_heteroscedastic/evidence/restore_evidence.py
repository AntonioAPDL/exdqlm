"""Reassemble, verify and extract the committed NHS1 evidence."""
from pathlib import Path
import hashlib,json,zipfile,gzip
root=Path(__file__).resolve().parent
# Large compressed predictive checkpoints use bounded-size Git objects too.
# Reassemble into a temporary file and verify before replacing any local copy.
checkpoint=root/'checkpoint_parts.json'
if checkpoint.exists():
 for item in json.loads(checkpoint.read_text())['files']:
  target=root/item['name']
  assert target.parent==root
  if item['mode']=='parts':
   temporary=target.with_name(target.name+'.restore-partial')
   with temporary.open('wb') as f:
    for part in item['parts']:
     data=(root/part['name']).read_bytes();assert len(data)==part['bytes']
     assert hashlib.sha256(data).hexdigest()==part['sha256'];f.write(data)
   assert temporary.stat().st_size==item['bytes']
   assert hashlib.sha256(temporary.read_bytes()).hexdigest()==item['sha256']
   temporary.replace(target)
   if temporary.exists():temporary.unlink()
  assert target.stat().st_size==item['bytes']
  assert hashlib.sha256(target.read_bytes()).hexdigest()==item['sha256']
 print('Verified',len(json.loads(checkpoint.read_text())['files']),'complete predictive checkpoints')
meta=json.loads((root/'archive_manifest.json').read_text())
archive=root/meta['archive']
with archive.open('wb') as f:
 for part in meta['parts']:
  b=(root/part['name']).read_bytes();assert len(b)==part['bytes']
  assert hashlib.sha256(b).hexdigest()==part['sha256'];f.write(b)
assert archive.stat().st_size==meta['archive_bytes']
assert hashlib.sha256(archive.read_bytes()).hexdigest()==meta['archive_sha256']
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 for name,expected in json.loads(z.read('SHA256.json')).items():assert hashlib.sha256(z.read(name)).hexdigest()==expected,name
 z.extractall(root/'restored')
for p in (root/'restored').rglob('*.csv.gz'):
 p.with_suffix('').write_bytes(gzip.decompress(p.read_bytes()))
print('Verified and restored',meta['numeric_files'],'numeric evidence files')
