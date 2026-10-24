"""Independent normalized-prior integration of the frozen grouped RHS target.

Inverse-CDF integration covers the full proper scale priors; Gaussian coefficients
are integrated with a dense observation-space covariance, independently of R/C++.
Eight randomized Sobol replications quantify numerical integration uncertainty.
"""
import json,time,hashlib
from pathlib import Path
import numpy as np,pandas as pd
from scipy.special import gammaincinv
from scipy.stats import qmc
root=Path('validation/autodesn/remediation');fixture=root/'artifacts/grouped_reference_fixture.json';f=json.loads(fixture.read_text());y=np.array(f['y']);n=len(y)
fields=['variance','log_global_1','log_global_2','log_slab','intercept','intercept_squared','fitted_mean_4','model_2','period_2','joint_2_2']
def integrate(power,seed):
 U=qmc.Sobol(4,scramble=True,bits=52,seed=seed).random_base2(power);assert ((U>0)&(U<1)).all()
 u1=np.tan(np.pi/2*U[:,0]);u2=np.tan(np.pi/2*U[:,1]);c2=2/gammaincinv(2,U[:,2]);s2=1/gammaincinv(3,U[:,3]);N=len(U);total=np.zeros(N);numerator=np.zeros(len(fields))
 for d in f['designs']:
  X=np.array(d['X']);assert X.shape[0]==n;groups=d['groups'];v=np.empty((N,len(groups)))
  for k,g in enumerate(groups):
   if g=='intercept':v[:,k]=f['intercept_variance']
   elif g=='calendar':v[:,k]=f['calendar_variance']
   else:
    u=u1 if g=='lag' else u2;h=(f['tau0']*f['fixed_local']*u)**2;v[:,k]=c2*h/(c2+h)
  C=np.einsum('ik,nk,jk->nij',X,v,X,optimize=True);C[:,np.arange(n),np.arange(n)]+=s2[:,None]
  sign,ld=np.linalg.slogdet(C);assert (sign>0).all()
  rhs=np.broadcast_to(np.stack([y,np.ones(n)],axis=1),(N,n,2));solution=np.linalg.solve(C,rhs);a=solution[:,:,0];b=solution[:,:,1]
  ll=-.5*(n*np.log(2*np.pi)+ld+(a*y).sum(1));w=np.exp(ll)*f['model_prior'][d['model']-1]*f['period_prior'][d['period_index']-1]
  mean=f['intercept_variance']*a.sum(1);var=f['intercept_variance']-f['intercept_variance']**2*b.sum(1);assert var.min()>-1e-8
  values=[s2,np.log(u1),np.log(u2),np.log(c2),mean,var+mean**2,y[3]-s2*a[:,3],int(d['model']==2),int(d['period_index']==2),int(d['model']==2 and d['period_index']==2)]
  total+=w;numerator+=np.array([(w*z).sum() for z in values])
 return total.mean(),numerator/total.sum(),float(total.sum()**2/(total@total))
started=time.monotonic();runs=[]
for power in [15,17]:
 for replicate in range(8):
  z,mu,concentration=integrate(power,10566100+replicate);runs.append(dict(power=power,replicate=replicate,normalizer=z,weight_concentration_index=concentration,**dict(zip(fields,mu))))
rows=pd.DataFrame(runs);rows.to_csv(root/'evidence/grouped_prior_integration_runs.csv',index=False);coarse=rows[rows.power==15];fine=rows[rows.power==17]
result=pd.DataFrame(dict(quantity=fields,reference=fine[fields].mean().values,reference_mcse=(fine[fields].std(ddof=1)/np.sqrt(8)).values,refinement_difference=np.abs(fine[fields].mean()-coarse[fields].mean()).values))
assert result.reference_mcse.max()<.003,result
result.to_csv(root/'evidence/grouped_prior_integration.csv',index=False)
record=dict(complete=True,scope='Independent conditional grouped-RHS posterior with fixed local scales, two learned global scales, one shared slab, proper Gaussian calendar, unknown IG noise and variable architecture dimension; not learned-local or recursive SBC',replications=8,prior_integration_counts=[2**15,2**17],maximum_reference_mcse=float(result.reference_mcse.max()),maximum_refinement_difference=float(result.refinement_difference.max()),fixture_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest(),elapsed_seconds=time.monotonic()-started,production_qualified=False)
(root/'evidence/grouped_prior_integration.json').write_text(json.dumps(record,indent=2)+'\n');print(result.to_string(index=False));print(json.dumps(record))
