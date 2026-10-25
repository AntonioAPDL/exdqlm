"""Pinned standard-public-runner GP job and storage-free numeric log export.

The export whitelist contains only this run's numerical outputs and resource
record. This script never prints environment variables or credentials.
"""
import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile

ROOT = Path('validation/autodesn/remediation')
PIN = '2ad372db2b8bea176e3b32a769bfb5d6cff80866'
JULIA_SHA = '6a78a03a71c7ab792e8673dc5cedb918e037f081ceb58b50971dfb7c64c5bf81'


def sha(path):
    return hashlib.file_digest(open(path, 'rb'), 'sha256').hexdigest()


def prepare(runtime):
    assert platform.machine() == 'x86_64' and sys.platform == 'linux'
    runtime.mkdir(parents=True, exist_ok=True)
    archive = runtime / 'julia.tar.gz'
    urllib.request.urlretrieve('https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.10-linux-x86_64.tar.gz', archive)
    assert sha(archive) == JULIA_SHA
    with tarfile.open(archive) as bundle:
        bundle.extractall(runtime, filter='data')
    project = runtime / 'AutoGP.jl'
    subprocess.run(['git', 'clone', '--no-checkout', 'https://github.com/probsys/AutoGP.jl.git', str(project)], check=True)
    subprocess.run(['git', '-C', str(project), 'checkout', '--detach', PIN], check=True)
    assert subprocess.check_output(['git', '-C', str(project), 'rev-parse', 'HEAD'], text=True).strip() == PIN
    frozen = ROOT / 'native_gp_environment'
    for name in ('Project.toml', 'Manifest.toml'):
        shutil.copyfile(frozen / name, project / name)
    (ROOT / 'artifacts').mkdir(exist_ok=True)
    shutil.copyfile(frozen / 'gp_training_proposal.toml', ROOT / 'artifacts/gp_training_proposal.toml')
    env = dict(os.environ, JULIA_DEPOT_PATH=str((runtime / 'depot').resolve()),
               JULIA_NUM_PRECOMPILE_TASKS='2', OPENBLAS_NUM_THREADS='1', OMP_NUM_THREADS='1')
    env.pop('LD_LIBRARY_PATH', None)
    subprocess.run([str(runtime / 'julia-1.10.10/bin/julia'), '--startup-file=no',
                    '--project=' + str(project), '-e', 'using Pkg; Pkg.instantiate(); Pkg.precompile()'], env=env, check=True)
    for name in ('Project.toml', 'Manifest.toml'):
        assert sha(frozen / name) == sha(project / name), 'Dependency resolution changed the pinned environment'


def export(seed, output=None):
    label = f'gp_n2000_p16_s{seed}_native'
    paths = sorted((ROOT / 'artifacts' / label).glob('*'))
    paths += sorted((ROOT / 'evidence').glob(label + '_resources.json'))
    paths += sorted((ROOT / 'artifacts/gp_sources').glob('*/manifest.json'))
    paths += [p for p in (ROOT / 'artifacts/gp_sources').glob('*/*') if p.is_file() and p.suffix in ('.jl', '.py', '.toml')]
    # No depot, environment dump, credentials, arbitrary logs or other jobs.
    paths = sorted(set(p for p in paths if p.is_file() and not p.name.endswith('.partial')))
    assert sum(p.stat().st_size for p in paths) <= 20_000_000
    manifest = dict(seed=seed, particles=16, rows=2000, native_pin=PIN,
                    checkout_sha=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                    host=dict(platform=platform.platform(), cpu_count=os.cpu_count(),
                              cpu_model=next((s.split(':', 1)[1].strip() for s in Path('/proc/cpuinfo').read_text().splitlines() if s.startswith('model name')), 'unknown')),
                    members=[dict(path=str(p), bytes=p.stat().st_size, sha256=sha(p)) for p in paths],
                    posterior_qualified=False, hardware_comparison_controlled=False)
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', zipfile.ZIP_DEFLATED) as bundle:
        for p in paths:
            bundle.write(p, str(p))
        bundle.writestr('remote_execution_manifest.json', json.dumps(manifest, indent=2) + '\n')
    data = buffer.getvalue()
    if output is not None:
        output.write_bytes(data)
    digest = hashlib.sha256(data).hexdigest()
    encoded = base64.b64encode(data).decode()
    print(f'AUTODESN_GP_EXPORT_BEGIN {seed} {len(data)} {digest}', flush=True)
    for index, start in enumerate(range(0, len(encoded), 12000)):
        print(f'AUTODESN_GP_EXPORT_PART {seed} {index} {encoded[start:start+12000]}', flush=True)
    print(f'AUTODESN_GP_EXPORT_END {seed} {digest}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['prepare', 'export'])
    parser.add_argument('--runtime', type=Path)
    parser.add_argument('--seed', type=int, choices=range(7366021, 7366025))
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.operation == 'prepare':
        assert args.runtime is not None
        prepare(args.runtime.resolve())
    else:
        assert args.seed is not None
        export(args.seed, args.output)
