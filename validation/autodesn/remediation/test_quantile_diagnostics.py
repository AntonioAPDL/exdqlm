"""Analytic Gaussian and symmetry references for predictive quantile diagnostics."""
import json
from pathlib import Path
import numpy as np
from scipy.stats import norm
from cross_budget import quantile_summary

checks=[]
# A single Gaussian: exact analytic quantiles and zero posterior MC variance.
for p in [.05,.25,.5,.75,.95]:
 q,se=quantile_summary(np.full((4,1024),1.3),np.full((4,1024),.49),p)
 expected=1.3+.7*norm.ppf(p)
 assert abs(q-expected)<1e-10 and se<1e-12
 checks.append(dict(kind='analytic_normal',probability=p,error=abs(q-expected),mcse=se))
# Symmetric separated components: a single-Gaussian quantile shortcut is wrong
# in the tails, while the median must remain exactly the symmetry center.
means=np.tile(np.r_[np.full(512,-2.),np.full(512,2.)],(4,1))
q,se=quantile_summary(means,np.full_like(means,.25),.5)
assert abs(q)<1e-10 and se>0
checks.append(dict(kind='separated_symmetric_median',error=abs(q),mcse=se))
# A common translation changes quantiles but leaves their uncertainty unchanged.
q2,se2=quantile_summary(means+7,np.full_like(means,.25),.5)
assert abs(q2-q-7)<1e-10 and abs(se2-se)<1e-10
checks.append(dict(kind='translation_equivariance',error=abs(q2-q-7),mcse_difference=abs(se2-se)))
for variance in [np.zeros((4,1024)),np.full((4,1024),np.nan)]:
 try:quantile_summary(means,variance,.5)
 except ValueError:pass
 else:raise AssertionError('Invalid variances accepted')
record=dict(complete=True,passed=True,checks=checks,invalid_inputs_rejected=2,
 scope='Fixed-design Gaussian-mixture quantiles and batch influence MCSE; not recursive predictive Monte Carlo qualification')
Path('validation/autodesn/remediation/evidence/quantile_diagnostics.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record))
