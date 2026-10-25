"""Seven-dimensional integration from normalized proper priors, independent of R.

Coefficients use the dense response-space Gaussian covariance. The three local
scales occupy a fixed space; the second reservoir scale integrates out in model 1.
"""
import hashlib
import json
import time
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.special import gammaincinv
from scipy.stats import qmc

root = Path("validation/autodesn/remediation")
fixture = root / "artifacts/production_scale_reference_fixture.json"
f = json.loads(fixture.read_text())
y = np.array(f["y"])
n = len(y)
fields = ["variance", "log_global_1", "log_global_2", "log_slab", "intercept",
          "intercept_squared", "fitted_mean_4", "model_2", "period_2", "joint_2_2",
          "log_local_lag", "log_local_reservoir_1"]


def integrate(power, seed):
    U = qmc.Sobol(7, scramble=True, bits=52, seed=seed).random_base2(power)
    assert ((U > 0) & (U < 1)).all()
    u1 = np.tan(np.pi / 2 * U[:, 0])
    u2 = np.tan(np.pi / 2 * U[:, 1])
    c2 = 2 / gammaincinv(2, U[:, 2])
    s2 = 1 / gammaincinv(3, U[:, 3])
    local = np.tan(np.pi / 2 * U[:, 4:7])
    N = len(U)
    total = np.zeros(N)
    numerator = np.zeros(len(fields))
    for d in f["designs"]:
        X = np.array(d["X"])
        assert X.shape[0] == n
        groups = d["groups"]
        v = np.empty((N, len(groups)))
        for k, group in enumerate(groups):
            if group == "intercept":
                v[:, k] = f["intercept_variance"]
            elif group == "calendar":
                v[:, k] = f["calendar_variance"]
            else:
                u = u1 if group == "lag" else u2
                h = (f["tau0"] * local[:, d["slots"][k] - 1] * u) ** 2
                v[:, k] = c2 * h / (c2 + h)
        C = np.einsum("ik,nk,jk->nij", X, v, X, optimize=True)
        C[:, np.arange(n), np.arange(n)] += s2[:, None]
        sign, ld = np.linalg.slogdet(C)
        assert (sign > 0).all()
        rhs = np.broadcast_to(np.stack([y, np.ones(n)], axis=1), (N, n, 2))
        solution = np.linalg.solve(C, rhs)
        a, b = solution[:, :, 0], solution[:, :, 1]
        ll = -.5 * (n * np.log(2 * np.pi) + ld + (a * y).sum(1))
        w = np.exp(ll) * f["model_prior"][d["model"] - 1] * f["period_prior"][d["period_index"] - 1]
        mean = f["intercept_variance"] * a.sum(1)
        var = f["intercept_variance"] - f["intercept_variance"] ** 2 * b.sum(1)
        assert var.min() > -1e-8
        values = [s2, np.log(u1), np.log(u2), np.log(c2), mean, var + mean ** 2,
                  y[3] - s2 * a[:, 3], int(d["model"] == 2), int(d["period_index"] == 2),
                  int(d["model"] == 2 and d["period_index"] == 2),
                  np.log(local[:, 0]), np.log(local[:, 1])]
        total += w
        numerator += np.array([(w * z).sum() for z in values])
    return total.mean(), numerator / total.sum(), float(total.sum() ** 2 / (total @ total))


started = time.monotonic()
runs = []
for power in [16, 18]:
    for replicate in range(8):
        z, mu, concentration = integrate(power, 9156101 + replicate)
        runs.append(dict(power=power, replicate=replicate, normalizer=z,
                         weight_concentration_index=concentration, **dict(zip(fields, mu))))
rows = pd.DataFrame(runs)
rows.to_csv(root / "evidence/production_scale_prior_integration_runs.csv", index=False)
coarse, fine = rows[rows.power == 16], rows[rows.power == 18]
result = pd.DataFrame(dict(quantity=fields, reference=fine[fields].mean().values,
                          reference_mcse=(fine[fields].std(ddof=1) / np.sqrt(8)).values,
                          refinement_difference=np.abs(fine[fields].mean() - coarse[fields].mean()).values))
assert result.reference_mcse.max() < .003, result
result.to_csv(root / "evidence/production_scale_prior_integration.csv", index=False)
record = dict(complete=True, replications=8, prior_integration_counts=[2 ** 16, 2 ** 18],
              maximum_reference_mcse=float(result.reference_mcse.max()),
              maximum_refinement_difference=float(result.refinement_difference.max()),
              fixture_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest(),
              elapsed_seconds=time.monotonic() - started, production_qualified=False,
              scope="Learned local and independent global scales, shared slab, proper Gaussian calendar, unknown noise, architecture/period averaging; seven-dimensional conditional posterior, not recursive calibration")
(root / "evidence/production_scale_prior_integration.json").write_text(json.dumps(record, indent=2) + "\n")
print(result.to_string(index=False))
print(json.dumps(record))
