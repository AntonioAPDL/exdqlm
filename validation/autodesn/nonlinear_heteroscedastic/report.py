"""Generate the NHS1 scientific report only from completed audited evidence."""
import argparse,json,tomllib
from pathlib import Path
import numpy as np,pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import findfont
from scipy.stats import invgamma
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,Image,PageBreak
from reportlab.lib.styles import getSampleStyleSheet,ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib import colors
HERE=Path(__file__).resolve().parent
LABELS=['AutoDESN RHS: 0.001 / 1','AutoDESN RHS: 1 / 2','AutoDESN ridge','Native AutoGP']
PALETTE=dict(zip(LABELS,['#983c83','#ce82a6','#2266a1','#bc7429']))
def main():
 p=argparse.ArgumentParser();p.add_argument('--data',type=Path,default=HERE/'artifacts');a=p.parse_args();b=a.data;c=b/'comparison'
 audit=json.loads((c/'audit.json').read_text());assert audit['complete'] and not audit['reference_inference_reused']
 pooled=pd.read_csv(c/'pooled_metrics.csv');horiz=pd.read_csv(c/'horizon_metrics.csv');scores=pd.read_csv(c/'all_scores.csv.gz')
 study=json.loads((HERE/'study.json').read_text());bank=json.loads((b/'standardized_bank/status.json').read_text())
 diag=pd.read_csv(c/'independent_diagnostics.csv');budgets=pd.read_csv(c/'mcmc_budget_sensitivity.csv')
 truth=pd.read_csv(HERE/'input/dgp_truth.csv');figures=c/'figures';figures.mkdir(exist_ok=True)
 plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'axes.spines.top':False,'axes.spines.right':False})
 fig,axes=plt.subplots(4,2,figsize=(10,12),layout='constrained')
 for ax,metric in zip(axes.flat,['RMSE','MAE','CRPS','NLL','Coverage50','Coverage90','Width50','Width90']):
  for lab in LABELS:
   g=horiz[horiz.model==lab];ax.plot(g.horizon,g[metric],label=lab,color=PALETTE[lab],lw=1.5)
  if metric.startswith('Coverage'):ax.axhline(int(metric[-2:])/100,color='gray',ls='--',lw=.7)
  ax.set(title=metric,xlabel='Forecast horizon');ax.grid(alpha=.15)
 handles,labels=axes[0,0].get_legend_handles_labels();fig.legend(handles,labels,loc='outside lower center',ncol=2,frameon=False)
 fig.savefig(figures/'horizons.png',dpi=170);plt.close(fig)
 fig,axes=plt.subplots(4,1,figsize=(10,10),layout='constrained')
 for ax,lab in zip(axes,LABELS):
  g=scores[(scores.model==lab)&(scores.horizon==30)]
  ax.plot(truth.time.iloc[2500:],truth.y.iloc[2500:],color='#303b45',lw=.65,label='Observed')
  ax.fill_between(g.target,g.lower90,g.upper90,color=PALETTE[lab],alpha=.15,label='90% interval')
  ax.fill_between(g.target,g.lower50,g.upper50,color=PALETTE[lab],alpha=.3,label='50% interval')
  ax.plot(g.target,g['mean'],color=PALETTE[lab],lw=1,label='30-step mean')
  ax.set(title=lab,ylabel='Response');ax.legend(ncol=4,frameon=False,fontsize=9)
 axes[-1].set_xlabel('Target time; observations available only through target minus 30')
 fig.savefig(figures/'forecasts.png',dpi=170);plt.close(fig)
 one=pd.read_csv(c/'one_step_calibration.csv');cal=pd.read_csv(c/'calibration_by_volatility.csv')
 fig,axes=plt.subplots(2,1,figsize=(10,7),layout='constrained')
 ref=one[one.model==LABELS[0]];axes[0].plot(ref.target,ref.true_conditional_sd,color='#273b4b',lw=1,label='True conditional SD')
 for lab in LABELS:
  g=one[one.model==lab];axes[0].plot(g.target,g.predictive_sd,lw=.8,c=PALETTE[lab],label=lab)
 axes[0].set(title='One-step predictive SD and true conditional innovation SD',xlabel='Target time',ylabel='SD');axes[0].legend(ncol=2,frameon=False,fontsize=9)
 bands=['low','middle','high'];x=np.arange(3)
 for j,lab in enumerate(LABELS):
  g=cal[cal.model==lab].set_index('band').loc[bands];axes[1].bar(x+(j-1.5)*.19,g.Coverage90,width=.19,label=lab,color=PALETTE[lab])
 axes[1].axhline(.9,c='gray',ls='--',lw=.8);axes[1].set_xticks(x,bands)
 axes[1].set(title='One-step 90% coverage by true volatility band',xlabel='Bands use true-SD cutoffs from training rows only',ylabel='Coverage',ylim=(0,1.04))
 fig.savefig(figures/'volatility.png',dpi=170);plt.close(fig)
 models={sc['id']:pd.read_csv(b/sc['id']/sc['method']/'model_probabilities.csv') for sc in study['scenarios']}
 top=sorted(set().union(*(set(g.nlargest(8,'posterior_probability').model) for g in models.values())))
 fig,ax=plt.subplots(figsize=(10,4),layout='constrained');x=np.arange(len(top))
 for j,(name,g) in enumerate(models.items()):ax.bar(x+(j-1)*.26,g.set_index('model').loc[top,'posterior_probability'],width=.26,label=name,color=list(PALETTE.values())[j])
 ax.set_xticks(x,[str(j) for j in top],fontsize=9);ax.set(xlabel='Frozen architecture ID',ylabel='Posterior probability');ax.legend(ncol=3,frameon=False)
 fig.savefig(figures/'architectures.png',dpi=170);plt.close(fig)
 fig,axes=plt.subplots(2,1,figsize=(10,5),layout='constrained')
 for ax,sc in zip(axes,study['scenarios'][:2]):
  tr=pd.read_csv(b/sc['id']/sc['method']/'traces.csv.gz')
  for chain,g in tr.groupby('chain'):ax.plot(np.arange(len(g))[::30],g.log_global.iloc[::30],lw=.5,alpha=.7,label=f'Chain {chain}')
  ax.set(title=f"{sc['id']}: log(u); tau = {sc['tau0']} u",xlabel='Retained iteration',ylabel='log(u)');ax.legend(ncol=3,frameon=False)
 fig.savefig(figures/'traces.png',dpi=170);plt.close(fig)
 fig,axes=plt.subplots(3,1,figsize=(10,7),layout='constrained')
 for j,sc in enumerate(study['scenarios'][:2]):
  tr=pd.read_csv(b/sc['id']/sc['method']/'traces.csv.gz')
  values=[(np.log(sc['tau0'])+tr.log_global)/np.log(10),tr.log_slab/np.log(10),tr.effective_slopes_diagonal]
  for ax,val in zip(axes,values):ax.hist(val,bins=70,density=True,histtype='step',lw=1.5,label=sc['id']+' posterior',color=list(PALETTE.values())[j])
  tau_grid=np.linspace(-5,1,500);t=10**tau_grid;a=sc['tau0']
  axes[0].plot(tau_grid,2*np.log(10)/np.pi*a*t/(a*a+t*t),ls='--',lw=1,color=list(PALETTE.values())[j],label=sc['id']+' prior')
  c_grid=np.linspace(-2,3,500);v=10**c_grid
  axes[1].plot(c_grid,np.log(10)*v*invgamma.pdf(v,a=sc['slab_df']/2,scale=sc['slab_df']*sc['slab_scale']**2/2),ls='--',lw=1,color=list(PALETTE.values())[j],label=sc['id']+' prior')
 for ax,label in zip(axes,['log10(tau)','log10(c squared)','Diagonal effective-slopes proxy']):
  ax.set(xlabel=label,ylabel='Posterior density');ax.legend(frameon=False,fontsize=8,ncol=2);ax.grid(alpha=.15)
 fig.savefig(figures/'shrinkage.png',dpi=170);plt.close(fig)
 pdfmetrics.registerFont(TTFont('DV',findfont('DejaVu Sans')));pdfmetrics.registerFont(TTFont('DVB',findfont('DejaVu Sans:weight=bold')))
 pdfmetrics.registerFontFamily('DV',normal='DV',bold='DVB',italic='DV',boldItalic='DVB')
 styles=getSampleStyleSheet()
 for st in styles.byName.values():st.fontName='DV';st.textColor=colors.HexColor('#24313d')
 styles['Title'].fontName='DVB';styles['Title'].fontSize=23;styles['Title'].leading=28
 styles['Heading1'].fontName='DVB';styles['Heading1'].fontSize=16;styles['Heading1'].leading=20
 styles['BodyText'].fontSize=9;styles['BodyText'].leading=14
 styles.add(ParagraphStyle('Small',parent=styles['BodyText'],fontSize=7.3,leading=10.5))
 story=[]
 def para(text,style='BodyText'):
  story.append(Paragraph(str(text).replace('<=','&lt;=').replace('>=','&gt;='),styles[style]));story.append(Spacer(1,7))
 def title(text):para(text,'Heading1')
 def table(rows,widths):
  tb=Table([[Paragraph(str(v),styles['Small']) for v in row] for row in rows],colWidths=widths,repeatRows=1,hAlign='LEFT')
  tb.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e8edf2')),('VALIGN',(0,0),(-1,-1),'TOP'),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),7),('LINEBELOW',(0,0),(-1,0),.6,colors.HexColor('#aab5c0')),('LINEBELOW',(0,1),(-1,-1),.25,colors.HexColor('#d8dee3'))]));story.append(tb);story.append(Spacer(1,9))
 def image(path,width=500):
  from PIL import Image as PIL
  w,h=PIL.open(path).size;story.append(Image(str(path),width=width,height=width*h/w))
 def page():story.append(PageBreak())
 para('AutoDESN and AutoGP: nonlinear heteroscedastic seasonal dynamics','Title')
 para('NHS1 | completed fresh comparison | study initiated 23 October 2026','Small')
 para('One new series combines threshold nonlinear dynamics, an asymmetric nonsinusoidal seasonal pattern and persistent, asymmetric conditional variance. No deterministic trend is present. The DGP, seed, prior controls, architecture candidates and forecasting protocol were fixed before fitting. Every model is fitted fresh; no C1 forecast output is reused.')
 title('Data-generating process')
 para('Write y(t)=s(t)+x(t). The centered period-60 seasonal offset combines two asymmetric triangular pulses, a ramp and a 12-step block pattern. The residual conditional mean is a(x1)*x1 +0.28*tanh(1.4*x2) -0.25*tanh(x12) +0.22*tanh(x60) +0.20*tanh(1.5*x1*x2), where xk=x(t-k), a(x)=0.58 for x&lt;0 and 0.22 otherwise.')
 para('The innovation is epsilon(t)=sqrt(h(t))*z(t), z(t) standard Gaussian. h(t)=omega(t)+0.06*epsilon(t-1)^2+0.10*epsilon(t-1)^2*I[epsilon(t-1)&lt;0]+0.82*h(t-1). The baseline omega(t) is positive, periodic and dependent on the previous residual; exact pulse definitions are in dgp.R. It is bounded by 0.046 and expected volatility persistence is 0.93. The residual linear coefficient is bounded by 0.58 and other location terms are bounded. These bounds prevent a trend or explosive second moments; the seasonal process is periodic rather than covariance-stationary.')
 table([['Setting','Frozen value'],['DGP','Seed 1766021; 6,000-step burn-in; 3,000 retained observations'],['Split and forecast grid','500 washout; 2,000 training; 500 test; 471 origins x30 leads'],['Requested normalized RHS','tau0=0.001; slab_scale=1; slab_df=4; c^2~IG(2,2)'],['Other priors','Unit half-Cauchy global multiplier/local scales; intercept N(0,10 variance); observation variance IG(3,1); ridge precision Gamma(2, rate 2)'],['Readout basis','Training-only column z-scores on rows 501:2500; no division by sqrt(d)'],['Primary forecast budget','192 joint posterior draws x8 recursive innovation paths']], [130,370])
 para('All fitted likelihoods retain constant observation-variance parameters. This is a calibration stress test under misspecification, not a claim that their conditional variance models match the DGP. Truth quantities are isolated from the observed-only training interface.','Small')
 page();title('The single frozen realization');image(HERE/'evidence/NHS1_DGP.png')
 para('The seed was not selected by inspecting forecast errors. DGP truth is used for these plots and post-fit calibration assessment only. Models receive the two-column time/response file. There is no full-series centering, and no held-out response is used to fit a scaler.','Small')
 page();title('Pooled forecast scores')
 table([['Model','RMSE','MAE','CRPS','NLL']]+[[r.model]+[f'{r[k]:.6f}' for k in ['RMSE','MAE','CRPS','NLL']] for _,r in pooled.iterrows()],[216,71,71,71,71])
 title('Predictive intervals')
 table([['Model','Cov.50%','Width50%','Cov.90%','Width90%']]+[[r.model]+[f'{r[k]:.4f}' for k in ['Coverage50','Width50','Coverage90','Width90']] for _,r in pooled.iterrows()],[216,71,71,71,71])
 para('Each model has exactly 14,130 dependent origin/lead pairs. Lower RMSE, MAE, CRPS and negative log predictive density (NLL) are better descriptively. Coverage and interval width must be assessed together. Native AutoGP marginal mixture scores are analytic; AutoDESN CRPS and intervals use recursive draws, and its NLL uses the conditional Gaussian mixture over simulated histories.')
 para('One realization cannot establish statistical superiority across DGPs or independent replications. Small gaps must also be assessed against posterior and predictive Monte Carlo error. No hyperparameter search uses these held-out outcomes.')
 page();title('Forecast quality by horizon');image(figures/'horizons.png')
 page();title('Rolling forecasts and predictive intervals');image(figures/'forecasts.png')
 para('Horizon 30 at all 471 origins. Parameters and architecture weights are frozen at origin 2500. Observed reservoir states update only between origins. Within a forecast, simulated responses drive all later states; future observations are absent. Native GP conditioning likewise incorporates only observations available at each origin, with kernel parameters and mixture weights fixed.','Small')
 page();title('Calibration under heteroscedasticity');image(figures/'volatility.png')
 para('Only horizon1 is compared with the true conditional innovation SD. A future realized conditional SD would not equal the marginal predictive SD of a multi-step forecast. Low/middle/high bands use the two training-only true-SD tertile cutoffs and are reporting diagnostics, not features supplied to the models.','Small')
 rows=[['Model','Band','Pairs','90% coverage','Predictive SD','True SD']]
 for _,r in cal.iterrows():rows.append([r.model,r.band,int(r.pairs),f'{r.Coverage90:.3f}',f'{r.mean_predictive_sd:.3f}',f'{r.mean_true_sd:.3f}'])
 table(rows,[170,55,45,80,75,75])
 page();title('Bayesian architecture averaging and shrinkage')
 para('For slopes, beta_j | tau,lambda_j,c² ~ N(0,v_j), v_j=c²*tau²*lambda_j²/(c²+tau²*lambda_j²), independently of observation variance sigma². The global multiplier u and local lambda_j have unit half-Cauchy priors; tau=tau0*u. The intercept has variance10. Architecture moves integrate every coefficient using C_m=sigma²*I+X_m*diag(10,v)*X_mᵀ, retaining its determinant and normalized Gaussian density. This is the normalized RHS, not the augmented rhs_ns prior.','Small')
 image(figures/'architectures.png')
 rows=[['Scenario','D','Layer widths','Input lags','Layer leaks','Layer radii','Seed']]
 for sc in study['scenarios']:
  g=models[sc['id']];lead=g.loc[g.posterior_probability.idxmax()]
  rows.append([sc['id'],int(lead.D),str(lead.widths),int(lead.m),str(lead.layer_leaks),str(lead.layer_radii),int(lead.seed)])
 table(rows,[90,25,105,35,110,110,25])
 para('Leading architectures are identified by the posterior mass, without changing the predictive mixture. Full candidate definitions, all 426 architecture probabilities and numerical uncertainty summaries are archived.','Small')
 page();title('RHS scales and shrinkage')
 rows=[['Scenario','Leading candidate','Mass (indicator SE)','tau median [5%,95%]','c^2 median [5%,95%]']]
 for sc in study['scenarios']:
  g=models[sc['id']];lead=g.loc[g.posterior_probability.idxmax()];indicator=diag[(diag.scenario==sc['id'])&(diag.parameter==f'model_{int(lead.model)}')].iloc[0];se=np.sqrt(lead.posterior_probability*(1-lead.posterior_probability)/indicator.bulk_ess);row=[sc['id'],f'{int(lead.model)}: {lead.candidate}',f'{lead.posterior_probability:.3f} ({se:.3f})']
  if sc['method']=='rhs':
   q=pd.read_csv(b/sc['id']/sc['method']/'shrinkage_quantiles.csv').set_index('parameter')
   for name in ['global_tau','slab_variance']:
    z=q.loc[name];row.append(f'{z["median"]:.4g} [{z.q05:.4g}, {z.q95:.4g}]')
  else:row+=['-','-']
  rows.append(row)
 table(rows,[90,100,70,120,120])
 para('The indicator-based SE uses the leading model frequency ESS as an approximate sampling-error diagnostic; conditional probability mass estimates have their own batch MCSE in the archived tables. Neither estimates variation across independent time-series realizations.','Small')
 for sc in study['scenarios'][:2]:
  q=pd.read_csv(b/sc['id']/sc['method']/'shrinkage_quantiles.csv').set_index('parameter').loc['effective_slopes_diagonal']
  para(f"{sc['id']} diagonal effective-slopes proxy: median {q['median']:.3f}, 5%-95% [{q.q05:.3f}, {q.q95:.3f}]. This sums d_j*(X'X)_jj / (sigma²+d_j*(X'X)_jj), using slope prior variances d_j; it ignores feature correlations and is not a count of selected coefficients.",'Small')
 para('tau0 is a prior multiplier, not a fixed posterior tau. Global, local and slab scales are sampled. The normalized Gaussian slope density and every architecture-dependent Gaussian determinant are retained. Layerwise common auxiliary coordinates and product-preserving interweaving preserve the same normalized RHS target; inactive proper priors integrate to one. No test-error screening substitutes for architecture averaging.','Small')
 image(figures/'shrinkage.png')
 para('Solid histograms are posterior densities; dashed curves are the normalized half-Cauchy global-scale and inverse-gamma slab priors after the log10 coordinate transformation. The effective-slopes panel is an approximation, with no implied variable-selection threshold.','Small')
 page();title('Retained-chain diagnostics');image(figures/'traces.png')
 rows=[['Scenario','Max rank R-hat','Min bulk ESS','Min tail/frequency ESS','Kept/chain']]
 for sc in study['scenarios']:
  z=diag[diag.scenario==sc['id']];st=json.loads((b/sc['id']/sc['method']/'status.json').read_text());n=budgets[(budgets.scenario==sc['id'])&(budgets.attempt==st['selected_attempt'])].n_mcmc.iloc[0]
  rows.append([sc['id'],f'{z.rhat.max():.5f}',f'{z.bulk_ess.min():.1f}',f'{z.tail_ess.min():.1f}',int(n)])
 table(rows,[125,90,90,100,95])
 para('Three chains; continuous split rank/folded R-hat<=1.01 and bulk/tail ESS>=400. Six fixed training-row fitted means are additionally monitored across architectures with different coefficient dimensions. The mean_log_local monitor averages the common auxiliary vector, including inactive prior coordinates; it is not an active-coefficient shrinkage summary. Architecture indicators with posterior mass>=1% also pass rank R-hat/frequency ESS, plus the R spectral-ESS and absolute chain-frequency-range gates. Binary frequency ESS is shown in both ESS columns. Checks pass before forecasting. These monitored diagnostics do not prove convergence or accurate rare-model probabilities. Full traces, controls, chain exploration and all failed budgets are archived.','Small')
 title('Architecture exploration')
 rows=[['Scenario','Models visited (chains 1/2/3)','Retained switches (chains 1/2/3)']]
 for sc in study['scenarios']:
  z=pd.read_csv(b/sc['id']/sc['method']/'exploration.csv')
  rows.append([sc['id'],' / '.join(str(int(v)) for v in z.unique_models),' / '.join(str(int(v)) for v in z.switches)])
 table(rows,[125,185,190])
 para('Visits and switches describe exploration; they are not convergence criteria. Proposal/acceptance counts include burn-in and are retained with the exact controls. Architecture indicator diagnostics concern the retained chains.','Small')
 page();title('Sampling and predictive budgets')
 rows=[['Scenario','Burn/chain','Kept/chain','Max R-hat','Min ESS','Max mass range','Pass']]
 for _,r in budgets.iterrows():rows.append([r.scenario,int(r.n_burn),int(r.n_mcmc),f'{r.max_rhat:.5f}',f'{r.min_ess:.1f}',f'{r.max_model_frequency_range:.3f}',str(bool(r.qualified))])
 table(rows,[135,55,60,65,70,65,50])
 para('The displayed R-hat/ESS columns concern continuous parameters. Pass additionally requires architecture diagnostics. After two failed model-only proposals, a joint architecture/log-scale Student-t mixture is fitted to completed training chains and frozen before fresh production. Four original model-only moves and two joint moves per sweep retain exact Gaussian coefficient-collapsed targets, prior/Jacobian constants and Hastings corrections. Initial production budgets are 16k/32k/64k/128k kept per chain. After the scaling-only final budget failed the 5-point architecture-frequency-range gate, a same-prior proposal recovery declares one fresh 3x128k budget. Shared training is reported once below. No failed screen is waived. No test scores inform recovery.','Small')
 title('Predictive Monte Carlo sensitivity')
 sens=pd.read_csv(c/'mc_sensitivity_summary.csv');rows=[['Scenario','N x K','RMSE (3 origins)','CRPS','NLL']]
 for sc in study['scenarios']:
  for n,k in [(192,8),(384,32)]:
   r=sens[(sens.scenario==sc['id'])&(sens.N==n)&(sens.K==k)].iloc[0];rows.append([sc['id'],f'{n} x{k}',f'{r.RMSE:.5f}',f'{r.CRPS:.5f}',f'{r.NLL:.5f}'])
 table(rows,[170,75,85,85,85])
 para('All 24 combinations per model are archived: origins 2500, 2735, 2970; N=192/384 and K=4/8/16/32. A setting has 90 dependent pairs, not 14,130. The same qualified posterior is reused. Native GP additionally exports full run-by-run forecast sensitivity for its two independent eight-particle SMC fits.','Small')
 page();title('Native AutoGP and measured runtime')
 gp=json.loads((b/'gp/status.json').read_text());native=json.loads((b/'gp/native_resources.json').read_text());gt=gp['timings']
 para('Fresh authors\' AutoGP 0.1.19 at revision 2ad372db2b8bea176e3b32a769bfb5d6cff80866, Julia 1.10.10. Native grammar/priors, depth 4, two independent eight-particle SMC fits; unchanged stage-wise schedule and HMC controls. Native save/reload and three-origin Gaussian-conditioning checks passed. These verify transport, not SMC posterior exploration.')
 rows=[['Run','Particles','Final particle ESS','Distinct kernel states','Largest weight']]
 for run in [1,2]:
  st=tomllib.loads((b/f'gp/run_{run}/status.toml').read_text());pa=pd.read_csv(b/f'gp/run_{run}/particles.csv');rows.append([run,8,f'{st["ess"]:.3f}',pa.kernel.nunique(),f'{pa.weight.max():.4f}'])
 table(rows,[70,90,115,115,110])
 para('Distinct exported kernel states include continuous parameter values, not just tree structures. Particle ESS can be reset by resampling; it does not establish exploration of kernel space. Run-by-run forecast sensitivity measures variation between two finite-particle approximations, not independent DGP replications.','Small')
 raw=json.loads((b/'raw_bank/status.json').read_text())
 bm=json.loads((b/"bank_memory.json").read_text())
 para(f"Shared raw builder: {raw['invocation_wall_seconds']:.2f}s wall; frozen standardized-design preparation: {bank['standardization_seconds']:.2f}s. The complete bank-building command, including startup and serialization, took {bm['invocation_wall_seconds']:.2f}s with parent peak RSS {bm['process_peak_rss_kib']/2**20:.2f}GiB. Reservoir candidates and state timing match across all AutoDESN priors.")
 rows=[['Scenario','Pilots(s)','Completed chain(s)','Observed fit wall(s)','Forecast compute(s)','State update(s)','Peak GiB']]
 for sc in study['scenarios']:
  st=json.loads((b/sc['id']/sc['method']/'status.json').read_text());t=st['timings'];m=json.loads((b/sc['id']/'process_memory.json').read_text())
  rows.append([sc['id'],f'{t["training_pilot_seconds"]:.2f}',f'{t["inference_seconds_all_attempts"]:.2f}',f'{m["fit_invocation_wall_seconds_sum"]:.2f}',f'{t["forecast_compute_seconds_sum"]:.2f}',f'{t["state_preparation_seconds_this_invocation"]:.2f}',f'{m["process_peak_rss_kib"]/2**20:.2f}'])
 table(rows,[100,50,70,70,70,60,80])
 for d in sorted(x for x in b.iterdir() if x.name.endswith(('_initial_proposal','_rebalanced_64k','_joint_initial'))):
  t=json.loads((d/'rhs/status.json').read_text())['timings'];para(f"Additional failed training cost ({d.name}): {t['inference_seconds_all_attempts']:.2f}s completed inference plus {t.get('training_pilot_seconds',0):.2f}s pilots. These training fits issued no forecasts. The requested-prior source is shared across RHS cases; the scaling-only joint source is additional recovery cost for that control.",'Small')
 for ledger in sorted((b/'validation').glob('execution_interruption_*.json')):
  lost=json.loads(ledger.read_text());t=lost['last_memory_record']['invocation_wall_seconds']
  para(f"Execution interruption ({lost.get('scenario','unknown')}): last observed invocation wall {t:.2f}s. Its completed chains are counted once in chain compute; the unfinished chain was recomputed. The first interrupted invocation's stdout was overwritten before backup; its last timing observation and resume logs are retained. Fit wall sums recorded invocations, including this observation, and includes repeated cache loading and diagnostics.",'Small')
 para(f"Native AutoGP summed SMC callback training: {gt['smc_training_seconds_sum']:.2f}s. Native invocation including startup, training, export and conditioning contracts: {gt['native_launcher_seconds_this_invocation']:.2f}s. Rolling conditioning/scoring/export: {gt['rolling_conditioning_scoring_seconds']:.2f}s. Native-process peak RSS: {native['native_peak_rss_kib']/2**20:.3f}GiB. Timer scopes differ from AutoDESN per-origin compute; no clean end-to-end speedup claim follows.",'Small')
 para('Inference totals include completed failed budgets; interrupted partial work is retained separately in wall-time logs. Forecast compute sums per-origin calls and excludes state preparation, scoring/export and sensitivity. Parent VmHWM excludes forked workers; Native Julia memory uses Linux wait4 child rusage. R uses one BLAS thread; the original native AutoGP script uses two BLAS threads and one Julia thread. Large inference/forecast jobs run sequentially. Hardware quota and memory limits are archived. Light validation/integrity checks and initial dependency setup may overlap inference; these are observed runtimes, not isolated hardware benchmarks.','Small')
 page();title('Validation, limits and reproducibility')
 para(f"All {bank['admitted']} admitted architectures share the raw bank and frozen feature transforms. Maximum absolute training column mean {bank['max_abs_mean']:.3g}; maximum sample-SD error {bank['max_sd_error']:.3g}. The API freezes exclusions for near-constant features; the intercept has its own proper prior and raw-coordinate transport includes its centering shift.")
 validation=json.loads((b/'validation/validation_status.json').read_text());para(validation['summary'])
 bench=pd.read_csv(b/'validation/standardized_backend_benchmark.csv').groupby('backend').elapsed_seconds.median()
 parity=pd.read_csv(b/'validation/standardized_backend_parity.csv')
 para(f"Fresh short computational benchmark: median R {bench['R']:.3f}s versus native kernels {bench['cpp']:.3f}s ({bench['R']/bench['cpp']:.2f}x). Four standardized synthetic designs,200 rows, up to64 slopes,100 burn +800 retained draws,three timing repetitions; setup/compilation excluded. Maximum coupled-draw discrepancy {parity.max_paired_draw_error.max():.3g}; identical model paths. Joint proposals are disabled in this short kernel benchmark; production timings include them. This is a computational check, not evidence of posterior convergence or a full-study speedup.",'Small')
 para('Independent path reconstruction verifies scores at the first, middle and last origins. Future-data perturbation changes every unavailable response by100 while holding posterior draws and innovations fixed; forecasts remain identical. Archived joint checkpoints are replayed against saved paths. The numeric archive has part-level, complete-archive and internal SHA256 checks, plus a restored-analysis round trip.','Small')
 para('The frozen reservoir grid includes input lag60, matching the DGP season and lag60 term. Broader stress studies should vary periods and independent seeds. Gaussian conditional variances are deliberately misspecified for this heteroscedastic DGP. Poor calibration in high-volatility periods motivates a future variance-model extension; such an extension would be a distinct benchmark with its own prior and validation. A single series and overlapping origin/lead pairs do not establish general superiority. Preprocessing is treated as frozen rather than jointly inferred.','Small')
 para('Release remains draft. The inherited scoped repository R CMD check has one nonportable-path error, three documentation/non-ASCII warnings and two notes. Focused tests and numerical checks are reported separately; no clean package-wide release check is claimed.','Small')
 para('See README.md and RESULTS.md in validation/autodesn/nonlinear_heteroscedastic. generate.R freezes the DGP; run.R/fit_joint.R/execute_joint.py fit the three AutoDESN cases; run_gp.py fits pinned Native AutoGP; export.R, archive.R, replay.R, analysis.py and report.py reproduce evidence and reporting. Existing C1 artifacts are preserved. Draft PR: https://github.com/AntonioAPDL/exdqlm/pull/4.','Small')
 out=HERE/'evidence/NHS1_AutoDESN_AutoGP_Report.pdf'
 def footer(canvas,doc):
  canvas.setFont('DV',7);canvas.setFillColor(colors.HexColor('#657282'));canvas.drawString(48,25,'NHS1 | one new DGP realization | study initiated 23 October 2026');canvas.drawRightString(548,25,str(doc.page))
 SimpleDocTemplate(str(out),pagesize=(596,842),leftMargin=42,rightMargin=42,topMargin=36,bottomMargin=36,title='NHS1 nonlinear heteroscedastic AutoDESN and AutoGP').build(story,onFirstPage=footer,onLaterPages=footer)
 print(out)
if __name__=='__main__':main()
