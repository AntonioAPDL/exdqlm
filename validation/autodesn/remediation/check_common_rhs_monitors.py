"""Supplementary diagnostics for the common 90-lag RHS block."""
import argparse,hashlib,json,sys
from pathlib import Path
import numpy as np
import pandas as pd
sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'standardized_rhs'))
from diagnostics import diagnostics

p=argparse.ArgumentParser();p.add_argument('phase');p.add_argument('--family',default='F1');p.add_argument('--directory',type=Path);p.add_argument('--evidence-root',type=Path);a=p.parse_args()
r=Path('validation/autodesn/remediation');phase=a.phase;d=a.directory or r/'artifacts/common_rhs_monitors'/phase;evidence=a.evidence_root or r/'evidence';evidence.mkdir(parents=True,exist_ok=True)
status=json.loads((d/'status.json').read_text());assert status['complete']
assert status.get('family','F1')==a.family
chains=[pd.read_csv(d/f'chain_{k}.csv') for k in range(1,5)]
assert all(c.chain.eq(k).all() for k,c in enumerate(chains,1))
assert len({len(c) for c in chains})==1 and all(c.columns.equals(chains[0].columns) for c in chains)
fields=list(chains[0].columns[2:]);assert len(fields)==270
rows=[dict(parameter=p,**diagnostics(np.array([c[p].to_numpy() for c in chains]))) for p in fields]
table=pd.DataFrame(rows);table.to_csv(evidence/f'{a.family}_{phase}_common_rhs_diagnostics.csv',index=False)
passed=bool(np.isfinite(table[['rhat','bulk_ess','tail_ess']]).all().all() and table.rhat.le(1.01).all() and table.bulk_ess.ge(400).all() and table.tail_ess.ge(400).all())
record=dict(complete=True,screen_passed=passed,phase=phase,family=a.family,parameters=len(fields),chains=4,stored_states_per_chain=len(chains[0]),maximum_rhat=float(table.rhat.max()),minimum_bulk_ess=float(table.bulk_ess.min()),minimum_tail_ess=float(table.tail_ess.min()),failed_parameters=table.loc[(table.rhat>1.01)|(table.bulk_ess<400)|(table.tail_ess<400),'parameter'].tolist(),source_status_sha256=hashlib.sha256((d/'status.json').read_bytes()).hexdigest(),source_csv_sha256={f'chain_{k}.csv':hashlib.sha256((d/f'chain_{k}.csv').read_bytes()).hexdigest() for k in range(1,5)},posterior_qualified=False,forecast_allowed=False,scope='Supplementary all90 common lag-coefficient, local-scale and effective prior-variance monitors, evaluated on matching saved states for the declared mean family. Existing full-trace screens remain separate. Passing finite monitors does not prove convergence of every posterior functional; failures block promotion. No variable selected using outcomes and no held-out data read.')
(evidence/f'{a.family}_{phase}_common_rhs_diagnostics.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record))
if not passed:raise SystemExit(2)
