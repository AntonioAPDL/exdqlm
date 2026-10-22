"""Check complete split, score, probability, diagnostic and source evidence."""
from pathlib import Path
import hashlib
import os
import numpy as np
import pandas as pd

OUT = Path(os.getenv("AUTODESN_LONG_OUT", "validation/autodesn/long_horizon/artifacts"))
scores = pd.read_csv(OUT / "scores.csv")
observed = pd.read_csv(OUT / "observed.csv")
audit = pd.read_csv(OUT / "audit.csv")
prob = pd.read_csv(OUT / "probability.csv")
diag = pd.read_csv(OUT / "diagnostics.csv")
summary = pd.read_csv(OUT / "summary.csv")
checks = []

def check(name, value, detail=""):
    passed = bool(value)
    checks.append(dict(check=name, passed=passed, detail=str(detail)))
    if not passed:
        raise AssertionError(f"{name}: {detail}")

n_cases = len(audit)
check("case_keys_unique", not audit.duplicated(["dgp", "repetition"]).any(), n_cases)
check("exact_split", ((audit.fit_start == 501) & (audit.fit_end == 1000) & (audit.n_train == 500) &
    (audit.forecast_origin == 1000) & (audit.horizon == 100) & (audit.conditioning_end == 500)).all())
check("path_contract", ((audit.outer_draws == 192) & (audit.inner_paths == 64) & (audit.total_paths == 12288)).all())
check("forecast_rows_complete", len(scores) == n_cases * 7 * 100, len(scores))
check("score_keys_unique", not scores.duplicated(["dgp", "repetition", "method", "horizon"]).any())
numeric = scores.select_dtypes(include=np.number)
check("finite_numeric_scores", np.isfinite(numeric).all().all())
check("all_paths_reported_finite", audit.all_forecasts_finite.all())
check("response_rows_complete", len(observed) == n_cases * 1100)
check("observation_keys_unique", not observed.duplicated(["dgp", "repetition", "time"]).any())
check("predictive_quantiles_ordered", (scores.lower90 <= scores.lower50).all() and
      (scores.lower50 <= scores["median"]).all() and (scores["median"] <= scores.upper50).all() and
      (scores.upper50 <= scores.upper90).all())

for (kind, rep), group in observed.groupby(["dgp", "repetition"]):
    check(f"split_labels_{kind}_{rep}", group[group.split == "washout"].time.tolist() == list(range(1,501)) and
          group[group.split == "training"].time.tolist() == list(range(501,1001)) and
          group[group.split == "forecast"].time.tolist() == list(range(1001,1101)))
    row = audit[(audit.dgp == kind) & (audit.repetition == rep)].iloc[0]
    prefix = group[group.time <= 500].y
    check(f"frozen_prefix_scale_{kind}_{rep}", np.isclose(row.center, prefix.mean(), atol=1e-12) and
          np.isclose(row.scale, prefix.std(ddof=1), atol=1e-12))
    p = prob[(prob.dgp == kind) & (prob.repetition == rep)]
    check(f"bank_size_{kind}_{rep}", len(p) == 72)
    check(f"probability_mass_{kind}_{rep}", abs(p.posterior_probability.sum()-1) < 1e-12 and
          abs(p.prior_probability.sum()-1) < 1e-12 and abs(p.occupancy.sum()-1) < 1e-12)
    for method in ("AutoDESN", "Fixed_DESN"):
        d = diag[(diag.dgp == kind) & (diag.repetition == rep) & (diag.method == method)]
        check(f"diagnostic_attempts_{kind}_{rep}_{method}", d.attempt.max() in (1,2) and len(d) == 2 * d.attempt.max())
        if d.attempt.max() == 2:
            first = d[d.attempt == 1]
            check(f"retry_only_if_needed_{kind}_{rep}_{method}", not first.diagnostic_screen_pass.all() and
                  ((first.rhat > 1.01).any() or (first.ess_spectral < 400).any() or (first.max_model_chain_range > .05).any()))
    for tail in ("paths", "mean_location_by_draw", "plugin_by_draw"):
        data = pd.read_csv(OUT / f"{kind}_r{rep:02d}_{tail}.csv")
        expected_cols = 65 if tail == "paths" else 193
        check(f"saved_{tail}_{kind}_{rep}", data.shape == (100, expected_cols) and
              np.isfinite(data.to_numpy()).all())

fields = ["squared_error", "absolute_error", "crps", "covered90", "width90", "latent_squared_error", "oracle_mean_squared_error"]
recomputed = scores.groupby(["dgp", "method"])[fields].mean().sort_index()
recorded = summary.set_index(["dgp", "method"]).sort_index()
check("aggregate_means_replay", np.allclose(recomputed.to_numpy(), recorded[fields].to_numpy(), rtol=1e-12, atol=1e-12))
check("rmse_replay", np.allclose(np.sqrt(recomputed.squared_error), recorded.rmse, rtol=1e-12, atol=1e-12))

launch = pd.read_csv(OUT / "launch_source_manifest.csv")
for row in launch.itertuples():
    check(f"launch_source_hash:{row.path}", hashlib.md5(Path(row.path).read_bytes()).hexdigest() == row.md5)

pd.DataFrame(checks).to_csv(OUT / "result_audit.csv", index=False)
print(f"{len(checks)} evidence checks passed; {n_cases} cases, {len(scores)} scored rows.")
