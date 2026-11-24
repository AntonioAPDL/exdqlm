"""Independent numerical truth/score audit. No fitted R density evaluates the references."""
import argparse,hashlib,json,math
from pathlib import Path
import numpy as np
import pandas as pd
from scipy import optimize,stats

ROOT=Path('validation/autodesn/median_small')
def g(z):return np.arcsinh(z)+.45*np.tanh(2.5*np.asarray(z))
def inverse_g(y):
    y=float(y)
    return optimize.brentq(lambda x:g(x)-y,np.sinh(y-.450001),np.sinh(y+.450001),xtol=1e-11)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def truth(origin_y,origin,h,prob=.5):
    cfg=json.loads((ROOT/'configuration.json').read_text())
    season=np.array(cfg['season']);season-=season.mean()
    z=inverse_g(origin_y-season[(origin-1)%12])
    h=np.asarray(h);a=cfg['phi']**h*z;b=cfg['innovation_scale']*sum_geom(cfg['phi'],h)
    return season[(origin+h-1)%12]+g(a+b*stats.cauchy.ppf(prob))
def sum_geom(r,h):return -np.expm1(np.asarray(h)*np.log(r))/(1-r)

def preflight():
    cfg=json.loads((ROOT/'configuration.json').read_text());data=pd.read_csv(ROOT/'output/data.csv')
    tests=json.loads((ROOT/'evidence/tests.json').read_text());assert tests['complete'] and tests['checks_passed']>=29
    checks=[]
    def ck(x,name):
        assert bool(x),name
        checks.append(name)
    ck(len(data)==3500,'canonical3500 observations')
    season=np.array(cfg['season']);season-=season.mean()
    ck(np.max(np.abs(data.y-data.season-g(data.z)))<1e-10,'independent observed transform')
    for o in [1900,2345,2840,2900,3440]:
        zz=inverse_g(data.y.iloc[o-1]-season[(o-1)%12])
        ck(abs(zz-data.z.iloc[o-1])<1e-8,'observed origin identifies state '+str(o))
    rng=np.random.default_rng(920241)
    for h in [1,2,60]:
        # Independent weighted innovation draws check Cauchy stability, not just the same formula.
        sums=rng.standard_cauchy((50000,h))@(cfg['innovation_scale']*cfg['phi']**np.arange(h))
        b=cfg['innovation_scale']*sum(cfg['phi']**np.arange(h))
        for p in [.05,.5,.95]:
            proportion=np.mean(sums<=b*stats.cauchy.ppf(p))
            ck(abs(proportion-p)<.012,'Cauchy convolution '+str((h,p)))
    fixture=pd.read_csv(ROOT/'evidence/gaussian_reference_inputs.csv')
    X=fixture.iloc[:,:-1].to_numpy();y=fixture.iloc[:,-1].to_numpy()
    P=np.diag([.1]+[1/.7]*(X.shape[1]-1));C=(np.eye(len(y))+X@np.linalg.solve(P,X.T))/3
    independent=stats.multivariate_t.logpdf(y,shape=C,df=6)
    ref=pd.read_csv(ROOT/'evidence/gaussian_reference.csv').iloc[0]
    ck(abs(independent-ref.log_evidence)<1e-10,'SciPy independent Gaussian coefficient/noise integrated likelihood')
    regen={str(p):sha(p) for p in [ROOT/'output/data.csv',ROOT/'configuration.json',ROOT/'common.R',ROOT/'tests.R']}
    result=dict(complete=True,checks_passed=len(checks),checks=checks,inputs=regen,
                source_sha256=sha(__file__),scope='Independent numerical references; not convergence')
    (ROOT/'evidence/python_preflight.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'preflight_checks_passed':len(checks)}))

def final():
    cfg=json.loads((ROOT/'configuration.json').read_text());data=pd.read_csv(ROOT/'output/data.csv')
    pred=pd.read_csv(ROOT/'output/test_forecasts.csv');fit=pd.read_csv(ROOT/'output/fitted_medians.csv')
    assert len(pred)==600 and np.array_equal(np.sort(pred.time),np.arange(2901,3501))
    assert pred.groupby('origin').size().eq(60).all() and len(pred.origin.unique())==10
    exact=np.concatenate([truth(data.y.iloc[o-1],o,np.arange(1,61)) for o in cfg['test_origins']])
    assert np.max(abs(exact-pred.true_median))<1e-9
    assert np.max(abs(data.y.to_numpy()[pred.time-1]-pred.observed))<1e-12
    trace=pd.read_csv(ROOT/'output/al_trace.csv');diag=pd.read_csv(ROOT/'output/al_diagnostics.csv')
    assert len(trace)==cfg['retained'] and np.isfinite(trace).all().all()
    for row in diag.itertuples():
        x=trace[row.parameter].to_numpy();batches=x.reshape((-1,100)).mean(1)
        assert abs(np.std(batches,ddof=1)/np.sqrt(len(batches))-row.MCSE)<1e-9
        assert abs(x[:len(x)//2].mean()-x[len(x)//2:].mean()-row.half_drift)<1e-9
    coarse=pd.read_csv(ROOT/'output/gaussian_coarse_scores.csv');fine=pd.read_csv(ROOT/'output/gaussian_fine_scores.csv')
    assert len(coarse)==576 and len(fine)==16
    assert coarse.candidate_id.nunique()==576 and fine.candidate_id.nunique()==16
    assert (coarse.horizon==60).all() and (coarse.origins==10).all() and (coarse.pairs==600).all()
    assert (fine.paths==256).all()
    selected=json.loads((ROOT/'output/selected_specification.json').read_text())
    best=fine.sort_values(['validation_pinball','dimension','candidate_id']).iloc[0]
    assert selected['candidate']['candidate_id']==best.candidate_id
    # Gaussian fitted objects, coefficient arrays and prediction arrays must never be persisted.
    for p in ROOT.rglob('*'):
        assert not (p.is_file() and 'gaussian' in p.name and p.suffix.lower() in ['.rds','.rdata','.npy','.npz'])
    rows=[]
    month_means=data.loc[(data.time>=501)&(data.time<=2900)].assign(month=lambda x:(x.time-1)%12).groupby('month').y.median()
    for name,estimate in [('AL-RHS',pred['median'].to_numpy()),
        ('Seasonal median',month_means.to_numpy()[(pred.time.to_numpy()-1)%12]),
        ('Persistence',data.y.to_numpy()[pred.origin.to_numpy()-1])]:
        e=pred.observed-estimate;oracle=pred.true_median-estimate
        rows.append(dict(model=name,pinball=float(np.mean(abs(e))*.5),observed_MAE=float(np.mean(abs(e))),
                         true_median_MAE=float(np.mean(abs(oracle))),true_median_RMSE=float(np.sqrt(np.mean(oracle**2)))))
    metrics=pd.DataFrame(rows);metrics.to_csv(ROOT/'output/metrics.csv',index=False)
    horizon=pred.assign(median_error=lambda x:abs(x['median']-x.true_median),
                        observed_error=lambda x:abs(x['median']-x.observed)).groupby('horizon')[['median_error','observed_error']].mean()
    horizon.to_csv(ROOT/'output/horizon_metrics.csv')
    coverage={str(level):dict(coverage=float(((pred.observed>=pred[lo])&(pred.observed<=pred[hi])).mean()),
       mean_width=float((pred[hi]-pred[lo]).mean())) for level,lo,hi in [(50,'q25','q75'),(90,'q05','q95')]}
    fitstat=dict(conditional_median_MAE=float(abs(fit['median']-fit.true_median).mean()),
                 conditional_median_RMSE=float(np.sqrt(np.mean((fit['median']-fit.true_median)**2))),
                 latent_band90_truth_fraction=float(((fit.true_median>=fit.q05)&(fit.true_median<=fit.q95)).mean()))
    resources=[]
    for p in (ROOT/'evidence').glob('*_resources.json'):
        r=json.loads(p.read_text());resources.append(dict(file=p.name,stage=r['stage'],attempt=r['attempt'],
          elapsed_seconds=r['elapsed_seconds'],peak_pss_MiB=r['sampled_peak_process_tree_pss_bytes']/2**20,exit_code=r['exit_code']))
    fitmeta=json.loads((ROOT/'evidence/fit.json').read_text())
    result=dict(complete=True,independent_score_and_truth_audit_passed=True,metrics=rows,predictive_intervals=coverage,
                fit=fitstat,resources=resources,production_chains=1,burn=cfg['burn'],retained=cfg['retained'],
                single_chain_screen_passed=fitmeta['single_chain_screen_passed'],posterior_convergence_proven=False,
                experiment_scope='One development series; architecture selection conditioned on observed validation outcomes',
                source_sha256=sha(__file__),input_sha256={str(p):sha(p) for p in (ROOT/'output').glob('*') if p.is_file()})
    (ROOT/'evidence/independent_audit.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'metrics':rows,'coverage':coverage,'fit':fitstat,'single_chain_screen_passed':fitmeta['single_chain_screen_passed']}))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('stage',choices=['preflight','final']);a=p.parse_args()
    (preflight if a.stage=='preflight' else final)()
