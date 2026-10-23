"""Build the supplemental scientific report from audited, completed evidence."""
import argparse,json,sys,zipfile
from pathlib import Path
import numpy as np,pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import findfont
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,Image,PageBreak
from reportlab.lib.styles import getSampleStyleSheet,ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT

HERE=Path(__file__).resolve().parent
SHORT={
 'RHS: standardized, tau0=0.001, slab=1':'RHS standardized: 0.001 / 1',
 'RHS: standardized, tau0=1, slab=2':'RHS standardized: 1 / 2',
 'Ridge: standardized':'Ridge standardized',
 'Ridge: original basis':'Ridge original',
 'RHS: original basis, tau0=1, slab=2':'RHS original: 1 / 2',
 'Native AutoGP':'Native AutoGP'}
COLORS=['#983c83','#cc6e95','#2266a1','#65a6ca','#a29aab','#c37b22']
def main():
 p=argparse.ArgumentParser();p.add_argument('--data',type=Path,default=HERE/'artifacts');a=p.parse_args()
 d=a.data/'comparison';audit=json.loads((d/'audit.json').read_text());assert audit['complete']
 pooled=pd.read_csv(d/'pooled_metrics.csv');horiz=pd.read_csv(d/'horizon_metrics.csv');scores=pd.read_csv(d/'all_scores.csv.gz')
 study=json.loads((HERE/'configuration.json').read_text());diag=pd.read_csv(d/'independent_diagnostics.csv')
 budgets=pd.read_csv(d/'mcmc_budget_sensitivity.csv');bank=json.loads((a.data/'standardized_bank/status.json').read_text())
 figures=d/'figures';figures.mkdir(exist_ok=True)
 plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'axes.spines.top':False,'axes.spines.right':False})
 labels=list(SHORT);palette=dict(zip(labels,COLORS))
 fig,axes=plt.subplots(3,2,figsize=(10,9),layout='constrained')
 for ax,metric in zip(axes.flat,['RMSE','MAE','CRPS','NLL','Coverage90','Width90']):
  for lab in labels:
   g=horiz[horiz.model==lab];ax.plot(g.horizon,g[metric],label=SHORT[lab],color=palette[lab],lw=1.4)
  if metric=='Coverage90':ax.axhline(.9,color='gray',ls='--',lw=.7)
  ax.set(xlabel='Forecast horizon',title=metric);ax.grid(alpha=.15)
 handles,leg=axes[0,0].get_legend_handles_labels();fig.legend(handles,leg,loc='outside lower center',ncol=2,frameon=False)
 fig.savefig(figures/'metrics.png',dpi=170);plt.close(fig)
 y=pd.read_csv(HERE.parent/'c1_comparison/input/C1.csv').y.to_numpy()
 fig,axes=plt.subplots(3,1,figsize=(10,8),layout='constrained')
 for ax,lab in zip(axes,[labels[0],labels[2],labels[5]]):
  g=scores[(scores.model==lab)&(scores.horizon==30)]
  ax.plot(np.arange(2501,3001),y[2500:3000],c='#3c454b',lw=.65,label='Observed')
  ax.fill_between(g.target,g.lower90,g.upper90,color=palette[lab],alpha=.15,label='90% interval')
  ax.fill_between(g.target,g.lower50,g.upper50,color=palette[lab],alpha=.3,label='50% interval')
  ax.plot(g.target,g['mean'],color=palette[lab],lw=1,label='30-step mean')
  ax.set(title=SHORT[lab],ylabel='Response');ax.legend(ncol=4,frameon=False,fontsize=10)
 axes[-1].set_xlabel('Target time; each forecast conditions on observations through target - 30')
 fig.savefig(figures/'forecasts.png',dpi=170);plt.close(fig)
 fig,axes=plt.subplots(2,1,figsize=(10,5),layout='constrained')
 for ax,sc in zip(axes,study['scenarios'][:2]):
  tr=pd.read_csv(a.data/sc['id']/sc['method']/'traces.csv.gz')
  for chain,g in tr.groupby('chain'):ax.plot(np.arange(len(g))[::30],g.log_global.iloc[::30],lw=.45,alpha=.7,label=f'Chain {chain}')
  ax.set(title=f"{sc['id']}: log(u), tau = {sc['tau0']} u",xlabel='Retained iteration',ylabel='log(u)');ax.legend(ncol=3,frameon=False)
 fig.savefig(figures/'traces.png',dpi=170);plt.close(fig)
 models={sc['id']:pd.read_csv(a.data/sc['id']/sc['method']/'model_probabilities.csv') for sc in study['scenarios']}
 top=set()
 for g in models.values():top.update(g.nlargest(8,'posterior_probability').model)
 ids=sorted(top);fig,ax=plt.subplots(figsize=(10,4),layout='constrained');x=np.arange(len(ids))
 for i,(name,g) in enumerate(models.items()):
  gg=g.set_index('model');ax.bar(x+(i-1)*.26,gg.loc[ids,'posterior_probability'],width=.26,label=name,color=COLORS[i])
 ax.set_xticks(x,[str(j) for j in ids],fontsize=10)
 ax.set(ylabel='Posterior probability',xlabel='Frozen architecture ID (full candidate names in the CSV)',title='Union of the eight leading architectures in each standardized fit');ax.legend(frameon=False,ncol=3)
 fig.savefig(figures/'architectures.png',dpi=170);plt.close(fig)
 pdfmetrics.registerFont(TTFont('DV',findfont('DejaVu Sans')));pdfmetrics.registerFont(TTFont('DVB',findfont('DejaVu Sans:weight=bold')))
 pdfmetrics.registerFontFamily('DV',normal='DV',bold='DVB',italic='DV',boldItalic='DVB')
 styles=getSampleStyleSheet()
 for s in styles.byName.values():s.fontName='DV';s.textColor=colors.HexColor('#24313d')
 styles['Title'].fontName='DVB';styles['Title'].fontSize=23;styles['Title'].leading=28
 styles['Heading1'].fontName='DVB';styles['Heading1'].fontSize=16;styles['Heading1'].leading=20
 styles['BodyText'].fontSize=9;styles['BodyText'].leading=14
 styles.add(ParagraphStyle('Small',parent=styles['BodyText'],fontSize=7.2,leading=10))
 story=[]
 def para(t,style='BodyText'):story.append(Paragraph(t.replace('<=','&lt;=').replace('>=','&gt;='),styles[style]));story.append(Spacer(1,7))
 def title(t):para(t,'Heading1')
 def table(rows,widths=None,size=7.6):
  content=[[Paragraph(str(v),styles['Small']) for v in row] for row in rows]
  tb=Table(content,colWidths=widths,repeatRows=1,hAlign='LEFT');tb.setStyle(TableStyle([
   ('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e8edf2')),('VALIGN',(0,0),(-1,-1),'TOP'),
   ('BOTTOMPADDING',(0,0),(-1,-1),7),('TOPPADDING',(0,0),(-1,-1),6),
   ('LINEBELOW',(0,0),(-1,0),.6,colors.HexColor('#aab5c0')),('LINEBELOW',(0,1),(-1,-1),.25,colors.HexColor('#d8dee3'))]))
  story.append(tb);story.append(Spacer(1,9))
 def image(name,width=500):
  from PIL import Image as PIL
  f=figures/name;w,h=PIL.open(f).size;story.append(Image(str(f),width=width,height=width*h/w))
 def page():story.append(PageBreak())
 para('AutoDESN: standardized readout and RHS sensitivity','Title')
 para('C1 supplemental report | completed numerical evidence | 23 October 2026','Small')
 para('The earlier AutoDESN comparison standardized the response using observations 1:500 and divided readout features by sqrt(d). It did not z-score each readout column. This study adds frozen per-column standardization using the same helpers as Q-DESN and reruns the requested normalized RHS prior.')
 table([['Setting','Requested fit'],['Readout features','Mean 0 and sample variance 1 on rows 501:2500; frozen thereafter'],['Prior controls','tau0 = 0.001; slab_scale = 1; slab_df = 4'],['Hierarchy','u and local scales half-Cauchy(0,1); tau = tau0 u; c^2 ~ inverse-gamma(2,2)'],['Other priors','Intercept N(0,10); observation variance inverse-gamma(3,1)'],['Protocol','500 washout; 2,000 training; 500 held out; 471 origins x 30 leads'],['Forecast budget','192 joint posterior draws x 8 recursive innovation paths; posterior fit once']],widths=[125,375])
 req=pooled.iloc[0];old=pooled[pooled.model=='RHS: original basis, tau0=1, slab=2'].iloc[0]
 change=100*(req.RMSE/old.RMSE-1)
 para(f"Requested fit pooled RMSE: <b>{req.RMSE:.6f}</b> ({change:+.2f}% relative to the earlier RHS run). This is a descriptive result on the same previously examined series, not an independent replication or a test of general superiority.")
 para('All reported standardized fits passed the declared chain checks and the independent rank-normalized R-hat / bulk and tail ESS screen. Shorter failed attempts are retained and counted in inference cost. Exact diagnostics and their limits appear below.')
 para('The historical prefix-scale sampler failed architecture exploration even at 64,000 retained draws per chain; it issued no forecasts. The revised sampler uses layerwise auxiliary slots and an exact product-preserving global/local update. Both preserve the normalized RHS marginal target. This change was made using training-chain diagnostics only.','Small')
 para('This is an exploratory sensitivity analysis. No further tau0/slab search used held-out errors. Overlapping rolling-origin pairs are dependent. Native AutoGP and original-basis outputs are reused, verified references; their inference is not represented as a new run.','Small')
 page();title('Pooled predictive scores')
 para('Every row contains exactly 14,130 origin-horizon pairs. RMSE, MAE, CRPS and negative log predictive density (NLL) are in original response units or the corresponding log-density scale. Smaller is better for these four scores.')
 rows=[['Model','RMSE','MAE','CRPS','NLL']]
 for _,r in pooled.iterrows():rows.append([SHORT[r.model]]+[f'{r[k]:.6f}' for k in ['RMSE','MAE','CRPS','NLL']])
 table(rows,[216,71,71,71,71])
 title('Predictive intervals')
 rows=[['Model','Cov. 50%','Width 50%','Cov. 90%','Width 90%']]
 for _,r in pooled.iterrows():rows.append([SHORT[r.model]]+[f'{r[k]:.4f}' for k in ['Coverage50','Width50','Coverage90','Width90']])
 table(rows,[216,71,71,71,71])
 para('Intervals and CRPS are computed from recursive predictive draws. NLL uses the conditional Gaussian mixture with simulated past paths; it is subject to finite predictive Monte Carlo error. The budget sensitivity below checks that numerical approximation on three fixed origins.')
 para('The scaling-only RHS case retains tau0=1 and slab_scale=2. Standardized ridge uses the same standardized bank as both RHS fits. Standardization changes prior geometry, so the original-basis ridge/RHS references are contextual comparisons rather than a controlled prior-only comparison.')
 page();title('Forecast quality by horizon');image('metrics.png',500)
 page();title('Rolling forecasts and predictive intervals');image('forecasts.png',500)
 para('These panels show horizon 30 at every rolling origin. Observed reservoir states are updated between forecast origins. Inside each issued forecast, future responses are simulated recursively, never read from the held-out series.','Small')
 page();title('Architecture averaging and shrinkage');image('architectures.png',500)
 rows=[['Scenario','Leading model','Probability','tau median [5%,95%]','c^2 median [5%,95%]','Diagonal effective slopes']]
 for sc in study['scenarios']:
  g=models[sc['id']];lead=g.loc[g.posterior_probability.idxmax()]
  row=[sc['id'],f"{int(lead.model)}: {lead.candidate}",f'{lead.posterior_probability:.5f}']
  if sc['method']=='rhs':
   q=pd.read_csv(a.data/sc['id']/sc['method']/'shrinkage_quantiles.csv').set_index('parameter')
   for nm in ['global_tau','slab_variance','effective_slopes_diagonal']:
    v=q.loc[nm];row.append(f'{v["median"]:.4g} [{v.q05:.4g}, {v.q95:.4g}]')
  else:row+=['-','-','-']
  rows.append(row)
 table(rows,[70,95,50,95,95,95])
 para('tau0 is a prior multiplier, not a fixed posterior value of tau. Both u and c^2 are sampled. The displayed slab values are posterior draws of c^2, not the slab_scale hyperparameter. Local scales remain coefficient-specific; their distribution is not replaced by a common penalty.')
 para('The effective-slope diagnostic sums the diagonal-design approximation to 1 minus the shrinkage factor. Correlated reservoir columns prevent interpreting it as an exact degrees-of-freedom count. The CSV also records aggregate log-local scale traces.','Small')
 para('Architecture probabilities are posterior occupancy averages across three chains. Proposals retain positive mass on every architecture and include the exact Hastings correction. No test-error screening replaces Bayesian architecture averaging.')
 page();title('MCMC convergence and numerical validation');image('traces.png',500)
 rows=[['Scenario','Max rank R-hat','Min bulk ESS','Min tail ESS','Retained / chain']]
 for sc in study['scenarios']:
  z=diag[diag.scenario==sc['id']];st=json.loads((a.data/sc['id']/sc['method']/'status.json').read_text());sel=budgets[(budgets.scenario==sc['id'])&(budgets.attempt==st['selected_attempt'])].iloc[0]
  rows.append([sc['id'],f'{z.rhat.max():.5f}',f'{z.bulk_ess.min():.1f}',f'{z.tail_ess.min():.1f}',int(sel.n_mcmc)])
 table(rows,[128,90,90,90,102])
 para('The independent screen includes continuous parameters and model indicators with posterior probability >=1%. Continuous rank-normalized split/folded R-hat must be <=1.01, bulk/tail ESS >=400. Binary model indicators use rank R-hat and frequency ESS; that ESS is shown in both ESS columns because a binary tail quantile can be constant. The R screen also checks spectral ESS and between-chain architecture frequency differences. These diagnostics provide evidence for monitored quantities; they do not prove convergence or estimate rare-model probabilities precisely.','Small')
 page();title('Sampling-budget sensitivity')
 rows=[['Scenario','Burn / chain','Kept / chain','Max R-hat','Min spectral ESS','Pass']]
 for _,r in budgets.iterrows():rows.append([r.scenario,int(r.n_burn),int(r.n_mcmc),f'{r.max_rhat:.5f}',f'{r.min_ess:.1f}',str(bool(r.qualified))])
 table(rows,[132,72,72,76,88,60])
 title('Predictive Monte Carlo sensitivity')
 sensitivity=[]
 sys.path.insert(0,str(HERE.parent/'rhs_comparison'));from support import aggregate
 for sc in study['scenarios']:
  frame=pd.read_csv(a.data/sc['id']/sc['method']/'mc_sensitivity.csv')
  assert len(frame)==720
  for (n,k),g in frame.groupby(['outer_draws','inner_paths']):sensitivity.append(dict(scenario=sc['id'],N=n,K=k,**aggregate(g)))
 sens=pd.DataFrame(sensitivity);sens.to_csv(d/'mc_sensitivity_summary.csv',index=False)
 rows=[['Scenario','N x K','RMSE (3 origins)','CRPS','NLL']]
 for sc in study['scenarios']:
  z=sens[sens.scenario==sc['id']]
  for n,k in [(192,8),(384,32)]:
   r=z[(z.N==n)&(z.K==k)].iloc[0];rows.append([sc['id'],f'{n} x {k}',f'{r.RMSE:.5f}',f'{r.CRPS:.5f}',f'{r.NLL:.5f}'])
 table(rows,[170,75,85,85,85])
 para('The full CSV contains all 24 settings per model: origins 2500, 2735, 2970; N=192/384; K=4/8/16/32. These reuse one qualified posterior per model. The 90 scored pairs in a setting are dependent and are not the full 14,130-pair comparison.','Small')
 page();title('Measured runtime and reproducibility')
 build=json.loads((a.data/'raw_bank/status.json').read_text())
 para(f"Shared raw reservoir construction: {build['invocation_wall_seconds']:.2f} s wall time ({build['candidate_compute_seconds_sum']:.2f} s summed candidate compute). Frozen readout preparation, including column standardization and sufficient statistics: {bank['standardization_seconds']:.2f} s. Bank loading, compilation and reporting are not inference.")
 rows=[['Scenario','Pilots (s)','Inference incl. failed attempts (s)','Forecast compute (s)','State update (s)','Parent peak RSS (GiB)']]
 for sc in study['scenarios']:
  st=json.loads((a.data/sc['id']/sc['method']/'status.json').read_text());t=st['timings'];m=json.loads((a.data/sc['id']/'process_memory.json').read_text())
  failed=a.data/sc['id']/'failed_fork_resume_memory.json'
  if failed.exists():m['process_peak_rss_kib']=max(m.get('process_peak_rss_kib') or 0,json.loads(failed.read_text()).get('process_peak_rss_kib') or 0) or None
  peak=f'{m["process_peak_rss_kib"]/2**20:.2f}' if m.get('process_peak_rss_kib') else 'NA'
  rows.append([sc['id'],f'{t["training_pilot_seconds"]:.2f}',f'{t["inference_seconds_all_attempts"]:.2f}',f'{t["forecast_compute_seconds_sum"]:.2f}',f'{t["state_preparation_seconds_this_invocation"]:.2f}',peak])
 table(rows,[94,60,104,83,74,85])
 para('Forecast compute is the sum of per-origin computation, not parallel wall time. State preparation, scoring, exports and predictive-budget sensitivity are excluded from that sum. Parent VmHWM excludes forked workers and is not a unique-memory estimate for the entire process tree. Cgroup observations include file cache and concurrent dependency setup.','Small')
 para('The initial scaling-only RSS sample used a namespace-local PID against host /proc and is invalid; it is reported as NA. The corrected observer resolves the process namespace explicitly. Ridge forecasting was interrupted after 98 origins and resumed from its saved fit and per-origin checkpoints; its measured peak covers the observed resume invocations, including a failed fork attempt. That failed resume took 255.02 s wall time, separate from completed forecast compute. No refit was needed.','Small')
 legacy=a.data/'legacy_prefix_requested/rhs/status.json'
 if legacy.exists():
  lt=json.loads(legacy.read_text())['timings'];para(f"Additional failed prefix-sampler development cost: {lt['inference_seconds_all_attempts']:.2f} s inference plus {lt['training_pilot_seconds']:.2f} s pilot computation. These produced no forecasts and are retained in the budget/diagnostic evidence.",'Small')
 with zipfile.ZipFile(HERE.parent/'rhs_comparison/evidence/C1_numeric_evidence.zip') as z:gp=json.loads(z.read('gp/status.json'))
 gt=gp['timings']
 para(f"Reused Native AutoGP reference: two runs with eight SMC particles each; summed training time {gt['smc_training_seconds_sum']:.2f} s; original native run/export time {gt['native_run_elapsed_seconds_sum']:.2f} s. Its later rolling conditioning/scoring/export replay took {gt['replayed_rolling_conditioning_scoring_export_seconds']:.2f} s with peak RSS {gt['replayed_peak_rss_kib']/2**20:.3f} GiB. A pure GP forecasting timer and native-training peak memory were unavailable. These are different timer scopes and cannot support a clean end-to-end speedup claim.", 'Small')
 bench=pd.read_csv(a.data/'validation/standardized_backend_benchmark.csv').groupby('backend').elapsed_seconds.median()
 error=pd.read_csv(a.data/'validation/standardized_backend_parity.csv').max_paired_draw_error.max()
 para(f"A separate short-chain computational benchmark (200 rows, four standardized designs, up to 64 slopes, 100 burn +800 retained draws; three timing repetitions) took median {bench['R']:.3f} s in R and {bench['cpp']:.3f} s with the native kernels, a {bench['R']/bench['cpp']:.2f}x ratio. Coupled coefficient/scale draws differed by at most {error:.3g}, with identical model paths. Setup and compilation were excluded. These short runs measure computation, not convergence.",'Small')
 page()
 title('Audit details')
 para(f"All 428 admitted architectures have the same raw reservoirs and candidate identities in all three new cases. Maximum absolute training feature mean: {bank['max_abs_mean']:.3g}; maximum sample-SD error: {bank['max_sd_error']:.3g}. No constant columns were found in this bank. The API freezes a constant-column exclusion mask when necessary.")
 para('Validation covers shared Q-DESN scaling parity, frozen transforms, intercept transport, direct/batched recursive forecast parity, backward-compatible ridge draws, normalized RHS densities, Gaussian integrated likelihoods, scale updates, architecture ratios, and R/C++ agreement. Saved path snapshots independently reproduce scores at the first, middle and last origins. See validation_status.json and the archived test logs for actual pass/skip counts.')
 validation=json.loads((a.data/'validation/validation_status.json').read_text())
 para(f"Current installed regression assertions: {validation['installed_regression']['passed']} passed, zero failures/errors/warnings, one loaded-DLL context skip covered separately by the source-only checks. The 32 independent small-posterior reference checks passed. Prior-preserving interweaving has independent conditional quadrature and no-information prior-CDF checks; the historical default sampler reproduces the earlier draws exactly.")
 para('Release status remains draft. The earlier scoped R CMD check recorded one inherited nonportable-path error, three existing documentation/non-ASCII warnings and two notes. This update installs and passes the focused checks; a clean repository-wide release check is not claimed.','Small')
 para('Reproduce from feature/autodesn-rhs-20261022: run standardized_rhs/run.R for requested, scaling_only and ridge_standardized sequentially; then rhs_comparison/sensitivity.R for each output, standardized_rhs/export.R, analysis.py and report.py. configuration.json fixes all budgets and seeds. Hash-guarded checkpoints reject changed inputs or production sources.','Small')
 para('Code and draft PR: https://github.com/AntonioAPDL/exdqlm/pull/3. Original report and reproducibility evidence remain under validation/autodesn/rhs_comparison/evidence/. This supplement preserves those results.','Small')
 out=HERE/'evidence';out.mkdir(exist_ok=True);pdf=out/'AutoDESN_Standardized_RHS_C1_Report.pdf'
 def footer(c,doc):
  c.setFont('DV',7);c.setFillColor(colors.HexColor('#657282'));c.drawString(48,25,'AutoDESN | exploratory C1 sensitivity | 23 October 2026');c.drawRightString(548,25,str(doc.page))
 SimpleDocTemplate(str(pdf),pagesize=(596,842),leftMargin=42,rightMargin=42,topMargin=36,bottomMargin=36,title='AutoDESN standardized RHS C1 sensitivity').build(story,onFirstPage=footer,onLaterPages=footer)
 print(pdf)
if __name__=='__main__':main()
