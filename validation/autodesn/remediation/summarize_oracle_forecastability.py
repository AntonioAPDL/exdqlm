"""Reproduce the known-state training-panel risk figure and numeric summary."""
from pathlib import Path
import hashlib,json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
r=Path('validation/autodesn/remediation')
roots=list((r/'artifacts/oracle_forecastability').glob('*/status.json'))
assert len(roots)==1
p=roots[0];s=json.loads(p.read_text());assert s['complete'] and s['monte_carlo_screen_passed'];d=p.parent
N=s['path_screens'][-1]['paths']
panel=pd.read_csv(d/f'paths_{N}.csv');h=pd.read_csv(d/'horizon_summary.csv')
fig,axes=plt.subplots(1,2,figsize=(10,3.6))
for _,t in panel.groupby('origin'):axes[0].plot(t.horizon,np.sqrt(t.predictive_variance),color='#b8c5ce',lw=.8,alpha=.65)
axes[0].plot(h.horizon,h.oracle_rmse_floor,color='#2275a5',lw=2,label='Equal-origin conditional risk')
axes[0].axhline(s['training_response_sd'],color='#59636d',ls='--',lw=1,label='Training response SD')
axes[0].set(xlabel='Forecast horizon',ylabel='Oracle conditional RMSE floor',title='Known DGP and true origin state')
axes[0].legend(frameon=False,fontsize=8);axes[0].grid(alpha=.15)
axes[1].stackplot(h.horizon,h.expected_innovation_variance,h.dynamic_mean_variance,colors=['#2275a5','#228877'],labels=['Future innovation variance','Propagation through nonlinear states'],alpha=.85)
axes[1].set(xlabel='Forecast horizon',ylabel='Conditional predictive variance',title='Law of total variance, fixed training panel')
axes[1].legend(frameon=False,fontsize=8,loc='lower right');axes[1].grid(alpha=.15)
for a in axes:a.spines[['top','right']].set_visible(False)
fig.tight_layout();out=r/'output/figures/oracle_forecastability.png';fig.savefig(out,dpi=180,bbox_inches='tight');plt.close(fig)
files=[p,d/f'paths_{N}.csv',d/'horizon_summary.csv',Path(__file__)]
record=dict(s,artifact_directory=str(d),source_status_sha256=hashlib.file_digest(p.open('rb'),'sha256').hexdigest(),figure=str(out),figure_sha256=hashlib.file_digest(out.open('rb'),'sha256').hexdigest(),horizon_results=h[h.horizon.isin([1,5,15,30])].to_dict('records'),maximum_relative_variance_mcse=float((panel.variance_mcse/panel.predictive_variance).max()),maximum_mean_mcse=float(panel.mean_mcse.max()),inputs={str(f):hashlib.file_digest(f.open('rb'),'sha256').hexdigest() for f in files},interpretation='At the fixed training-origin panel, even the privileged known-state predictor has a conditional RMSE floor about0.44 at horizon1 and0.58 at horizon30. These are conditional future risks, not scores on realized test observations. Do not compare them numerically to held-out model RMSE from different origins or claim population bounds. About40% of horizon30 variance comes from nonlinear propagation of future innovations; the rest is expected innovation variance. This does not qualify any candidate posterior or full benchmark.')
(r/'evidence/oracle_forecastability.json').write_text(json.dumps(record,indent=2)+'\n')
print('Oracle summary and figure reproduced',record['figure_sha256'])
