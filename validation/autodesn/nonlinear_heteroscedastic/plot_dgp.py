"""Show the single frozen DGP realization without selecting or changing it."""
from pathlib import Path
import numpy as np,pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
HERE=Path(__file__).resolve().parent
def main():
 d=pd.read_csv(HERE/'input/dgp_truth.csv');out=HERE/'evidence';out.mkdir(exist_ok=True)
 plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'axes.spines.top':False,'axes.spines.right':False})
 fig,ax=plt.subplots(4,1,figsize=(12,10),layout='constrained')
 ax[0].plot(d.time,d.y,color='#243d53',lw=.6)
 ax[0].axvspan(1,500,color='#b6bdc5',alpha=.3,label='Washout: 500')
 ax[0].axvspan(2500,3000,color='#d88732',alpha=.18,label='Held out: 500')
 ax[0].set(title='NHS1 | one frozen seed | no trend',ylabel='Response');ax[0].legend(ncol=2,frameon=False)
 g=d[(d.time>=2201)&(d.time<=2500)]
 ax[1].plot(g.time,g.y,lw=.8,c='#243d53',label='Observed')
 ax[1].plot(g.time,g.conditional_mean,lw=1.2,c='#993e7e',label='True conditional mean')
 ax[1].set(title='Training-only detail: threshold and nonlinear dynamics',ylabel='Response');ax[1].legend(ncol=2,frameon=False)
 ax[2].plot(np.arange(1,61),d.season.iloc[:60],color='#277a73',lw=1.6,marker='.',ms=3)
 ax[2].set(title='Centered seasonal pattern: asymmetric pulses, ramp and short blocks',xlabel='Position within 60-step cycle',ylabel='Seasonal offset')
 ax[3].plot(d.time,d.conditional_sd,c='#be692d',lw=.8)
 ax[3].axvline(2500,c='gray',ls='--',lw=.8)
 ax[3].set(title='True conditional innovation SD: seasonal variation and persistent asymmetric clustering',xlabel='Time',ylabel='Conditional SD')
 for a in ax:a.grid(alpha=.13)
 fig.savefig(out/'NHS1_DGP.png',dpi=160);plt.close(fig)
 print(out/'NHS1_DGP.png')
if __name__=='__main__':main()
