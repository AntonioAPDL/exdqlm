"""Freeze a full-support proposal's training periodogram centers, never a prior."""
import hashlib,json
from pathlib import Path
import numpy as np,pandas as pd
from scipy.signal import periodogram
HERE=Path(__file__).resolve().parent;source=HERE.parent/'nonlinear_heteroscedastic/input/series.csv'
y=pd.read_csv(source,nrows=2500).y.to_numpy()[500:2500];assert len(y)==2000
f,p=periodogram(y);valid=np.flatnonzero((f>=1/120)&(f<=1/20));ranking=valid[np.argsort(p[valid])[::-1]];peaks=[]
for i in ranking:
 period=float(1/f[i])
 if all(abs(np.log(period/q))>np.log(1.15) for q in peaks):peaks.append(period)
 if len(peaks)==5:break
folder=HERE/'artifacts';folder.mkdir(exist_ok=True)
(folder/'gp_training_proposal.toml').write_text('periods = ['+', '.join(map(repr,peaks))+']\n')
record=dict(complete=True,training_only=True,rows=[501,2500],raw_periods=peaks,training_sha256=hashlib.sha256(y.tobytes()).hexdigest(),proposal_only=True)
(HERE/'evidence/gp_training_proposal.json').write_text(json.dumps(record,indent=2)+'\n');print(record)
