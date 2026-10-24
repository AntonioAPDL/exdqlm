"""Independent normalized prior integration versus native variable-tree MH."""
import hashlib, json, sys, tomllib
from pathlib import Path
import numpy as np
import pandas as pd
root=Path('validation/autodesn/remediation')
sys.path.insert(0,str(root.parent/'standardized_rhs'))
from diagnostics import diagnostics
d=root/'artifacts/gp_leaf_reference'
status=tomllib.loads((d/'status.toml').read_text());assert status['complete']
chains=[]
for k in range(1,5):
 p=d/f'trace_{k}.csv';s=tomllib.loads((d/f'chain_{k}_status.toml').read_text())
 assert s['complete'] and hashlib.sha256(p.read_bytes()).hexdigest()==s['trace_sha256']
 chains.append(pd.read_csv(p))
reference=pd.read_csv(root/'evidence/gp_leaf_prior_integration.csv');rows=[]
for r in reference.itertuples():
 x=np.array([c[r.quantity].to_numpy() for c in chains]);n=x.shape[1];bs=int(np.sqrt(n));batches=np.concatenate([v[:n//bs*bs].reshape(n//bs,bs).mean(1) for v in x]);mcse=float(batches.std(ddof=1)/np.sqrt(len(batches)))
 estimate=float(x.mean());tolerance=7*np.hypot(mcse,r.reference_mcse)+2*r.refinement_difference+1e-4
 rows.append(dict(quantity=r.quantity,reference=r.reference,estimate=estimate,absolute_error=abs(estimate-r.reference),batch_mcse=mcse,tolerance=tolerance,moment_passed=abs(estimate-r.reference)<tolerance,**diagnostics(x)))
table=pd.DataFrame(rows);table.to_csv(root/'evidence/gp_leaf_mcmc_reference_checks.csv',index=False)
passed=bool(table.moment_passed.all() and (table.rhat<=1.01).all() and (table.bulk_ess>=400).all() and (table.tail_ess>=400).all())
result=dict(complete=True,passed=passed,chains=4,retained_per_chain=32000,joint_functionals=len(rows),maximum_rhat=float(table.rhat.max()),minimum_bulk_ess=float(table.bulk_ess.min()),minimum_tail_ess=float(table.tail_ess.min()),moments_passed=bool(table.moment_passed.all()),scope='Complete native default depth-one leaf grammar, all parameters/noise integrated; native prior-independence MH against independent normalized-prior dense integration. Not full depth-four grammar or SMC qualification.',production_qualified=False,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
(root/'evidence/gp_leaf_mcmc_reference.json').write_text(json.dumps(result,indent=2)+'\n');print(table.to_string(index=False));print(json.dumps(result))
if not passed:raise SystemExit(1)
