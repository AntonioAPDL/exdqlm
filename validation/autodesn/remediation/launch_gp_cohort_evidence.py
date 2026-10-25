"""Immutable, identity-bound deterministic audit of four native SMC outputs."""
import argparse, hashlib, json, os, shutil, subprocess, sys
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument('run');p.add_argument('particles',type=int);p.add_argument('seeds')
p.add_argument('--period-moves',type=int,choices=[0,10],default=0)
p.add_argument('--julia',required=True);p.add_argument('--project',required=True);p.add_argument('--depot',required=True)
a=p.parse_args();r=Path('validation/autodesn/remediation')
files=[r/'gp_cohort_evidence.jl',r/'gp_evidence.jl',Path(__file__).resolve().relative_to(Path.cwd())]
manifest={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest()
snapshot=r/'artifacts/gp_cohort_evidence_sources'/key
for f in files:
 target=snapshot/f;target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest[str(f)]
 else:shutil.copyfile(f,target);target.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
label=f'gp{a.particles}_period{a.period_moves}_cohort_{a.run}'
output=r/'artifacts'/label
record=r/'evidence'/f'{label}_resources.json';attempt=1
while output.exists() or record.exists():
 attempt+=1;output=r/'artifacts'/f'{label}_attempt{attempt}'
 record=r/'evidence'/f'{label}_attempt{attempt}_resources.json'
env=dict(os.environ,JULIA_DEPOT_PATH=str(Path(a.depot).resolve()),JULIA_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1')
env.pop('LD_LIBRARY_PATH',None)
cmd=[sys.executable,str(r/'run_process.py'),'--record',str(record),'--log',str(r/'artifacts'/f'{label}_attempt{attempt}.log'),'--max-seconds','300','--max-cgroup-anon-bytes','6400000000',str(Path(a.julia).resolve()),'--startup-file=no','--project='+str(Path(a.project).resolve()),str(snapshot/r/'gp_cohort_evidence.jl'),a.run,str(a.particles),a.seeds,str(a.period_moves),str(output)]
raise SystemExit(subprocess.call(cmd,env=env))
