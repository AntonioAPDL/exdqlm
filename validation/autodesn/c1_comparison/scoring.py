"""Exact marginal Gaussian-mixture scoring and causal Gaussian conditioning."""
from __future__ import annotations
import numpy as np
from scipy.special import ndtr, logsumexp
from scipy.optimize import brentq

def condition_one(mu, covariance, observed):
    """Remove the first index, conditioned on that observed response only."""
    v=float(covariance[0,0])
    if not np.isfinite(v) or v<=0:
        raise ValueError("Nonpositive conditional predictive variance")
    cross=covariance[1:,0].copy()
    m=mu[1:]+cross/v*(observed-mu[0])
    c=covariance[1:,1:]-np.outer(cross,cross)/v
    c=(c+c.T)/2
    return m,c

def normal_abs_expectation(delta,sd):
    z=delta/sd
    return 2*sd*np.exp(-.5*z*z)/np.sqrt(2*np.pi)+delta*(2*ndtr(z)-1)

def mixture_score(actual,mu,sd,weights):
    mu=np.asarray(mu,float);sd=np.asarray(sd,float);w=np.asarray(weights,float)
    if not (np.all(np.isfinite(mu)) and np.all(np.isfinite(sd)) and np.all(sd>0)
            and np.all(w>=0) and abs(w.sum()-1)<1e-10):
        raise ValueError("Invalid mixture")
    positive=w>0;mu=mu[positive];sd=sd[positive];w=w[positive]
    m=float(w@mu); variance=float(w@(sd*sd+(mu-m)**2))
    first=w@normal_abs_expectation(actual-mu,sd)
    second=(w[:,None]*w[None,:]*normal_abs_expectation(mu[:,None]-mu[None,:],np.hypot(sd[:,None],sd[None,:]))).sum()/2
    crps=float(first-second)
    nll=float(-logsumexp(np.log(w)-np.log(sd)-.5*np.log(2*np.pi)-.5*((actual-mu)/sd)**2))
    lo=float(np.min(mu-12*sd));hi=float(np.max(mu+12*sd))
    q=[brentq(lambda x:float(w@ndtr((x-mu)/sd))-p,lo,hi,xtol=1e-11) for p in (.05,.25,.5,.75,.95)]
    return dict(mean=m,predictive_sd=np.sqrt(variance),lower90=q[0],lower50=q[1],median=q[2],
        upper50=q[3],upper90=q[4],squared_error=(m-actual)**2,absolute_error=abs(m-actual),
        crps=crps,negative_log_score=nll,covered50=q[1]<=actual<=q[3],
        covered90=q[0]<=actual<=q[4],width50=q[3]-q[1],width90=q[4]-q[0])
