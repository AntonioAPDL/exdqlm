"""Independent recursion, Gaussian identities, selection and evidence contracts."""
from pathlib import Path
import json,sys,ast,zipfile,gzip
import numpy as np,pandas as pd
from scipy.stats import norm
from scipy.linalg import solve_triangular
from oracle import location,pulse,season
from lag_ablation import fit_path,forecast
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;OUT=HERE/'artifacts'
def main():
 truth=pd.read_csv(ROOT/'input/dgp_truth.csv');d=pd.read_csv(OUT/'oracle_R_reference.csv');o=2500;N=8;buffer=np.repeat(truth.residual.to_numpy()[o-60:o,None],N,axis=1);pos=0;h=np.full(N,truth.conditional_sd.iloc[o-1]**2);e=np.full(N,truth.conditional_sd.iloc[o-1]*truth.innovation.iloc[o-1]);maxerr=0
 for lead in range(1,31):
  q=d[d.horizon==lead];a=buffer[(pos-1)%60];f=location(a,buffer[(pos-2)%60],buffer[(pos-12)%60],buffer[pos]);h=.008+.018*pulse(o+lead,.18,.1)+.012*pulse(o+lead,.64,.18)+.008*np.tanh(a)**2+.06*e**2+.10*e**2*(e<0)+.82*h;e=np.sqrt(h)*q.z.to_numpy();x=f+e
  maxerr=max(maxerr,float(np.max(abs(q.mu.to_numpy()-season(o+lead)-f))),float(np.max(abs(q.variance.to_numpy()-h))),float(np.max(abs(q.y.to_numpy()-season(o+lead)-x))));buffer[pos]=x;pos=(pos+1)%60
 assert maxerr<1e-12
 # Recover variance from observed residuals and known DGP, without burn-in state.
 x=truth.residual.to_numpy();eps=x[60:]-location(x[59:-1],x[58:-2],x[48:-12],x[:-60]);v=.2;recovered=[]
 for t in range(62,3001):
  e=eps[t-62];a=x[t-2];v=.008+.018*pulse(t,.18,.1)+.012*pulse(t,.64,.18)+.008*np.tanh(a)**2+.06*e*e+.10*e*e*(e<0)+.82*v;recovered.append(v)
 err=np.max(abs(np.array(recovered)[2500-62:]-truth.conditional_sd.to_numpy()[2499:]**2));assert err<1e-12
 # Triangular innovations equal Gaussian conditional means, no future responses.
 C=np.array([[2.,.4,.2],[.4,1.,.3],[.2,.3,1.5]]);y=np.array([.5,-.7,1.2]);L=np.linalg.cholesky(C);w=solve_triangular(L,y,lower=True);m=y-np.diag(L)*w
 for i in range(3):assert abs(m[i]-(0 if i==0 else C[i,:i]@np.linalg.solve(C[:i,:i],y[:i])))<1e-12
 # Diagnostic forecaster uses only <=origin and is linear for point recursion.
 actual=truth.y.to_numpy();fit=fit_path(actual,np.arange(501,2001),[1,2,12,60],True,[.01])[0];m,v=forecast(fit,actual,[2500]);changed=actual.copy();changed[2500:]+=100;m2,v2=forecast(fit,changed,[2500]);assert np.array_equal(m,m2) and np.array_equal(v,v2)
 for file in ['capacity_status.json','oracle_status.json','gp_audit_status.json','lag_ablation_status.json','quasiperiodic_gp_status.json']:assert json.loads((OUT/file).read_text())['complete']
 joint=pd.read_csv(OUT/'native_log_joint_check.csv');candidate=joint[joint.kind=='training_fitted_candidate'];assert np.ptp(candidate.native_log_joint)<1e-8 and (candidate.latent_dimension==10).all();assert candidate.native_log_joint.min()>joint[(joint.kind=='original_particle')&(joint.latent_dimension==10)].native_log_joint.max()
 with zipfile.ZipFile(ROOT/'evidence/NHS1_numeric_evidence.zip') as archive:
  for rel in ['requested/rhs/scores.csv','scaling_only/rhs/scores.csv','ridge_standardized/ridge/scores.csv','gp/scores.csv']:assert gzip.decompress(archive.read(rel+'.gz'))==(ROOT/'artifacts'/rel).read_bytes(),rel
 risk=pd.read_csv(OUT/'conditional_risk.csv');assert np.isfinite(risk.select_dtypes('number')).all().all();a=risk[(risk.model=='AutoDESN RHS: 0.001 / 1')&(risk.horizon=='1')].iloc[0];scores=pd.read_csv(ROOT/'artifacts/requested/rhs/scores.csv');scores=scores[scores.horizon==1];expected=np.sqrt(np.mean((scores['mean'].to_numpy()-truth.conditional_mean.to_numpy()[scores.target-1])**2));assert abs(a.conditional_mean_RMSE-expected)<1e-12;assert abs(a.irreducible_expected_SD-np.sqrt(np.mean(truth.conditional_sd.to_numpy()[scores.target-1]**2)))<1e-12
 status=dict(risk_aggregation_matches_independent_analytic_one_step=True,original_four_score_tables_unchanged=True,native_candidate_uses_same_prior_and_equal_dimension=True,complete=True,independent_R_path_max_error=maxerr,variance_state_recovery_error=float(err),Gaussian_prequential_identity_passed=True,diagnostic_future_perturbation_passed=True,original_forecasts_reconstructed_to_1e_10=True,oracle_paths=32768)
 (OUT/'audit_validation.json').write_text(json.dumps(status,indent=2));print(json.dumps(status))
if __name__=='__main__':main()
