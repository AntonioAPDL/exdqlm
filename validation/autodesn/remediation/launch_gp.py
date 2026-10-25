"""Run one observed, immutable, same-prior native AutoGP experiment.

--period-moves 0 isolates the larger-budget native sampler before adding the
registered invariant proposal. Every invocation gets a fresh output directory.
"""
import argparse
import hashlib
import gzip
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from contextlib import nullcontext
from large_job import single_large_job

p = argparse.ArgumentParser()
p.add_argument('--rows', type=int, choices=[128, 256, 512, 2000], default=2000)
p.add_argument('--particles', type=int, choices=[8, 16, 32, 64], default=16)
p.add_argument('--seed', type=int, required=True)
p.add_argument('--period-moves', type=int, choices=[0, 10], default=0)
p.add_argument('--snapshot')
p.add_argument('--julia', type=Path, required=True)
p.add_argument('--project', type=Path, required=True)
p.add_argument('--depot', type=Path, required=True)
a = p.parse_args()
root = Path('validation/autodesn/remediation')
files = [root/'gp_run.jl', root/'gp_moves.jl', root/'artifacts/gp_training_proposal.toml', Path(__file__),root/'large_job.py',root/'run_process.py']
manifest = {str(f): hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
key = a.snapshot or hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
snapshot = root/'artifacts/gp_sources'/key
if a.snapshot:
    manifest = json.loads((snapshot/'manifest.json').read_text())
else:
    snapshot.mkdir(parents=True, exist_ok=True)
    for f in files:
        target = snapshot/f.name
        if target.exists():
            assert hashlib.sha256(target.read_bytes()).hexdigest() == manifest[str(f)]
        else:
            shutil.copyfile(f, target)
            target.chmod(0o444)
    (snapshot/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
for name, sha in manifest.items():
    assert hashlib.sha256((snapshot/Path(name).name).read_bytes()).hexdigest() == sha
label = f'gp_n{a.rows}_p{a.particles}_s{a.seed}'+('_native' if a.period_moves == 0 else '')
out = root/'artifacts'/label
assert not out.exists() or not any(out.iterdir()), 'Use a fresh seed; do not append old stages'
record = root/'evidence'/f'{label}_resources.json'
assert not record.exists(), 'Preserve existing invocation evidence'
env = os.environ.copy()
env.pop('LD_LIBRARY_PATH', None)
env.update(JULIA_DEPOT_PATH=str(a.depot.resolve()), JULIA_NUM_THREADS='2',
           OPENBLAS_NUM_THREADS='1', OMP_NUM_THREADS='1',
           AUTOGP_FROZEN_PROPOSAL=str((snapshot/'gp_training_proposal.toml').resolve()))
cmd = [sys.executable, str(root/'run_process.py'), '--record', str(record),
       '--log', str(root/'artifacts'/f'{label}.log'), '--max-seconds', '7200',
       '--max-cgroup-anon-bytes', '6100000000', str(a.julia.resolve()),
       '--startup-file=no', '--project='+str(a.project.resolve()),
       str(snapshot/'gp_run.jl'), str(a.rows), str(a.particles), str(a.seed), str(a.period_moves)]
print(json.dumps(dict(snapshot=key, rows=a.rows, particles=a.particles,
                      seed=a.seed, period_moves=a.period_moves)), flush=True)
reservation=single_large_job(root,label) if a.rows>=512 or a.particles>=32 else nullcontext()
with reservation:
    code = subprocess.call(cmd, env=env)
    # Preserve the complete, explicitly whitelisted inference log even on a
    # failed/capped calculation. Compression keeps log-bundle transport small.
    console = root/'artifacts'/f'{label}.log'
    if console.exists():
        out.mkdir(parents=True, exist_ok=True)
        temporary = out/'inference.log.gz.writing'
        with console.open('rb') as source, temporary.open('wb') as destination:
            with gzip.GzipFile(filename='', mode='wb', fileobj=destination, mtime=0) as zipped:
                shutil.copyfileobj(source, zipped)
        with gzip.open(temporary, 'rb') as verified:
            while verified.read(65536):
                pass
        os.replace(temporary, out/'inference.log.gz')
    raise SystemExit(code)
