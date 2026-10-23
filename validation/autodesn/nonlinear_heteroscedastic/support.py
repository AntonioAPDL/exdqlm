"""Shared, strict protocol and score checks for the RHS comparison."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tomllib

import numpy as np
import pandas as pd
from scipy.special import logsumexp

ROOT = Path(__file__).resolve().parent
LEGACY = ROOT
SCORE_COLUMNS = ["origin", "horizon", "target", "actual", "model", "mean", "predictive_sd",
    "lower90", "lower50", "median", "upper50", "upper90", "squared_error", "absolute_error",
    "crps", "negative_log_score", "covered50", "covered90", "width50", "width90"]
LABELS = {"ridge": "AutoDESN ridge", "rhs": "AutoDESN RHS", "gp": "AutoGP"}


def sha256(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def write_json(value, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".partial")
    temporary.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n")
    temporary.replace(path)


def configuration(mode="full"):
    cfg = json.loads((ROOT / "configuration.json").read_text())
    for name, expected in cfg["input_sha256"].items():
        if sha256(LEGACY / "input" / name) != expected:
            raise ValueError(f"Frozen NHS1 input hash mismatch: {name}")
    cfg["mode"] = mode
    if mode == "smoke":
        cfg.update(washout=30, fit_start=31, fit_end=110, n_train=80,
            test_start=111, test_end=120, n_test=10, first_origin=110,
            last_origin=115, origins=6, H=5, outer_draws=12, inner_paths=2,
            checkpoint_draws=24)
    elif mode != "full":
        raise ValueError("Only full or smoke results may be aggregated")
    return cfg


def validate_scores(scores, cfg, label):
    missing = set(SCORE_COLUMNS) - set(scores)
    if missing:
        raise ValueError(f"Missing score columns: {sorted(missing)}")
    if set(scores.model) != {label}:
        raise ValueError(f"Unexpected model labels for {label}")
    if len(scores) != cfg["origins"] * cfg["H"] or scores.duplicated(["origin", "horizon"]).any():
        raise ValueError("Missing or duplicate origin/lead pairs")
    expected = {(o, h) for o in range(cfg["first_origin"], cfg["last_origin"] + 1)
        for h in range(1, cfg["H"] + 1)}
    if set(zip(scores.origin, scores.horizon)) != expected:
        raise ValueError("Origin/lead grid differs from the frozen protocol")
    numeric = scores[SCORE_COLUMNS].drop(columns=["model"]).to_numpy(dtype=float)
    if not np.isfinite(numeric).all():
        raise ValueError("Nonfinite score or predictive summary")
    np.testing.assert_array_equal(scores.target, scores.origin + scores.horizon)
    y = pd.read_csv(LEGACY / "input/series.csv").y.to_numpy()
    np.testing.assert_allclose(scores.actual, y[scores.target.to_numpy(dtype=int) - 1], rtol=0, atol=1e-12)
    quantiles = scores[["lower90", "lower50", "median", "upper50", "upper90"]].to_numpy()
    if (np.diff(quantiles, axis=1) < 0).any() or (scores.predictive_sd <= 0).any():
        raise ValueError("Invalid predictive scale or quantile ordering")
    np.testing.assert_allclose(scores.squared_error, (scores["mean"] - scores.actual)**2, rtol=1e-10, atol=1e-10)
    np.testing.assert_allclose(scores.absolute_error, abs(scores["mean"] - scores.actual), rtol=1e-10, atol=1e-10)
    for level in (50, 90):
        lo, hi = scores[f"lower{level}"], scores[f"upper{level}"]
        np.testing.assert_array_equal(scores[f"covered{level}"], (scores.actual >= lo) & (scores.actual <= hi))
        np.testing.assert_allclose(scores[f"width{level}"], hi - lo, rtol=1e-10, atol=1e-10)
    return scores[SCORE_COLUMNS].copy()


def diagnostic_gate(directory, cfg):
    directory = Path(directory)
    parameters = pd.read_csv(directory / "diagnostics.csv")
    models = pd.read_csv(directory / "model_probabilities.csv")
    if "sampled" in parameters:
        flags = parameters.sampled.astype(str).str.lower()
        if not flags.isin(["true", "false", "1", "0"]).all():
            return False
        parameters = parameters[flags.isin(["true", "1"])]
    if parameters.empty or models.empty:
        return False
    p = parameters[["rhat", "ess_spectral"]].to_numpy()
    ranges = models.chain_range.to_numpy()
    g = cfg["diagnostic_gates"]
    return bool(np.isfinite(p).all() and np.isfinite(ranges).all()
        and p[:, 0].max() <= g["rhat_max"] and p[:, 1].min() >= g["ess_min"]
        and ranges.max() <= g["model_chain_range_max"])


def sample_score(actual, paths):
    x = paths.yrep.to_numpy(); n = len(x); sx = np.sort(x)
    crps = np.mean(abs(x - actual)) - np.dot(2 * np.arange(1, n + 1) - n - 1, sx) / n**2
    q = np.quantile(x, [.05, .25, .5, .75, .95], method="median_unbiased")
    nll = -(logsumexp(-np.log(paths.sd) - .5 * np.log(2 * np.pi)
        - .5 * ((actual - paths.mu) / paths.sd)**2) - np.log(n))
    return np.r_[paths.mu.mean(), crps, nll, q]


def audit_paths(directory, scores, cfg):
    directory = Path(directory)
    origins = list(range(cfg["first_origin"], cfg["last_origin"] + 1))
    selected = sorted({origins[0], origins[(len(origins) - 1) // 2], origins[-1]})
    errors = []
    for origin in selected:
        paths = pd.read_csv(directory / f"paths_{origin}.csv.gz")
        if not np.isfinite(paths[["horizon", "yrep", "mu", "sd"]].to_numpy(dtype=float)).all() or (paths.sd <= 0).any():
            raise ValueError("Nonfinite path or nonpositive conditional Gaussian scale")
        if set(paths.horizon) != set(range(1, cfg["H"] + 1)):
            raise ValueError("Raw paths have missing or extra forecast leads")
        for h in range(1, cfg["H"] + 1):
            sample = paths[paths.horizon == h]
            if len(sample) != cfg["outer_draws"] * cfg["inner_paths"]:
                raise ValueError("Wrong posterior/innovation path count")
            path_id = "trajectory" if "trajectory" in sample else "path"
            if sample[path_id].duplicated().any():
                raise ValueError("Duplicate trajectories in raw forecast paths")
            ref = scores[(scores.origin == origin) & (scores.horizon == h)].iloc[0]
            expected = ref[["mean", "crps", "negative_log_score", "lower90", "lower50",
                "median", "upper50", "upper90"]].to_numpy(dtype=float)
            delta = float(np.max(abs(sample_score(ref.actual, sample) - expected)))
            if not np.isfinite(delta) or delta >= 1e-9:
                raise ValueError(f"Independent score audit failed: origin {origin}, lead {h}, error {delta}")
            errors.append(delta)
    return dict(complete=True, checked_marginals=len(errors), max_absolute_error=max(errors),
        method="Independent NumPy/SciPy reconstruction from exported recursive paths")


def aggregate(scores):
    return dict(RMSE=float(np.sqrt(scores.squared_error.mean())), MAE=float(scores.absolute_error.mean()),
        CRPS=float(scores.crps.mean()), NLL=float(scores.negative_log_score.mean()),
        Coverage50=float(scores.covered50.mean()), Coverage90=float(scores.covered90.mean()),
        Width50=float(scores.width50.mean()), Width90=float(scores.width90.mean()), pairs=len(scores))


def validate_native_checks(checks):
    expected = {(origin, component) for origin in (2500, 2735, 2970) for component in range(1, 9)}
    if len(checks) != 24 or set(zip(checks.origin, checks.component)) != expected:
        raise ValueError("GP native checks must contain all three origins and eight particles")
    errors = checks[["mean_max_error", "covariance_max_error"]].to_numpy(dtype=float)
    if not np.isfinite(errors).all() or (errors < 0).any() or (errors >= 1e-5).any():
        raise ValueError("GP native conditioning errors are missing or exceed tolerance")
    return errors.max(axis=0)


def validate_gp_evidence(directory):
    directory = Path(directory); runs = []; times = []; maxima = []
    schedule = [0, 32, 64, 128, 256, 512, 1000, 1500, 2000]
    for run in (1, 2):
        d = directory / f"run_{run}"
        status = tomllib.loads((d / "status.toml").read_text())
        expected = dict(complete=True, fixed_weights=True, fit_rows=2000, n_future=500,
            n_particles=8, seed=1166019 + run)
        if any(status.get(k) != v for k, v in expected.items()):
            raise ValueError("GP native run status differs from the pinned C1 protocol")
        maxima.append(validate_native_checks(pd.read_csv(d / "native_checks.csv")))
        particles = pd.read_csv(d / "particles.csv")
        if len(particles) != 8 or set(particles.component) != set(range(1, 9)):
            raise ValueError("GP particle identifiers are incomplete")
        w = particles.weight.to_numpy(); noise = particles.noise_variance.to_numpy()
        if (not np.isfinite(w).all() or (w < 0).any() or abs(w.sum() - 1) > 1e-10
                or not np.isfinite(noise).all() or (noise <= 0).any()):
            raise ValueError("Invalid GP particle weights or observation-noise variances")
        ess = 1 / np.sum(w * w)
        if not np.isfinite(status.get("ess", np.nan)) or abs(status["ess"] - ess) > 1e-8:
            raise ValueError("GP reported particle ESS disagrees with its exported weights")
        progress = pd.read_csv(d / "smc_progress.csv").tail(len(schedule))
        if len(progress) != len(schedule) or progress.step.tolist() != schedule:
            raise ValueError("GP final completed SMC schedule is incomplete")
        elapsed = progress.elapsed.to_numpy()
        if not np.isfinite(elapsed).all() or (elapsed < 0).any() or (np.diff(elapsed) < 0).any():
            raise ValueError("GP SMC callback times are invalid")
        runs.append(status); times.append(float(elapsed[-1]))
    maximum = np.max(maxima, axis=0)
    return dict(complete=True, runs=runs, training_seconds_sum=sum(times),
        max_native_mean_error=float(maximum[0]), max_native_covariance_error=float(maximum[1]))
