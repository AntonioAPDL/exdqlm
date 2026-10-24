"""Freeze completed delivery metadata, restore archives and verify the round trip."""
import json,gzip,hashlib,subprocess,sys,shutil
from datetime import datetime,timezone
from pathlib import Path
import pandas as pd
HERE=Path(__file__).resolve().parent
def main():
 b=HERE/'artifacts';e=HERE/'evidence';c=b/'comparison'
 assert json.loads((c/'audit.json').read_text())['complete']
 replay=json.loads((b/'validation/replay_validation.json').read_text());assert replay['complete'] and replay['windows']==9 and replay['max_path_error']<1e-10
 qa=json.loads((b/'validation/report_validation.json').read_text());pdf=e/'NHS1_AutoDESN_AutoGP_Report.pdf'
 assert qa['complete'] and qa['pdf_sha256']==hashlib.sha256(pdf.read_bytes()).hexdigest()
 cases=[('requested','rhs'),('scaling_only','rhs'),('ridge_standardized','ridge')]
 for case,method in cases:
  st=json.loads((b/case/method/'status.json').read_text());assert st['complete'] and st['qualified'] and st['score_pairs']==14130
  assert json.loads((b/case/method/'independent_screen.json').read_text())['passed']
 gp=json.loads((b/'gp/status.json').read_text());assert gp['complete'] and not gp['reused']
 streams=[]
 for p in sorted(b.rglob('*.csv.gz')):
  if 'trace-' in p.name:continue
  with gzip.open(p,'rb') as f:
   while f.read(1048576):pass
  streams.append(str(p.relative_to(b)))
 (b/'validation/compressed_integrity.json').write_text(json.dumps(dict(complete=True,read_through_eof=True,files=streams),indent=2))
 status=dict(complete=True,completed_UTC=datetime.now(timezone.utc).isoformat(),series='NHS1',dgp_realizations=1,dependent_rolling_pairs=True,seed=1766021,
  washout=500,training=2000,test=500,origins_per_model=471,horizons=30,pairs_per_model=14130,
  requested_rhs_controls=dict(tau0=.001,slab_scale=1,slab_df=4),standardize_features=True,normalize_features=False,
  new_fits=['AutoDESN RHS .001/1','AutoDESN RHS 1/2','AutoDESN ridge','Native AutoGP'],reference_inference_reused=False,
  posterior_parameters_fixed_after_origin=2500,all_AutoDESN_diagnostic_screens_passed=True,
  independent_functional_checks='Six fixed training-row means, continuous scales and appreciable-mass architecture indicators',
  prior_or_DGP_tuned_to_test_outcomes=False,native_checks_passed=True,checkpoint_replay_windows=9,
  package_release_check_clean=False,release_note='Inherited scoped check: 1 nonportable-path error, 3 documentation/non-ASCII warnings, 2 notes. Focused checks pass.',
  numerical_background_work_running=False)
 (b/'final_status.json').write_text(json.dumps(status,indent=2))
 pooled=pd.read_csv(c/'pooled_metrics.csv');diag=pd.read_csv(c/'independent_diagnostics.csv');budgets=pd.read_csv(c/'mcmc_budget_sensitivity.csv')
 lines=['# Completed NHS1 nonlinear heteroscedastic comparison','',
 'One new predeclared realization was generated with seed 1766021. All models were fitted fresh; C1 scores were not reused. See DGP.md for the exact nonlinear location, asymmetric period-60 seasonal forcing, GJR variance and moment bounds. Simulation burn-in 6,000 is separate from the retained 500-observation reservoir washout.','',
 'The frozen protocol is 500 washout/2,000 training/500 test; 471 origins 2500:2970 and 30 horizons yield 14,130 dependent pairs per model. Parameters and architecture weights are fitted once at 2500. Observations update states between origins; simulated responses are used recursively within AutoDESN forecasts. Native GP uses causal Gaussian conditioning with fixed fitted parameters/weights.','',
 'All AutoDESN readout columns are standardized using rows 501:2500 only, with no sqrt(d) division. Scalers and masks are frozen and the intercept is proper and unscaled. The same 456 reservoir definitions and washout-admission rule are applied to this new dataset; the admitted bank is shared across all three priors.','',
 'Requested normalized RHS controls: tau0=0.001, slab_scale=1, slab_df=4, giving c²~IG(2,2). The global multiplier and local scales are unit half-Cauchy; tau=0.001*u is learned. Intercept variance 10 and observation variance IG(3,1) are retained. The scaling-only RHS controls are 1/2/4. No prior or DGP coefficient was tuned using held-out errors.','',
 '## Pooled predictive scores','',
 '| Model | RMSE | MAE | CRPS | NLL | Cov50 | Width50 | Cov90 | Width90 |',
 '|---|---:|---:|---:|---:|---:|---:|---:|---:|']
 for _,r in pooled.iterrows():lines.append('| '+r.model+' | '+' | '.join(f'{r[k]:.6f}' for k in ['RMSE','MAE','CRPS','NLL','Coverage50','Width50','Coverage90','Width90'])+' |')
 lines+=['','Full horizon tables, one-step calibration against true conditional volatility, intervals, predictive plots and budget sensitivity are in the report and evidence CSVs. The models retain constant observation-variance parameters, so changing innovation variance is deliberately misspecified. DGP truth is used only for reporting.','',
 '## Retained-chain diagnostics','',
 '| Scenario | Max rank R-hat | Min bulk ESS | Min tail/frequency ESS |',
 '|---|---:|---:|---:|']
 for case,_ in cases:
  z=diag[diag.scenario==case];lines.append(f'| {case} | {z.rhat.max():.6f} | {z.bulk_ess.min():.1f} | {z.tail_ess.min():.1f} |')
 lines+=['','Three chains per AutoDESN fit; continuous quantities, six fixed training-row fitted means and architecture indicators with mass>=1% are screened. Binary frequency ESS appears in both ESS columns. R spectral-ESS and chain-frequency-range gates are also required. Checks precede test forecasting. These monitored diagnostics support the retained fits but do not prove convergence or accurately estimate rare-model probabilities.','',
 'All completed failed budgets and both model-only training proposals are retained. The subsequent full-support architecture/log-scale joint MH mixture is frozen using training chains only, with exact transformed normalized priors, coefficient-collapsed targets, Hastings corrections and fresh production seeds. Each sweep has the original four model-only plus two joint proposals; initial production retained budgets are 16k/32k/64k/128k per chain. The initial auxiliary scaling-control fit failed its final architecture-frequency-range gate and issued no forecasts. Its replacement used a fresh same-prior proposal fitted only to training draws, passed both diagnostic screens with an additional 3 x 128k retained budget, and supplied the auxiliary forecasts reported here. Shared proposal-training inference is reported once; this additional same-prior training cost is reported separately. No failed convergence screen is waived. Sampling-budget sensitivity is in mcmc_budget_sensitivity.csv; predictive sensitivity covers 24 origin/budget combinations per AutoDESN case, using the same qualified posterior.','',
 '## Native GP, numerical tests and interpretation','',
 'Native AutoGP uses Julia 1.10.10, authors\' revision 2ad372db2b8bea176e3b32a769bfb5d6cff80866 (version 0.1.19), the native grammar/priors, depth 4 and the frozen two eight-particle SMC runs. Native posterior transport and conditioning checks pass. Particle ESS, exported kernel states and run-by-run predictive sensitivity are retained; these do not prove exploration of kernel space.','',
 'Fresh validation includes 12 DGP assertions, 24 R workflow assertions, 6 Python dataset/scoring/conditioning contracts, R/C++ small-chain parity and native GP contracts. Current-source regressions were rerun: 652 focused installed assertions (one context skip covered separately), 76 source-only assertions, 77 R study contracts, 6 Python contracts, 4 diagnostic tests and 32 independent posterior-reference checks. The optional joint kernel additionally passes 6 independent density states, 36 ordered acceptance ratios and 4 fixed-local and 5 learned-local/interwoven posterior functionals against independent integration; disabled-option draws match previous source exactly. These tests are separate from the actual large-chain diagnostics.','',
 'Future-observation perturbations leave forecasts identical at three origins per case. All nine archived-checkpoint replay windows pass. Raw path scores are reconstructed independently. Compressed evidence is read through EOF and has part/archive/internal SHA256 verification. The restored analysis reproduced all six summary CSVs exactly.','',
 'Runtime and memory scopes are separated in the PDF: shared reservoirs, frozen feature preparation, pilots, all completed inference attempts, state updates, forecast compute, native GP training/export/rolling conditioning and observed process peaks. Short R/C++ computational benchmarks are not convergence or full-study speedup evidence. Completed chain computations and the last interruption timing observation are retained. The first interrupted scaling invocation lost its stdout before backup; its unfinished chain was recomputed.','',
 'There is one realization, not 471 independent replications or 14,130 independent test observations. Differences are descriptive; no general superiority claim is made. The inherited package-wide release issues remain: 1 portability error, 3 existing documentation/non-ASCII warnings and 2 notes. The PR remains draft and is not merged.','',
 '## Reproduction and deliverables','',
 'Use README.md. The PDF, full horizon/pooled summaries and diagnostics are under evidence/. Compact 384-draw joint forecast checkpoints and frozen feature geometry are committed separately. The numeric archive retains monitored scalar/functional traces, exact controls, full score tables, path snapshots, GP covariance/particle exports and native checkpoints. Huge inference designs and full per-iteration coefficient vectors are rebuilt from scripts/seeds. No numerical work remains running.','']
 (HERE/'RESULTS.md').write_text('\n'.join(lines))
 subprocess.run([sys.executable,str(HERE/'prepare_delivery.py')],check=True)
 subprocess.run([sys.executable,str(HERE/'archive.py')],check=True)
 subprocess.run([sys.executable,str(e/'restore_evidence.py')],check=True)
 subprocess.run([sys.executable,str(HERE/'analysis.py'),'--data',str(e/'restored')],check=True)
 summary=['pooled_metrics.csv','horizon_metrics.csv','independent_diagnostics.csv','mcmc_budget_sensitivity.csv','mc_sensitivity_summary.csv','calibration_by_volatility.csv']
 for name in summary:
  assert (c/name).read_bytes()==(e/'restored/comparison'/name).read_bytes(),name
  shutil.copyfile(c/name,e/name)
 status['archive_roundtrip_verified']=True;(e/'execution_status.json').write_text(json.dumps(status,indent=2))
 names=['NHS1_AutoDESN_AutoGP_Report.pdf','NHS1_DGP.png','frozen_feature_geometry.rds']+[case+'_forecast_checkpoint.rds' for case,_ in cases]
 manifest={name:dict(bytes=(e/name).stat().st_size,sha256=hashlib.sha256((e/name).read_bytes()).hexdigest()) for name in names}
 (e/'deliverable_manifest.json').write_text(json.dumps(dict(complete=True,archive_roundtrip_verified=True,summary_parity_exact=True,files=manifest),indent=2))
 print('Completed evidence and exact restored-analysis parity verified',flush=True)
if __name__=='__main__':main()
