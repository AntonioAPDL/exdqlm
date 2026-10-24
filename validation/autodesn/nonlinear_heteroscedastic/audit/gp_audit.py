"""Independent native-kernel reconstruction and an in-grammar known-period GP diagnostic."""
import ast,json,time
from pathlib import Path
import numpy as np,pandas as pd
from scipy.linalg import cho_factor,cho_solve,solve_triangular
from scipy.optimize import minimize
from scipy.stats import norm
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;OUT=HERE/'artifacts'
def parse(s):
 def node(v):
  if isinstance(v,ast.Constant):return v.value
  if isinstance(v,ast.UnaryOp) and isinstance(v.op,ast.USub):return -node(v.operand)
  if isinstance(v,ast.Call) and isinstance(v.func,ast.Name) and v.func.id in ['Times','Plus','Linear','Periodic','GammaExponential','SquaredExponential','Constant','WhiteNoise']:
   return (v.func.id,[node(a) for a in v.args])
  raise ValueError('Unsupported kernel export')
 return node(ast.parse(s.replace('AutoGP.GP.',''),mode='eval').body)
def kernel(node,a,b):
 kind,p=node;D=abs(a[:,None]-b[None,:])
 if kind=='Times':return kernel(p[0],a,b)*kernel(p[1],a,b)
 if kind=='Plus':return kernel(p[0],a,b)+kernel(p[1],a,b)
 if kind=='Periodic':return p[2]*np.exp(-2*np.sin(np.pi*D/p[1])**2/p[0]**2)
 if kind=='GammaExponential':return p[2]*np.exp(-(D/p[0])**p[1])
 if kind=='SquaredExponential':return p[1]*np.exp(-.5*(D/p[0])**2)
 if kind=='Linear':return p[1]+p[2]*(a[:,None]-p[0])*(b[None,:]-p[0])
 if kind=='Constant':return np.full(D.shape,p[0])
 if kind=='WhiteNoise':return p[0]*(D==0)
 raise ValueError(kind)
