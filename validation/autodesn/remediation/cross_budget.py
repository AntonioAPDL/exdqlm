"""Compare successive, independently screened posterior budgets on training data.

This certificate cannot authorize forecasts: calibration, mode checks and predictive
Monte Carlo qualification are separate requirements. It never reads test responses.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import norm

ROOT = Path(__file__).resolve().parent


def summary(values, kind="mean", noise=None):
    """Independent chain batches and delta-method MCSE for a posterior functional."""
    x = np.asarray(values, dtype=float)
    n = x.shape[1]
    size = int(np.sqrt(n))
    count = n // size
    xb = x[:, :count * size].reshape(-1, size)
    if kind == "mean":
        value = float(x.mean())
        batches = xb.mean(1)
    else:
        assert noise is not None and np.asarray(noise).shape == x.shape
        mean = x.mean()
        second = (x * x + noise).mean()
        value = float(np.sqrt(second - mean * mean))
        nb = np.asarray(noise)[:, :count * size].reshape(-1, size)
        # Influence function of sqrt(E[mu^2 + sigma^2] - E[mu]^2).
        batches = ((xb * xb + nb).mean(1) - 2 * mean * xb.mean(1)) / (2 * value)
    return value, float(batches.std(ddof=1) / np.sqrt(len(batches)))


def compare(family, left_name, right_name):
    names = [left_name, right_name]
    directories = [ROOT / "artifacts" / family / n for n in names]
    configs, qualifications, traces, validations = [], [], [], []
    for directory in directories:
        config = json.loads((directory / "configuration.json").read_text())
        status = json.loads((directory / "status.json").read_text())
        qualification = json.loads((directory / "qualification.json").read_text())
        validation_path = ROOT / "evidence" / f"{family}_{directory.name}_checkpoint_validation.json"
        validation = json.loads(validation_path.read_text())
        assert status["complete"] and validation["complete"]
        assert validation["target_id"] == qualification["target_id"] == status["target_id"]
        assert config["phase"] == "production" and config["chains"] == 4
        for file, sha in qualification["trace_sha256"].items():
            assert hashlib.sha256((directory / file).read_bytes()).hexdigest() == sha
        configs.append(config)
        qualifications.append(qualification)
        validations.append(validation)
        traces.append([pd.read_csv(directory / f"trace_{k}.csv") for k in range(1, 5)])
    assert qualifications[0]["target_id"] == qualifications[1]["target_id"]
    for field in ["proposal_sha256", "local_proposal_sha256", "bank_id", "priors", "beta_prior"]:
        assert configs[0].get(field) == configs[1].get(field), "Cross-budget comparison requires a common frozen target/proposal policy: " + field
    assert configs[0].get("local_scale_proposal", False) == configs[1].get("local_scale_proposal", False)
    ladder = [32000, 128000, 256000]
    index = ladder.index(configs[0]["retained"])
    assert index + 1 < len(ladder) and configs[1]["retained"] == ladder[index + 1]
    assert not family.startswith("SV"), "SV needs matched latent-variance probe summaries; do not substitute constant noise."
    sd = configs[1].get("training_response_sd", configs[0].get("training_response_sd"))
    assert sd is not None and np.isfinite(sd) and sd > 0
    rows = []

    def add(name, arrays, practical, kind="mean", noises=None, relative=False):
        estimates = [summary(arrays[i], kind, None if noises is None else noises[i]) for i in range(2)]
        difference = abs(estimates[1][0] - estimates[0][0])
        tolerance = practical * np.mean([estimates[0][0], estimates[1][0]]) if relative else practical
        rows.append(dict(quantity=name, left=estimates[0][0], right=estimates[1][0],
                         left_mcse=estimates[0][1], right_mcse=estimates[1][1],
                         difference=difference, practical_tolerance=tolerance,
                         practical_passed=bool(difference <= tolerance),
                         combined_mcse=float(np.hypot(estimates[0][1], estimates[1][1]))))

    probes = [c for c in traces[0][0] if c.startswith("fitted_probe_")]
    assert probes and all(c in traces[1][0] for c in probes)
    noises = [np.array([t.variance.to_numpy() for t in ts]) for ts in traces]
    for probe in probes:
        arrays = [np.array([t[probe].to_numpy() for t in ts]) for ts in traces]
        add(probe + "_mean", arrays, .01 * sd)
        add(probe + "_predictive_sd", arrays, .02, "sd", noises, relative=True)
    for field in ["model", "period_index"]:
        values = sorted(set(np.concatenate([t[field].to_numpy() for ts in traces for t in ts])))
        for value in values:
            arrays = [np.array([(t[field].to_numpy() == value).astype(float) for t in ts]) for ts in traces]
            if np.mean([x.mean() for x in arrays]) >= .01:
                add(f"{field}_{value}", arrays, .02)
    table = pd.DataFrame(rows)
    critical = float(norm.ppf(1 - .01 / (2 * len(table))))
    table["simultaneous_mc_tolerance"] = critical * table.combined_mcse
    table["mc_consistency_passed"] = table.difference <= table.simultaneous_mc_tolerance + 1e-12
    passed = bool(all(q["screen_passed"] for q in qualifications)
                  and table.practical_passed.all() and table.mc_consistency_passed.all())
    label = f"{family}_{left_name}_vs_{right_name}"
    table.to_csv(ROOT / "evidence" / (label + "_stability.csv"), index=False)
    record = dict(complete=True, cross_budget_passed=passed, family=family, phases=names,
                  target_id=qualifications[0]["target_id"],
                  individual_screens_passed=[q["screen_passed"] for q in qualifications],
                  practical_stability_passed=bool(table.practical_passed.all()),
                  mc_consistency_passed=bool(table.mc_consistency_passed.all()),
                  familywise_normal_critical_value=critical, checked_quantities=len(table),
                  response_sd=sd, qualified=False, forecast_allowed=False,
                  validation_contract_ids=[v["contract_id"] for v in validations],
                  scope="Successive fresh posterior budgets; fixed training-probe means and marginal constant-noise predictive SDs, major model/period masses; no held-out outcomes read",
                  pending=["independent calibration/mode review", "predictive Monte Carlo sensitivity", "full scientific promotion"])
    (ROOT / "evidence" / (label + "_stability.json")).write_text(json.dumps(record, indent=2) + "\n")
    return record


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("family")
    parser.add_argument("left")
    parser.add_argument("right")
    args = parser.parse_args()
    result = compare(args.family, args.left, args.right)
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["cross_budget_passed"] else 2)
