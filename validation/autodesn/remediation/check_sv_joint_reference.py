"""Compare independent quadrature to four full public SV Gibbs chains."""
import json,sys,hashlib
from pathlib import Path
import numpy as np,pandas as pd
root=Path('validation/autodesn/remediation');sys.path.insert(0,str(root.parent/'standardized_rhs'));from diagnostics import diagnostics
ref=pd.read_csv(root/'evidence/sv_joint_reference.csv');d=root/'artifacts/sv_joint_reference';status=json.loads((d/'status.json').read_text());assert status['complete'];chains=[pd.read_csv(d/f'joint_{k}.csv') for k in range(1,5)]
rows=[]
for r in ref.itertuples():
 x=np.array([c[r.quantity].to_numpy() for c in chains]);dg=diagnostics(x)
 # Independent batch mean MCSE at the saved joint-state spacing.
 n=x.shape[1];batch_size=int(np.sqrt(n));batches=n//batch_size;bm=np.concatenate([v[:batches*batch_size].reshape(batches,batch_size).mean(1) for v in x]);mcse=float(bm.std(ddof=1)/np.sqrt(len(bm)))
 estimate=float(x.mean());tolerance=7*mcse+2*r.refinement_difference+1e-4
 rows.append(dict(quantity=r.quantity,reference=r.reference,estimate=estimate,absolute_error=abs(estimate-r.reference),batch_mcse=mcse,tolerance=tolerance,moment_passed=abs(estimate-r.reference)<tolerance,**dg))
table=pd.DataFrame(rows);table.to_csv(root/'evidence/sv_joint_mcmc_reference_checks.csv',index=False)
passed=bool(table.moment_passed.all() and (table.rhat<=1.01).all() and (table.bulk_ess>=400).all() and (table.tail_ess>=400).all())
record=dict(complete=True,passed=passed,chains=4,joint_functionals=len(rows),maximum_rhat=float(table.rhat.max()),minimum_bulk_ess=float(table.bulk_ess.min()),minimum_tail_ess=float(table.tail_ess.min()),moments_passed=bool(table.moment_passed.all()),source_status_sha256=hashlib.sha256((d/'status.json').read_bytes()).hexdigest(),scope='Full unknown-noise/intercept/stationary-state/persistence/volatility posterior on two fixed responses; not production convergence or unconditional recursive calibration',production_qualified=False)
(root/'evidence/sv_joint_mcmc_reference.json').write_text(json.dumps(record,indent=2)+'\n');print(table.to_string(index=False));print(json.dumps(record))
if not passed:raise SystemExit(1)
