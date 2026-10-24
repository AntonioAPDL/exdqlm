"""Aggregate diagnostic evidence without modifying the original experiment."""
from pathlib import Path
import json,sys,re,argparse
import numpy as np,pandas as pd
from scipy.stats import norm
from scipy.signal import periodogram
from gp_audit import parse
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;OUT=HERE/'artifacts';sys.path.insert(0,str(ROOT));from support import aggregate

def main():
 global OUT
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--data',type=Path,default=OUT,help='Numeric evidence directory, including restored audit evidence');OUT=parser.parse_args().data.resolve()
 snapshot=OUT/'benchmark_scores.csv.gz'
 truth=pd.read_csv(ROOT/'input/dgp_truth.csv');original=pd.read_csv(snapshot if snapshot.exists() else ROOT/'artifacts/comparison/all_scores.csv.gz');oracle=pd.read_csv(OUT/'oracle_scores.csv');lag=pd.read_csv(OUT/'lag_ablation_scores.csv.gz');gp=pd.read_csv(OUT/'fixed_period_gp_scores.csv');gp['model']='Fixed-period GP diagnostic';oracle['model']='DGP oracle'
 qgp=pd.read_csv(OUT/'quasiperiodic_gp_scores.csv');qgp['model']='Quasiperiodic GP diagnostic';scores=pd.concat([original,oracle,lag,gp,qgp],ignore_index=True);rows=[]
 for name,g in scores.groupby('model',sort=False):rows.append(dict(model=name,**aggregate(g)))
 pooled=pd.DataFrame(rows);pooled.to_csv(OUT/'pooled_comparison.csv',index=False)
 pd.DataFrame([dict(model=name,horizon=h,**aggregate(g)) for (name,h),g in scores.groupby(['model','horizon'],sort=False)]).to_csv(OUT/'horizon_comparison.csv',index=False)
 risk=[]
 for name,g in scores.groupby('model',sort=False):
  q=g[['origin','horizon','mean','squared_error']].merge(oracle[['origin','horizon','mean','variance','mean_mcse']].rename(columns={'mean':'oracle_mean','variance':'oracle_variance','mean_mcse':'oracle_mcse'}),on=['origin','horizon'],validate='one_to_one')
  for h in ['pooled',*range(1,31)]:
   a=q if h=='pooled' else q[q.horizon==h];variance=a.oracle_variance.mean();extra=max(0.,float(np.mean((a['mean']-a.oracle_mean)**2-a.oracle_mcse**2)))
   risk.append(dict(model=name,horizon=h,actual_RMSE=np.sqrt(a.squared_error.mean()),irreducible_expected_SD=np.sqrt(variance),conditional_mean_RMSE=np.sqrt(extra),expected_RMSE=np.sqrt(variance+extra),irreducible_fraction_of_expected_MSE=variance/(variance+extra)))
 risk=pd.DataFrame(risk);assert np.isfinite(risk.select_dtypes('number')).all().all();risk.to_csv(OUT/'conditional_risk.csv',index=False)
 # Point references use only observed history or fixed training estimates.
 y=truth.y.to_numpy();phase=(truth.time.to_numpy()-1)%60;tr=np.arange(500,2500);pm=np.array([y[tr[phase[tr]==j]].mean() for j in range(60)]);base=[]
 for name in ['training_mean','persistence','seasonal_naive60','phase60_climatology']:
  for o in range(2500,2971):
   t=np.arange(o,o+30);pred=pm[phase[t]] if name=='phase60_climatology' else np.full(30,y[tr].mean()) if name=='training_mean' else y[t-60] if name=='seasonal_naive60' else np.full(30,y[o-1]);base.append(pd.DataFrame(dict(model=name,origin=o,horizon=np.arange(1,31),mean=pred,squared_error=(y[t]-pred)**2,absolute_error=abs(y[t]-pred))))
 base=pd.concat(base);pd.DataFrame([dict(model=k,RMSE=np.sqrt(g.squared_error.mean()),MAE=g.absolute_error.mean()) for k,g in base.groupby('model')]).to_csv(OUT/'simple_baselines.csv',index=False)
 # One-step Gaussian moment projection: explicitly distinct from mixture scores.
 # Expectations below integrate Y~N(true mean,true variance) analytically.
 ablation=[];one=original[original.horizon==1].copy();one['true_mu']=truth.conditional_mean.to_numpy()[one.target-1];one['true_var']=truth.conditional_sd.to_numpy()[one.target-1]**2
 def A(d,s):z=d/s;return 2*s*norm.pdf(z)+d*(2*norm.cdf(z)-1)
 for name,g in one.groupby('model',sort=False):
  for mean_type,var_type in [('fitted','fitted'),('oracle','fitted'),('fitted','oracle'),('oracle','oracle')]:
   m=g['mean'] if mean_type=='fitted' else g.true_mu;v=g.predictive_sd**2 if var_type=='fitted' else g.true_var;delta=m-g.true_mu
   expected_nll=.5*(np.log(2*np.pi*v)+(g.true_var+delta**2)/v);expected_crps=A(delta,np.sqrt(v+g.true_var))-np.sqrt(v/np.pi)
   ablation.append(dict(model=name,mean=mean_type,variance=var_type,expected_Gaussian_NLL=expected_nll.mean(),expected_Gaussian_CRPS=expected_crps.mean(),Gaussian_moment_projection_not_full_mixture=True))
 pd.DataFrame(ablation).to_csv(OUT/'mean_variance_ablation.csv',index=False)
 # Descriptive residual dependence; no iid standard errors or superiority test.
 acf=[]
 for name,g in one.groupby('model',sort=False):
  e=g.actual.to_numpy()-g['mean'].to_numpy();sq=e*e
  for lag_ in [1,2,5,12,30,60]:acf.append(dict(model=name,lag=lag_,error_ACF=np.corrcoef(e[lag_:],e[:-lag_])[0,1],squared_error_ACF=np.corrcoef(sq[lag_:],sq[:-lag_])[0,1]))
 pd.DataFrame(acf).to_csv(OUT/'residual_dependence.csv',index=False)
 periods=[]
 for split,idx in [('training',tr),('test',np.arange(2500,3000))]:
  for signal in ['y','residual']:
   f,p=periodogram(truth[signal].to_numpy()[idx]);at=np.argsort(p[1:])[-8:]+1
   for j in at[::-1]:periods.append(dict(split=split,signal=signal,period=1/f[j],power=p[j]))
 pd.DataFrame(periods).to_csv(OUT/'periodogram_peaks.csv',index=False)
 byphase_test=np.array([y[np.arange(2500,3000)[phase[2500:]==j]].mean() for j in range(60)])
 def canonical(node):
  kind,args=node
  if kind not in ['Times','Plus']:return kind
  parts=[]
  def gather(n):
   if n[0]==kind:gather(n[1][0]);gather(n[1][1])
   else:parts.append(canonical(n))
  gather(node);return kind+'('+','.join(sorted(parts))+')'
 native=[]
 for run in [1,2]:
  snapshot=OUT/f'native_run{run}_particles.csv'
  for _,r in pd.read_csv(snapshot if snapshot.exists() else ROOT/f'artifacts/gp/run_{run}/particles.csv').iterrows():native.append(dict(run=run,component=int(r.component),weight=float(r.weight),noise_sd=float(np.sqrt(r.noise_variance)),periods=[float(p) for p in re.findall(r'Periodic\([^,]+, ([^,]+),',r.kernel)],skeleton=canonical(parse(r.kernel)),kernel=r.kernel))
 (OUT/'native_gp_kernel_audit.json').write_text(json.dumps(native,indent=2));div=[]
 for run in [1,2]:
  r=[k for k in native if k['run']==run];sk={k['skeleton']:0. for k in r}
  for k in r:sk[k['skeleton']]+=k['weight']
  div.append(dict(run=run,distinct_structures=len(sk),structure_probabilities=sk,effective_number_of_structures=1/sum(v*v for v in sk.values())))
 mc=pd.read_csv(OUT/'oracle_half_scores.csv');mc_summary=dict(full=aggregate(oracle),half=aggregate(mc),rms_mean_mcse=np.sqrt(np.mean(oracle.mean_mcse**2)),half_difference_variance_to_MCSE_ratio=float(np.mean((oracle.mean_half_a-oracle.mean_half_b)**2/4)/np.mean(oracle.mean_mcse**2)))
 joint=pd.read_csv(OUT/'native_log_joint_check.csv');candidate=joint[joint.kind=='training_fitted_candidate'];old=joint[(joint.kind=='original_particle')&(joint.latent_dimension==10)];gap=float(candidate.native_log_joint.iloc[0]-old.native_log_joint.max())
 metadata=dict(native_equal_dimension_log_joint_gap=gap,native_candidate_log_joint=float(candidate.native_log_joint.iloc[0]),best_original_equal_dimension_log_joint=float(old.native_log_joint.max()),complete=True,pairs_per_model=14130,original_benchmark_unchanged=True,diagnostics_post_hoc=True,DGP_realizations=1,training_test_phase_profile_correlation=float(np.corrcoef(pm,byphase_test)[0,1]),gp_structure_diversity=div,native_prior_period_below60_probability=float(norm.cdf(np.log(60/1999)+1.5)),native_prior_period_54_to66_probability=float(norm.cdf(np.log(66/1999)+1.5)-norm.cdf(np.log(54/1999)+1.5)),oracle_MC=mc_summary,actual_training_innovation_RMS=float(np.sqrt(np.mean((truth.residual-truth.conditional_mean+truth.season).iloc[tr]**2))),mean_training_true_variance=float(np.mean(truth.conditional_sd.iloc[tr]**2)),mean_test_true_variance=float(np.mean(truth.conditional_sd.iloc[2500:2971]**2)))
 (OUT/'analysis_status.json').write_text(json.dumps(metadata,indent=2));print(pooled[['model','RMSE','CRPS','NLL']].round(5).to_string(index=False))
if __name__=='__main__':main()
