"""Freeze the complete proposal-training R sources before launching a trainer."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('family',choices=['F1','F2','F2flat']);p.add_argument('phase');p.add_argument('output');p.add_argument('--coordinates',type=int);a=p.parse_args()
root=Path('validation/autodesn/remediation');driver=root/'train_local_proposal.R'
files=sorted(Path('R').glob('*.R'))+[driver,root/'launch_local_training.py',root/'run_process.py']
assert all(not f.is_absolute() for f in files)
manifest={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files};key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();snapshot=root/'artifacts/proposal_sources'/key
for f in files:
 target=snapshot/f;target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest[str(f)]
 else:shutil.copyfile(f,target);target.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
record=root/'evidence'/f'{a.family}_{a.output}_training_resources.json';assert not record.exists()
env=os.environ.copy();env['AUTODESN_PROPOSAL_SOURCE_SNAPSHOT']=str(snapshot.resolve())
cmd=[sys.executable,str(root/'run_process.py'),'--record',str(record),'--log',str(root/'artifacts'/f'{a.family}_{a.output}_training.log'),'--max-seconds','300','--max-cgroup-anon-bytes','6100000000','Rscript','--vanilla',str(snapshot/driver),a.family,a.phase,a.output]
if a.coordinates is not None:
 assert a.coordinates>0;cmd.append(str(a.coordinates))
print(json.dumps(dict(snapshot=key,family=a.family,source_phase=a.phase,output=a.output,maximum_kernel_coordinates=a.coordinates)),flush=True)
raise SystemExit(subprocess.call(cmd,env=env))
