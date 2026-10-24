"""Training-selected linear lag/phase diagnostic forecasts; not Bayesian AutoDESN."""
from pathlib import Path
import json,time
import numpy as np,pandas as pd
from scipy.stats import norm
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;OUT=HERE/'artifacts'

def design(y,ts,lags,phase):
 A=y[np.asarray(ts)[:,None]-1-np.asarray(lags)[None,:]] if lags else np.empty((len(ts),0))
 if phase:A=np.column_stack([A,((np.asarray(ts)[:,None]-1)%60==np.arange(59)[None,:]).astype(float)])
 return A

def fit_path(y,ts,lags,phase,lambdas):
 F=design(y,ts,lags,phase);c=F.mean(0);s=F.std(0,ddof=1);A=(F-c)/s;target=y[ts-1];e,V=np.linalg.eigh(A.T@A/len(A));v=V.T@(A.T@(target-target.mean())/len(A));result=[]
 for lam in lambdas:
  denom=e+lam
  if lam==0:denom=np.where(e>max(e)*1e-12,denom,np.inf)
  b=(V@(v/denom))/s;intercept=target.mean()-c@b;variance=np.mean((target-intercept-F@b)**2)
  result.append(dict(beta=b,intercept=intercept,variance=variance,lags=lags,phase=phase,lambda_=lam))
 return result

def forecast(f,y,origins,H=30):
 lags=np.array(f['lags']);p=len(lags);long=max(lags) if p else 1;means=[];phi=np.zeros(long+1);phi[lags]=f['beta'][:p];psi=np.zeros(H);psi[0]=1
 for j in range(1,H):psi[j]=sum(phi[k]*psi[j-k] for k in range(1,min(j,long)+1))
 v=f['variance']*np.cumsum(psi*psi)
 for o in origins:
  hist=list(y[o-long:o]);m=[]
  for h in range(1,H+1):
   value=f['intercept']+sum(f['beta'][k]*hist[-lag] for k,lag in enumerate(lags))
   ph=(o+h-1)%60
   if f['phase'] and ph<59:value+=f['beta'][p+ph]
   m.append(value);hist.append(value)
  means.append(m)
 return np.asarray(means),v

def main():
 cfg=json.loads((HERE/'protocol.json').read_text());y=pd.read_csv(ROOT/'input/series.csv').y.to_numpy();lambdas=cfg['ridge_penalties'];cases={'AR4':([1,2,12,60],False),'AR60':(list(range(1,61)),False),'AR90':(list(range(1,91)),False),'AR4_phase60':([1,2,12,60],True),'AR60_phase60':(list(range(1,61)),True),'AR90_phase60':(list(range(1,91)),True)}
 cv=[];scores=[];fits={};o=np.arange(2500,2971);val_o=np.arange(2000,2471);actual=y[o[:,None]+np.arange(30)];val_y=y[val_o[:,None]+np.arange(30)]
 for name,(lags,phase) in cases.items():
  path=fit_path(y,np.arange(501,2001),lags,phase,lambdas);errs=[np.mean((forecast(f,y,val_o)[0]-val_y)**2) for f in path];best=int(np.argmin(errs));f=fit_path(y,np.arange(501,2501),lags,phase,[lambdas[best]])[0];m,v=forecast(f,y,o);sd=np.sqrt(v)[None,:];z=(actual-m)/sd
  for k,err in enumerate(errs):cv.append(dict(model=name,lambda_=lambdas[k],validation_RMSE=np.sqrt(err),selected=k==best))
  row=pd.DataFrame(dict(origin=np.repeat(o,30),horizon=np.tile(np.arange(1,31),len(o)),target=(o[:,None]+np.arange(1,31)).ravel(),actual=actual.ravel(),mean=m.ravel(),predictive_sd=np.broadcast_to(sd,m.shape).ravel(),squared_error=((actual-m)**2).ravel(),absolute_error=abs(actual-m).ravel(),crps=(sd*(z*(2*norm.cdf(z)-1)+2*norm.pdf(z)-1/np.sqrt(np.pi))).ravel(),negative_log_score=(-norm.logpdf(actual,m,sd)).ravel(),covered50=(abs(z)<=norm.ppf(.75)).ravel(),covered90=(abs(z)<=norm.ppf(.95)).ravel(),width50=np.broadcast_to(2*norm.ppf(.75)*sd,m.shape).ravel(),width90=np.broadcast_to(2*norm.ppf(.95)*sd,m.shape).ravel()))
  row['model']=name;scores.append(row);fits[name]={**f,'beta':f['beta'].tolist(),'validation_RMSE':np.sqrt(errs[best]),'selection_only_training':True}
 pd.concat(scores).to_csv(OUT/'lag_ablation_scores.csv.gz',index=False);pd.DataFrame(cv).to_csv(OUT/'lag_ablation_selection.csv',index=False)
 (OUT/'lag_ablation_fits.json').write_text(json.dumps(fits,indent=2));best=min(fits,key=lambda k:fits[k]['validation_RMSE']);(OUT/'lag_ablation_status.json').write_text(json.dumps(dict(complete=True,best_family_by_validation=best,period_and_AR4_lags_DGP_informed=True,AR60_and_AR90_generic_lag_windows=True,fitted_once=2500,nonBayesian_plugin_Gaussian_diagnostic=True),indent=2));print('Lag/phase diagnostic complete; validation-selected:',best)
if __name__=='__main__':main()
