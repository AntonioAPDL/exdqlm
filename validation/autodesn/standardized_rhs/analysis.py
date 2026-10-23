"""Audit/compare all completed standardized fits with the frozen references."""
import argparse,gzip,io,json,sys,zipfile,hashlib
from pathlib import Path
import numpy as np,pandas as pd
from diagnostics import diagnostics
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'rhs_comparison'))
from support import configuration,validate_scores,audit_paths,aggregate
LABELS={'requested':'RHS: standardized, tau0=0.001, slab=1',
 'scaling_only':'RHS: standardized, tau0=1, slab=2','ridge_standardized':'Ridge: standardized'}

def main():
 p=argparse.ArgumentParser();p.add_argument('--data',type=Path,default=HERE/'artifacts');a=p.parse_args();out=a.data/'comparison';out.mkdir(exist_ok=True)
 study=json.loads((HERE/'configuration.json').read_text());cfg=configuration();scores=[];records=[];diagnostic_rows=[];budgets=[];audit={};shared=None;shared_models=None
 for sc in study['scenarios']:
  d=a.data/sc['id']/sc['method'];st=json.loads((d/'status.json').read_text())
  assert st['complete'] and st['qualified'] and st['score_pairs']==14130 and st['origins']==471
  assert not st['posterior_updates'] and not st['model_weight_updates']
  provenance=json.loads((d/'provenance.json').read_text());saved=provenance['configuration']
  assert provenance['contract_id']==st['contract_id']
  assert saved['readout_standardization']['standardize_features'] and not saved['readout_standardization']['normalize_features']
  for key in ['input_sha256','washout','fit_start','fit_end','n_train','first_origin','last_origin','H','outer_draws','inner_paths','innovation_seed']:
   assert saved[key]==cfg[key],key
  if sc['method']=='rhs':assert saved['rhs_control']==dict({k:sc[k] for k in ['tau0','slab_scale','slab_df']},**study['sampler'])
  for source in provenance['production_source']:
   assert hashlib.sha256((HERE.parents[2]/source['path']).read_bytes()).hexdigest()==source['sha256']
  geometry=(st['bank_id'],provenance['production_source'])
  if shared is None:shared=geometry
  else:assert geometry==shared
  tr=pd.read_csv(d/'traces.csv.gz');params=['variance','ridge_precision'] if sc['method']=='ridge' else ['variance','log_global','log_slab','mean_log_local','intercept','fitted_rms','effective_slopes_diagonal']
  models=pd.read_csv(d/'model_probabilities.csv')
  definitions=models[['model','candidate','D','prior_probability']]
  if shared_models is None:shared_models=definitions
  else:pd.testing.assert_frame_equal(shared_models,definitions)
  parity=json.loads((d/'transport_parity.json').read_text());assert parity['complete'] and parity['max_path_error']<1e-10 and not parity['future_observations_used']
  for name in params:
   x=np.array([g[name].to_numpy() for _,g in tr.groupby('chain')]);diagnostic_rows.append(dict(scenario=sc['id'],parameter=name,**diagnostics(x)))
  for m in models.loc[models.posterior_probability>=.01,'model']:
   x=np.array([(g.model.to_numpy()==m).astype(float) for _,g in tr.groupby('chain')]);diagnostic_rows.append(dict(scenario=sc['id'],parameter=f'model_{m}',**diagnostics(x)))
  rows=pd.read_csv(d/'scores.csv');label='AutoDESN RHS' if sc['method']=='rhs' else 'AutoDESN ridge'
  rows=validate_scores(rows,cfg,label);audit[sc['id']]=audit_paths(d,rows,cfg)
  rows['model']=LABELS[sc['id']];rows['scenario']=sc['id'];scores.append(rows)
  records.append(dict(scenario=sc['id'],**aggregate(rows)))
  for ad in sorted(d.glob('attempt_*')):
   s=json.loads((ad/'status.json').read_text());dd=pd.read_csv(ad/'diagnostics.csv');mm=pd.read_csv(ad/'model_probabilities.csv')
   dd=dd[dd.sampled]
   budgets.append(dict(scenario=sc['id'],**s,max_rhat=dd.rhat.max(),min_ess=dd.ess_spectral.min(),
    leading_model=int(mm.loc[mm.posterior_probability.idxmax(),'model']),leading_probability=mm.posterior_probability.max()))
 legacy=a.data/'legacy_prefix_requested/rhs'
 if legacy.exists():
  for ad in sorted(legacy.glob('attempt_*')):
   s=json.loads((ad/'status.json').read_text());dd=pd.read_csv(ad/'diagnostics.csv');mm=pd.read_csv(ad/'model_probabilities.csv');dd=dd[dd.sampled]
   budgets.append(dict(scenario='legacy_prefix_requested',**s,max_rhat=dd.rhat.max(),min_ess=dd.ess_spectral.min(),
    max_architecture_rhat=mm.loc[mm.posterior_probability>=.01,'rhat_indicator'].max(),
    model_chain_range=mm.chain_range.max(),leading_model=int(mm.loc[mm.posterior_probability.idxmax(),'model']),leading_probability=mm.posterior_probability.max()))
 diagnostics_table=pd.DataFrame(diagnostic_rows);diagnostics_table.to_csv(out/'independent_diagnostics.csv',index=False)
 assert (diagnostics_table.rhat<=1.01).all() and (diagnostics_table.bulk_ess>=400).all() and (diagnostics_table.tail_ess>=400).all(),'Independent posterior screen failed'
 archive=HERE.parent/'rhs_comparison/evidence/C1_numeric_evidence.zip'
 if not archive.exists():
  parts=sorted(archive.parent.glob(archive.name+'.part-*'));assert len(parts)==2
  with archive.open('wb') as f:
   for part in parts:f.write(part.read_bytes())
 with zipfile.ZipFile(archive) as z:
  manifest=json.loads(z.read('SHA256.json'))
  for name,expected in manifest.items():assert hashlib.sha256(z.read(name)).hexdigest()==expected,name
  for key,label in [('ridge','Ridge: original basis'),('rhs','RHS: original basis, tau0=1, slab=2'),('gp','Native AutoGP')]:
   status=json.loads(z.read(key+'/status.json'));assert status['complete'] and status['benchmark_complete']
   assert status['origins']==471 and status['score_pairs']==14130
   assert status['posterior_updates'] is False and status['model_weight_updates'] is False
   if key=='gp':assert status['native_checks_passed'] and status['input_sha256']==cfg['input_sha256']
   frame=pd.read_csv(io.BytesIO(z.read(key+'/scores.csv.gz')),compression='gzip');frame=validate_scores(frame,cfg,{'ridge':'AutoDESN ridge','rhs':'AutoDESN RHS','gp':'AutoGP'}[key])
   frame['model']=label;frame['scenario']='reference_'+key;scores.append(frame)
   records.append(dict(scenario='reference_'+key,**aggregate(frame)))
 all_scores=pd.concat(scores,ignore_index=True);all_scores.to_csv(out/'all_scores.csv.gz',index=False)
 pooled=pd.DataFrame([dict(model=label,**aggregate(g)) for label,g in all_scores.groupby('model',sort=False)])
 pooled.to_csv(out/'pooled_metrics.csv',index=False)
 pd.DataFrame([dict(model=label,horizon=h,**aggregate(g)) for (label,h),g in all_scores.groupby(['model','horizon'],sort=False)]).to_csv(out/'horizon_metrics.csv',index=False)
 pd.DataFrame(budgets).to_csv(out/'mcmc_budget_sensitivity.csv',index=False)
 (out/'audit.json').write_text(json.dumps(dict(complete=True,exploratory=True,pairs_per_model=14130,unit_variance=True,
  interpretation=study['interpretation'],path_audits=audit,reference_inference_reused=True),indent=2))
 print(pooled.to_string(index=False))
if __name__=='__main__':main()
