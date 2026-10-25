"""Reclaim duplicate working copies only after exact committed-Git verification.

The immutable blobs remain in the fetched repository and remote feature branch.
restore_checkpoints.py reads missing parts with raw git cat-file and verifies SHA.
"""
import argparse, hashlib, json, os, subprocess
from pathlib import Path
from restore_checkpoints import restore

p=argparse.ArgumentParser();p.add_argument('manifests',nargs='+',type=Path);a=p.parse_args()
root=Path('validation/autodesn/remediation');head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
tree=subprocess.check_output(['git','ls-tree','-r',head],text=True)
blobs={line.split('\t',1)[1]:line.split()[2] for line in tree.splitlines()};parts={}
for manifest in a.manifests:
 restore(manifest,git_ref=head)
 for part in json.loads(manifest.read_text())['parts']:parts[part['path']]=part
paths=[];bytes_=0
for name,part in parts.items():
 path=Path(name);assert path.parent==root/'evidence/checkpoints' and '.zip.part-' in path.name
 if not path.exists():continue
 b=path.read_bytes();assert hashlib.sha256(b).hexdigest()==part['sha256']
 sha=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest();assert blobs.get(name)==sha
 assert subprocess.check_output(['git','cat-file','blob',f'{head}:{name}'])==b
 paths.append(name);bytes_+=len(b)
if paths:
 subprocess.run(['git','update-index','-z','--skip-worktree','--stdin'],input=('\0'.join(paths)+'\0').encode(),check=True)
 for name in paths:Path(name).unlink()
record=dict(complete=True,commit=head,working_copies_removed=len(paths),bytes_reclaimed=bytes_,manifests=[str(m) for m in a.manifests],restoration='restore_checkpoints.py reads omitted parts directly from the same local Git blobs; remote committed checkpoint content unchanged')
(root/'evidence/working_archive_compaction.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record))
