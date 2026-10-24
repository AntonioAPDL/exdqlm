"""Independent normalized-prior integration versus public grouped-RHS chains."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd

root = Path("validation/autodesn/remediation")
sys.path.insert(0, str(root.parent / "standardized_rhs"))
from diagnostics import diagnostics

parser = argparse.ArgumentParser()
parser.add_argument("--learned-local", action="store_true")
args = parser.parse_args()
label = "local" if args.learned_local else "grouped"
reference = pd.read_csv(root / f"evidence/{label}_prior_integration.csv")
directory = root / f"artifacts/{label}_reference"
status = json.loads((directory / "status.json").read_text())
assert status["complete"] and status["chains"] == 4
chains = [pd.read_csv(directory / f"trace_{k}.csv") for k in range(1, 5)]
locals_ = [pd.read_csv(directory / f"locals_{k}.csv") for k in range(1, 5)] if args.learned_local else None
for c in chains:
    c["intercept_squared"] = c.intercept ** 2
    c["model_2"] = (c.model == 2).astype(float)
    c["period_2"] = (c.period_index == 2).astype(float)
    c["joint_2_2"] = c.model_2 * c.period_2
rows = []
for r in reference.itertuples():
    source = locals_ if r.quantity.startswith("log_local_") else chains
    x = np.array([c[r.quantity].to_numpy() for c in source])
    diagnostic = diagnostics(x)
    n = x.shape[1]
    size = int(np.sqrt(n))
    count = n // size
    batches = np.concatenate([v[:count * size].reshape(count, size).mean(1) for v in x])
    mcse = float(batches.std(ddof=1) / np.sqrt(len(batches)))
    estimate = float(x.mean())
    tolerance = 7 * np.hypot(mcse, r.reference_mcse) + 2 * r.refinement_difference + 1e-4
    rows.append(dict(quantity=r.quantity, reference=r.reference, estimate=estimate,
                     absolute_error=abs(estimate - r.reference), batch_mcse=mcse,
                     tolerance=tolerance, moment_passed=abs(estimate - r.reference) < tolerance,
                     **diagnostic))
table = pd.DataFrame(rows)
table.to_csv(root / f"evidence/{label}_mcmc_reference_checks.csv", index=False)
passed = bool(table.moment_passed.all() and (table.rhat <= 1.01).all()
              and (table.bulk_ess >= 400).all() and (table.tail_ess >= 400).all())
record = dict(complete=True, passed=passed, chains=4, retained_per_chain=24000,
              joint_functionals=len(rows), maximum_rhat=float(table.rhat.max()),
              minimum_bulk_ess=float(table.bulk_ess.min()), minimum_tail_ess=float(table.tail_ess.min()),
              moments_passed=bool(table.moment_passed.all()),
              source_status_sha256=hashlib.sha256((directory / "status.json").read_bytes()).hexdigest(),
              chain_sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in directory.glob("chain_*.rds")},
              scope=("Learned-local conditional grouped-RHS with exact additional local-scale independence moves; " if args.learned_local else "Fixed-local conditional grouped-RHS; ") + "learned independent globals, shared slab, proper calendar, unknown noise, variable readout dimension and nonuniform architecture/period proposals; not recursive SBC or production convergence",
              production_qualified=False)
(root / f"evidence/{label}_mcmc_reference.json").write_text(json.dumps(record, indent=2) + "\n")
print(table.to_string(index=False))
print(json.dumps(record))
if not passed:
    raise SystemExit(1)
