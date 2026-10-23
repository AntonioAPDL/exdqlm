"""Import only the audited, frozen ridge and AutoGP outputs; RHS is always fresh."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import tomllib

import pandas as pd

from support import ROOT, LABELS, configuration, diagnostic_gate, sha256, validate_scores, validate_gp_evidence, write_json


def import_one(source, out, method, cfg):
    provenance = json.loads((source / "provenance.json").read_text())
    if provenance["source_commit"] != cfg["source_commit"]:
        raise ValueError("Cached baseline source revision differs from frozen C1")
    overall = json.loads((source / "comparison/audit.json").read_text())
    if not (overall["complete"] and overall["native_gp_checks"] and overall["frozen_model_weights"]):
        raise ValueError("Cached comparison did not pass its original audit")
    required = [source / "provenance.json", source / "comparison/audit.json"]
    status = dict(complete=True, benchmark_complete=True, mode="full", method=method,
        model=LABELS[method], reused=True, source_commit=provenance["source_commit"],
        origins=cfg["origins"], score_pairs=cfg["origins"] * cfg["H"], fit_rows=cfg["n_train"],
        posterior_updates=False, model_weight_updates=False)
    copies = {}
    if method == "ridge":
        d = source / "desn"
        original = json.loads((d / "status.json").read_text())
        if not (original["complete"] and original["qualified"] and diagnostic_gate(d, cfg)):
            raise ValueError("Cached ridge chain diagnostics do not pass the frozen gates")
        for field, expected in {"fit_rows": cfg["n_train"], "origins": cfg["origins"],
                "outer_draws": cfg["outer_draws"], "inner_paths": cfg["inner_paths"]}.items():
            if original.get(field) != expected:
                raise ValueError(f"Cached ridge {field} differs from the frozen protocol")
        scores = pd.read_csv(d / "scores.csv"); scores["model"] = LABELS[method]
        required += [d / "scores.csv", d / "status.json", d / "diagnostics.csv", d / "model_probabilities.csv",
            d / "cross_language_score_audit.json", d / "specification_audit.csv", d / "session.txt"]
        for name in ("diagnostics.csv", "model_probabilities.csv", "specification_audit.csv", "session.txt", "mc_sensitivity.csv"):
            required.append(d / name)
            copies[d / name] = name
        for origin in (2500, 2735, 2970):
            path = d / f"forecast_samples_{origin}.csv.gz"
            required.append(path); copies[path] = f"paths_{origin}.csv.gz"
        status.update(qualified=True, diagnostic_gates_passed=True, chains=3,
            innovation_seed=cfg["innovation_seed"], outer_draws=cfg["outer_draws"], inner_paths=cfg["inner_paths"],
            timings=dict(original_combined_elapsed_seconds=original["elapsed_seconds"],
                feature_build_seconds=None, inference_seconds=None, forecast_seconds=None),
            timing_note="Reused old run. Its single elapsed timer includes feature construction, sampling, forecasts and MC sensitivity; separate phase times were not recorded.")
        status["original_status"] = original
    else:
        validate_gp_evidence(source / "gp")
        file = source / "comparison/all_scores.csv.gz"
        scores = pd.read_csv(file); scores = scores[scores.model == "AutoGP"].copy()
        required.append(file); statuses = []; train_seconds = 0
        for run in (1, 2):
            d = source / "gp" / f"run_{run}"
            s = tomllib.loads((d / "status.toml").read_text())
            if not (s["complete"] and s["fixed_weights"] and s["fit_rows"] == 2000
                    and s["n_particles"] == 8 and s["n_future"] == 500
                    and s["seed"] == 1166019 + run):
                raise ValueError("Cached AutoGP run does not satisfy the frozen protocol")
            checks = pd.read_csv(d / "native_checks.csv")
            if checks.mean_max_error.max() >= 1e-5 or checks.covariance_max_error.max() >= 1e-5:
                raise ValueError("Cached AutoGP native conditioning check failed")
            progress = pd.read_csv(d / "smc_progress.csv")
            train_seconds += float(progress.iloc[-1].elapsed); statuses.append(s)
            for name in ("status.toml", "particles.csv", "native_checks.csv", "smc_progress.csv"):
                required.append(d / name); copies[d / name] = f"run_{run}/{name}"
        status.update(native_checks_passed=True, autogp_revision="2ad372db2b8bea176e3b32a769bfb5d6cff80866",
            smc_runs=statuses, timings=dict(smc_training_seconds_sum=train_seconds,
                native_run_elapsed_seconds_sum=sum(s["elapsed_seconds"] for s in statuses),
                rolling_forecast_seconds=None),
            timing_note="Reused original GP training and native export timers. The old combined comparison timer cannot isolate GP rolling forecasts.")
    scores = validate_scores(scores, cfg, LABELS[method])
    manifest = {str(p.relative_to(source)): sha256(p) for p in sorted(set(required))}
    d = out / method
    old = d / "status.json"
    if old.exists():
        previous = json.loads(old.read_text())
        old_manifest = previous.get("cached_source_sha256", {})
        if not (previous.get("reused") and old_manifest
                and all(manifest.get(name) == value for name, value in old_manifest.items())):
            raise ValueError(f"Refusing to overwrite a different/fresh result: {d}")
        if old_manifest == manifest:
            print(f"{method}: identical frozen import already present")
            return
        # A later importer may add another original evidence file, such as the
        # existing MC sensitivity table. Every previously imported hash must agree.
    if (d / "contract.rds").exists():
        raise ValueError(f"Refusing to replace in-progress fresh inference: {d}")
    d.mkdir(parents=True, exist_ok=True)
    for path, name in copies.items():
        target = d / name; target.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(path, target)
    scores.to_csv(d / "scores.csv", index=False)
    status.update(cached_source_directory=str(source.resolve()), cached_source_sha256=manifest,
        input_sha256=cfg["input_sha256"])
    write_json(status, old)
    print(f"{method}: imported {len(scores)} validated score pairs; reused=true")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--from", dest="source", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=ROOT / "artifacts/full")
    parser.add_argument("--methods", nargs="+", choices=["ridge", "gp"], default=["ridge", "gp"])
    args = parser.parse_args(); cfg = configuration()
    for method in args.methods:
        import_one(args.source, args.out, method, cfg)


if __name__ == "__main__":
    main()