def main():
 started=time.perf_counter();truth=pd.read_csv(ROOT/'input/dgp_truth.csv');y=truth.y.to_numpy();t=np.arange(501,2501,dtype=float);future=np.arange(2501,3001,dtype=float);center=y[500:2500].mean();target=y[500:2500]-center;n=len(t);native_train=np.zeros(n);native_prequential=np.zeros(n);native_future=np.zeros(500);checks=[];statistics=[]
 for run in [1,2]:
  part=pd.read_csv(ROOT/f'artifacts/gp/run_{run}/particles.csv');ref=pd.read_csv(ROOT/f'artifacts/gp/run_{run}/means.csv').to_numpy()
  for j,r in part.iterrows():
   k=parse(r.kernel);C=kernel(k,t,t);C.flat[::n+1]+=r.noise_variance;cf=cho_factor(C,lower=True,check_finite=False);alpha=cho_solve(cf,target,check_finite=False);train_mu=y[500:2500]-r.noise_variance*alpha;fmean=center+kernel(k,future,t)@alpha;err=float(np.max(abs(fmean-ref[:,j])));assert err<1e-6,(run,j,err)
   native_train+=r.weight/2*train_mu;native_prequential+=r.weight/2*(y[500:2500]-np.diag(cf[0])*solve_triangular(cf[0],target,lower=True,check_finite=False));native_future+=r.weight/2*fmean
   checks.append(dict(run=run,component=j+1,export_mean_max_error=err));statistics.append(dict(run=run,component=j+1,weight=r.weight,training_log_likelihood=-.5*(target@alpha+2*np.log(np.diag(cf[0])).sum()+n*np.log(2*np.pi)),noise_variance=r.noise_variance))
 pd.DataFrame(checks).to_csv(OUT/'gp_reconstruction.csv',index=False);pd.DataFrame(statistics).to_csv(OUT/'gp_training_likelihood.csv',index=False);pd.DataFrame(dict(time=t,smoothed_mean=native_train,mean=native_prequential,actual=y[500:2500],true_mean=truth.conditional_mean.to_numpy()[500:2500])).to_csv(OUT/'gp_training_fit.csv',index=False)
 # Known period is privileged structural information. This kernel lies in the
 # existing grammar at depth2; fitting it by likelihood is not native SMC.
 D=abs(t[:,None]-t[None,:]);S=np.sin(np.pi*D/60)**2;I=np.eye(n)
 def objective(theta,gradient=True):
  ap,ell,ar,length,noise=np.exp(theta);P=ap*np.exp(-2*S/ell**2);E=ar*np.exp(-D/length);C=P+E+noise*I
  try:cf=cho_factor(C,lower=True,check_finite=False)
  except np.linalg.LinAlgError:return (1e100,np.zeros(5))
  alpha=cho_solve(cf,target,check_finite=False);val=.5*(target@alpha+2*np.log(np.diag(cf[0])).sum()+n*np.log(2*np.pi))
  Q=cho_solve(cf,I,check_finite=False)-np.outer(alpha,alpha)
  g=.5*np.array([np.sum(Q*P),np.sum(Q*P*4*S/ell**2),np.sum(Q*E),np.sum(Q*E*D/length),noise*np.trace(Q)])
  return val,g
 fits=[]
 for start in [[.15,.3,.3,5,.15],[.15,1.,.3,20,.15]]:
  r=minimize(objective,np.log(start),jac=True,method='L-BFGS-B',bounds=[(-12,3),(-5,3),(-12,3),(-2,7),(-12,3)],options=dict(maxiter=90,ftol=1e-9,gtol=1e-4));fits.append(r);print('Fixed period GP start',len(fits),'objective',r.fun,'converged',r.success,flush=True)
 valid=[r for r in fits if r.success];assert valid,'Fixed-period GP optimization did not converge';best=min(valid,key=lambda r:r.fun);ap,ell,ar,length,noise=np.exp(best.x)
 k=('Plus',[('Periodic',[ell,60.,ap]),('GammaExponential',[length,1.,ar])]);C=kernel(k,t,t)+noise*I;cf=cho_factor(C,lower=True,check_finite=False);cross=kernel(k,future,t);prior=kernel(k,future,future)+noise*np.eye(500);alpha=cho_solve(cf,target,check_finite=False);m=center+cross@alpha;cov=prior-cross@cho_solve(cf,cross.T,check_finite=False);cov=(cov+cov.T)/2
 train_mu=y[500:2500]-noise*alpha;prequential=y[500:2500]-np.diag(cf[0])*solve_triangular(cf[0],target,lower=True,check_finite=False);pd.DataFrame(dict(time=t,smoothed_mean=train_mu,mean=prequential,actual=y[500:2500],true_mean=truth.conditional_mean.to_numpy()[500:2500])).to_csv(OUT/'fixed_period_gp_training_fit.csv',index=False)
 # Causal fixed-parameter rank-one conditioning between origins, same protocol.
 score=[]
 for origin in range(2500,2971):
  h=np.arange(1,31);actual=y[origin:origin+30];mean=m[:30];sd=np.sqrt(np.diag(cov)[:30]);z=(actual-mean)/sd
  score.append(pd.DataFrame(dict(origin=origin,horizon=h,target=origin+h,actual=actual,mean=mean,predictive_sd=sd,squared_error=(actual-mean)**2,absolute_error=abs(actual-mean),crps=sd*(z*(2*norm.cdf(z)-1)+2*norm.pdf(z)-1/np.sqrt(np.pi)),negative_log_score=-norm.logpdf(actual,mean,sd),covered50=abs(z)<=norm.ppf(.75),covered90=abs(z)<=norm.ppf(.95),width50=2*norm.ppf(.75)*sd,width90=2*norm.ppf(.95)*sd)))
  if origin<2970:
   c=cov[1:,0].copy();q=cov[0,0];m=m[1:]+c/q*(y[origin]-m[0]);cov=cov[1:,1:]-np.outer(c,c)/q;cov=(cov+cov.T)/2
 pd.concat(score).to_csv(OUT/'fixed_period_gp_scores.csv',index=False)
 status=dict(complete=True,native_kernel_reconstruction_max_error=max(r['export_mean_max_error'] for r in checks),parameters=dict(period=60.,periodic_variance=ap,periodic_lengthscale=ell,OU_variance=ar,OU_lengthscale=length,noise_variance=noise),best_training_negative_log_likelihood=best.fun,optimization_starts=[dict(converged=bool(r.success),nll=float(r.fun),iterations=int(r.nit)) for r in fits],elapsed_seconds=time.perf_counter()-started,known_period_is_privileged=True,maximum_kernel_depth=2,not_Bayesian_SMC=True,selection_uses_test=False,native_train_mu_RMSE=float(np.sqrt(np.mean((native_train-truth.conditional_mean.to_numpy()[500:2500])**2))))
 (OUT/'gp_audit_status.json').write_text(json.dumps(status,indent=2));print(json.dumps(status),flush=True)
if __name__=='__main__':main()
