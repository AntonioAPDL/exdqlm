"""Independent SciPy densities, detailed balance and Sobol posterior integrals."""
from pathlib import Path
import json,sys
import numpy as np,pandas as pd
from scipy.stats import multivariate_t,multivariate_normal,invgamma,cauchy,qmc
from scipy.special import logsumexp
HERE=Path(__file__).resolve().parent;D=HERE/'artifacts/validation/joint_oracle'
sys.path.insert(0,str(HERE.parent/'standardized_rhs'))
from diagnostics import diagnostics
p=json.loads((D/'proposal.json').read_text());rows=pd.read_csv(D/'densities.csv');y=np.array([.8,-.3]);prior=np.array([.4,.6]);q=np.array([.7,.3]);x=np.array([-1,1])/np.sqrt(2)
def expected(model,z):
 s,u,c=np.exp(z);v=1/(1/c+1/(.3*u)**2) if model==2 else 0
 C=s*np.eye(2)+np.ones((2,2))+v*np.outer(x,x)
 likelihood=multivariate_normal.logpdf(y,mean=np.zeros(2),cov=C)
 target=np.log(prior[model-1])+likelihood+invgamma.logpdf(s,a=3,scale=1)+z[0]+np.log(2)+cauchy.logpdf(u)+z[1]+invgamma.logpdf(c,a=2,scale=2)+z[2]
 density=logsumexp([np.log(.9)+multivariate_t.logpdf(z,loc=np.array(p['center'])[model-1],shape=np.array(p['scale']),df=5),np.log(.1)+multivariate_t.logpdf(z,loc=np.array(p['wide_center']),shape=np.array(p['wide_scale']),df=5)])
 return np.array([likelihood,target,density])
for _,r in rows.iterrows():
 z=r[['log_variance','log_global','log_slab']].to_numpy(float)
 np.testing.assert_allclose(r[['log_likelihood','log_target','log_q']].to_numpy(float),expected(int(r.model),z),rtol=1e-11,atol=1e-11)
# Every ordered pair, including same-architecture global moves.
ratios=pd.read_csv(D/'acceptance_ratios.csv')
for _,pair in ratios.iterrows():
  a=rows.iloc[int(pair.old_row)-1];b=rows.iloc[int(pair.new_row)-1]
  log_forward=np.log(q[int(b.model)-1])+b.log_q
  log_reverse=np.log(q[int(a.model)-1])+a.log_q
  delta=b.log_target-a.log_target+log_reverse-log_forward
  np.testing.assert_allclose(pair.implemented_log_ratio,delta,rtol=1e-11,atol=1e-11)
  np.testing.assert_allclose(a.log_target+log_forward+min(0,delta),b.log_target+log_reverse+min(0,-delta),atol=1e-12)
# Marginalize coefficients independently in an orthonormal basis, then
# integrate scales under their normalized priors using scrambled Sobol points.
references=[]
for scramble in [891,892,893,894]:
 U=qmc.Sobol(3,scramble=True,seed=scramble).random_base2(18)
 s=invgamma.ppf(U[:,0],a=3,scale=1);u=np.tan(np.pi*U[:,1]/2);c=invgamma.ppf(U[:,2],a=2,scale=2)
 v=1/(1/c+1/(.3*u)**2);along=y.sum()/np.sqrt(2);across=(y[1]-y[0])/np.sqrt(2)
 weighted=[]
 for j in range(2):
  other=s+(v if j==1 else 0)
  likelihood=np.exp(-.5*(2*np.log(2*np.pi)+np.log(s+2)+np.log(other)+along**2/(s+2)+across**2/other))
  weighted.append(prior[j]*likelihood)
 total=weighted[0]+weighted[1];Z=total.mean()
 references.append([weighted[1].mean()/Z,(total*(u<1)).mean()/Z,(total*(c<1.2)).mean()/Z,(total*(s<.4)).mean()/Z])
reference=np.mean(references,axis=0);reference_error=np.std(references,axis=0,ddof=1)/2
trace=pd.read_csv(D/'posterior.csv');functions={'model_2':(trace.model==2).astype(float),'u_below_1':(trace.global_scale<1).astype(float),'c2_below_1.2':(trace.slab_variance<1.2).astype(float),'variance_below_.4':(trace.variance<.4).astype(float)}
checks=[]
for i,(name,values) in enumerate(functions.items()):
 z=np.array([values[trace.chain==k].to_numpy() for k in [1,2,3]]);d=diagnostics(z);estimate=values.mean();se=np.sqrt(estimate*(1-estimate)/d['bulk_ess'])
 assert d['rhat']<=1.01 and d['bulk_ess']>=800,(name,d)
 assert abs(estimate-reference[i])<=5*se+5*reference_error[i]+.004,(name,estimate,reference[i],se)
 checks.append(dict(parameter=name,estimate=estimate,reference=reference[i],reference_se=reference_error[i],mcmc_se=se,**d))
pd.DataFrame(checks).to_csv(D/'independent_posterior_checks.csv',index=False)
(D/'status.json').write_text(json.dumps(dict(complete=True,deterministic_density_states=6,ordered_detailed_balance_pairs=36,independent_posterior_functionals=4,sobol_points_per_scramble=2**18,scrambles=4),indent=2))
print(pd.DataFrame(checks).to_string(index=False));print('Independent joint-kernel density, balance and posterior checks passed')
