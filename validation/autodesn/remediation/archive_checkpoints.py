"""Versioned bank-free numerical checkpoints with part and internal SHA256."""
import argparse,hashlib,io,json,os,zipfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('label');p.add_argument('--previous',type=Path,help='Verified parent manifest; unchanged members are inherited, never duplicated');a=p.parse_args()
root=Path('validation/autodesn/remediation');out=root/'evidence'/'checkpoints';out.mkdir(parents=True,exist_ok=True);base=out/a.label
assert not Path(str(base)+'.manifest.json').exists(),'A checkpoint archive label is immutable'
files=set()
for family in ['F1','F2','SV','F2flat','SVseasonal','F1ridge','F2ridge']:
 family_dir=root/'artifacts'/family
 for st in family_dir.glob('*/chain_*_status.json'):
  status=json.loads(st.read_text());assert status['complete'];k=status['chain'];d=st.parent
  cp=d/f'chain_{k}.rds';assert hashlib.sha256(cp.read_bytes()).hexdigest()==status['checkpoint_sha256']
  files.update([st,cp,d/f'trace_{k}.csv',d/'contract.rds',d/'configuration.json'])
  for name in ['status.json','independent_diagnostics.csv','qualification.json','model_metadata.csv']:
   if (d/name).exists():files.add(d/name)
 for name in ['frozen_proposal.rds','frozen_local_proposal.rds']:
  if (family_dir/name).exists():files.add(family_dir/name)
 files.update(family_dir.glob('frozen_local_proposal_*.rds'));files.update(family_dir.glob('frozen_proposal_*.rds'))
for pattern in ['sbc_*/*.rds','sbc_*/*.csv','gp_n*/*','source_snapshots/*/manifest.json','source_snapshots/*/R/*.R','source_snapshots/*/src/*.cpp','source_snapshots/*/validation/autodesn/remediation/*.R','gp_drivers/*/*',
                'sbc_sources/**/*','recursive_sbc_sources/**/*','sv_reference_sources/**/*','reference_sources/**/*','legacy_sbc_source/**/*','drivers/*.R',
                'recursive_sbc_*/*.rds','recursive_sbc_*/*.csv','recursive_sbc_*/*.json',
                'grouped_reference/*','local_reference/*','sv_joint_reference/*','*_reference_fixture.json',
                '*_attempt*.log','grouped_reference.log','local_reference.log','sv_joint_mcmc.log']:
 files.update(p for p in (root/'artifacts').glob(pattern) if p.is_file() and not p.name.endswith('.partial'))
for name in ['test_results.rds','installed_tests.rds','legacy_test_results.rds','gp_training_proposal.toml','F1_pilot.log','F2_pilot.log','sbc_rhs.log','gp_128_16.log','gp_512_16.log','gp_2000_16.log','inference_cache_manifest.json','forecast_templates.rds']:
 f=root/'artifacts'/name
 if f.exists():files.add(f)
previous={};parent=None
if a.previous:
 old=json.loads(a.previous.read_text());previous={r['path']:r for r in old.get('inherited_members',[])+old['members']}
 parent=dict(path=str(a.previous),sha256=hashlib.sha256(a.previous.read_bytes()).hexdigest())
 candidates={str(f):dict(path=str(f),bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest()) for f in files}
 files={f for f in files if candidates[str(f)]!=previous.get(str(f))}
class MultipartSink(io.RawIOBase):
 def __init__(self):self.position=0;self.buffer=bytearray();self.parts=[];self.digest=hashlib.sha256()
 def writable(self):return True
 def seekable(self):return False
 def tell(self):return self.position
 def seek(self,*args):raise io.UnsupportedOperation('Sequential multipart archive')
 def flush_part(self):
  if not self.buffer:return
  content=bytes(self.buffer);self.buffer.clear();path=Path(str(base)+f'.zip.part-{len(self.parts)+1:03}');temporary=Path(str(path)+'.writing');assert not path.exists()
  with open(temporary,'xb') as f:f.write(content);f.flush();os.fsync(f.fileno())
  os.replace(temporary,path);self.parts.append(dict(path=str(path),bytes=len(content),sha256=hashlib.sha256(content).hexdigest()))
 def write(self,content):
  data=memoryview(content);self.digest.update(data);n=len(data);self.position+=n
  while len(data):
   count=min(600000-len(self.buffer),len(data));self.buffer.extend(data[:count]);data=data[count:]
   if len(self.buffer)==600000:self.flush_part()
  return n
 def finish(self):
  self.flush_part();fd=os.open(out,os.O_RDONLY);os.fsync(fd);os.close(fd)

assert not list(out.glob(a.label+'.zip.part-*')),'Preserve a partial attempt and choose a new archive label'
sink=MultipartSink();members=[]
with zipfile.ZipFile(sink,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for f in sorted(files):
  content=f.read_bytes();z.writestr(str(f),content);members.append(dict(path=str(f),bytes=len(content),sha256=hashlib.sha256(content).hexdigest()))
sink.finish();parts=sink.parts
# Verification reads the completed immutable blocks, not a seek-written large
# intermediate ZIP. A separate restore invocation checks fresh-process reads.
content=b''.join(Path(part['path']).read_bytes() for part in parts)
assert len(content)==sink.position and hashlib.sha256(content).hexdigest()==sink.digest.hexdigest()
with zipfile.ZipFile(io.BytesIO(content)) as z:
 assert z.testzip() is None
 for member in members:assert hashlib.sha256(z.read(member['path'])).hexdigest()==member['sha256']
new_paths={r['path'] for r in members}
manifest=dict(label=a.label,archive_sha256=sink.digest.hexdigest(),archive_bytes=sink.position,parts=parts,members=members,inherited_members=[r for path,r in previous.items() if path not in new_paths],parent_manifest=parent,storage='Sequential multipart ZIP; fsync and atomic part publication; no monolithic intermediate archive',scope='Bank-free verified completed chains and atomic calibration cases, full recorded source snapshots and completed/interrupted native stages; partial experiments remain partial. Delta archives require their checksum-verified parent.',posterior_qualified=False)
Path(str(base)+'.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(dict(bytes=len(content),members=len(members),parts=len(parts),manifest=str(base)+'.manifest.json')))
