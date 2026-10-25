"""Validate SMC unnormalized measures against independent normalized-prior QMC.

The existing reference source is parsed, never imported with its output-writing
top-level driver. The exact frozen independent integrand is reused unchanged.
"""
import ast,hashlib,json
from pathlib import Path
import numpy as np
import pandas as pd
root=Path('validation/autodesn/remediation')
source=Path(__file__).with_name('gp_leaf_prior_integration.py')
tree=ast.parse(source.read_text());selected=[]
for node in tree.body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='records' for t in node.targets):break
    selected.append(node)
ns={};exec(compile(ast.Module(body=selected,type_ignores=[]),str(source),'exec'),ns)
qmc={}
for power in [16,18]:
    values=[]
    for k in range(8):
        z,m=ns['integrals'](power,7466101+k)
        values.append(np.r_[z,z*m[[0,1,2,3]]])
    qmc[power]=np.array(values)
reference=qmc[18].mean(0);reference_mcse=qmc[18].std(0,ddof=1)/np.sqrt(8)
refinement=np.abs(reference-qmc[16].mean(0))
r=pd.read_csv(root/'evidence/gp_smc_normalizer_replicas.csv')
names=['normalizer','unnormalized_linear','unnormalized_gamma','unnormalized_periodic','unnormalized_noise']
checks=[]
for mode,t in r.groupby('rejuvenation'):
    z=np.exp(t.log_evidence.to_numpy())
    estimates=z[:,None]*np.column_stack([np.ones(len(t)),t[['linear_probability','gamma_probability','periodic_probability','noise_variance']]])
    mean=estimates.mean(0);mcse=estimates.std(0,ddof=1)/np.sqrt(len(t))
    # Fixed before execution: six combined MC SE, plus QMC refinement and .2%
    # relative numerical floor. This checks finite-reference agreement only.
    tolerance=6*np.sqrt(mcse**2+reference_mcse**2)+2*refinement+.002*np.abs(reference)
    for j,name in enumerate(names):
        checks.append(dict(rejuvenation=bool(mode),quantity=name,estimate=mean[j],reference=reference[j],mcse=mcse[j],reference_mcse=reference_mcse[j],refinement=refinement[j],tolerance=tolerance[j],absolute_error=abs(mean[j]-reference[j]),passed=bool(abs(mean[j]-reference[j])<=tolerance[j])))
table=pd.DataFrame(checks);table.to_csv(root/'evidence/gp_smc_normalizer_checks.csv',index=False)
result=dict(complete=True,passed=bool(table.passed.all()),checks=len(table),replicas_per_arm=64,particles=128,arms=['no_rejuvenation','native_2_structure_1_HMC'],fixture=dict(times=[0,.19,.47,1],response=[.13,-.24,.12,.07]),qmc_powers=[16,18],qmc_scrambles=8,independent_integrand_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),maximum_reference_relative_mcse=float(np.max(reference_mcse/np.abs(reference))),full_depth_four_qualified=False,scope='Complete continuous depth-one native leaf target; validates final weight accounting and unnormalized replica measures. Does not establish production deep-tree convergence or sufficient numbers of independent runs.')
(root/'evidence/gp_smc_normalizer_reference.json').write_text(json.dumps(result,indent=2)+'\n')
print(table.to_string(index=False))
raise SystemExit(0 if result['passed'] else 1)
