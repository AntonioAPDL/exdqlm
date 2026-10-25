"""Descriptive training diagnostics, without held-out scoring or run selection."""
import hashlib,json,tomllib
from pathlib import Path
import numpy as np
import pandas as pd
r=Path('validation/autodesn/remediation');inputs={}
def csv(p):
    inputs[str(p)]=hashlib.sha256(p.read_bytes()).hexdigest();return pd.read_csv(p)
p=r/'artifacts/gp_training_audit16/status.toml'
inputs[str(p)]=hashlib.sha256(p.read_bytes()).hexdigest();status=tomllib.loads(p.read_text())
assert status['complete'] and not status['pooled']
truth=csv(r/'evidence/F1_production_256000_joint128_recoverable_training_function.csv')
evidence=csv(r/'evidence/gp16_evidence_audit.csv').set_index('seed')
rows=[]
for s in status['replicates']:
    seed=s['seed'];t=csv(r/'artifacts/gp_training_audit16'/f'training_s{seed}.csv')
    assert np.array_equal(t.time,truth.time) and np.max(np.abs(t.observed-truth.y))<1e-12
    rows.append(dict(seed=seed,training_observed_rmse=float(np.sqrt(np.mean((t['mean']-truth.y)**2))),training_conditional_mean_rmse=float(np.sqrt(np.mean((t['mean']-truth.conditional_mean)**2))),conditional_mean_correlation=float(np.corrcoef(t['mean'],truth.conditional_mean)[0,1]),particle_ess=s['particle_ess'],maximum_particle_weight=s['maximum_particle_weight'],corrected_log_evidence=evidence.loc[seed,'log_evidence'],native_api_partial_log_evidence=evidence.loc[seed,'pre_resampling_accumulator'],maximum_native_probe_error=max(s['native_probe_max_errors'])))
table=pd.DataFrame(rows);table.to_csv(r/'evidence/gp16_training_diagnostics.csv',index=False)
logz=table.corrected_log_evidence.to_numpy();w=np.exp(logz-logz.max());w/=w.sum()
summary=dict(complete=True,replicas=4,rows=2000,particles=16,log_evidence_range=float(np.ptp(logz)),normalized_evidence_weights=w.tolist(),effective_number_of_evidence_weighted_replicas=float(1/np.sum(w*w)),maximum_native_probe_error=float(table.maximum_native_probe_error.max()),all_replicas_included=True,heldout_used=False,pooled_forecasts_issued=False,posterior_qualified=False,mode_budget_screen_passed=False,reason='Four completed runs have grossly different evidence estimates and near-single-replica weight dominance. This budget is not computationally qualified; lower observed training residual error does not establish forecasting quality.',inputs=inputs,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope='Descriptive conditional training audit of all four registered replicas. Corrected normalizers agree algebraically with Gen; independent small-target integration is separately recorded. No selection or hyperparameter change uses these outputs.')
(r/'evidence/gp16_training_diagnostics.json').write_text(json.dumps(summary,indent=2)+'\n')
print(table.to_string(index=False));print(json.dumps({k:v for k,v in summary.items() if k!='inputs'}))
