"""Audit and aggregate only complete, protocol-compatible C1 model outputs."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import time

import numpy as np
import pandas as pd

from support import ROOT, LEGACY, LABELS, configuration, validate_scores, diagnostic_gate, audit_paths, aggregate, sha256, validate_gp_evidence, write_json


def check_status(status, method, cfg, directory):
    if not status.get("complete") or status.get("mode") != cfg["mode"]:
        raise ValueError(f"{method} is incomplete or belongs to a different run mode")
    if status.get("posterior_updates") is not False or status.get("model_weight_updates") is not False:
        raise ValueError(f"{method} does not declare fixed posterior/model weights")
    for field, expected in {"model": LABELS[method], "fit_rows": cfg["n_train"],
            "origins": cfg["origins"], "score_pairs": cfg["origins"] * cfg["H"]}.items():
        if status.get(field) != expected:
            raise ValueError(f"{method} status field {field} differs from the frozen protocol")
    if method in ("ridge", "rhs"):
        for field in ("outer_draws", "inner_paths"):
            if status.get(field) != cfg[field]:
                raise ValueError(f"{method} {field} differs from the frozen forecast budget")
    if cfg["mode"] == "full":
        if not status.get("benchmark_complete"):
            raise ValueError(f"{method} is not a completed benchmark")
        if method in ("ridge", "rhs") and not (status.get("qualified")
                and status.get("chains") == cfg["chains"] and diagnostic_gate(directory, cfg)):
            raise ValueError(f"{method} fails the three-chain frozen diagnostic gates")
        if method == "rhs" and status.get("reused"):
            raise ValueError("RHS must be run fresh")
        if method == "gp" and not status.get("native_checks_passed"):
            raise ValueError("GP native conditioning checks did not pass")
        if method == "gp":
            validate_gp_evidence(directory)
        if status.get("reused"):
            if status.get("input_sha256") != cfg["input_sha256"] or status.get("source_commit") != cfg["source_commit"]:
                raise ValueError("Reused baseline does not identify the frozen inputs and source revision")
        elif method in ("ridge", "rhs"):
            provenance = json.loads((Path(directory) / "provenance.json").read_text())
            saved = provenance["configuration"]
            fields = ["mode", "input_sha256", "source_commit", "washout", "fit_start", "fit_end", "n_train",
                "test_start", "test_end", "n_test", "first_origin", "last_origin", "origins", "H", "chains",
                "outer_draws", "inner_paths", "checkpoint_draws", "innovation_seed", "ridge_seed", "rhs_seed",
                "diagnostic_gates", "attempts", "washout_tolerance", "refit_per_origin", "update_model_weights"]
            for field in fields:
                if saved.get(field) != cfg[field]:
                    raise ValueError(f"{method} saved configuration differs in {field}")
            if not status.get("bank_id") or provenance.get("contract_id") != status.get("contract_id"):
                raise ValueError("Fresh model does not identify its bank and matching source contract")
            if method == "rhs":
                if saved.get("rhs_control") != cfg["rhs_control"]:
                    raise ValueError("RHS prior controls differ from the frozen comparison")
                control = saved.get("model_control", {})
                if any(control.get(k) != v for k, v in cfg["model_control"].items()) or set(control) - set(cfg["model_control"]) - {"proposal"}:
                    raise ValueError("Unexpected RHS architecture-move controls")
                if "proposal" in control:
                    adaptation = saved.get("training_proposal", {})
                    q = np.asarray(control["proposal"], dtype=float)
                    model_count = len(pd.read_csv(Path(directory) / "model_probabilities.csv"))
                    if (not adaptation.get("frozen_before_chain") or adaptation.get("test_outcomes_used") is not False
                            or adaptation.get("prior_or_likelihood_changed") is not False
                            or len(q) != model_count or not np.isfinite(q).all() or (q <= 0).any() or abs(q.sum() - 1) > 1e-10
                            or any(len(adaptation.get(k, "")) != 64 for k in ("source_file_sha256", "source_contract_id", "adapter_sha256"))):
                        raise ValueError("Changed proposal lacks the explicit frozen training-only provenance")
        else:
            if status.get("source_contract", {}).get("input_sha256") != cfg["input_sha256"]:
                raise ValueError("Fresh GP does not identify the frozen inputs")
            if status.get("julia_version") != "1.10.10" or status.get("autogp_revision") != "2ad372db2b8bea176e3b32a769bfb5d6cff80866":
                raise ValueError("Fresh GP revision/runtime differs from the pinned experiment")
    elif status.get("qualified") or status.get("benchmark_complete"):
        raise ValueError("Smoke output must never be marked benchmark-qualified")
    if method in ("ridge", "rhs") and status.get("innovation_seed") != cfg["innovation_seed"]:
        raise ValueError("Ridge and RHS must use the same frozen innovation bank")


def figures(scores, cfg, directory):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    colors = {"AutoDESN ridge": "#2365a3", "AutoDESN RHS": "#993f8d", "AutoGP": "#c46e1d"}
    labels = [x for x in colors if x in set(scores.model)]
    y = pd.read_csv(LEGACY / "input/C1.csv").y.to_numpy()
    plt.rcParams.update({"font.family": "DejaVu Sans", "axes.spines.top": False, "axes.spines.right": False})
    fig, axes = plt.subplots(len(labels), 1, figsize=(13, 3.1 * len(labels)), layout="constrained", squeeze=False)
    for ax, label in zip(axes[:, 0], labels):
        g = scores[(scores.model == label) & (scores.horizon == cfg["H"])]
        targets = np.arange(cfg["test_start"], cfg["test_end"] + 1)
        ax.plot(targets, y[targets - 1], color="#303846", lw=.8, label="Observed")
        ax.fill_between(g.target, g.lower90, g.upper90, color=colors[label], alpha=.18, label="90% interval")
        ax.fill_between(g.target, g.lower50, g.upper50, color=colors[label], alpha=.3, label="50% interval")
        ax.plot(g.target, g["mean"], color=colors[label], lw=1.2, label=f"{cfg['H']}-step mean")
        ax.set_title(label, loc="left"); ax.set_ylabel("Response"); ax.legend(ncol=4, frameon=False, fontsize=8)
    axes[-1, 0].set_xlabel(f"Target time; each forecast uses observed responses only through target − {cfg['H']}")
    fig.suptitle("C1: fixed posterior, rolling observed-state conditioning" if cfg["mode"] == "full"
        else "SMOKE TEST ONLY — short chains, not benchmark results", fontsize=14)
    fig.savefig(directory / "rolling_forecasts.png", dpi=160); plt.close(fig)
    leads = pd.read_csv(directory / "metrics_by_horizon.csv")
    fig, axes = plt.subplots(2, 2, figsize=(11, 7), layout="constrained")
    for ax, metric in zip(axes.flat, ("RMSE", "CRPS", "Coverage90", "Width90")):
        for label in labels:
            g = leads[leads.model == label]
            ax.plot(g.horizon, g[metric], color=colors[label], label=label)
        if metric == "Coverage90":
            ax.axhline(.9, color="#777", ls="--", lw=.8)
        ax.set_title(metric, loc="left"); ax.set_xlabel("Forecast lead"); ax.grid(alpha=.15)
    axes[0, 0].legend(frameon=False)
    fig.suptitle("C1 performance by lead" if cfg["mode"] == "full" else "SMOKE TEST ONLY — unqualified", fontsize=14)
    fig.savefig(directory / "performance_by_horizon.png", dpi=160); plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["full", "smoke"], default="full")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--no-plots", action="store_true")
    args = parser.parse_args(); cfg = configuration(args.mode)
    out = args.out or ROOT / "artifacts" / args.mode
    methods = ["ridge", "rhs", "gp"] if args.mode == "full" else ["ridge", "rhs"]
    scores = []; statuses = {}; audits = {}; evidence = {}; proposal_tuning = {}; started = time.perf_counter()
    for method in methods:
        d = out / method
        status = json.loads((d / "status.json").read_text())
        check_status(status, method, cfg, d)
        s = validate_scores(pd.read_csv(d / "scores.csv"), cfg, LABELS[method])
        if method in ("ridge", "rhs"):
            audits[method] = audit_paths(d, s, cfg)
            if not status.get("reused") and (d / "provenance.json").exists():
                saved = json.loads((d / "provenance.json").read_text())["configuration"]
                if "training_proposal" in saved:
                    proposal_tuning[method] = saved["training_proposal"]
        scores.append(s); statuses[method] = status
        files = ["status.json", "scores.csv"]
        if method in ("ridge", "rhs"):
            files += ["diagnostics.csv", "model_probabilities.csv"]
        else:
            files += [f"run_{run}/{name}" for run in (1, 2) for name in
                ("status.toml", "particles.csv", "native_checks.csv", "smc_progress.csv")]
        evidence[method] = {name: sha256(d / name) for name in files}
    all_scores = pd.concat(scores, ignore_index=True)
    if args.mode == "full":
        ridge_models = pd.read_csv(out / "ridge/model_probabilities.csv")
        rhs_models = pd.read_csv(out / "rhs/model_probabilities.csv")
        for field in ("model", "candidate", "D"):
            np.testing.assert_array_equal(ridge_models[field], rhs_models[field])
        np.testing.assert_allclose(ridge_models.prior_probability, rhs_models.prior_probability, rtol=0, atol=1e-13)
        if not statuses["ridge"].get("reused") and statuses["ridge"].get("bank_id") != statuses["rhs"].get("bank_id"):
            raise ValueError("Fresh ridge and RHS do not use the same frozen feature bank")
    summary = []; leads = []
    scopes = [("all leads, all test targets", all_scores), ("lead 1", all_scores[all_scores.horizon == 1]),
        (f"lead {cfg['H']}", all_scores[all_scores.horizon == cfg["H"]])]
    if cfg["mode"] == "full":
        scopes += [("targets 2501–2600", all_scores[all_scores.target <= 2600]),
                   ("targets 2601–3000", all_scores[all_scores.target > 2600])]
    for scope, data in scopes:
        for label, g in data.groupby("model", sort=False):
            summary.append(dict(scope=scope, model=label, **aggregate(g)))
    for (label, h), g in all_scores.groupby(["model", "horizon"], sort=False):
        leads.append(dict(model=label, horizon=int(h), **aggregate(g)))
    directory = out / "comparison"; directory.mkdir(parents=True, exist_ok=True)
    all_scores.to_csv(directory / "all_scores.csv.gz", index=False)
    pd.DataFrame(summary).to_csv(directory / "metrics.csv", index=False)
    pd.DataFrame(leads).to_csv(directory / "metrics_by_horizon.csv", index=False)
    sensitivity = []
    for method in methods:
        path = out / method / "mc_sensitivity.csv"
        if path.exists():
            frame = pd.read_csv(path)
            settings = {(o, n, k) for o in (2500, 2735, 2970) for n in (192, 384) for k in (4, 8, 16, 32)}
            if len(frame) != 720 or set(zip(frame.origin, frame.outer_draws, frame.inner_paths)) != settings:
                raise ValueError("MC sensitivity does not contain the frozen 24 settings")
            for (origin, n, k), g in frame.groupby(["origin", "outer_draws", "inner_paths"]):
                np.testing.assert_array_equal(g.horizon, np.arange(1, 31))
                np.testing.assert_array_equal(g.target, g.origin + g.horizon)
                sensitivity.append(dict(model=LABELS[method], reused=statuses[method].get("reused", False),
                    origin=int(origin), outer_draws=int(n), inner_paths=int(k), **aggregate(g)))
    if sensitivity:
        pd.DataFrame(sensitivity).to_csv(directory / "mc_sensitivity_summary.csv", index=False)
    if not args.no_plots:
        figures(all_scores, cfg, directory)
    result = dict(complete=True, benchmark_complete=args.mode == "full", qualified=args.mode == "full",
        mode=args.mode, models=[LABELS[m] for m in methods], origins=cfg["origins"], horizon=cfg["H"],
        pairs_per_model=cfg["origins"] * cfg["H"], input_sha256=cfg["input_sha256"],
        frozen_model_weights=True, common_innovation_seed=cfg["innovation_seed"], independent_path_audits=audits,
        training_only_proposal_tuning=proposal_tuning,
        source_evidence_sha256=evidence, model_status=statuses, aggregation_seconds=time.perf_counter() - started,
        aggregation_source_sha256={p.name: sha256(p) for p in (ROOT / "report.py", ROOT / "support.py")},
        interpretation="One previously selected synthetic C1 series. Overlapping origin/lead pairs are dependent; no independent-sample significance claim. Ridge/RHS differ only in readout prior and inference, with the same frozen feature bank and forecast protocol. Smoke outputs do not measure benchmark performance.")
    write_json(result, directory / "audit.json")
    print(pd.DataFrame(summary).query("scope == 'all leads, all test targets'").to_string(index=False))
    if args.mode == "smoke":
        print("SMOKE ONLY: pipeline verified; all performance numbers are unqualified.")


if __name__ == "__main__":
    main()
