"""Run the pinned original Julia AutoGP study in an isolated output workspace."""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import tomllib

import pandas as pd

from support import ROOT, LEGACY, configuration, sha256, validate_scores, validate_gp_evidence, write_json

LEGACY_CODE = ROOT.parent / "c1_comparison"

REVISION = "2ad372db2b8bea176e3b32a769bfb5d6cff80866"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True, help="Pinned authors' AutoGP.jl checkout")
    parser.add_argument("--julia", default="julia")
    parser.add_argument("--out", type=Path, default=ROOT / "artifacts")
    args = parser.parse_args(); cfg = configuration()
    julia_version = subprocess.check_output([args.julia, "--startup-file=no", "-e", "print(VERSION)"], text=True).strip()
    if julia_version != "1.10.10":
        raise ValueError(f"The frozen GP protocol requires Julia 1.10.10; found {julia_version}")
    revision = subprocess.check_output(["git", "-C", str(args.project), "rev-parse", "HEAD"], text=True).strip()
    if revision != REVISION:
        raise ValueError(f"AutoGP must use pinned revision {REVISION}; found {revision}")
    dirty = subprocess.check_output(["git", "-C", str(args.project), "status", "--porcelain", "--untracked-files=no"], text=True)
    if dirty.strip():
        raise ValueError("The pinned AutoGP source checkout has tracked modifications")
    out = args.out.resolve(); d = out / "gp"; d.mkdir(parents=True, exist_ok=True)
    if (d / "status.json").exists() and json.loads((d / "status.json").read_text()).get("reused"):
        raise ValueError("Use another output directory for fresh GP; cached baseline already exists here")
    source_files = [LEGACY_CODE / "run_autogp.jl", LEGACY / "configuration.toml",
        LEGACY_CODE / "scoring.py", LEGACY_CODE / "report.py", Path(__file__).resolve()]
    contract = dict(autogp_revision=revision, input_sha256=cfg["input_sha256"],
        source_sha256={str(p.relative_to(ROOT.parent.parent.parent)): sha256(p) for p in source_files})
    contract_path = d / "contract.json"
    if contract_path.exists() and json.loads(contract_path.read_text()) != contract:
        raise ValueError("GP checkpoint contract changed; use another output directory")
    write_json(contract, contract_path)
    workspace = out / "gp_workspace"
    isolated = workspace / "validation/autodesn/c1_comparison"
    (isolated / "input").mkdir(parents=True, exist_ok=True)
    (isolated / "artifacts").mkdir(exist_ok=True)
    shutil.copy2(LEGACY / "configuration.toml", isolated / "configuration.toml")
    shutil.copy2(ROOT / "input/series.csv", isolated / "input/C1.csv")
    link = isolated / "artifacts/gp"
    if not link.exists():
        link.symlink_to(d, target_is_directory=True)
    if link.resolve() != d:
        raise ValueError("Unexpected GP output link")
    env = os.environ.copy(); env.update(JULIA_NUM_THREADS="1", OPENBLAS_NUM_THREADS="2", OMP_NUM_THREADS="2")
    started = time.perf_counter()
    command = [args.julia, "--startup-file=no", f"--project={args.project.resolve()}", str(LEGACY_CODE / "run_autogp.jl")]
    with (d / "native_launcher.log").open("a") as log:
        native = subprocess.Popen(command,cwd=workspace,env=env,stdout=log,stderr=subprocess.STDOUT)
        _, wait_status, usage = os.wait4(native.pid,0)
        native.returncode = os.waitstatus_to_exitcode(wait_status)
        write_json(dict(complete=True,exit_code=native.returncode,
            native_peak_rss_kib=usage.ru_maxrss,user_seconds=usage.ru_utime,
            system_seconds=usage.ru_stime,
            scope='Native Julia training plus export and conditioning contracts; Linux wait4 child rusage'),
            d/'native_resources.json')
        if native.returncode:
            raise subprocess.CalledProcessError(native.returncode,command)
    native_seconds = time.perf_counter() - started
    native_audit = validate_gp_evidence(d)
    # Reuse the independently checked, exact Gaussian-mixture conditioning and
    # scoring adapter without calling its ARIMA/DESN comparison entry point.
    sys.path.insert(0, str(LEGACY_CODE))
    spec = importlib.util.spec_from_file_location("frozen_c1_report", LEGACY_CODE / "report.py")
    adapter = importlib.util.module_from_spec(spec); spec.loader.exec_module(adapter)
    adapter.ART = out; adapter.OUT = d
    begun = time.perf_counter()
    scores, statuses = adapter.gp_forecasts(pd.read_csv(ROOT / "input/series.csv").y.to_numpy())
    rolling_seconds = time.perf_counter() - begun
    scores = validate_scores(scores, cfg, "AutoGP"); scores.to_csv(d / "scores.csv", index=False)
    train_seconds = sum(float(pd.read_csv(d / f"run_{k}/smc_progress.csv").iloc[-1].elapsed) for k in (1, 2))
    result = dict(complete=True, benchmark_complete=True, mode="full", method="gp", model="AutoGP", reused=False,
        fit_rows=2000, origins=471, score_pairs=14130, posterior_updates=False, model_weight_updates=False,
        native_checks_passed=True, native_evidence_audit=native_audit,
        autogp_revision=revision, julia_version=julia_version, smc_runs=statuses, source_contract=contract,
        timings=dict(smc_training_seconds_sum=train_seconds, native_launcher_seconds_this_invocation=native_seconds,
            rolling_conditioning_scoring_seconds=rolling_seconds),
        timing_note="SMC training sums the final completed-run callback times, retained when a completed posterior is reused. Abandoned fitting attempts are excluded. Native launcher measures this invocation, including startup, export and conditioning checks. Rolling timer includes Python conditioning, scores and sensitivity export.")
    write_json(result, d / "status.json")


if __name__ == "__main__":
    main()
