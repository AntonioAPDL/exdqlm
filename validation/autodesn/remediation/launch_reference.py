"""Immutable, resource-capped launcher for conditional posterior references."""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("name", choices=["local_reference", "grouped_reference", "local_joint_reference"])
a = p.parse_args()
root = Path("validation/autodesn/remediation")
driver = root / (a.name + ".R")
files = sorted(Path("R").glob("*.R")) + [Path("src/autodesn_rhs.cpp"), driver]
manifest = {str(f): hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
key = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
snapshot = root / "artifacts/reference_sources" / key
for f in files:
    target = snapshot / f
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        assert hashlib.sha256(target.read_bytes()).hexdigest() == manifest[str(f)]
    else:
        shutil.copyfile(f, target)
        target.chmod(0o444)
(snapshot / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
record = root / "evidence" / (a.name + "_resources.json")
assert not record.exists(), "Preserve previous evidence; choose an explicit new experiment identity."
env = os.environ.copy()
env["AUTODESN_SOURCE_SNAPSHOT"] = str(snapshot.resolve())
command = [sys.executable, str(root / "run_process.py"), "--record", str(record),
           "--log", str(root / "artifacts" / (a.name + ".log")), "--max-seconds", "1800",
           "Rscript", "--vanilla", str(snapshot / driver)]
print(json.dumps(dict(snapshot=key, name=a.name)), flush=True)
raise SystemExit(subprocess.call(command, env=env))
