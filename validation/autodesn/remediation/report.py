"""Build the evidence-backed execution report; unfinished work stays explicit."""
import hashlib, json, subprocess
from pathlib import Path
from xml.sax.saxutils import escape

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
import numpy as np
import pandas as pd
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, PageBreak

ROOT=Path('validation/autodesn/remediation');E=ROOT/'evidence';OUT=ROOT/'output';FIG=OUT/'figures';PDF=OUT/'pdf'
FIG.mkdir(parents=True,exist_ok=True);PDF.mkdir(parents=True,exist_ok=True)
HISTORY=ROOT.parent/'nonlinear_heteroscedastic'
NAVY='#17324b';BLUE='#2275a5';TEAL='#228877';AMBER='#b57920';RED='#a84242';PALETTE=[BLUE,TEAL,AMBER,'#8a65a3','#59636d','#4b7b8a']
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'axes.spines.top':False,'axes.spines.right':False,'axes.labelcolor':NAVY,'text.color':NAVY,'axes.titleweight':'bold','savefig.facecolor':'white'})
inputs={};partial_observations={}
def read_json(path,default=None):
    path=Path(path)
    if not path.exists():return default
    inputs[str(path)]=hashlib.sha256(path.read_bytes()).hexdigest();return json.loads(path.read_text())
def read_csv(path,**kwargs):
    path=Path(path)
    with path.open('rb') as handle:inputs[str(path)]=hashlib.file_digest(handle,'sha256').hexdigest()
    return pd.read_csv(path,**kwargs)
def fmt(x,d=3):return 'not measured' if x is None else f'{x:,.{d}f}'
def save_plot(fig,name):
    path=FIG/(name+'.png');fig.savefig(path,dpi=180,bbox_inches='tight');plt.close(fig);return path

def archived_case_count(directory):
    manifests=sorted((E/'checkpoints').glob('remediation_checkpoint_*.manifest.json'))
    if not manifests:return 0
    manifest_path=manifests[-1];manifest=read_json(manifest_path)
    prefix=str(directory)+'/case_'
    cases={r['path']:r for r in manifest.get('inherited_members',[])+manifest['members'] if r['path'].startswith(prefix) and r['path'].endswith('.rds')}
    partial_observations[str(directory)]=dict(manifest=str(manifest_path),members=list(cases.values()))
    return len(cases)

tests=read_json(E/'family_release_source_tests.json') or read_json(E/'calendar_release_source_tests.json') or read_json(E/'extended_tests.json',{});installed=read_json(E/'family_release_installed_tests.json') or read_json(E/'calendar_release_installed_tests.json') or read_json(E/'portable_installed_tests.json',{});legacy=read_json(E/'legacy_tests.json',{})
package_ci=read_json(E/'full_package_ci_audit.json',{})
qualifications=[]
for path in sorted(E.glob('F1_production_*_qualification.json')):
    q=read_json(path);directory=ROOT/'artifacts/F1'/q['phase'];cfg=read_json(directory/'configuration.json',{})
    qualifications.append((q,cfg))
