"""Depth-three in-grammar GP diagnostic, initialized by training periodogram."""
from pathlib import Path
import json,time
import numpy as np,pandas as pd
from scipy.linalg import cho_factor,cho_solve
from scipy.optimize import minimize
from scipy.signal import periodogram
from scipy.stats import norm
from gp_audit import kernel
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;OUT=HERE/'artifacts'
def main():
 started=time.perf_counter();y=pd.read_csv(ROOT/'input/series.csv').y.to_numpy();t=np.arange(501,2501,dtype=float);future=np.arange(2501,3001,dtype=float);center=y[500:2500].mean();target=y[500:2500]-center;n=len(t);D=abs(t[:,None]-t[None,:]);S=np.sin(np.pi*D/60)**2;I=np.eye(n)
 f,p=periodogram(target);eligible=(f>=1/100)&(f<=1/8);peak=f[np.flatnonzero(eligible)[np.argmax(p[eligible])]];period0=1/peak
 def obj(theta):
  aps,ls,apq,lq,period,length,noise=np.exp(theta);P=aps*np.exp(-2*S/ls**2);angle=np.pi*D/period;Qk=apq*np.exp(-2*np.sin(angle)**2/lq**2-D/length);C=P+Qk+noise*I
  cf=cho_factor(C,lower=True,check_finite=False);alpha=cho_solve(cf,target,check_finite=False);value=.5*(target@alpha+2*np.log(np.diag(cf[0])).sum()+n*np.log(2*np.pi));R=cho_solve(cf,I,check_finite=False)-np.outer(alpha,alpha)
  grad=.5*np.array([np.sum(R*P),np.sum(R*P*4*S/ls**2),np.sum(R*Qk),np.sum(R*Qk*4*np.sin(angle)**2/lq**2),np.sum(R*Qk*2*angle*np.sin(2*angle)/lq**2),np.sum(R*Qk*D/length),noise*np.trace(R)])
  return value,grad
 fits=[]
 for lq in [.5,1.5]:
  start=np.log([.1,.3,.4,lq,period0,100,.08]);bounds=[(-12,3),(-5,3),(-12,3),(-5,3),(np.log(.7*period0),np.log(1.3*period0)),(-2,10),(-12,3)]
  r=minimize(obj,start,jac=True,method='L-BFGS-B',bounds=bounds,options=dict(maxiter=120,ftol=1e-9,gtol=1e-4));fits.append(r);print('Quasi GP',r.success,r.fun,r.nit,flush=True)
 good=[r for r in fits if r.success];assert good;best=min(good,key=lambda r:r.fun);aps,ls,apq,lq,period,length,noise=np.exp(best.x)
 # Check analytic gradient at the fitted state against finite differences.
 val,g=obj(best.x);fd=[]
 for j in range(7):
  d=np.zeros(7);d[j]=1e-5;fd.append((obj(best.x+d)[0]-obj(best.x-d)[0])/2e-5)
 gradient_error=float(np.max(abs(np.asarray(fd)-g)));assert gradient_error<.02
 k=('Plus',[('Periodic',[ls,60.,aps]),('Times',[('Periodic',[lq,period,apq]),('GammaExponential',[length,1.,1.])])]);C=kernel(k,t,t)+noise*I;cf=cho_factor(C,lower=True,check_finite=False);cross=kernel(k,future,t);m=center+cross@cho_solve(cf,target,check_finite=False);cov=kernel(k,future,future)+noise*np.eye(500)-cross@cho_solve(cf,cross.T,check_finite=False);cov=(cov+cov.T)/2;rows=[]
 for origin in range(2500,2971):
  h=np.arange(1,31);actual=y[origin:origin+30];mean=m[:30];sd=np.sqrt(np.diag(cov)[:30]);z=(actual-mean)/sd
  rows.append(pd.DataFrame(dict(origin=origin,horizon=h,target=origin+h,actual=actual,mean=mean,predictive_sd=sd,squared_error=(actual-mean)**2,absolute_error=abs(actual-mean),crps=sd*(z*(2*norm.cdf(z)-1)+2*norm.pdf(z)-1/np.sqrt(np.pi)),negative_log_score=-norm.logpdf(actual,mean,sd),covered50=abs(z)<=norm.ppf(.75),covered90=abs(z)<=norm.ppf(.95),width50=2*norm.ppf(.75)*sd,width90=2*norm.ppf(.95)*sd)))
  if origin<2970:
   c=cov[1:,0].copy();q=cov[0,0];m=m[1:]+c/q*(y[origin]-m[0]);cov=cov[1:,1:]-np.outer(c,c)/q;cov=(cov+cov.T)/2
 pd.concat(rows).to_csv(OUT/'quasiperiodic_gp_scores.csv',index=False)
 status=dict(complete=True,periodogram_initial_period=period0,learned_oscillatory_period=period,calendar_period=60.,calendar_period_is_privileged=True,parameters=dict(calendar_variance=aps,calendar_lengthscale=ls,oscillatory_variance=apq,oscillatory_lengthscale=lq,coherence_length=length,noise_variance=noise),negative_log_likelihood=float(best.fun),gradient_finite_difference_max_error=gradient_error,maximum_kernel_depth=3,within_existing_native_grammar=True,not_Bayesian_SMC=True,selection_uses_test=False,elapsed_seconds=time.perf_counter()-started)
 (OUT/'quasiperiodic_gp_status.json').write_text(json.dumps(status,indent=2));(OUT/'gp_candidate.toml').write_text('\n'.join(f'{k} = {v}' for k,v in dict(**status['parameters'],period=period).items()));print(json.dumps(status),flush=True)
if __name__=='__main__':main()
