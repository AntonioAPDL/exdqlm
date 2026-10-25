"""Content-addressed, immutable source launch; checkpoints never share a live driver."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
from large_job import single_large_job
p=argparse.ArgumentParser();p.add_argument('family',choices=['F1','F2','SV','F2flat','SVseasonal','F1ridge','F2ridge']);p.add_argument('phase',choices=['pilot','production']);p.add_argument('budget',type=int,nargs='?',default=32000);p.add_argument('--workers',type=int,choices=[1,2,4],default=1);p.add_argument('--snapshot',help='Existing immutable snapshot key, required to resume its contract');p.add_argument('--cache',action='store_true');p.add_argument('--run-label',default='');p.add_argument('--chains',default='1,2,3,4');p.add_argument('--local-proposal',default='',help='Frozen training-only optional exact local proposal checkpoint');p.add_argument('--global-proposal',default='',help='Frozen scale/model/period proposal checkpoint');p.add_argument('--statistics-cache',default='',help='Frozen exact unweighted design-statistics cache; does not change the target');p.add_argument('--local-scales',action='store_true',help='Jointly propose scales and reservoir locals with exact corrections')
p.add_argument('--checkpoint-every',type=int,default=0,help='Positive sweep interval for exact within-chain recovery; zero disables')
p.add_argument('--stop-after-sweeps',type=int,help='Bounded absolute checkpoint sweep; not a completed fit')
p.add_argument('--prefix-manifest',default='',help='Verified chronological-prefix bank manifest; never reuse final-origin proposals')
p.add_argument('--mean-selection',default='',help='Frozen qualified two-fold mean-selection certificate required for SV')
p.add_argument('--input-preflight',default='',help='Fresh JSON output for input validation only; no inference or qualification')
a=p.parse_args()
assert a.checkpoint_every>=0
assert a.stop_after_sweeps is None or (a.checkpoint_every>0 and a.stop_after_sweeps>0)
root=Path('validation/autodesn/remediation');files=sorted(Path('R').glob('*.R'))+[Path('src/autodesn_rhs.cpp'),Path('src/RcppExports.cpp'),root/'fit.R',root/'fit_inputs.R',root/'development_registry.json']
if a.snapshot:
 key=a.snapshot;snapshot=root/'artifacts'/'source_snapshots'/key
 manifest=json.loads((snapshot/'manifest.json').read_text())
 for path,sha in manifest.items():assert hashlib.sha256((snapshot/path).read_bytes()).hexdigest()==sha
else:
 manifest={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files};key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=root/'artifacts'/'source_snapshots'/key
 for f in files:
  target=snapshot/f;target.parent.mkdir(parents=True,exist_ok=True)
  if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest[str(f)]
  else:shutil.copyfile(f,target);target.chmod(0o444)
 (snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
env=os.environ.copy();env['AUTODESN_SOURCE_SNAPSHOT']=str(snapshot.resolve());env['AUTODESN_CHAIN_WORKERS']=str(a.workers);env['AUTODESN_INFERENCE_CACHE']='1' if a.cache else '0';env['AUTODESN_RUN_LABEL']=a.run_label;env['AUTODESN_CHAINS']=a.chains
env['AUTODESN_STATISTICS_CACHE']=a.statistics_cache
run_root=root/'artifacts'
env['AUTODESN_PREFIX_MANIFEST']=a.prefix_manifest
env['AUTODESN_MEAN_SELECTION']=a.mean_selection
env['AUTODESN_INPUT_PREFLIGHT']=a.input_preflight
if a.prefix_manifest:
 data=json.loads(Path(a.prefix_manifest).read_text());assert data['complete'] and data['cutoff'] in (1500,2000)
 run_root=root/'artifacts/fold_fits'/f'cutoff{data["cutoff"]}'
 env['AUTODESN_PREFIX_MANIFEST']=a.prefix_manifest
 env['AUTODESN_INFERENCE_CACHE']='1'
 env['AUTODESN_RUN_ROOT']=str(run_root)
if a.mean_selection:env['AUTODESN_MEAN_SELECTION']=a.mean_selection
if a.input_preflight:env['AUTODESN_INPUT_PREFLIGHT']=a.input_preflight
env['AUTODESN_RUN_ROOT']=str(run_root)
if a.prefix_manifest or a.mean_selection or a.input_preflight:assert 'fit_inputs.R' in (snapshot/root/'fit.R').read_text()
env['AUTODESN_CHECKPOINT_EVERY']=str(a.checkpoint_every)
env['AUTODESN_CHECKPOINT_STOP_AFTER']=str(a.stop_after_sweeps) if a.stop_after_sweeps is not None else 'Inf'
if a.checkpoint_every:assert 'AUTODESN_CHECKPOINT_EVERY' in (snapshot/root/'fit.R').read_text()
env['AUTODESN_LOCAL_PROPOSAL']=a.local_proposal
env['AUTODESN_FROZEN_PROPOSAL']=a.global_proposal;env['AUTODESN_LOCAL_SCALE_PROPOSAL']='1' if a.local_scales else '0'
if a.local_proposal:assert 'AUTODESN_LOCAL_PROPOSAL' in (snapshot/root/'fit.R').read_text()
if a.global_proposal:assert 'AUTODESN_FROZEN_PROPOSAL' in (snapshot/root/'fit.R').read_text()
if a.local_scales:assert a.local_proposal and 'AUTODESN_LOCAL_SCALE_PROPOSAL' in (snapshot/root/'fit.R').read_text()
if a.statistics_cache:assert 'AUTODESN_STATISTICS_CACHE' in (snapshot/root/'fit.R').read_text()
if a.cache:assert 'AUTODESN_INFERENCE_CACHE' in (snapshot/root/'fit.R').read_text()
label=(f'fold{data["cutoff"]}_' if a.prefix_manifest else '')+f'{a.family}_{a.phase}_{a.budget}'+('_'+a.run_label if a.run_label else '')
if a.input_preflight:label+='_input_preflight'
invocation=run_root/a.family/('pilot' if a.phase=='pilot' else f'production_{a.budget}'+('_'+a.run_label if a.run_label else ''))
record=root/'evidence'/f'{label}_resources.json';attempt=1
while record.exists() or (invocation/f'invocation_{attempt}.json').exists():
 attempt+=1;record=root/'evidence'/f'{label}_attempt{attempt}_resources.json'
invocation_data=dict(snapshot=key,workers=a.workers,cache=a.cache,statistics_cache=a.statistics_cache,checkpoint_every=a.checkpoint_every,stop_after_sweeps=a.stop_after_sweeps,chains=a.chains,local_proposal=a.local_proposal,global_proposal=a.global_proposal,local_scales=a.local_scales,launcher_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),resource_runner_sha256=hashlib.sha256((root/'run_process.py').read_bytes()).hexdigest())
invocation_data.update(prefix_manifest=a.prefix_manifest,mean_selection=a.mean_selection,input_preflight_only=bool(a.input_preflight))
command=[sys.executable,str(root/'run_process.py'),'--record',str(record),'--log',str(root/'artifacts'/f'{label}_attempt{attempt}.log'),'--max-seconds','7200','--max-cgroup-anon-bytes','6400000000','Rscript','--vanilla',str(snapshot/root/'fit.R'),a.family,a.phase,str(a.budget)]
if a.input_preflight:
 assert not Path(a.input_preflight).exists()
 # Read-only bounded input audit, like the independent numerical references;
 # the large-job reservation continues to exclude simultaneous full fits.
 raise SystemExit(subprocess.call(command,env=env))
with single_large_job(root,f'{a.family} {a.phase} {a.budget}'):
 invocation.mkdir(parents=True,exist_ok=True)
 (invocation/f'invocation_{attempt}.json').write_text(json.dumps(invocation_data,indent=2)+'\n')
 print(json.dumps(dict(snapshot=key,workers=a.workers,family=a.family,phase=a.phase,budget=a.budget)),flush=True)
 raise SystemExit(subprocess.call(command,env=env))