latest=max(qualifications,key=lambda item:item[1].get('retained',0)) if qualifications else None
traces=None;trace_figure=occupancy_figure=None
if latest:
    q,c=latest;directory=ROOT/'artifacts/F1'/q['phase']
    traces=[read_csv(directory/f'trace_{k}.csv',usecols=['model','variance','log_global_1','log_slab','fitted_probe_4','norm_lag','norm_reservoir']) for k in range(1,5)]
    fig,axes=plt.subplots(3,2,figsize=(7,6.0),sharex=True)
    fields=[('variance','Noise variance'),('log_global_1','Log global multiplier'),('log_slab','Log slab variance'),('fitted_probe_4','Training fitted-mean probe'),('norm_lag','Lag coefficient norm'),('norm_reservoir','Reservoir coefficient norm')]
    for ax,(field,label) in zip(axes.flat,fields):
        for k,t in enumerate(traces):
            step=max(1,len(t)//1800);ax.plot(np.arange(1,len(t)+1)[::step],t[field].to_numpy()[::step],lw=.5,alpha=.75,color=PALETTE[k],label=f'Chain {k+1}')
        ax.set_title(label,fontsize=9,loc='left');ax.grid(alpha=.15)
    axes[0,0].legend(ncol=2,fontsize=7,frameon=False)
    for ax in axes[-1,:]:ax.set_xlabel('Retained sweep (display subsample)')
    fig.suptitle(f"F1, {c.get('retained',0):,} draws per chain - qualification pending",fontsize=12)
    fig.tight_layout();trace_figure=save_plot(fig,'F1_traces')
    metadata=read_csv(directory/'model_metadata.csv').set_index('model')
    counts=pd.concat([t.model.value_counts(normalize=True).rename(k) for k,t in enumerate(traces)],axis=1).fillna(0)
    top=counts.mean(axis=1).nlargest(10).index;top_counts=counts.loc[top]
    fig,(ax,bx)=plt.subplots(1,2,figsize=(7,3.55),gridspec_kw={'width_ratios':[1.3,1]})
    for k in range(4):ax.scatter(top_counts[k],np.arange(len(top))+(k-1.5)*.13,s=18,color=PALETTE[k],label=f'C{k+1}')
    ax.set_yticks(np.arange(len(top)),[str(metadata.loc[int(m),'candidate']) for m in top]);ax.invert_yaxis();ax.set_xlabel('Within-chain occupancy');ax.set_title('Ten most visited reservoirs',loc='left',fontsize=9);ax.legend(ncol=4,fontsize=7,frameon=False,loc='lower right');ax.grid(axis='x',alpha=.15)
    for k,t in enumerate(traces):
        bx.scatter(t.norm_lag.iloc[::max(1,len(t)//1000)],t.norm_reservoir.iloc[::max(1,len(t)//1000)],s=2,alpha=.18,color=PALETTE[k])
    bx.set_xlabel('Lag coefficient norm');bx.set_ylabel('Reservoir coefficient norm');bx.set_title('Readout allocation',loc='left',fontsize=9);fig.tight_layout();occupancy_figure=save_plot(fig,'F1_occupancy_and_norms')

references=[]
for stem,label in [('grouped','Grouped, fixed locals'),('local','Grouped, learned locals'),('local_joint','Joint scale/local proposal'),('sv_joint','Full two-response SV'),('gp_leaf','Complete GP leaf grammar'),('production_scale','RHS controls .001 / 1')]:
    s=read_json(E/f'{stem}_mcmc_reference.json')
    if s:references.append((stem,label,s,read_csv(E/f'{stem}_mcmc_reference_checks.csv')))
fig,ax=plt.subplots(figsize=(7,3.2))
for i,(stem,label,s,t) in enumerate(references):
    ratio=t.absolute_error/t.tolerance;ax.scatter(ratio,np.arange(len(t))*.02+i,s=18,color=PALETTE[i],label=label)
ax.axvline(1,color=RED,ls='--',lw=1);ax.set_xlim(0,max(1.12,max((float((t.absolute_error/t.tolerance).max()) for _,_,_,t in references),default=0)*1.03));ax.set_yticks(range(len(references)),[v[1] for v in references]);ax.set_xlabel('Absolute moment error / registered numerical-MC tolerance');ax.grid(axis='x',alpha=.18);fig.tight_layout();reference_figure=save_plot(fig,'independent_reference_agreement')

calibration_figure=None
calibration_paths=[('Fixed exogenous design',ROOT/'artifacts/sbc_rhs_24000/ranks.csv'),('Recursive frozen map',ROOT/'artifacts/recursive_sbc_constant_n200_k24000_recovered96000/ranks.csv')]
if all(path.exists() for _,path in calibration_paths):
    fig,axes=plt.subplots(1,2,figsize=(7,2.8))
    for ax,(label,path) in zip(axes,calibration_paths):
        ranks=read_csv(path);n=len(ranks);bound=np.sqrt(np.log(2*ranks.shape[1]/.01)/(2*n));grid=np.linspace(0,1,201)
        ax.fill_between(grid,np.maximum(0,grid-bound),np.minimum(1,grid+bound),color='#e9f0f5')
        ax.plot(grid,grid,color=NAVY,lw=.8,ls='--')
        for column in ranks:
            display={'variance':'Noise variance','fitted_mean':'Fitted mean','joint_likelihood':'Log likelihood','architecture':'Architecture','period':'Period','global':'Global','slab':'Slab'}.get(column,column)
            x=np.sort(ranks[column]);ax.step(np.r_[0,x,1],np.r_[0,np.arange(1,n+1)/n,1],where='post',label=display,lw=.8)
        ax.set(xlabel='Randomized posterior rank',ylabel='Empirical CDF',title=label,xlim=(0,1),ylim=(0,1));ax.legend(fontsize=7,ncol=2,frameon=False,loc='lower right');ax.grid(alpha=.12)
    fig.tight_layout();calibration_figure=save_plot(fig,'calibration_rank_ecdf')

historical=read_csv(HISTORY/'evidence/pooled_metrics.csv');horizon=read_csv(HISTORY/'evidence/horizon_metrics.csv')
models=['AutoDESN RHS: 0.001 / 1','AutoDESN ridge','Native AutoGP']
short=['Historical RHS .001 / 1','Historical ridge','Historical native GP']
fig,axes=plt.subplots(1,3,figsize=(7,2.8))
for i,(name,label) in enumerate(zip(models,short)):
    t=horizon[horizon.model==name].sort_values('horizon')
    for ax,metric in zip(axes,['RMSE','CRPS','Coverage90']):ax.plot(t.horizon,t[metric],color=PALETTE[i],label=label,lw=1.4)
for ax,metric in zip(axes,['RMSE','CRPS','Coverage90']):ax.set_title(metric,loc='left');ax.set_xlabel('Horizon');ax.grid(alpha=.15)
axes[-1].axhline(.9,color=RED,ls='--',lw=.8);axes[0].legend(fontsize=6,frameon=False);fig.tight_layout();historical_figure=save_plot(fig,'historical_horizon_scores')

capacity=None;capacity_summary=None;capacity_figure=None
if (E/'representation_capacity.csv').exists():
    capacity=read_csv(E/'representation_capacity.csv');capacity_summary=read_csv(E/'representation_capacity_summary.csv')
    read_json(E/'representation_capacity.json');read_json(E/'representation_capacity_interpretation.json')
    fig,ax=plt.subplots(figsize=(7,3.0))
    labels=[('F0','Reservoir'),('F1','Reservoir + direct lags'),('F2_known_period60','Known period 60 probe (privileged)')]
    for i,(space,label) in enumerate(labels):
        t=capacity[capacity.space==space].sort_values('conditional_mean_training_span_rmse')
        ax.step(t.conditional_mean_training_span_rmse,np.cumsum(t.prior_weight),where='post',color=PALETTE[i],label=label,lw=1.4)
    ax.set(xlabel='Per-architecture training approximation RMSE (response units)',ylabel='Cumulative architecture prior mass',ylim=(0,1.01))
    ax.grid(alpha=.15);ax.legend(fontsize=7,frameon=False,loc='lower right');fig.tight_layout();capacity_figure=save_plot(fig,'training_span_capacity')

statistics_benchmark=read_json(E/'statistics_cache_benchmark.json',{})
checkpoint_reference=read_json(E/'checkpoint_fresh_process.json',{})
checkpoint_execution=read_json(E/'checkpoint_recovery_execution.json',{})
interruption=read_json(E/'F1_statistics_256_interruption.json',{})
statistics_pairs=read_csv(E/'statistics_cache_benchmark.csv') if (E/'statistics_cache_benchmark.csv').exists() else None

training_function=None;training_figure=None
if latest:
    stem=f"F1_{latest[0]['phase']}_training_function"
    training_function=read_json(E/(stem+'.json'))
    if training_function:
        t=read_csv(E/(stem+'.csv'));display=t[t.time>2200]
        fig,(ax,bx)=plt.subplots(2,1,figsize=(7,5.3),gridspec_kw={'height_ratios':[1.4,1]})
        ax.plot(display.time,display.y,color='#a9afb4',lw=.6,label='Observed response')
        ax.fill_between(display.time,display.q05,display.q95,color=BLUE,alpha=.2,label='90% latent-mean band')
        ax.plot(display.time,display.conditional_mean,color=NAVY,lw=1,label='Known DGP conditional mean')
        ax.plot(display.time,display.posterior_mean,color=BLUE,lw=.9,label='RHS posterior mean')
        ax.set(xlabel='Training time',ylabel='Response',title='Last 300 training observations; no held-out outcomes')
        ax.legend(fontsize=7,ncol=2,frameon=False);ax.grid(alpha=.12)
        bx.scatter(t.conditional_mean,t.posterior_mean,s=3,alpha=.25,color=BLUE)
        limits=[min(t.conditional_mean.min(),t.posterior_mean.min()),max(t.conditional_mean.max(),t.posterior_mean.max())]
        bx.plot(limits,limits,color=NAVY,ls='--',lw=.8)
        bx.set(xlabel='Known DGP conditional mean',ylabel='RHS fitted mean',title='All 2,000 training points')
        bx.grid(alpha=.12);fig.tight_layout();training_figure=save_plot(fig,'training_conditional_mean_audit')

font_path=font_manager.findfont(font_manager.FontProperties(family='DejaVu Sans'))
bold_path=font_manager.findfont(font_manager.FontProperties(family='DejaVu Sans',weight='bold'))
pdfmetrics.registerFont(TTFont('DV',font_path));pdfmetrics.registerFont(TTFont('DV-Bold',bold_path))
styles=getSampleStyleSheet();styles.add(ParagraphStyle(name='BodyDV',fontName='DV',fontSize=9.3,leading=14,spaceAfter=9,textColor=colors.HexColor(NAVY)))
styles.add(ParagraphStyle(name='SmallDV',fontName='DV',fontSize=7.8,leading=11,spaceAfter=7,textColor=colors.HexColor(NAVY)))
styles.add(ParagraphStyle(name='TitleDV',fontName='DV-Bold',fontSize=26,leading=31,spaceAfter=14,textColor=colors.HexColor(NAVY)))
styles.add(ParagraphStyle(name='HeadDV',fontName='DV-Bold',fontSize=17,leading=22,spaceAfter=13,textColor=colors.HexColor(NAVY)))
styles.add(ParagraphStyle(name='CellDV',fontName='DV',fontSize=8,leading=11,textColor=colors.HexColor(NAVY)))
story=[]
def p(text,small=False):return Paragraph(escape(str(text)),styles['SmallDV' if small else 'BodyDV'])
def add(text,small=False):story.append(p(text,small))
def title(text):story.append(Paragraph(escape(text),styles['HeadDV']))
def table(rows,widths=None):
    data=[[p(str(c),True) for c in row] for row in rows]
    t=Table(data,colWidths=widths,repeatRows=1,hAlign='LEFT');t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e9f0f5')),('VALIGN',(0,0),(-1,-1),'TOP'),('LINEBELOW',(0,0),(-1,0),.7,colors.HexColor(BLUE)),('LINEBELOW',(0,1),(-1,-1),.25,colors.HexColor('#d8e0e5')),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),5)]));story.append(t);story.append(Spacer(1,10))
def image(path,width=6.7*inch,max_height=4.8*inch):
    from PIL import Image as PILImage
    with PILImage.open(path) as im:w,h=im.size
    height=width*h/w
    if height>max_height:width*=max_height/height;height=max_height
    story.append(Image(str(path),width=width,height=height,hAlign='LEFT'));story.append(Spacer(1,7))
def page():story.append(PageBreak())

story.append(Paragraph('AutoDESN remediation',styles['TitleDV']));add('NHS1 nonlinear, seasonal and heteroscedastic series | 24 October 2026')
title('Execution and validation checkpoint')
table([['Outcome','Verified status'],['Implementation','Opt-in augmented readouts, period averaging, normalized grouped RHS, conditional SV, filtering, exact proposals and causal recursion are implemented.'],['Numerical correctness',f"{tests.get('passed','?')} source assertions pass; installed test results are reported separately. Independent reference outcomes and their scopes are reported separately."],['Production inference','No production posterior is yet scientifically qualified. Individually passing R-hat and ESS are insufficient when architecture-frequency or cross-budget gates fail.'],['Predictive comparison','No new full rolling-origin forecasts or independent confirmation scores are claimed. Historical scores are shown only as unchanged context.']], [100,380])
add('The work is not complete from start to finish. The distinction is deliberate: numerical identities, computational adequacy and predictive improvement are different requirements. Unfinished experiments cannot supply forecast scores or evidence of improvement.')
add('Repository: AntonioAPDL/exdqlm. Feature branch: feature/autodesn-remediation-20261023. Draft pull request: https://github.com/AntonioAPDL/exdqlm/pull/5.',True)
add('This report is generated from the output files listed in report_inputs.json. It preserves failed runs and source/checkpoint identities; scripts alone are never counted as executed experiments.',True)

page();title('Frozen statistical and forecasting contracts')
table([['Component','Executed reference convention'],['Data protocol','500 washout observations; 2,000 scored training observations; 500 held out. Fit once at 2500; origins 2500:2970; horizons 1:30.'],['Feature geometry','Original 456 reservoir definitions, 426 admitted. Training-only column centers and sample SDs; no square-root dimension normalization. Conditioning-prefix response/input transform is frozen.'],['Intercept and noise','Independent intercept Normal(0, variance 10); observation variance IG(shape 3, rate 1).'],['Normalized RHS','tau = 0.001 * u; u and each local scale are unit half-Cauchy. Slab variance IG(2,2): slab_scale=1, slab_df=4. Coefficient variance = 1 / (1/(tau*local)^2 + 1/slab_variance).'],['Mean families','F1 adds lags 1:90. F2 adds period-averaged Fourier terms over integers 20:120, up to 16 non-Nyquist harmonics. Flat and separately named grouped priors are supported.'],['Grouped prior','Independent lag/reservoir global scales; one shared slab; Gaussian calendar variance 0.5^2/[1+(harmonic/4)^4].'],['Conditional SV','Standardized stationary AR(1) state; (phi+1)/2 ~ Beta(10,1.5); omega ~ HalfNormal(0.5). Optional four-harmonic centered log variance.']], [105,375])
add('Definition audit: all 336 deep candidates use identity bridges; no PCA is fitted. The builder can draw seeded random reducers for other dimensions. The plan correction changes no model or prior. Prefix folds retain those maps and refit training scalers; see PLAN_CORRECTIONS_20261024.md.',True)
add('Every issued path holds its joint architecture, period and static parameters fixed. Simulated responses update future lags and reservoir states. Actual observations update states only between origins. Conditional SV filtering retains frozen outer parameter weights and replays training uncertainty; it is not full sequential parameter reweighting.')
add('The normalized RHS is not the augmented rhs_ns target. Coefficient-independent noise scaling, all Gaussian determinants, inactive proper priors and exact Hastings corrections are retained. See MATH.md for the joint densities and partial-collapse order.',True)

page();title('Independent posterior validation')
rows=[['Conditional reference','Quantities','Max R-hat','Min bulk / tail ESS','Check']]
for stem,label,s,t in references:rows.append([label,str(s['joint_functionals']),fmt(s['maximum_rhat'],6),f"{s['minimum_bulk_ess']:,.0f} / {s['minimum_tail_ess']:,.0f}",'PASS' if s.get('passed',False) else 'FAIL'])
table(rows,[150,65,80,130,55]);image(reference_figure,max_height=3.3*inch)
add('References use dense response-space Gaussian covariances and integration over normalized scale priors. The learned-local check integrates seven dimensions and tests nonuniform architecture/period proposals, variable active dimensions and the added reservoir-local proposal. SV uses independent full two-response quadrature, not only scalar conditional identities.')
add('The initial grouped RHS references use tau0=0.2. The additional seven-dimensional check uses the requested tau0=0.001, slab_scale=1, slab_df=4, with a proper intercept and unknown noise. The two-response SV target is intercept-only. These conditional checks do not certify the complete production workflow.',True)
add('The GP posterior-integration reference covers all three supported leaves and all four latent parameters under the pinned default depth-one grammar. It checks normalized scores and prior-independence MH; it does not qualify depth-four SMC.',True)
composite=read_json(E/'gp_composite_reference.json')
if composite:add('An additional finite conditional check enumerates all 30 default depth-two syntactic trees, including nine change-point trees and ordered sum/product pairs, across five latent fixtures. Independent covariances, normalized active/inactive prior constants and conditional architecture probabilities agree. This checks multiplicities at that depth; it does not integrate all continuous parameters or prove deep-tree exploration.',True)
add(f"The AutoDESN extension source suite has {tests.get('tests','?')} tests and {tests.get('passed','?')} passing assertions; its installed suite records {installed.get('passed','?')} passing assertions. Earlier legacy regression evidence records 804 passes with one separately covered context skip. Passing these checks is not proof of convergence on the 426-reservoir bank.",True)
fresh_ci=read_json(E/'full_package_ci_680_audit.json')
ci_repair=read_json(E/'ci_fixture_repairs.json')
if package_ci:add('Package-wide checks remain red: bf347f3 recorded 155 failures and four check errors; the later680c6f59 check recorded 152 failures, 50 warnings, 9 skips, 6548 passes and one check error. The latest complete compressed log is retained. Two repaired fixture contexts pass 47 assertions; the shipped-data example executes and repository-only config is excluded. Broader integration, backend, numerical and documentation failures remain unresolved. Scoped AutoDESN passes do not establish package-wide success.',True)

page();title('Production convergence: all gates still apply')
rows=[['F1 run','R-hat max','ESS min','Largest chain frequency range','Screen']]
for q,c in sorted(qualifications,key=lambda x:(x[1].get('retained',0),x[0]['phase'])):
    label=('Coordinate16 ' if 's16' in q['phase'] else 'Joint full-vector ' if 'joint' in q['phase'] else 'Local move ' if 'local' in q['phase'] else 'Baseline ')+f"{c.get('retained',0):,}"
    rows.append([label,fmt(q['maximum_rhat'],4),fmt(min(q['minimum_bulk_ess'],q['minimum_tail_ess']),0),fmt(max(q['frequency_ranges'].values()),4),'pass' if q['screen_passed'] else 'FAIL'])
table(rows,[110,70,65,150,85])
if trace_figure:image(trace_figure,max_height=3.9*inch)
add('Registered gates: rank/folded R-hat <=1.01, bulk/tail ESS >=400, major-category probability MCSE <=0.01, chain frequency ranges <=0.03. Two successive qualified fresh budgets must also agree within practical and Monte Carlo tolerances. No gate is waived because a different diagnostic passes.',True)
level256=read_json(E/'F1_256000_execution_summary.json')
if level256:add('The 256k joint run is the first individual level to pass. All 73 training-probe, predictive-quantile and major-probability comparisons against 128k pass their practical/MC tolerances, but the cross-budget certificate remains false because 128k fails its own frequency screen. A fresh 512k level with 128k warmup is registered before execution; it keeps the same frozen proposals, prior and target.',True)

page();title('Architecture exploration and shrinkage')
if occupancy_figure:image(occupancy_figure,max_height=3.7*inch)
add('These occupancies and coefficient norms use the latest complete run shown above. Full posterior qualification remains pending even when an individual screen passes. Distinct reservoir modes can have similar fitted functions; a small continuous-parameter R-hat alone does not establish adequate architecture probabilities.')
add('The RHS prior is continuous; exact zeros are not its sparsity mechanism. Coefficient norms and threshold counts depend on the standardized, correlated basis and do not measure a selected-variable count. Conditional group EDF is recorded at the Gaussian substep; a separate audit recomputes it at matching saved scales.')
shrink=read_json(E/f"F1_{latest[0]['phase']}_shrinkage.json") if latest else None
if shrink:
    shrink_summary={s['quantity']:s for s in shrink['summary']}
    add(f"The matching-state audit finds a median {100*shrink_summary['fraction_below_001_sd']['median']:.1f}% of standardized-feature slopes below 0.01 response SD, and median {shrink_summary['number_above_01_sd']['median']:.0f} above 0.1 response SD. Median actual global scale is {shrink_summary['actual_tau']['median']:.5f}, since the multiplier is sampled despite tau0=.001. Median slab SD is {shrink_summary['slab_sd']['median']:.3f}; slab_scale=1 is a hyperprior scale. This documents strong shrinkage with retained effects, not adequate predictive fit.")
add('The optional computational repair proposes active reservoir-local scales from a normalized prior/kernel-product mixture and inactive slots from their proper priors. It restores marginalized auxiliaries, then redraws coefficients. Every reservoir retains support. The proposal is frozen from training-only checkpoints; it changes computation, not tau0, the slab, the likelihood or architecture priors.')
qmeta=read_json(E/'F1_frozen_local_proposal_128.json')
if qmeta:add(f"The 128k-trained proposal has kernel estimates for {qmeta['models_with_kernel']} reservoirs and uses exact prior proposals for {qmeta['models_using_prior_only']} others. Scarce training samples do not remove a reservoir.",True)

if capacity_figure:
    page();title('Representation: a training-only capacity probe')
    image(capacity_figure,max_height=3.3*inch)
    rows=[['Feature space','Median rank / columns','Prior-weighted mean RMSE','Best RMSE']]
    labels={'F0':'Reservoir only','F1':'Add direct lags 1:90','F2_known_period60':'Add known calendar60 (privileged)'}
    for t in capacity_summary.itertuples():rows.append([labels[t.space],f'{int(t.median_rank)} / {int(t.median_columns)}',fmt(t.prior_weighted_mean_span_rmse,3),fmt(t.minimum_span_rmse,3)])
    table(rows,[170,105,120,85])
    add('Each architecture is projected separately onto the known one-step conditional mean along observed training history, using an unpenalized SVD fit on rows 501:2500. No held-out observations enter this audit. The feature geometry of all 426 candidates reproduces the frozen bank hash, and nested-space residuals never increase.')
    add('Direct lags substantially reduce the per-architecture training approximation error. This is evidence that the added basis can represent useful mean structure. It does not show that the RHS posterior has learned it, that shrinkage is adequate, or that recursive forecasts improve.')
    add('The period60 probe is privileged. It tests a calendar space also present in the automatic model support, but supplies no period information to the automatic fit. The plotted weights are architecture priors, not posterior probabilities. A Bayesian averaged mean combines spaces; these per-model bounds are not lower bounds on its error.',True)
    add('All designs are numerically full rank under the registered SVD threshold. Median condition numbers are about 2022-4269; the maximum is about 1.9e8. Correlated feature directions can make individual coefficients difficult to interpret even when fitted functions are stable.',True)

if training_function:
    page();title('Retained signal, remaining mean bias')
    image(training_figure,max_height=4.8*inch)
    m=training_function['metrics']
    table([['Training-only diagnostic','Response units'],['RHS mean vs known conditional mean',fmt(m['training_conditional_mean_rmse'],4)],['RHS mean vs observed response',fmt(m['training_observed_rmse'],4)],['Realized innovations: observed minus true mean',fmt(m['realized_innovation_rmse'],4)],['Weighted unpenalized fits vs true mean',fmt(m['weighted_unpenalized_fit_conditional_mean_rmse'],4)],['Weighted privileged projections vs true mean',fmt(m['weighted_privileged_projection_rmse'],4)]],[350,130])
    add(f"The fitted/true mean correlation is {m['conditional_mean_correlation']:.4f}. Shrinkage improves the descriptive conditional-mean error relative to unpenalized fits of the same stored architecture mixture. The privileged truth projections show additional representational room; neither projection is a fitted forecasting alternative or an error bound for Bayesian averaging.",True)
    add(f"The latent-mean bands omit observation noise. Their descriptive within-training 90% truth coverage is {100*m['descriptive_training_latent_coverage90']:.1f}%, indicating substantial remaining mean discrepancy. This is not predictive interval coverage or independent repeated-sample coverage. These are 8,192 stored joint states from the first individually passing level; full posterior qualification is pending.",True)

standardization=read_json(E/'full_standardization.json')
common=read_json(E/f"F1_{latest[0]['phase']}_common_rhs_diagnostics.json") if latest else None
if standardization or common:
    page();title('Feature and common-scale audit')
    if standardization:
        table([['Executed standardization check','Result'],['All 426 reservoir and direct-lag readouts','PASS'],['All 101 periods, F2 and F2flat','PASS; calendar matrices identical'],['Largest absolute feature mean',f"{standardization['maximum_absolute_mean']:.3g}"],['Largest unit sample-SD error',f"{standardization['maximum_sample_sd_error']:.3g}"],['Intercept','Constant; proper prior; exempt'],['Dimension division','None']],[275,205])
        add('The audit reads the actual inference Gram matrices and calendar designs. Every slope is centered and scaled using training rows 501:2500. Reservoir input/response conditioning retains the frozen first-500 transformation. These verified fits do not require a standardization redo.')
    if common:
        table([['Shared RHS quantities','Four-chain result'],['All 90 lag coefficients, log locals, log prior variances',f"{common['parameters']} monitors"],['Largest rank/folded R-hat',fmt(common['maximum_rhat'],6)],['Minimum bulk / tail ESS',f"{common['minimum_bulk_ess']:,.0f} / {common['minimum_tail_ess']:,.0f}"],['Failed monitors',str(len(common['failed_parameters']))]],[335,145])
        add('These supplementary checks use 2,048 matching joint states per chain. They cover all common lags rather than a few selected coordinates. Reservoir-specific quantities change dimension; their exploration remains subject to the full-trace architecture and cross-budget checks. Finite diagnostic screens cannot establish convergence of every posterior functional.')
    pause=read_json(E/'F1_512000_midpoint_pause_verified.json')
    if pause:add('The independent 512k level was durably verified at 320k total sweeps per chain: 128k warmup and 192k retained. That pause is not a completed 512k fit or an independent shorter-budget fit. Subsequent continuation is recorded in invocation/resource files; it cannot promote the posterior until final validation.',True)

gp_training=read_json(E/'gp16_training_diagnostics.json')
if gp_training:
    page();title('Native GP: completion is not qualification')
    t=read_csv(E/'gp16_training_diagnostics.csv')
    table([['16-particle seed','Observed RMSE','True-mean RMSE','Particle ESS','Max weight']]+[[str(int(row.seed)),fmt(row.training_observed_rmse,4),fmt(row.training_conditional_mean_rmse,4),fmt(row.particle_ess,2),fmt(row.maximum_particle_weight,3)] for row in t.itertuples()],[100,100,100,90,90])
    add('All four independent native depth-four, 2,000-row runs completed and their serialized posteriors, training-only inputs, stage records and resource exits were retrieved and verified. Independent streamed Gaussian algebra reproduces all native training probes, with maximum error '+f"{gp_training['maximum_native_probe_error']:.2g}. No forecast has been issued from these runs.")
    add('The GP fits have smaller observed training residuals than RHS, but larger errors against the DGP conditional mean: 0.240-0.301 versus 0.153 for RHS. This is consistent with some noise fitting. The comparison is descriptive on one training realization; it does not establish forecasting performance, convergence, or superiority.')
    add('The four GP evidence estimates span '+f"{gp_training['log_evidence_range']:.1f} log units. Correct evidence-weighted aggregation has effective replica count {gp_training['effective_number_of_evidence_weighted_replicas']:.1f}, with virtually all weight on one run. This fails the registered mode/budget review. Four finished jobs are insufficient evidence of reliable Bayesian averaging.")
    read_json(E/'native_gp_pooling_correction.json');read_csv(E/'gp16_evidence_audit.csv')
    add('A concrete accounting defect was found in the pinned native API: it returns the evidence accumulated before the last resampling. Native SMC leaves final particle weights unresampled. Correct pooling adds logsumexp(final log weights) - log(particle count), as in Gen.log_ml_estimate. The postprocessing now reproduces Gen exactly; no completed forecast used the old partial field.')
    gp_normalizer=read_json(E/'gp_smc_normalizer_reference.json')
    if gp_normalizer:add(f"Independent normalized-prior integration checks the complete depth-one continuous leaf target against 64 native SMC replicas per arm (128 particles), with and without native rejuvenation. All {gp_normalizer['checks']} unnormalized-measure comparisons "+('pass.' if gp_normalizer['passed'] else 'do not pass.')+' This validates small-target normalizer accounting, not depth-four exploration.',True)
    else:add('Independent normalized-prior integration for small-target SMC normalizers is still pending. Higher particle budgets and deep-tree mode checks remain mandatory.',True)
    page();title('Native GP budgets and period intervention')
    imported32=[read_json(p) for p in sorted(E.glob('gp32_s*_imported.json'))]
    if imported32:
        table([['Verified GP32 replica','Wall (minutes)','Peak PSS (GiB)']]+[[str(v['seed']),fmt(v['wall_seconds']/60,1),fmt(v.get('peak_PSS_KiB',v.get('peak_pss_kib'))/1048576,2)] for v in imported32],[210,135,135])
        add(f"{len(imported32)} of four 32-particle replicas have verified complete outputs, exit-zero resource records and CRC-checked full compressed inference logs at this checkpoint. This does not qualify the cohort. These jobs use immutable source 892fa693.",True)
    if read_json(E/'gp16_period10_registration.json'):
        gp32=read_json(E/'gp32_evidence_diagnostics.json',{})
        if gp32:add(f"The full corrected 32-particle log-evidence range is {gp32['log_evidence_range']:.3f}; the effective evidence-weighted replica count is {gp32['effective_evidence_replicas']:.3f}. This budget fails computational qualification. All four replicas are retained; no best-run selection or forecast is allowed.")
        repaired=[read_json(p) for p in sorted(E.glob('gp16_period10_s*_imported.json'))]
        if repaired:table([['Period-intervention replica','Wall (minutes)','Peak PSS (GiB)']]+[[str(v['seed']),fmt(v['wall_seconds']/60,1),fmt(v['peak_pss_kib']/1048576,2)] for v in repaired],[210,135,135])
        add(f'{len(repaired)} of four registered 16-particle replicas with ten additional invariant period moves are verified complete. The other two were observed fitting. The prior/grammar remain fixed and the proposal uses training-only peaks with exact Hastings correction. Keep this computational policy separate from strict native controls. No cohort qualification or forecast is claimed.',True)
        if read_json(ROOT/'remote_gp_requests/budget64.json'):add('The registered native 64-particle control uses four fresh replicas and the unchanged native target/schedule/move kernels. Its 14,400-second process cap is fixed before 64-particle outputs. The request is pending publication/launch at this report checkpoint; check actual workflow records before crediting execution.',True)

page();title('Calibration scope and actual execution status')
rows=[['Calibration','Executed result / limitation']]
for name,label in [('sbc_ridge','Fixed-design ridge'),('sbc_rhs','Fixed-design RHS, initial budget'),('sbc_rhs_24000','Fixed-design RHS, 24k budget')]:
    s=read_json(E/(name+'.json'))
    if s:rows.append([label,f"{s['replications']} cases; rank envelope {'passed' if s['uniformity_envelope_passed'] else 'FAILED'}; minimum monitored spectral ESS {s['minimum_case_spectral_ess']:.1f}; {s['cases_below_400_ess']} cases below 400."])
    else:
        directory=ROOT/'artifacts'/name;count=archived_case_count(directory)
        rows.append([label,f'{count} archived atomic case checkpoints; no completed aggregate calibration result.'])
pilot=read_json(E/'recursive_sbc_constant_n12_k3000.json')
if pilot:rows.append(['Recursive feasibility pilot',f"12 cases; simultaneous rank bound {pilot['simultaneous_DKW_bound']:.3f}, observed deviation {pilot['maximum_uniform_ecdf_deviation']:.3f}; {pilot['cases_below_400_ess']} cases below ESS 400. Too small and computationally unresolved."])
for variance in ['constant','sv']:
    path=E/f'recursive_sbc_{variance}_n200_k24000.json';s=read_json(path);directory=ROOT/'artifacts'/f'recursive_sbc_{variance}_n200_k24000'
    if s:rows.append([f'Recursive {variance}, 24k',f"{s['replications']} cases; rank envelope {'passed' if s['uniformity_envelope_passed'] else 'FAILED'}; minimum ESS {s['minimum_case_spectral_ess']:.1f}; {s['cases_below_400_ess']} cases below 400."])
    else:rows.append([f'Recursive {variance}, 24k',f"{archived_case_count(directory)} archived case checkpoints; no completed calibration conclusion."])
recovered=read_json(E/'recursive_sbc_constant_n200_k24000_recovered96000.json')
if recovered:rows.append(['Recursive constant, recovery',f"Same 200 cases; case 11 recomputed at 96k retained after ESS-only selection. Rank envelope {'passed' if recovered['uniformity_envelope_passed'] else 'FAILED'}; minimum monitored ESS {recovered['minimum_case_spectral_ess']:.1f}; no cases below 400."])
table(rows,[150,330])
if calibration_figure:image(calibration_figure,max_height=2.8*inch)
add('Fixed-design SBC holds candidate matrices exogenous. Recursive-model SBC freezes weights, projections, input/response transforms and readout scalers on an independent prefix, then generates and reconstructs only causal paths. Neither validates unconditional calibration of a production pipeline that estimates its transformations from each observed response series.')
add('The pilot is retained, not pooled into a larger batch or counted as confirmation. Calibration and confirmation seed namespaces are recorded separately. No NHS1 confirmatory series has been generated or unblinded. A seed-block assignment change before confirmation is documented in seed_namespace_decision.json.',True)
add('Fixed-design and recursive RHS calibration use tau0=0.2 and slab_scale=1, slab_df=4. Their priors and independently frozen feature maps differ from the production fit and their conclusions have that scope.',True)
add('The initial and larger fixed-design budgets use the same 200 prior-predictive cases. Recursive recovery also adds no independent cases. The fixed-design noise-variance ranks have the largest deviation (0.117 versus the registered simultaneous bound 0.135); passing an envelope is not proof of exact calibration.',True)

page();title('Runtime, memory and engineering checks')
rows=[['Observed process','Wall (s)','Aggregate PSS (GiB)','Exit / status']]
for file,label in [('F1_production_32000_resources.json','Original full-bank fork'),('F1_production_32000_cache1_resources.json','Exact cache, F1 32k'),('F1_production_128000_cache1_resources.json','Exact cache, F1 128k'),('F1_production_32000_local128_resources.json','Exact local move, F1 32k'),('F1_production_32000_joint128_resources.json','Joint scale/local policy, F1 32k'),('F1_production_256000_joint128_recoverable_attempt3_resources.json','Joint F1 256k continuation'),('compact_forecast_templates_resources.json','Recover compact forecast maps')]:
    s=read_json(E/file)
    if s:
        pss=s.get('sampled_peak_process_tree_pss_kib');valid='unreliable early scope' if file=='F1_production_32000_resources.json' else fmt(pss/1048576 if pss else None,2)
        rows.append([label,fmt(s.get('elapsed_seconds'),1),valid,str(s.get('exit_code'))])
table(rows,[190,75,125,90])
add('Process wall time includes startup, compilation/cache loading and saving. Fit checkpoints separately record inference elapsed time. Earlier aggregate PSS sampling missed descendants; those values are not used as measured total memory. Corrected records sample process-tree PSS and explicitly label environment-wide anonymous memory, which includes concurrent jobs.')
maps=read_json(E/'compact_forecast_templates.json')
if maps:add(f"All {maps['reservoirs']} numeric reservoir maps preserve before/after transitions exactly within each serial and batched backend. Last training features differ by at most {maps['maximum_training_feature_error']:.2g}. Compact maps occupy {maps['bytes']/1e6:.2f} MB. They remove unused construction closures, not weights or candidate models.")
add('An H_last/H_all integration defect was corrected before any new benchmark forecast. It affected the new adapter, not the already frozen historical forecast results. The earlier OOM, corrupted derived cache rejection, incomplete GP run and failed launcher remain part of the cost/evidence ledger.')
trace_bench=read_json(E/'trace_storage_benchmark.json')
if trace_bench:add('Paired small-target trace-storage benchmark: median 11.401 s with data frames, 8.897 s with matrices, preserving full traces and matching joint states bit for bit. This is not a full-study speedup claim.',True)
add('Forecast performance remains separately scoped: the synthetic reservoir-64/H30/192-outer/8-inner batch benchmark was 2.359 s versus 0.285 s, maximum path difference below 1e-13. No new full rolling-panel forecasting runtime is available.',True)

page();title('Exact computation and interruption recovery')
if statistics_pairs is not None:
    table([['Paired trial','Uncached (s)','Cached (s)']]+[[str(int(r.pair)),fmt(r.uncached_seconds,3),fmt(r.cached_seconds,3)] for r in statistics_pairs.itertuples()], [150,165,165])
add('Three same-seed full-bank trials preserve all recorded traces, matching coefficient/local/volatility states, fitted probes and architecture masses bit for bit. Median sampling time is 49.976 s without the fixed statistics cache and 30.306 s with it; preparing all 426 F1 entries took 1.859 s. Each trial uses 500 warmup and 2,000 retained sweeps. These paired computations are not independent DGP replications or a complete-study speedup.')
add('The optional cache stores fixed unweighted X-transpose-X and X-transpose-y values under a numeric-payload memory bound. Partial caching falls back to exact computation and retains every model/period. It does not change the prior, target, posterior weights or random updates. Weighted SV statistics are recomputed as covariance changes.',True)
if interruption:
    add('The first fresh 256k invocation disappeared before completed chains or an exit/resource record were observed. Its cause and final iteration are unknown. It contributes neither a completed posterior nor an invented runtime total. This interruption exposed the need for checkpoints within each long chain.')
if checkpoint_reference:
    add('Recovery now saves all Markov variables, auxiliary scales, retained draws, probes, counters and RNG state at complete sweep boundaries. A separate four-process C++/grouped-RHS/seasonal-SV experiment pauses at sweep 47 and finishes the same 120-sweep budget; every recorded state and counter matches uninterrupted computation exactly.')
    add('Resume verifies the target, kernel, full budget, source, runtime, thread settings and payload checksum. Box-Muller RNG is rejected because its hidden cached normal is absent from .Random.seed. Bounded pauses are explicitly incomplete fits and do not authorize forecasts.',True)
if checkpoint_execution:
    add("The earlier bounded recovery audit recorded: " + checkpoint_execution['report_statement'])
if level256:add(f"The subsequent full continuation completes all four chains with exit 0. Summing the three observed process invocations gives {level256['known_active_wall_seconds_sum']/60:.2f} active minutes, including repeated startup/checkpoint work and excluding pauses between invocations. Peak process-tree PSS is {level256['peak_process_tree_pss_kib']/1048576:.2f} GiB; sampled environment anonymous memory includes simultaneous audits. The earlier unknown-exit invocation remains uncredited.")
add('No new full rolling-origin forecast or independent confirmation result is produced by these engineering checks. The model qualification thresholds remain unchanged.',True)

blocks=read_json(E/'calendar_cache_benchmark_lawvalidated.json')
if blocks:
    page();title('Calendar computation and exact recovery')
    table([['Full 426-model / 101-period short computation','Direct','Shared blocks'],['Design panel median (69 pairs)',fmt(blocks['direct_design_median_seconds'],3)+' s',fmt(blocks['block_design_median_seconds'],3)+' s'],['Sampler median (100 warmup + 500 retained)',fmt(blocks['direct_sampler_median_seconds'],3)+' s',fmt(blocks['block_sampler_median_seconds'],3)+' s']],[300,90,90])
    add(f"The optional block cache uses {blocks['numeric_payload_bytes']/1024**2:.1f} MiB numeric payload and takes {blocks['construction_seconds']:.2f} seconds to construct. It factors common lag, reservoir and calendar cross-products. Only {blocks['cached_reservoir_calendar_interactions']:,} interactions are stored; every other architecture-period pair remains available and is computed on demand.")
    add('Three alternating-order same-seed short trials give about 37% lower median sampler time under concurrent production load. These are computational repetitions, not independent time-series replications or a whole-study speed claim. The existing long F1 run keeps its original cache and source snapshot.')
    law=read_json(E/'calendar_cache_law_checks.json')
    if law:
        table([['Numerical validation','Largest difference'],['1,572 full-bank design pairs: Gram entries',f"{blocks['maximum_gram_absolute_error']:.2g}"],['38 matching-hyperparameter Gaussian laws: log evidence',f"{law['maximum_log_evidence_error']:.2g}"],['Gaussian conditional KL',f"{law['maximum_gaussian_KL']:.2g}"],['Conditional fitted means',f"{law['maximum_fitted_mean_error']:.2g}"],['Independent dense response-space log evidence',f"{law['maximum_dense_response_log_evidence_error']:.2g}"]],[350,130])
    add('The original full-bank path comparison failed its component-wise relative 1e-9 threshold for coefficients and local scales. That failure is preserved. Reordered floating-point sums do not promise bit-identical Markov trajectories, even with equal discrete choices. Independent Gaussian-law checks, rather than a relaxed convergence gate, establish the arithmetic accuracy.',True)
    recovered_blocks=read_json(E/'checkpoint_calendar_fresh_process.json')
    if recovered_blocks:add('Exact recovery now hashes the actual statistics-cache contents in addition to source, runtime, priors, transition settings and full budget. The same partial block cache reproduces all saved states and counters across four fresh R processes for grouped RHS with seasonal SV and C++. Changing cache type, budget or contents is rejected.',True)
    add('S3 signature checks fell from seven inconsistencies to zero. The latest source and outside-Git installed extension suites include '+str(tests.get('passed','?'))+' and '+str(installed.get('passed','?'))+' passing assertions, respectively. Broader repository CI remains a separate unresolved requirement.',True)

page();title('Chronological folds and selected mean')
rows=[['Cutoff','Scored training rows','Preparation (s)','Peak PSS (GiB)','Terminal feature error']]
for cutoff in [1500,2000]:
    fold=read_json(E/f'prefix_bank_{cutoff}.json')
    resource=read_json(E/(f'prefix_bank_{cutoff}_attempt2_resources.json' if cutoff==1500 else f'prefix_bank_{cutoff}_resources.json'))
    binding=read_json(E/f'prefix{cutoff}_forecast_binding.json')
    if fold and resource and binding:rows.append([str(cutoff),str(cutoff-500),fmt(resource['elapsed_seconds'],2),fmt(resource['sampled_peak_process_tree_pss_kib']/1048576,2),f"{binding['maximum_terminal_feature_error']:.2g}"])
table(rows,[65,110,100,100,105])
add('Both complete preparations audit all 456 fixed definitions and retain 426 architectures. Only observations through the training cutoff enter construction. Input transforms and reservoir maps retain the original 500-observation conditioning protocol; readout, lag and calendar scalers are fitted on 501:cutoff. Both forecast adapters reproduce all 426 last training-row features. Preparation totals include construction, admission/scaling, map validation and cache preparation; they are not isolated reservoir timings.')
read_json(E/'prefix_bank_1500_failure1.json')
add('The first adapter attempt incorrectly used the helper default tolerance10^-5 instead of the frozen NHS10^-3, rejecting 51 extra candidates. All 456 warmup errors match the original exactly. That 375-model bank was rejected before inference; the corrected folds preserve 426-model support. The failed attempt and exact cleanup inventory remain recorded. Existing 426-model inference was unaffected.',True)
add('The generalized driver isolates each prefix posterior and its frozen proposal files. Both full-bank input preflights pass, but no qualified fold posterior, rolling validation score or selected-mean certificate exists yet. Tests and input checks do not replace those computations.')
add('SV and seasonal SV now require a frozen certificate binding both qualified development folds. They preserve the selected F1/F2/F2flat mean. For F1 seasonal volatility, harmonics=0 retains period averaging for the four variance harmonics while adding no mean calendar coefficients; the proper period prior integrates to one in a period-independent mean likelihood.')
read_json(E/'variance_only_seasonality_tests.json');read_json(E/'fit_inputs_tests.json')
add('The 30 variance-only normalization/integration and R/C++ checks pass. The broader scoped suite passes 830 assertions in source and a fresh installation outside Git. A separate isolated fixture checks certificate hashes and selected-mean controls. No actual mean selection, production SV fit or new benchmark forecast follows from these checks.',True)

page();title('Historical forecast context - unchanged')
image(historical_figure,max_height=3.1*inch)
rows=[['Historical model','RMSE','MAE','CRPS','NLL','50% cover / width','90% cover / width']]
for name,label in zip(models,short):
    r=historical[historical.model==name].iloc[0];rows.append([label,fmt(r.RMSE),fmt(r.MAE),fmt(r.CRPS),fmt(r.NLL),f'{r.Coverage50:.3f} / {r.Width50:.3f}',f'{r.Coverage90:.3f} / {r.Width90:.3f}'])
table(rows,[125,45,45,45,45,87.5,87.5])
add('These scores are the original completed NHS1 reference, not outcomes of the new augmented or volatility models. Each row pools 471 rolling origins and 30 horizons. The 14,130 pairs are dependent observations from one realization; they are not 14,130 independent simulation replications.')
add('High pooled coverage can conceal excess width and regime-dependent undercoverage. Visual failure to track every realized spike also includes irreducible innovation uncertainty. The new work must separately establish computational adequacy and then compare conditional means, proper scores and calibration. None of the historical rankings proves that a new model is superior.')

page();title('Unfinished gates and reproducible handoff')
table([['Gate','What is still required'],['Posterior qualification','Two successive qualified fresh budgets, targeted mode checks, probability precision and cross-budget stability under frozen computational controls.'],['Mean-family selection','Both prefix banks and state bindings are complete. Fit and qualify their posteriors, run frozen-fit rolling validation and select by the registered CRPS rule.'],['Native AutoGP','Complete full-size independent same-prior runs and particle/move-budget sensitivity. Small feasibility runs and an interrupted full run do not qualify it.'],['Conditional variance','Recursive constant/SV calibration has resolved within its frozen-map scope. Production-chain qualification and conditional particle-filter budget checks remain.'],['Prediction','Outer/inner Monte Carlo panel; full 471-origin, 30-horizon comparisons with RMSE, MAE, CRPS, NLL, intervals and calibrated runtimes.'],['Independent confirmation','Frozen 30-realization mean/GP block, separate variance block and registered stress cells. None can be replaced by overlapping origin-horizon pairs.']], [125,355])
add('Checkpoints preserve completed numeric states, traces, case records, immutable executed sources and failure logs. restore_checkpoints.py verifies archive ancestry, every part and every extracted member. Large construction/inference banks are referenced by checksums and deterministic rebuild scripts rather than duplicated in each fitted object.')
add('Primary evidence: MATH.md; execution.json; development_registry.json; independent-reference check CSV/JSON files; F1 checkpoint-validation and qualification records; resource records; versioned checkpoint manifests. The report input manifest supplies their exact SHA256 values.',True)
add('The appropriate conclusion at this checkpoint is an implemented and increasingly validated statistical extension with unresolved production and predictive gates. It is not a completed forecast comparison or a superiority claim.')

def footer(canvas,doc):
    canvas.saveState();canvas.setStrokeColor(colors.HexColor('#d8e0e5'));canvas.line(42,39,553,39);canvas.setFont('DV',7);canvas.setFillColor(colors.HexColor(NAVY));canvas.drawString(42,26,'NHS1 | implementation and validation | 24 October 2026');canvas.drawRightString(553,26,str(doc.page));canvas.restoreState()
path=PDF/'AutoDESN_Remediation_Execution_Report.pdf'
doc=SimpleDocTemplate(str(path),pagesize=(595.28,841.89),rightMargin=42,leftMargin=42,topMargin=44,bottomMargin=53,title='AutoDESN remediation: execution and validation checkpoint',author='AntonioAPDL / reproducible execution')
doc.build(story,onFirstPage=footer,onLaterPages=footer)
for file in [Path('R/autodesn.R'),Path('R/qdesn_normal.R'),Path('R/qdesn_vb.R'),Path('NAMESPACE'),Path('R/autodesn_calendar_cache.R'),Path('R/autodesn_checkpoint.R'),Path('R/autodesn_statistics_cache.R'),Path('R/autodesn_gaussian.R'),Path('R/autodesn_extended.R'),Path('R/autodesn_extended_bank.R'),Path('R/autodesn_extended_forecast.R'),Path('R/autodesn_extended_local.R'),ROOT/'fit.R',ROOT/'fit_inputs.R',ROOT/'launch_fit.py',ROOT/'load_forecast_bank.R',ROOT/'execution.json',ROOT/'development_registry.json',Path(__file__)]:inputs[str(file)]=hashlib.sha256(file.read_bytes()).hexdigest()
record=dict(complete=True,report=str(path),report_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),execution_context_date='2026-10-24',last_committed_base=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),inputs=inputs,partial_observations=partial_observations,scientific_study_complete=False,new_forecast_comparison_complete=False)
(OUT/'report_inputs.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({k:record[k] for k in ['complete','report','report_sha256','scientific_study_complete']}))
