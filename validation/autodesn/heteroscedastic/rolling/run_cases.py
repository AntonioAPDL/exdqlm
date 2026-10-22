"""Bounded-memory independent R case workers; safe to resume checkpoints."""
from pathlib import Path
import subprocess,os,time,csv,sys
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(os.getenv('AUTODESN_ROLLING_OUT',str(ROOT/'validation/autodesn/heteroscedastic/rolling/artifacts'))).resolve()
R=os.getenv('AUTODESN_RSCRIPT','Rscript')
WORKERS=int(os.getenv('AUTODESN_CASE_WORKERS','2'))
env=os.environ.copy()
env.update({'OPENBLAS_NUM_THREADS':'1','OMP_NUM_THREADS':'1','MKL_NUM_THREADS':'1','AUTODESN_ROLLING_OUT':str(OUT)})
with (OUT/'cases.csv').open() as f: cases=list(csv.DictReader(f))
pending=[c for c in cases if not (OUT/f'{c["dgp"]}_r{int(c["repetition"]):02d}'/'complete.json').exists()]
running=[];failed=[]
while pending or running:
    while pending and len(running)<WORKERS:
        c=pending.pop(0);ident=f'{c["dgp"]}_r{int(c["repetition"]):02d}'
        log=(OUT/f'{ident}.log').open('a',buffering=1)
        p=subprocess.Popen([R,'validation/autodesn/heteroscedastic/rolling/run_case.R',c['dgp'],c['repetition']],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        running.append((ident,p,log));print(f'Started {ident}',flush=True)
    still=[]
    for ident,p,log in running:
        status=p.poll()
        if status is None:still.append((ident,p,log))
        else:
            log.close();print(f'Finished {ident}: exit {status}',flush=True)
            if status!=0:failed.append((ident,status))
    running=still
    if pending or running:time.sleep(2)
if failed:raise SystemExit(f'Failed cases: {failed}; checkpoints retained for resume.')
print('All nine rolling cases complete.',flush=True)
