"""Exact NHS1 simulator continuation and high-budget conditional-risk audit."""
from pathlib import Path
import json,hashlib,time
import numpy as np,pandas as pd
from scipy.special import logsumexp
from scipy.stats import norm
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;OUT=HERE/'artifacts';OUT.mkdir(exist_ok=True)

def pulse(t,a,b):
 p=((t-1)%60)/60;d=min(abs(p-a),1-abs(p-a));return max(0.,1-d/b)
def season(t):
 def wave(k):return pulse(k,.18,.1)-.8*pulse(k,.64,.18)+.35*(2*((k-1)%60)/60-1)+.18*(1 if (k-1)%12<4 else -.5)
 return wave(t)-np.mean([wave(k) for k in range(1,61)])
def location(a,b,c,d):return np.where(a<0,.58,.22)*a+.28*np.tanh(1.4*b)-.25*np.tanh(c)+.22*np.tanh(d)+.20*np.tanh(1.5*a*b)
def score_sample(y,mu,v,actual):
 n=len(y);z=np.sort(y);q=np.quantile(y,[.05,.25,.5,.75,.95]);mean=float(mu.mean())
 return dict(mean=mean,predictive_sd=float(np.sqrt(v.mean()+np.var(mu))),variance=float(v.mean()+np.var(mu)),mean_mcse=float(np.std(mu,ddof=1)/np.sqrt(n)),
  lower90=q[0],lower50=q[1],median=q[2],upper50=q[3],upper90=q[4],squared_error=(mean-actual)**2,absolute_error=abs(mean-actual),
  crps=float(np.mean(abs(y-actual))-np.dot(2*np.arange(1,n+1)-n-1,z)/n**2),negative_log_score=float(-logsumexp(norm.logpdf(actual,mu,np.sqrt(v)))+np.log(n)),
  covered50=bool(q[1]<=actual<=q[3]),covered90=bool(q[0]<=actual<=q[4]),width50=q[3]-q[1],width90=q[4]-q[0])
def main():
 cfg=json.loads((HERE/'protocol.json').read_text());contract=dict(protocol_sha256=hashlib.sha256((HERE/'protocol.json').read_bytes()).hexdigest(),truth_sha256=hashlib.sha256((ROOT/'input/dgp_truth.csv').read_bytes()).hexdigest());guard=OUT/'oracle_cache_contract.json'
 if guard.exists():assert json.loads(guard.read_text())==contract,'Oracle cache contract changed; use a clean output directory'
 else:guard.write_text(json.dumps(contract,indent=2))
 truth=pd.read_csv(ROOT/'input/dgp_truth.csv');x=truth.residual.to_numpy();y=truth.y.to_numpy();N=cfg['oracle_paths_per_origin'];H=30;rows=[];half=[];started=time.perf_counter()
 # Independent verification of generator location, variance and retained season.
 times=np.arange(61,3001);idx=times-1
 check_mu=np.array([season(t) for t in times])+location(x[idx-1],x[idx-2],x[idx-12],x[idx-60])
 eps=truth.conditional_sd.to_numpy()*truth.innovation.to_numpy();h=truth.conditional_sd.to_numpy()**2
 check_h=np.array([.008+.018*pulse(t,.18,.1)+.012*pulse(t,.64,.18) for t in times])+.008*np.tanh(x[idx-1])**2+.06*eps[idx-1]**2+.10*eps[idx-1]**2*(eps[idx-1]<0)+.82*h[idx-1]
 assert np.max(abs(check_mu-truth.conditional_mean.to_numpy()[idx]))<1e-12
 assert np.max(abs(check_h-h[idx]))<1e-12
 assert np.max(abs(y-x-np.array([season(t) for t in range(1,3001)])))<1e-12
 for o in range(2500,2971):
  cache=OUT/f'oracle_{o}.csv'
  if cache.exists():rows.extend(pd.read_csv(cache).to_dict('records'));half.extend(pd.read_csv(OUT/f'half_{o}.csv').to_dict('records'));continue
  rng=np.random.default_rng(np.random.SeedSequence([cfg['oracle_seed'],o]));buffer=np.repeat(x[o-60:o,None],N,axis=1);pos=0;error=np.full(N,eps[o-1]);var=np.full(N,h[o-1]);local=[];halflocal=[]
  for lead in range(1,H+1):
   t=o+lead;a=buffer[(pos-1)%60];b=buffer[(pos-2)%60];c=buffer[(pos-12)%60];d=buffer[pos]
   var=.008+.018*pulse(t,.18,.1)+.012*pulse(t,.64,.18)+.008*np.tanh(a)**2+.06*error**2+.10*error**2*(error<0)+.82*var
   f=location(a,b,c,d);mu=season(t)+f;error=np.sqrt(var)*rng.standard_normal(N);nextx=f+error;yp=season(t)+nextx;actual=y[t-1]
   score=score_sample(yp,mu,var,actual);small=score_sample(yp[:N//2],mu[:N//2],var[:N//2],actual)
   if lead==1:
    assert abs(mu[0]-truth.conditional_mean.iloc[t-1])<1e-12 and abs(var[0]-h[t-1])<1e-12
    sigma=np.sqrt(var[0]);z=(actual-mu[0])/sigma;score.update(variance=var[0],predictive_sd=sigma,mean_mcse=0.,crps=sigma*(z*(2*norm.cdf(z)-1)+2*norm.pdf(z)-1/np.sqrt(np.pi)),negative_log_score=-norm.logpdf(actual,mu[0],sigma))
   score.update(origin=o,horizon=lead,target=t,actual=actual,mean_half_a=float(mu[:N//2].mean()),mean_half_b=float(mu[N//2:].mean()))
   small.update(origin=o,horizon=lead,target=t,actual=actual);local.append(score);halflocal.append(small)
   buffer[pos]=nextx;pos=(pos+1)%60
  pd.DataFrame(local).to_csv(cache,index=False);pd.DataFrame(halflocal).to_csv(OUT/f'half_{o}.csv',index=False);rows.extend(local);half.extend(halflocal)
  if (o-2500)%25==0:print('Oracle',o,'elapsed',round(time.perf_counter()-started,1),flush=True)
 result=pd.DataFrame(rows);small=pd.DataFrame(half);assert len(result)==14130;result.to_csv(OUT/'oracle_scores.csv',index=False);small.to_csv(OUT/'oracle_half_scores.csv',index=False)
 status=dict(complete=True,paths_per_origin=N,pairs=14130,origins=471,elapsed_seconds=time.perf_counter()-started,maximum_mean_mcse=float(result.mean_mcse.max()),rms_mean_mcse=float(np.sqrt(np.mean(result.mean_mcse**2))),one_step_mu_error=float(np.max(abs(check_mu-truth.conditional_mean.to_numpy()[idx]))),variance_recursion_error=float(np.max(abs(check_h-h[idx]))),truth_sha256=hashlib.sha256((ROOT/'input/dgp_truth.csv').read_bytes()).hexdigest(),privileged_DGP_oracle=True,future_observations_used_within_forecast=False)
 (OUT/'oracle_status.json').write_text(json.dumps(status,indent=2));print(json.dumps(status),flush=True)
if __name__=='__main__':main()
