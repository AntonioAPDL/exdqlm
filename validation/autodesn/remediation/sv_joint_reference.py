"""Independent low-dimensional full SV posterior, integrating the proper intercept.

Two responses; unknown noise, stationary states, persistence and volatility SD.
No DESN or NHS1 input is used. All Gaussian determinants remain in the integral.
"""
import json,math,time
from pathlib import Path
import numpy as np,pandas as pd
from scipy.special import roots_hermitenorm,roots_jacobi,roots_genlaguerre,gamma,erfc
from numpy.polynomial.legendre import leggauss
root=Path('validation/autodesn/remediation');y1,y2=.2,1.1;v0=10.;a=3.;b=1.;omega_sd=.5
fields=['variance','log_variance','intercept','intercept_squared','phi','omega','omega_squared','u1','u2','u1_u2','eta1','eta2','log_likelihood']
def integrate(np_,no,nz,ns):
 phi,wp=roots_jacobi(np_,.5,9.);wp/=wp.sum()
 w,ww=leggauss(no);omega=2*(w+1);ww=2*ww*np.sqrt(2/np.pi)/omega_sd*np.exp(-omega**2/(2*omega_sd**2))
 z,wz=roots_hermitenorm(nz);wz/=np.sqrt(2*np.pi);z1=z[:,None];z2=z[None,:];wzz=(wz[:,None]*wz[None,:])[:,:,None]
 precision,ws=roots_genlaguerre(ns,a-1);ws/=gamma(a);s=(b/precision)[None,None,:]
 total=0.;sums=np.zeros(len(fields))
 for f,pf in zip(phi,wp):
  u1=np.broadcast_to(z1,(nz,nz))[:,:,None];u2=(f*z1+np.sqrt(1-f*f)*z2)[:,:,None]
  for o,po in zip(omega,ww):
   eta1=o*u1;eta2=o*u2;d1=s*np.exp(eta1);d2=s*np.exp(eta2);det=d1*d2+v0*(d1+d2)
   logl=-np.log(2*np.pi)-.5*(np.log(det)+(v0*(y1-y2)**2+d2*y1*y1+d1*y2*y2)/det)
   weights=pf*po*wzz*ws[None,None,:]*np.exp(logl)
   mu=v0*(d2*y1+d1*y2)/det;var=v0*d1*d2/det
   expected_ll=-np.log(2*np.pi)-.5*(np.log(d1)+np.log(d2)+((y1-mu)**2+var)/d1+((y2-mu)**2+var)/d2)
   values=[s,np.log(s),mu,var+mu*mu,f,o,o*o,u1,u2,u1*u2,eta1,eta2,expected_ll]
   total+=weights.sum()
   sums+=np.array([(weights*x).sum() for x in values])
 return total,sums/total
started=time.monotonic();coarse=integrate(24,24,20,28);fine=integrate(40,40,32,48)
result=pd.DataFrame(dict(quantity=fields,reference=fine[1],coarse=coarse[1],refinement_difference=np.abs(fine[1]-coarse[1])))
# Engineering tolerance is fixed before examining MCMC results.
assert result.refinement_difference.max()<.003,result
result.to_csv(root/'evidence/sv_joint_reference.csv',index=False)
tail_bound=(a/b)/(2*np.pi)*np.sqrt(2/np.pi)/omega_sd*np.sqrt(np.pi)/(2*np.sqrt(1.5))*erfc(np.sqrt(1.5)*4)/(fine[0]/2)
assert tail_bound<1e-8
status=dict(omega_posterior_tail_upper_bound=float(tail_bound),complete=True,scope='Independent two-response full SV posterior: proper N(0,10) intercept, IG(3,1) noise, stationary Gaussian states, Beta(10,1.5) persistence transform and HN(.5) volatility SD',data=[y1,y2],quadrature_coarse=[24,24,20,28],quadrature_fine=[40,40,32,48],normalizer=float(fine[0]),maximum_refinement_difference=float(result.refinement_difference.max()),omega_integration_interval=[0,4],elapsed_seconds=time.monotonic()-started,production_qualified=False)
(root/'evidence/sv_joint_reference.json').write_text(json.dumps(status,indent=2)+'\n');print(result.to_string(index=False));print(json.dumps(status))
