"""Reconstruct the nine original simulation seeds and plot selectable examples.

Run from any directory with Python, numpy, scipy, pandas, matplotlib and pypdf.
The R-compatible MT initializer and inversion normal stream are verified against
all 23,400 archived observations plus their conditional means/scales/regimes.
SciPy's inverse normal CDF can differ from R's at floating-point precision;
the exported audit records the maximum discrepancy for every series.
"""
from pathlib import Path
from io import BytesIO
import argparse, hashlib, json, subprocess, zipfile
import numpy as np
import pandas as pd
from scipy.special import ndtri, expit
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
from matplotlib.lines import Line2D
from matplotlib.backends.backend_pdf import PdfPages
from pypdf import PdfReader, PdfWriter

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
KINDS=['smooth_scale','threshold_gjr','switching_seasonal']
FAMILIES={
 'smooth_scale':('A','Smooth nonlinear dynamics','Changing noise scale depends on recent values and a 36-day cycle.'),
 'threshold_gjr':('B','Threshold dynamics + GJR volatility','The mean switches with the sign of the last value; shocks produce asymmetric volatility clusters.'),
 'switching_seasonal':('C','Hidden regimes + seasonal memory','48-day seasonal dynamics and a 12-day lag interact with persistent changes in noise regime.')}
COLORS={'line':'#245b78','test':'#ba6b2e','wash':'#edf1f4','held':'#fff0dc','ink':'#203847','muted':'#627784'}

def r_uniform(seed,n):
    """R's default Mersenne-Twister stream, without changing global NumPy RNG."""
    state=int(seed)
    for _ in range(50):state=(69069*state+1)&0xffffffff
    words=[]
    for _ in range(625):
        state=(69069*state+1)&0xffffffff;words.append(state)
    rng=np.random.RandomState()
    rng.set_state(('MT19937',np.asarray(words[1:],dtype=np.uint32),624,0,0.))
    u=rng.randint(0,2**32,size=n,dtype=np.uint32).astype(np.float64)/2**32
    return np.clip(u,.5/2**32,1-.5/2**32)

def r_normal(seed,n):
    u=r_uniform(seed,2*n).reshape(n,2)
    probability=(np.floor(2**27*u[:,0])+u[:,1])/2**27
    return ndtri(probability)

def simulate(kind,n,seed):
    z=r_normal(seed+1,n);u=r_uniform(seed+2,n)
    state=1 if r_uniform(seed+3,1)[0]<5/7 else 2
    lag=np.zeros(12);variance=1.;error=0.
    y=np.empty(n);mu=np.empty(n);sd=np.empty(n);regime=np.full(n,np.nan)
    for k in range(n):
        t=k+1;a,b,c=lag[:3]
        if kind=='threshold_gjr':variance=.03+.06*error**2+.12*error**2*(error<0)+.85*variance
        if kind=='switching_seasonal':state=1 if u[k] < (.98 if state==1 else .05) else 2
        if kind=='smooth_scale':
            mean=.35*a+.45*np.sin(1.5*b)+.2*c/(1+c*c)
            scale=.16+.75*expit(3*(abs(a)-.55))+.18*(.5+.5*np.sin(2*np.pi*t/36))
        elif kind=='threshold_gjr':
            mean=(-.2+.45*a+.25*np.tanh(b) if a<0 else .15+.25*a-.35*np.tanh(b))+.1*np.sin(c)
            scale=np.sqrt(variance)
        elif kind=='switching_seasonal':
            mean=.35*a+.3*np.tanh(lag[11])+.55*np.sin(2*np.pi*t/48)
            mean+=.2*np.sin(b) if state==1 else -.2*np.tanh(a*b)+.3*np.cos(2*np.pi*t/24)
            scale=.22+.08*abs(np.tanh(a)) if state==1 else .85+.3*abs(np.tanh(a/2))
            regime[k]=state
        else:raise ValueError(kind)
        mu[k]=mean;sd[k]=scale;error=scale*z[k];y[k]=mean+error
        lag=np.r_[y[k],lag[:-1]]
    return pd.DataFrame({'time':np.arange(1,n+1),'y':y,'realized_location':mu,
        'realized_innovation_sd':sd,'simulated_hidden_state':regime})

def decorate(ax,zoom=False):
    ax.spines[['top','right']].set_visible(False)
    ax.spines[['left','bottom']].set_color('#c5d0d8')
    ax.tick_params(colors=COLORS['muted'],labelsize=8.5,length=3)
    ax.grid(axis='y',color='#dfe7ec',alpha=.65,lw=.5)
    ax.set_axisbelow(True)
    if zoom:
        ax.set_xlim(2500,3000);ax.set_xticks([2500,2600,2700,2800,2900,3000])
        ax.set_facecolor('#fffbf5')
    else:
        ax.axvspan(0,500,color=COLORS['wash'],zorder=0)
        ax.axvspan(2500,3000,color=COLORS['held'],alpha=.65,zorder=0)
        for boundary in [500,2500]:ax.axvline(boundary,color='#8b9ba6',ls=(0,(3,3)),lw=.65)
        ax.set_xlim(1,3000);ax.set_xticks([1,500,1000,1500,2000,2500,3000])

