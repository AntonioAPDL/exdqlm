"""Independent split rank/folded R-hat and FFT Geyer bulk/tail ESS."""
import numpy as np
from scipy.stats import rankdata,norm

def split(x):
 n=x.shape[1]//2
 return np.concatenate([x[:,:n],x[:,-n:]],axis=0)
def rank(x):return norm.ppf((rankdata(x).reshape(x.shape)-.375)/(x.size+.25))
def rhat(x):
 m,n=x.shape;w=np.var(x,axis=1,ddof=1).mean()
 return np.sqrt(((n-1)/n*w+np.var(x.mean(axis=1),ddof=1))/w) if w>0 else np.nan
def ess(x):
 m,n=x.shape
 if n<4 or np.var(x)==0:return np.nan
 z=x-x.mean(axis=1,keepdims=True);ft=np.fft.rfft(z,n=2**int(np.ceil(np.log2(2*n))),axis=1)
 ac=np.fft.irfft(ft*np.conjugate(ft),axis=1)[:,:n]/n
 w=ac[:,0].mean()*n/(n-1);vp=w*(n-1)/n+np.var(x.mean(axis=1),ddof=1)
 if vp<=0:return np.nan
 rho=1-(w-ac.mean(axis=0))/vp;rho[0]=1
 paired=rho[:2*(n//2)].reshape(-1,2).sum(axis=1);stop=np.where(paired<=0)[0]
 if len(stop):paired=paired[:stop[0]]
 if not len(paired):return np.nan
 return m*n/max(-1+2*np.minimum.accumulate(paired).sum(),1/np.log10(m*n))
def diagnostics(x):
 x=split(x);z=rank(x);lo,hi=np.quantile(x,[.05,.95])
 return dict(rhat=max(rhat(z),rhat(rank(abs(x-np.median(x))))),bulk_ess=ess(z),
  tail_ess=min(ess((x<=lo).astype(float)),ess((x>=hi).astype(float))))
