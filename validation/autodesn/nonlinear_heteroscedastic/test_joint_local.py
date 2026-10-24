"""Independent four-scale prior integration for joint MH + learned locals."""
from pathlib import Path
import json,sys
import numpy as np,pandas as pd
from scipy.stats import invgamma,qmc
HERE=Path(__file__).resolve().parent;D=HERE/'artifacts/validation/joint_local_oracle'
sys.path.insert(0,str(HERE.parent/'standardized_rhs'))
from diagnostics import diagnostics
refs=[];y=np.array([.8,-.3]);along=y.sum()/np.sqrt(2);across=(y[1]-y[0])/np.sqrt(2)
for seed in [9191,9192,9193,9194]:
 U=qmc.Sobol(4,scramble=True,seed=seed).random_base2(18)
 s=invgamma.ppf(U[:,0],a=3,scale=1);u=np.tan(np.pi*U[:,1]/2)
 c=invgamma.ppf(U[:,2],a=2,scale=2);lam=np.tan(np.pi*U[:,3]/2)
 v=1/(1/c+1/(.3*u*lam)**2)
 w=[]
 for j,prior in enumerate([.4,.6]):
  other=s+(v if j else 0)
  w.append(prior*np.exp(-.5*(2*np.log(2*np.pi)+np.log(s+2)+np.log(other)+along**2/(s+2)+across**2/other)))
 total=w[0]+w[1];Z=total.mean()
 refs.append([w[1].mean()/Z,(total*(u<1)).mean()/Z,(total*(c<1.2)).mean()/Z,
  (total*(s<.4)).mean()/Z,(.5*w[0]+w[1]*(lam<1)).mean()/Z])
ref=np.mean(refs,axis=0);refse=np.std(refs,axis=0,ddof=1)/2
assert abs(ref[1]-ref[4])<8*np.hypot(refse[1],refse[4])+.001,'Normalized priors imply u/local exchangeability'
tr=pd.read_csv(D/'posterior.csv')
functions={'model_2':(tr.model==2).astype(float),'u_below_1':(tr.global_scale<1).astype(float),
 'c2_below_1.2':(tr.slab_variance<1.2).astype(float),'variance_below_.4':(tr.variance<.4).astype(float),
 'local_below_1_inactive_integrated':tr.local_below_1_RB}
checks=[]
for i,(name,values) in enumerate(functions.items()):
 x=np.array([values[tr.chain==k].to_numpy() for k in [1,2,3]]);dg=diagnostics(x)
 estimate=values.mean();se=np.sqrt(np.var(values,ddof=1)/dg['bulk_ess'])
 assert dg['rhat']<=1.01 and dg['bulk_ess']>=800,(name,dg)
 assert abs(estimate-ref[i])<=5*se+5*refse[i]+.004,(name,estimate,ref[i],se)
 checks.append(dict(parameter=name,estimate=estimate,reference=ref[i],reference_se=refse[i],mcmc_se=se,**dg))
pd.DataFrame(checks).to_csv(D/'independent_posterior_checks.csv',index=False)
(D/'status.json').write_text(json.dumps(dict(complete=True,learned_local_interweave_joint_functionals=5,
 normalized_prior_dimensions=4,sobol_points_per_scramble=2**18,scrambles=4,chains=3,retained_per_chain=20000,
 inactive_local_prior_integrated_exactly=True),indent=2))
print(pd.DataFrame(checks).to_string(index=False));print('Learned-local/interwoven joint posterior oracle PASSED')