def draw(ax,data,zoom=False):
    decorate(ax,zoom)
    if zoom:
        z=data[data.time>=2501];ax.plot(z.time,z.y,color=COLORS['test'],lw=.8)
    else:
        ax.plot(data.time,data.y,color=COLORS['line'],lw=.62)
        z=data[data.time>=2500];ax.plot(z.time,z.y,color=COLORS['test'],lw=.65)
    ax.set_ylabel('Response',fontsize=9,color=COLORS['muted'])

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output-dir',type=Path,default=HERE/'artifacts')
    parser.add_argument('--pdf-output',type=Path,default=ROOT.parent/'output/pdf/AutoDESN_Time_Series_Gallery.pdf')
    args=parser.parse_args();out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=True)
    pdf_path=args.pdf_output.resolve();pdf_path.parent.mkdir(parents=True,exist_ok=True)
    cases=pd.read_csv(ROOT/'validation/autodesn/heteroscedastic/rolling/artifacts/cases.csv')
    archived_path=ROOT/'validation/autodesn/heteroscedastic/artifacts/observed.csv'
    archived=pd.read_csv(archived_path)
    data={};audit=[];choices=[];frames=[]
    for c in cases.itertuples():
        letter=FAMILIES[c.dgp][0];ident=f'{letter}{c.repetition}'
        simulated=simulate(c.dgp,3000,int(c.dgp_seed))
        saved=archived[(archived.dgp==c.dgp)&(archived.repetition==c.repetition)].sort_values('time')
        assert len(saved)==2600 and np.array_equal(saved.time,np.arange(1,2601))
        record={'series':ident,'dgp':c.dgp,'repetition':c.repetition,'seed':c.dgp_seed,'checked_observations':len(saved)}
        for field in ['y','realized_location','realized_innovation_sd']:
            difference=float(np.max(np.abs(simulated[field].iloc[:2600].to_numpy()-saved[field].to_numpy())))
            assert difference<2e-11,(ident,field,difference)
            record[field+'_max_absolute_difference']=difference
        if c.dgp=='switching_seasonal':assert np.array_equal(simulated.simulated_hidden_state.iloc[:2600],saved.simulated_hidden_state)
        prefix=simulate(c.dgp,2600,int(c.dgp_seed))
        assert np.array_equal(prefix.y,simulated.y.iloc[:2600])
        assert np.isfinite(simulated[['y','realized_location','realized_innovation_sd']]).all().all()
        assert (simulated.realized_innovation_sd>0).all()
        record['prefix_invariant']=True;record['passed']=True;audit.append(record)
        simulated['series']=ident;simulated['dgp']=c.dgp;simulated['repetition']=c.repetition
        simulated['seed']=c.dgp_seed
        simulated['split']=np.where(simulated.time<=500,'washout',np.where(simulated.time<=2500,'training','test'))
        assert simulated.split.value_counts().to_dict()=={'training':2000,'washout':500,'test':500}
        data[ident]=simulated;frames.append(simulated)
        choices.append({'series':ident,'dgp':c.dgp,'repetition':c.repetition,'seed':c.dgp_seed,
                        'n_washout':500,'n_train':2000,'n_test':500,'H':30,'rolling_origins':471})
    all_data=pd.concat(frames,ignore_index=True)
    all_data.to_csv(out/'all_nine_series.csv.gz',index=False,float_format='%.17g',compression={'method':'gzip','mtime':0})
    pd.DataFrame(choices).to_csv(out/'series_choices.csv',index=False)
    pd.DataFrame(audit).to_csv(out/'prefix_validation.csv',index=False)
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'pdf.fonttype':42,
                        'axes.titleweight':'bold','axes.labelcolor':COLORS['muted'],'text.color':COLORS['ink']})
    legend=[Patch(facecolor=COLORS['wash'],label='Washout: 1-500'),
            Line2D([0],[0],color=COLORS['line'],lw=1.3,label='Training: 501-2500'),
            Patch(facecolor=COLORS['held'],edgecolor=COLORS['test'],lw=.7,label='Test: 2501-3000')]
    tmp=out/'gallery_pages.pdf';figures=[]
    with PdfPages(tmp,metadata={'Title':'AutoDESN - Choose One Simulated Series','Author':'Q-DESN reproducible simulation study','CreationDate':None,'ModDate':None}) as pages:
        fig,axes=plt.subplots(3,3,figsize=(15.4,10.7))
        for i,kind in enumerate(KINDS):
            for j in range(3):
                ident=f'{FAMILIES[kind][0]}{j+1}';x=data[ident];ax=axes[i,j];draw(ax,x)
                ax.set_title(f'{ident}  |  seed {int(x.seed.iloc[0])}',loc='left',fontsize=11,pad=9)
                if j==0:ax.set_ylabel(FAMILIES[kind][1]+'\nResponse',fontsize=9)
                if i==2:ax.set_xlabel('Day',fontsize=9)
        fig.suptitle('Nine simulated series - choose one example',x=.065,y=.983,ha='left',fontsize=20,weight='bold')
        fig.text(.065,.944,'Same original seeds | 500 washout + 2,000 training + 500 test days | all curves are simulated observations',fontsize=10,color=COLORS['muted'])
        fig.legend(handles=legend,loc='lower center',bbox_to_anchor=(.5,.018),ncol=3,frameon=False,fontsize=10)
        fig.text(.065,.002,'IDs A1-C3 identify the choice. Vertical scales vary by panel. No model forecasts are shown.',fontsize=8.5,color=COLORS['muted'])
        fig.subplots_adjust(left=.08,right=.98,top=.885,bottom=.10,hspace=.39,wspace=.24)
        fig.savefig(out/'all_nine_overview.png',dpi=170);pages.savefig(fig);plt.close(fig);figures.append('all_nine_overview.png')
        for number,kind in enumerate(KINDS,2):
            letter,title,description=FAMILIES[kind]
            fig,axes=plt.subplots(3,2,figsize=(15.0,10.5),gridspec_kw={'width_ratios':[1.65,1]})
            for j in range(3):
                ident=f'{letter}{j+1}';x=data[ident]
                for k in range(2):
                    ax=axes[j,k];draw(ax,x,zoom=bool(k))
                    ax.set_title(f'{ident}  |  '+('all 3,000 days' if k==0 else '500-day test window'),loc='left',fontsize=11,pad=9)
                    if j==2:ax.set_xlabel('Day',fontsize=9)
                axes[j,0].text(1,.99,f'seed {int(x.seed.iloc[0])}',transform=axes[j,0].transAxes,ha='right',va='top',fontsize=8,color=COLORS['muted'])
            fig.suptitle(f'{letter}  |  {title}',x=.065,y=.982,ha='left',fontsize=21,weight='bold')
            fig.text(.065,.943,description,fontsize=10.3,color=COLORS['muted'])
            fig.text(.065,.916,'Left: complete trajectory with split boundaries. Right: the same observed test block, enlarged.',fontsize=9.5,color=COLORS['muted'])
            fig.legend(handles=legend,loc='lower center',bbox_to_anchor=(.5,.022),ncol=3,frameon=False,fontsize=10)
            fig.text(.065,.006,f'Choose {letter}1, {letter}2 or {letter}3. These are simulated data, not forecasts.  |  {number}/4',fontsize=9,color=COLORS['muted'])
            fig.subplots_adjust(left=.065,right=.98,top=.86,bottom=.11,hspace=.43,wspace=.14)
            name=f'{letter}_{kind}.png';fig.savefig(out/name,dpi=170);pages.savefig(fig);plt.close(fig);figures.append(name)
    writer=PdfWriter();writer.append(str(tmp))
    evidence=BytesIO()
    with zipfile.ZipFile(evidence,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for name in ['all_nine_series.csv.gz','series_choices.csv','prefix_validation.csv']:
            archive.write(out/name,name)
        archive.write(Path(__file__),'generate_gallery.py')
        archive.write(ROOT/'validation/autodesn/heteroscedastic/dgp.R','original_dgp.R')
    writer.add_attachment('Series_Choices_Data_and_Validation.zip',evidence.getvalue())
    writer.add_metadata({'/Title':'AutoDESN - Nine Simulated Series for Selection','/Subject':'500 washout, 2000 training, 500 test; observations only; no fitted forecasts'})
    with pdf_path.open('wb') as stream:writer.write(stream)
    tmp.unlink()
    assert len(PdfReader(pdf_path).pages)==4
    record={'purpose':'Select one series before fitting and comparing forecasting models',
            'series':9,'days_per_series':3000,'washout':500,'training':2000,'test':500,
            'prefix_checks_passed':9,'archived_observations_checked':23400,
            'max_y_difference':max(x['y_max_absolute_difference'] for x in audit),
            'normal_quantile':'SciPy ndtri, R-compatible MT/inversion inputs; numerical-prefix parity checked',
            'original_data_sha256':hashlib.sha256(archived_path.read_bytes()).hexdigest(),
            'original_dgp_sha256':hashlib.sha256((ROOT/'validation/autodesn/heteroscedastic/dgp.R').read_bytes()).hexdigest(),
            'source_head':subprocess.check_output(['/usr/bin/git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'no_forecasting_models_run':True,'plots':figures,'pdf_name':pdf_path.name,
            'pdf_sha256':hashlib.sha256(pdf_path.read_bytes()).hexdigest()}
    (out/'gallery_validation.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record,indent=2))

if __name__=='__main__':main()
