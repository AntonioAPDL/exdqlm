"""Independent integration of the complete depth-one native leaf grammar.

The pinned default depth-one grammar has equal mass on Linear,
GammaExponential and Periodic, and zero mass on Constant and SE. Integrate all
four standard-normal latent parameters (including noise), without fitting or
calling native covariance functions. This is a small reference, not depth-four
SMC qualification. Scrambled Sobol variation and refinement are both reported.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.special import ndtri, expit
from scipy.stats import qmc

root = Path('validation/autodesn/remediation')
times = np.array([0., .19, .47, 1.])
y = np.array([.13, -.24, .12, .07])
delta = np.abs(times[:, None]-times[None, :])
names = ['linear_probability', 'gamma_probability', 'periodic_probability',
         'noise_variance', 'log_noise_latent', 'amplitude', 'log_likelihood',
         'fitted_mean_3', 'latent_second_moment_3']

def integrals(power, seed):
    z = ndtri(qmc.Sobol(4, scramble=True, seed=seed).random_base2(power))
    total = np.zeros(len(names)+1)
    for start in range(0, len(z), 8192):
        latent = z[start:start+8192]
        p = np.exp(-1.5+latent)
        noise = p[:, 0]+1e-5
        for m in range(3):
            if m == 0:
                shifted = times[None, :]-p[:, 1, None]
                K = p[:, 2, None, None]+p[:, 3, None, None]*shifted[:, :, None]*shifted[:, None, :]
            elif m == 1:
                K = p[:, 3, None, None]*np.exp(-(delta[None, :, :]/p[:, 1, None, None])**(2*expit(latent[:, 2, None, None])))
            else:
                K = p[:, 3, None, None]*np.exp(-2*np.sin(np.pi*delta[None, :, :]/p[:, 2, None, None])**2/p[:, 1, None, None]**2)
            C = K+noise[:, None, None]*np.eye(4)
            L = np.linalg.cholesky(C)
            a = np.linalg.solve(L, np.broadcast_to(y, (len(latent), 4))[..., None])
            ll = -2*np.log(2*np.pi)-np.log(np.diagonal(L, axis1=1, axis2=2)).sum(1)-.5*(a*a).sum((1, 2))
            alpha = np.linalg.solve(L.transpose(0, 2, 1), a)[..., 0]
            mu = (K[:, 2, :]*alpha).sum(1)
            v = K[:, 2, 2]-(np.linalg.solve(L, K[:, :, 2, None])**2).sum((1, 2))
            assert np.all(v >= -1e-10)
            values = np.column_stack([np.full(len(latent), float(m == j)) for j in range(3)]+
                [noise, latent[:, 0], p[:, 3], ll, mu, mu*mu+v])
            w = np.exp(ll)/3
            total[0] += w.sum()
            total[1:] += (w[:, None]*values).sum(0)
    return total[0]/len(z), total[1:]/total[0]

records = {}
for power in [16, 18]:
    runs = [integrals(power, 7466101+k) for k in range(8)]
    x = np.array([r[1] for r in runs])
    records[power] = (x.mean(0), x.std(0, ddof=1)/np.sqrt(len(x)))
mean, se = records[18]
table = pd.DataFrame(dict(quantity=names, reference=mean, reference_mcse=se,
                          refinement_difference=np.abs(mean-records[16][0])))
table.to_csv(root/'evidence/gp_leaf_prior_integration.csv', index=False)
result = dict(complete=True, grammar='native default max_depth=1; all three supported leaf types',
              tree_prior=[1/3]*3, normalized_latent_prior='four independent standard normals',
              model_jitter=1e-5, maximum_reference_mcse=float(se.max()),
              maximum_refinement_difference=float(table.refinement_difference.max()),
              scrambles=8, powers=[16, 18], seed_base=7466101,
              fixture=dict(times=times.tolist(), response=y.tolist()),
              source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              production_qualified=False)
(root/'evidence/gp_leaf_prior_integration.json').write_text(json.dumps(result, indent=2)+'\n')
print(table.to_string(index=False))
