"""Versioned bank-free numerical checkpoints with part and internal SHA256."""
import argparse,hashlib,io,json,os,zipfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('label');p.add_argument('--previous',type=Path,help='Verified parent manifest; unchanged members are inherited, never duplicated');p.add_argument('--skip-live-progress',action='store_true',help='Inherit earlier canonical progress; separately capture immutable advancing-state copies with capture_running_checkpoints.R');p.add_argument('--skip-live-observations',action='store_true',help='Inherit earlier observations without adding redundant intermediate copies; completed canonical fits are still archived');a=p.parse_args()
root=Path('validation/autodesn/remediation');out=root/'evidence'/'checkpoints';out.mkdir(parents=True,exist_ok=True);base=out/a.label
assert not Path(str(base)+'.manifest.json').exists(),'A checkpoint archive label is immutable'
files=set();skipped_live_progress=[]
for family in ['F1','F2','SV','F2flat','SVseasonal','F1ridge','F2ridge']:
 family_dir=root/'artifacts'/family
 for config in family_dir.glob('*/configuration.json'):
  files.add(config)
  for name in ['contract.rds','model_metadata.csv','status.json']:
   if (config.parent/name).exists():files.add(config.parent/name)
  files.update(config.parent.glob('invocation_*.json'))
 for st in family_dir.glob('*/chain_*_status.json'):
  if st.name.endswith('_progress_status.json'):continue
  status=json.loads(st.read_text());assert status['complete'];k=status['chain'];d=st.parent
  cp=d/f'chain_{k}.rds';assert hashlib.sha256(cp.read_bytes()).hexdigest()==status['checkpoint_sha256']
  files.update([st,cp,d/f'trace_{k}.csv',d/'contract.rds',d/'configuration.json'])
  for name in ['status.json','independent_diagnostics.csv','qualification.json','model_metadata.csv']:
   if (d/name).exists():files.add(d/name)
  files.update(d.glob('invocation_*.json'))
 for st in family_dir.glob('*/chain_*_progress_status.json'):
  status=json.loads(st.read_text());assert not status['complete'] and status['paused'];d=st.parent
  final=d/f'chain_{status["chain"]}_status.json'
  if final.exists() and json.loads(final.read_text()).get('complete'):
   # The verified final fit above supersedes a last-pause marker. Its live
   # continuation file is redundant and may have advanced beyond that marker.
   continue
  if a.skip_live_progress:
   skipped_live_progress.append(str(st));continue
  cp=d/f'chain_{status["chain"]}_progress.rds'
  assert hashlib.sha256(cp.read_bytes()).hexdigest()==status['checkpoint_sha256'],'Only archive a quiescent, verified pause; a running checkpoint is not immutable'
  files.update([st,cp])
 for name in ['frozen_proposal.rds','frozen_local_proposal.rds']:
  if (family_dir/name).exists():files.add(family_dir/name)
 files.update(family_dir.glob('frozen_local_proposal_*.rds'));files.update(family_dir.glob('frozen_proposal_*.rds'))
