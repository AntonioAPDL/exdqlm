"""Reassemble, verify and extract the committed standardized C1 evidence."""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parent;meta=json.loads((root/'archive_manifest.json').read_text())
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
print('Verified and restored',meta['numeric_files'],'numeric evidence files')
