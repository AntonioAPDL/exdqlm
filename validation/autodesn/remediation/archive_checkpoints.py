"""Versioned bank-free numerical checkpoints with part and internal SHA256."""
import argparse,hashlib,json,zipfile
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
for pattern in ['sbc_*/*.rds','sbc_*/*.csv','gp_n*/*','source_snapshots/*/manifest.json','source_snapshots/*/R/*.R','source_snapshots/*/src/*.cpp','source_snapshots/*/validation/autodesn/remediation/*.R','gp_drivers/*/*',
                'sbc_sources/**/*','sv_reference_sources/**/*','reference_sources/**/*','legacy_sbc_source/**/*','drivers/*.R',
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
archive=Path(str(base)+'.zip');members=[]
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for f in sorted(files):
  content=f.read_bytes();z.writestr(str(f),content);members.append(dict(path=str(f),bytes=len(content),sha256=hashlib.sha256(content).hexdigest()))
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 for member in members:assert hashlib.sha256(z.read(member['path'])).hexdigest()==member['sha256']
content=archive.read_bytes();parts=[]
for i,offset in enumerate(range(0,len(content),600000),1):
 chunk=content[offset:offset+600000];part=Path(str(base)+f'.zip.part-{i:03}');part.write_bytes(chunk);parts.append(dict(path=str(part),bytes=len(chunk),sha256=hashlib.sha256(chunk).hexdigest()))
new_paths={r['path'] for r in members}
manifest=dict(label=a.label,archive_sha256=hashlib.sha256(content).hexdigest(),archive_bytes=len(content),parts=parts,members=members,inherited_members=[r for path,r in previous.items() if path not in new_paths],parent_manifest=parent,scope='Bank-free verified completed chains and atomic calibration cases, full recorded source snapshots and completed/interrupted native stages; partial experiments remain partial. Delta archives require their checksum-verified parent.',posterior_qualified=False)
Path(str(base)+'.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');archive.unlink();print(json.dumps(dict(bytes=len(content),members=len(members),parts=len(parts),manifest=str(base)+'.manifest.json')))
