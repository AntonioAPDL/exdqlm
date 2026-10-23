"""Audit R predictive summaries against raw samples using NumPy/SciPy."""
import json
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.special import logsumexp
ROOT=Path(__file__).resolve().parent
def audit():
    d=ROOT/'artifacts/desn';scores=pd.read_csv(d/'scores.csv');errors=[]
    for origin in (2500,2735,2970):
        samples=pd.read_csv(d/f'forecast_samples_{origin}.csv.gz')
        for h,g in samples.groupby('horizon'):
            ref=scores[(scores.origin==origin)&(scores.horizon==h)].iloc[0];y=ref.actual
            x=g.yrep.to_numpy();n=len(x);sx=np.sort(x)
            crps=np.mean(abs(x-y))-np.dot(2*np.arange(1,n+1)-n-1,sx)/n**2
            quantiles=np.quantile(x,[.05,.25,.5,.75,.95],method='median_unbiased')
            nll=-(logsumexp(-np.log(g.sd)-.5*np.log(2*np.pi)-.5*((y-g.mu)/g.sd)**2)-np.log(n))
            delta=max(abs(crps-ref.crps),abs(nll-ref.negative_log_score),abs(g.mu.mean()-ref['mean']),
                np.max(abs(quantiles-ref[['lower90','lower50','median','upper50','upper90']].to_numpy(dtype=float))))
            assert delta<1e-9,(origin,h,delta)
            errors.append(delta)
    result=dict(complete=True,checked_marginals=len(errors),max_absolute_error=max(errors))
    (d/'cross_language_score_audit.json').write_text(json.dumps(result,indent=2));print(result)
if __name__=='__main__':audit()
