"""Audit fresh NHS1 forecasts and compare all models without reusing C1 scores."""
import argparse,json,hashlib,sys
from pathlib import Path
import numpy as np,pandas as pd
from support import configuration,validate_scores,audit_paths,aggregate,validate_gp_evidence,sha256
HERE=Path(__file__).resolve().parent
LABELS={'requested':'AutoDESN RHS: 0.001 / 1','scaling_only':'AutoDESN RHS: 1 / 2','ridge_standardized':'AutoDESN ridge','gp':'Native AutoGP'}
def main():
 p=argparse.ArgumentParser();p.add_argument('--data',type=Path,default=HERE/'artifacts');a=p.parse_args()
 b=a.data;c=b/'comparison';c.mkdir(exist_ok=True);cfg=configuration();study=json.loads((HERE/'study.json').read_text())
 scores=[];audits={};diagnostics=[];budgets=[];geometry=None;definitions=None
 bank=json.loads((b/'standardized_bank/status.json').read_text())
 assert bank['unit_variance'] and not bank['dimension_normalization']
 assert bank['max_abs_mean']<1e-9 and bank['max_sd_error']<1e-9
 for sc in study['scenarios']:
  d=b/sc['id']/sc['method'];st=json.loads((d/'status.json').read_text());pr=json.loads((d/'provenance.json').read_text());saved=pr['configuration']
  assert st['complete'] and st['qualified'] and st['score_pairs']==14130 and st['origins']==471
  assert not st['posterior_updates'] and not st['model_weight_updates']
  assert st['contract_id']==pr['contract_id']
  assert saved['readout_standardization']['standardize_features'] and not saved['readout_standardization']['normalize_features']
  for k in ['input_sha256','washout','fit_start','fit_end','n_train','first_origin','last_origin','H','outer_draws','inner_paths','innovation_seed']:assert saved[k]==cfg[k],k
  if sc['method']=='rhs':assert saved['rhs_control']==dict({k:sc[k] for k in ['tau0','slab_scale','slab_df']},**study['sampler'])
  for source in pr['production_source']+pr.get('harness_source',[])+saved.get('extra_harness_source',[]):assert sha256(HERE.parents[2]/source['path'])==source['sha256']
  this=(st['bank_id'],pr['production_source'])
  if geometry is None:geometry=this
  else:assert geometry==this
  models=pd.read_csv(d/'model_probabilities.csv');dd=models[['model','candidate','D','prior_probability']]
  if definitions is None:definitions=dd
  else:pd.testing.assert_frame_equal(definitions,dd)
  screen=json.loads((d/'independent_screen.json').read_text());assert screen['passed'] and screen['checked_before_forecasting']
  z=pd.read_csv(d/'independent_diagnostics.csv');assert (z.rhat<=1.01).all() and (z.bulk_ess>=400).all() and (z.tail_ess>=400).all()
  z['scenario']=sc['id'];diagnostics.append(z)
  parity=json.loads((d/'transport_parity.json').read_text());assert parity['complete'] and parity['max_path_error']<1e-10 and not parity['future_observations_used']
  causality=json.loads((d/'causality_audit.json').read_text());assert causality['complete'] and causality['max_path_error']==0
  rows=validate_scores(pd.read_csv(d/'scores.csv'),cfg,'AutoDESN RHS' if sc['method']=='rhs' else 'AutoDESN ridge')
  audits[sc['id']]=audit_paths(d,rows,cfg);rows['model']=LABELS[sc['id']];scores.append(rows)
 for case in list(study['scenarios'])+[dict(id=x.name,method='rhs') for x in b.iterdir() if x.name.endswith(('_initial_proposal','_rebalanced_64k','_joint_initial'))]:
  d=b/case['id']/case['method']
  if not d.exists():continue
  controls=json.loads((d/'provenance.json').read_text())['configuration']['attempts']
  for ad in sorted(d.glob('attempt_*')):
   st=json.loads((ad/'status.json').read_text());ctl=controls[int(st['attempt'])-1]
   z=pd.read_csv(ad/'diagnostics.csv');z=z[z.sampled];md=pd.read_csv(ad/'model_probabilities.csv')
   budgets.append(dict(scenario=case['id'],**{**st,**ctl},max_rhat=z.rhat.max(),min_ess=z.ess_spectral.min(),max_model_frequency_range=md.chain_range.max()))
 gp=b/'gp';st=json.loads((gp/'status.json').read_text());assert st['complete'] and not st['reused'] and st['native_checks_passed']
 assert st['source_contract']['input_sha256']==cfg['input_sha256']
 audits['gp_native']=validate_gp_evidence(gp)
 rows=validate_scores(pd.read_csv(gp/'scores.csv'),cfg,'AutoGP');rows['model']=LABELS['gp'];scores.append(rows)
 all_scores=pd.concat(scores,ignore_index=True);all_scores.to_csv(c/'all_scores.csv.gz',index=False)
 pooled=pd.DataFrame([dict(model=label,**aggregate(g)) for label,g in all_scores.groupby('model',sort=False)])
 pooled.to_csv(c/'pooled_metrics.csv',index=False)
 pd.DataFrame([dict(model=label,horizon=h,**aggregate(g)) for (label,h),g in all_scores.groupby(['model','horizon'],sort=False)]).to_csv(c/'horizon_metrics.csv',index=False)
 pd.concat(diagnostics,ignore_index=True).to_csv(c/'independent_diagnostics.csv',index=False)
 pd.DataFrame(budgets).to_csv(c/'mcmc_budget_sensitivity.csv',index=False)
 sensitivity=[]
 for sc in study['scenarios']:
  frame=pd.read_csv(b/sc['id']/sc['method']/'mc_sensitivity.csv');assert len(frame)==720
  for (n,k),g in frame.groupby(['outer_draws','inner_paths']):sensitivity.append(dict(scenario=sc['id'],N=n,K=k,**aggregate(g)))
 pd.DataFrame(sensitivity).to_csv(c/'mc_sensitivity_summary.csv',index=False)
 # One-step variance is conditional on observed history. Do not confuse the
 # realized future innovation SD with a multi-step marginal predictive SD.
 truth=pd.read_csv(HERE/'input/dgp_truth.csv').set_index('time')
 cuts=np.quantile(truth.loc[501:2500,'conditional_sd'],[1/3,2/3])
 calibration=[]
 one=all_scores[all_scores.horizon==1].copy();one['true_conditional_sd']=truth.loc[one.target,'conditional_sd'].to_numpy()
 one['true_conditional_mean']=truth.loc[one.target,'conditional_mean'].to_numpy()
 one['volatility_band']=pd.cut(one.true_conditional_sd,[-np.inf,*cuts,np.inf],labels=['low','middle','high'])
 one.to_csv(c/'one_step_calibration.csv',index=False)
 for (model,band),g in one.groupby(['model','volatility_band'],observed=True):
  calibration.append(dict(model=model,band=band,**aggregate(g),mean_true_sd=g.true_conditional_sd.mean(),mean_predictive_sd=g.predictive_sd.mean(),conditional_mean_RMSE=float(np.sqrt(np.mean((g['mean']-g.true_conditional_mean)**2)))))
 pd.DataFrame(calibration).to_csv(c/'calibration_by_volatility.csv',index=False)
 audit=dict(complete=True,new_DGP=True,reference_inference_reused=False,pairs_per_model=14130,dgp_realizations=1,dependent_rolling_pairs=True,path_audits=audits,one_step_volatility_cuts_from_training=cuts.tolist())
 (c/'audit.json').write_text(json.dumps(audit,indent=2));print(pooled.to_string(index=False))
if __name__=='__main__':main()