for pattern in ['sbc_*/*.rds','sbc_*/*.csv','gp_n*/*','source_snapshots/*/manifest.json','source_snapshots/*/R/*.R','source_snapshots/*/src/*.cpp','source_snapshots/*/validation/autodesn/remediation/*.R','source_snapshots/*/validation/autodesn/remediation/*.json','gp_drivers/*/*',
                'sbc_sources/**/*','recursive_sbc_sources/**/*','sv_reference_sources/**/*','reference_sources/**/*','gp_sources/**/*','gp_reference_sources/**/*','legacy_sbc_source/**/*','drivers/*.R',
                'recursive_sbc_*/*.rds','recursive_sbc_*/*.csv','recursive_sbc_*/*.json',
                'grouped_reference/*','local_reference/*','local_joint_reference/*','local_partial_reference/*','sv_joint_reference/*','gp_leaf_reference/*','gp_composite_reference/*','*_reference_fixture.json',
                'proposal_sources/**/*','portable_test_sources/**/*','profile_full_bank/*','environment_recovery_prior_invocation/*',
                'checkpoint_process_sources/**/*','checkpoint_fresh_process/**/*',
                'prefix_sources/**/*','prefix_fold_fixture/**/*','capacity_sources/**/*','representation_capacity/**/*','live_chain_snapshots/**/*',
                'production_scale_sources/**/*','production_scale_reference/*',
                'fit_audit_sources/**/*','fit_audit_failures/**/*','common_monitor_sources/**/*','common_rhs_monitors/**/*',
                'remote_gp_runs/**/*','remote_gp_logs/**/*','remote_ci_logs/*',
                'gp_audit_sources/**/*','gp_training_audit16/*','gp_evidence_sources/**/*','gp_normalizer_sources/**/*',
                's3_doc_sources/**/*',
                'calendar_cache_sources/**/*','calendar_law_sources/**/*','calendar_checkpoint_sources/**/*','checkpoint_calendar_fresh_process/**/*','calendar_release_runs/**/*',
                'full_prefix_sources/**/*','prefix_reference_maps/*',
                'gp_cohort_evidence_sources/**/*','gp32_period0_cohort*/*',
                'prefix_banks/*/manifest.json','prefix_banks/*/raw_bank/*.csv','prefix_banks/*/raw_bank/status.json','prefix_banks/*/raw_bank/contract.rds',
                'prefix_banks/*/standardized_bank/*.csv','prefix_banks/*/standardized_bank/status.json','prefix_banks/*/standardized_bank/contract.rds',
                'calendar_cache_benchmark/fit_*.rds','calendar_cache_benchmark/dimensions.csv','calendar_cache_benchmark_lawvalidated/fit_*.rds','calendar_cache_benchmark_lawvalidated/dimensions.csv',
                '*_attempt*.log','gp_n*.log','gp_leaf_reference.log','checkpoint_fresh_process.log','grouped_reference.log','local_reference.log','local_joint_reference.log','local_partial_reference.log','sv_joint_mcmc.log']:
 if a.skip_live_observations and pattern.startswith('live_chain_snapshots/'):
  continue
 files.update(p for p in (root/'artifacts').glob(pattern) if p.is_file() and not p.name.endswith('.partial'))
for name in ['test_results.rds','statistics_cache_test_results.rds','checkpoint_test_results.rds','portable_installed_tests.rds','installed_tests.rds','legacy_test_results.rds','ci_fixture_repair_tests.rds','s3_api_test_results.rds','s3_api_installed_test_results.rds','gp_training_proposal.toml','F1_pilot.log','F2_pilot.log','sbc_rhs.log','gp_128_16.log','gp_512_16.log','gp_2000_16.log','inference_cache_manifest.json','forecast_templates.rds','frozen_bank_builder/source_manifest.json']:
 f=root/'artifacts'/name
 if f.exists():files.add(f)
for name in ['calendar_cache_test_results.rds','calendar_release_source_results.rds','calendar_release_installed_results.rds']:
 f=root/'artifacts'/name
 if f.exists():files.add(f)
for name in ['family_release_source_results.rds','family_release_installed_results.rds','variance_only_seasonality_results.rds']:
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
manifest=dict(label=a.label,archive_sha256=sink.digest.hexdigest(),archive_bytes=sink.position,parts=parts,members=members,inherited_members=[r for path,r in previous.items() if path not in new_paths],parent_manifest=parent,storage='Sequential multipart ZIP; fsync and atomic part publication; no monolithic intermediate archive',scope='Bank-free verified completed chains and atomic calibration cases, recorded source snapshots, immutable observations of incomplete advancing chains, and completed/interrupted native stages; partial experiments remain partial. Delta archives require their checksum-verified parent.',posterior_qualified=False)
manifest['canonical_progress_status_paths_inherited_without_live_read']=skipped_live_progress
manifest['new_live_observation_copies_omitted']=a.skip_live_observations
Path(str(base)+'.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(dict(bytes=len(content),members=len(members),parts=len(parts),manifest=str(base)+'.manifest.json')))
