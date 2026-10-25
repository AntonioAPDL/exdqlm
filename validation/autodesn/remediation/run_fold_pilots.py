"""Foreground, bounded six-cell pilot batch; every posterior remains unqualified."""
import argparse,datetime,hashlib,json,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--launcher',type=Path,required=True);p.add_argument('--snapshot',required=True);a=p.parse_args()
r=Path('validation/autodesn/remediation');manifest=json.loads((r/'artifacts/source_snapshots'/a.snapshot/'manifest.json').read_text())
records=[]
for cutoff in [1500,2000]:
 for family in ['F1','F2','F2flat']:
  d=r/f'artifacts/fold_fits/cutoff{cutoff}'/family/'pilot';status=d/'status.json'
  def verify():
   s=json.loads(status.read_text());assert s['complete'] and s['retained_per_chain']==2000 and s['source_sha256']==manifest
   for k in range(1,5):
    st=json.loads((d/f'chain_{k}_status.json').read_text())
    assert st['complete'] and st['target_id']==s['target_id']
    assert hashlib.file_digest((d/f'chain_{k}.rds').open('rb'),'sha256').hexdigest()==st['checkpoint_sha256']
   return s
  reused=status.exists() and json.loads(status.read_text()).get('complete',False)
  if not reused:
   cmd=[sys.executable,str(a.launcher),family,'pilot','--workers','4','--cache','--snapshot',a.snapshot,'--prefix-manifest',str(r/f'evidence/prefix_bank_{cutoff}.json')]
   result=subprocess.run(cmd)
   if result.returncode:raise SystemExit(result.returncode)
  s=verify();record=dict(cutoff=cutoff,family=family,complete=True,reused_verified_existing=reused,
   burn=1000,retained_per_chain=2000,chains=4,target_id=s['target_id'],posterior_qualified=False)
  records.append(record);print(json.dumps(record),flush=True)
out=dict(complete=True,observed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),cells=records,
 source_snapshot=a.snapshot,launcher_sha256=hashlib.file_digest(a.launcher.open('rb'),'sha256').hexdigest(),
 scope='All six training-only chronological mean-family pilots and full-support proposal guides. Actual budget1000warmup+2000retained per chain, irrespective of the legacy requested-budget filename. No production convergence, selection or forecasts credited.')
path=r/'evidence/fold_pilot_batch.json';assert not path.exists();path.write_text(json.dumps(out,indent=2)+'\n')
