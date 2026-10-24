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
NAVY='#17324b';BLUE='#2275a5';TEAL='#228877';AMBER='#b57920';RED='#a84242';PALETTE=[BLUE,TEAL,AMBER,'#8a65a3','#59636d']
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'axes.spines.top':False,'axes.spines.right':False,'axes.labelcolor':NAVY,'text.color':NAVY,'axes.titleweight':'bold','savefig.facecolor':'white'})
inputs={};partial_observations={}
def read_json(path,default=None):
    path=Path(path)
    if not path.exists():return default
    inputs[str(path)]=hashlib.sha256(path.read_bytes()).hexdigest();return json.loads(path.read_text())
def read_csv(path,**kwargs):
    path=Path(path);inputs[str(path)]=hashlib.sha256(path.read_bytes()).hexdigest();return pd.read_csv(path,**kwargs)
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

tests=read_json(E/'extended_tests.json',{});installed=read_json(E/'installed_tests.json',{});legacy=read_json(E/'legacy_tests.json',{})
qualifications=[]
for path in sorted(E.glob('F1_production_*_qualification.json')):
    q=read_json(path);directory=ROOT/'artifacts/F1'/q['phase'];cfg=read_json(directory/'configuration.json',{})
    qualifications.append((q,cfg))
baseline=[(q,c) for q,c in qualifications if q['phase'].endswith('cache1')]
latest=max(baseline,key=lambda item:item[1].get('retained',0)) if baseline else None
traces=None;trace_figure=occupancy_figure=None
if latest:
    q,c=latest;directory=ROOT/'artifacts/F1'/q['phase']
    traces=[read_csv(directory/f'trace_{k}.csv') for k in range(1,5)]
    fig,axes=plt.subplots(3,2,figsize=(7,6.0),sharex=True)
    fields=[('variance','Noise variance'),('log_global_1','Log global multiplier'),('log_slab','Log slab variance'),('fitted_probe_4','Training fitted-mean probe'),('norm_lag','Lag coefficient norm'),('norm_reservoir','Reservoir coefficient norm')]
    for ax,(field,label) in zip(axes.flat,fields):
        for k,t in enumerate(traces):
            step=max(1,len(t)//1800);ax.plot(np.arange(1,len(t)+1)[::step],t[field].to_numpy()[::step],lw=.5,alpha=.75,color=PALETTE[k],label=f'Chain {k+1}')
        ax.set_title(label,fontsize=9,loc='left');ax.grid(alpha=.15)
    axes[0,0].legend(ncol=2,fontsize=7,frameon=False)
    for ax in axes[-1,:]:ax.set_xlabel('Retained sweep (display subsample)')
    fig.suptitle(f"Baseline F1, {c.get('retained',0):,} draws per chain - unqualified",fontsize=12)
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
for stem,label in [('grouped','Grouped, fixed locals'),('local','Grouped, learned locals'),('local_joint','Joint scale/local proposal'),('sv_joint','Full two-response SV'),('gp_leaf','Complete GP leaf grammar')]:
    s=read_json(E/f'{stem}_mcmc_reference.json')
    if s:references.append((stem,label,s,read_csv(E/f'{stem}_mcmc_reference_checks.csv')))
fig,ax=plt.subplots(figsize=(7,3.2))
for i,(stem,label,s,t) in enumerate(references):
    ratio=t.absolute_error/t.tolerance;ax.scatter(ratio,np.arange(len(t))*.02+i,s=18,color=PALETTE[i],label=label)
ax.axvline(1,color=RED,ls='--',lw=1);ax.set_xlim(0,1.12);ax.set_yticks(range(len(references)),[v[1] for v in references]);ax.set_xlabel('Absolute moment error / registered numerical-MC tolerance');ax.grid(axis='x',alpha=.18);fig.tight_layout();reference_figure=save_plot(fig,'independent_reference_agreement')

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
table([['Outcome','Verified status'],['Implementation','Opt-in augmented readouts, period averaging, normalized grouped RHS, conditional SV, filtering, exact proposals and causal recursion are implemented.'],['Numerical correctness',f"{tests.get('passed','?')} source assertions pass; installed test results are reported separately. Independent small-target posterior references agree."],['Production inference','No production posterior is yet scientifically qualified. Individually passing R-hat and ESS are insufficient when architecture-frequency or cross-budget gates fail.'],['Predictive comparison','No new full rolling-origin forecasts or independent confirmation scores are claimed. Historical scores are shown only as unchanged context.']], [100,380])
add('The work is not complete from start to finish. The distinction is deliberate: numerical identities, computational adequacy and predictive improvement are different requirements. Unfinished experiments cannot supply forecast scores or evidence of improvement.')
add('Repository: AntonioAPDL/exdqlm. Feature branch: feature/autodesn-remediation-20261023. Draft pull request: https://github.com/AntonioAPDL/exdqlm/pull/5.',True)
add('This report is generated from the output files listed in report_inputs.json. It preserves failed runs and source/checkpoint identities; scripts alone are never counted as executed experiments.',True)

page();title('Frozen statistical and forecasting contracts')
table([['Component','Executed reference convention'],['Data protocol','500 washout observations; 2,000 scored training observations; 500 held out. Fit once at 2500; origins 2500:2970; horizons 1:30.'],['Feature geometry','Original 456 reservoir definitions, 426 admitted. Training-only column centers and sample SDs; no square-root dimension normalization. Conditioning-prefix response/input transform is frozen.'],['Intercept and noise','Independent intercept Normal(0, variance 10); observation variance IG(shape 3, rate 1).'],['Normalized RHS','tau = 0.001 * u; u and each local scale are unit half-Cauchy. Slab variance IG(2,2): slab_scale=1, slab_df=4. Coefficient variance = 1 / (1/(tau*local)^2 + 1/slab_variance).'],['Mean families','F1 adds lags 1:90. F2 adds period-averaged Fourier terms over integers 20:120, up to 16 non-Nyquist harmonics. Flat and separately named grouped priors are supported.'],['Grouped prior','Independent lag/reservoir global scales; one shared slab; Gaussian calendar variance 0.5^2/[1+(harmonic/4)^4].'],['Conditional SV','Standardized stationary AR(1) state; (phi+1)/2 ~ Beta(10,1.5); omega ~ HalfNormal(0.5). Optional four-harmonic centered log variance.']], [105,375])
add('Every issued path holds its joint architecture, period and static parameters fixed. Simulated responses update future lags and reservoir states. Actual observations update states only between origins. Conditional SV filtering retains frozen outer parameter weights and replays training uncertainty; it is not full sequential parameter reweighting.')
add('The normalized RHS is not the augmented rhs_ns target. Coefficient-independent noise scaling, all Gaussian determinants, inactive proper priors and exact Hastings corrections are retained. See MATH.md for the joint densities and partial-collapse order.',True)

page();title('Independent posterior validation')
rows=[['Conditional reference','Checked quantities','Maximum R-hat','Minimum bulk / tail ESS']]
for stem,label,s,t in references:rows.append([label,str(s['joint_functionals']),fmt(s['maximum_rhat'],6),f"{s['minimum_bulk_ess']:,.0f} / {s['minimum_tail_ess']:,.0f}"])
table(rows,[170,80,95,135]);image(reference_figure,max_height=3.3*inch)
add('References use dense response-space Gaussian covariances and integration over normalized scale priors. The learned-local check integrates seven dimensions and tests nonuniform architecture/period proposals, variable active dimensions and the added reservoir-local proposal. SV uses independent full two-response quadrature, not only scalar conditional identities.')
add('The grouped RHS references use tau0=0.2 for tractable small-target checks; production uses the requested tau0=0.001. The two-response SV target is intercept-only. These checks do not certify the complete production workflow.',True)
add('The GP reference integrates all three supported leaves and all four latent parameters under the pinned default depth-one grammar. It checks native normalized scores and prior-independence MH, rather than qualifying depth-four SMC or composite-tree multiplicities.',True)
add(f"The source suite has {tests.get('tests','?')} tests and {tests.get('passed','?')} passing assertions; the installed suite records {installed.get('passed','?')} passing assertions. Earlier legacy regression evidence records 804 passes with one separately covered context skip. Passing these checks is not proof of convergence on the 426-reservoir bank.",True)

page();title('Production convergence: all gates still apply')
rows=[['F1 run','R-hat max','ESS min','Largest chain frequency range','Screen']]
for q,c in sorted(qualifications,key=lambda x:(x[1].get('retained',0),x[0]['phase'])):
    label=('Joint move ' if 'joint' in q['phase'] else 'Local move ' if 'local' in q['phase'] else 'Baseline ')+f"{c.get('retained',0):,}"
    rows.append([label,fmt(q['maximum_rhat'],4),fmt(min(q['minimum_bulk_ess'],q['minimum_tail_ess']),0),fmt(max(q['frequency_ranges'].values()),4),'pass' if q['screen_passed'] else 'FAIL'])
table(rows,[110,70,65,150,85])
if trace_figure:image(trace_figure,max_height=4.6*inch)
add('Registered gates: rank/folded R-hat <=1.01, bulk/tail ESS >=400, major-category probability MCSE <=0.01, chain frequency ranges <=0.03. Two successive qualified fresh budgets must also agree within practical and Monte Carlo tolerances. No gate is waived because a different diagnostic passes.',True)

page();title('Architecture exploration and shrinkage')
if occupancy_figure:image(occupancy_figure,max_height=3.7*inch)
add('These are occupancies and coefficient norms from an unqualified run, not certified posterior architecture probabilities. Distinct reservoir modes can have similar fitted functions. A small continuous-parameter R-hat does not establish adequate architecture probabilities.')
add('The RHS prior is continuous; exact zeros are not its sparsity mechanism. Coefficient norms and threshold counts depend on the standardized, correlated basis and do not measure a selected-variable count. Conditional group EDF is recorded at the Gaussian substep; a separate audit recomputes it at matching saved scales.')
shrink=read_json(E/'F1_production_128000_cache1_shrinkage.json')
if shrink:add('Descriptive matching-state audit of the unqualified baseline 128k run: median 80% of standardized-feature slopes below 0.01 response SD; median five above 0.1 response SD. The median actual global scale was 0.00453 despite tau0=0.001, because the global multiplier is sampled. This is neither an all-zero fit nor evidence that its representation is adequate.')
add('The optional computational repair proposes active reservoir-local scales from a normalized prior/kernel-product mixture and inactive slots from their proper priors. It restores marginalized auxiliaries, then redraws coefficients. Every reservoir retains support. The proposal is frozen from training-only checkpoints; it changes computation, not tau0, the slab, the likelihood or architecture priors.')
qmeta=read_json(E/'F1_frozen_local_proposal_128.json')
if qmeta:add(f"The 128k-trained proposal has kernel estimates for {qmeta['models_with_kernel']} reservoirs and uses exact prior proposals for {qmeta['models_using_prior_only']} others. Scarce training samples do not remove a reservoir.",True)

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
for file,label in [('F1_production_32000_resources.json','Original full-bank fork'),('F1_production_32000_cache1_resources.json','Exact cache, F1 32k'),('F1_production_128000_cache1_resources.json','Exact cache, F1 128k'),('F1_production_32000_local128_resources.json','Exact local move, F1 32k'),('F1_production_32000_joint128_resources.json','Joint scale/local policy, F1 32k'),('compact_forecast_templates_resources.json','Recover compact forecast maps')]:
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

page();title('Historical forecast context - unchanged')
image(historical_figure,max_height=3.1*inch)
rows=[['Historical model','RMSE','MAE','CRPS','NLL','50% cover / width','90% cover / width']]
for name,label in zip(models,short):
    r=historical[historical.model==name].iloc[0];rows.append([label,fmt(r.RMSE),fmt(r.MAE),fmt(r.CRPS),fmt(r.NLL),f'{r.Coverage50:.3f} / {r.Width50:.3f}',f'{r.Coverage90:.3f} / {r.Width90:.3f}'])
table(rows,[125,45,45,45,45,87.5,87.5])
add('These scores are the original completed NHS1 reference, not outcomes of the new augmented or volatility models. Each row pools 471 rolling origins and 30 horizons. The 14,130 pairs are dependent observations from one realization; they are not 14,130 independent simulation replications.')
add('High pooled coverage can conceal excess width and regime-dependent undercoverage. Visual failure to track every realized spike also includes irreducible innovation uncertainty. The new work must separately establish computational adequacy and then compare conditional means, proper scores and calibration. None of the historical rankings proves that a new model is superior.')

page();title('Unfinished gates and reproducible handoff')
table([['Gate','What is still required'],['Posterior qualification','Two successive qualified fresh budgets, targeted mode checks, probability precision and cross-budget stability under frozen computational controls.'],['Mean-family selection','Rebuild PCA/scalers at cutoffs 1500 and 2000; qualified frozen-fit rolling validation; select by registered CRPS rule.'],['Native AutoGP','Complete full-size independent same-prior runs and particle/move-budget sensitivity. Small feasibility runs and an interrupted full run do not qualify it.'],['Conditional variance','Complete recursive/SV calibration, production-chain qualification and conditional particle-filter budget checks. Small-target validation is complete only at its stated scope.'],['Prediction','Outer/inner Monte Carlo panel; full 471-origin, 30-horizon comparisons with RMSE, MAE, CRPS, NLL, intervals and calibrated runtimes.'],['Independent confirmation','Frozen 30-realization mean/GP block, separate variance block and registered stress cells. None can be replaced by overlapping origin-horizon pairs.']], [125,355])
add('Checkpoints preserve completed numeric states, traces, case records, immutable executed sources and failure logs. restore_checkpoints.py verifies archive ancestry, every part and every extracted member. Large construction/inference banks are referenced by checksums and deterministic rebuild scripts rather than duplicated in each fitted object.')
add('Primary evidence: MATH.md; execution.json; development_registry.json; independent-reference check CSV/JSON files; F1 checkpoint-validation and qualification records; resource records; versioned checkpoint manifests. The report input manifest supplies their exact SHA256 values.',True)
add('The appropriate conclusion at this checkpoint is an implemented and increasingly validated statistical extension with unresolved production and predictive gates. It is not a completed forecast comparison or a superiority claim.')

def footer(canvas,doc):
    canvas.saveState();canvas.setStrokeColor(colors.HexColor('#d8e0e5'));canvas.line(42,39,553,39);canvas.setFont('DV',7);canvas.setFillColor(colors.HexColor(NAVY));canvas.drawString(42,26,'NHS1 | implementation and validation | 24 October 2026');canvas.drawRightString(553,26,str(doc.page));canvas.restoreState()
path=PDF/'AutoDESN_Remediation_Execution_Report.pdf'
doc=SimpleDocTemplate(str(path),pagesize=(595.28,841.89),rightMargin=42,leftMargin=42,topMargin=44,bottomMargin=53,title='AutoDESN remediation: execution and validation checkpoint',author='AntonioAPDL / reproducible execution')
doc.build(story,onFirstPage=footer,onLaterPages=footer)
for file in [Path('R/autodesn_extended.R'),Path('R/autodesn_extended_bank.R'),Path('R/autodesn_extended_forecast.R'),Path('R/autodesn_extended_local.R'),ROOT/'execution.json',ROOT/'development_registry.json',Path(__file__)]:inputs[str(file)]=hashlib.sha256(file.read_bytes()).hexdigest()
record=dict(complete=True,report=str(path),report_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),execution_context_date='2026-10-24',last_committed_base=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),inputs=inputs,partial_observations=partial_observations,scientific_study_complete=False,new_forecast_comparison_complete=False)
(OUT/'report_inputs.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({k:record[k] for k in ['complete','report','report_sha256','scientific_study_complete']}))
