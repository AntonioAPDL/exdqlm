"""Rebuild the lost NHS training bank under its frozen original builder."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from large_job import single_large_job

root = Path('validation/autodesn/remediation').resolve()
snapshot = root/'artifacts/frozen_bank_builder'
manifest = json.loads((snapshot/'source_manifest.json').read_text())
assert manifest['revision'] == 'fea371fbfa73c425a6f98407095194c1e8098a24'
for path, sha in manifest['files'].items():
    source = snapshot/path
    assert hashlib.sha256(source.read_bytes()).hexdigest() == sha
    source.chmod(0o444)
out = Path('validation/autodesn/nonlinear_heteroscedastic/artifacts').resolve()
attempt = 1
while (root/'evidence'/f'bank_rebuild_{attempt}_resources.json').exists() or (root/'artifacts'/f'bank_rebuild_{attempt}.log').exists():
    attempt += 1
record = root/'evidence'/f'bank_rebuild_{attempt}_resources.json'
log = root/'artifacts'/f'bank_rebuild_{attempt}.log'
invocation = dict(source_manifest_sha256=hashlib.sha256((snapshot/'source_manifest.json').read_bytes()).hexdigest(), frozen_revision=manifest['revision'], output=str(out), stage='build', test_data_used=False, source_files=len(manifest['files']), launcher_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
with single_large_job(root, 'frozen original bank reconstruction'):
    (root/'evidence'/f'bank_rebuild_{attempt}_invocation.json').write_text(json.dumps(invocation, indent=2)+'\n')
    cmd = [sys.executable, str(root/'run_process.py'), '--record', str(record), '--log', str(log), '--max-seconds', '3600', '--max-cgroup-anon-bytes', '6100000000', 'Rscript', '--vanilla', 'validation/autodesn/nonlinear_heteroscedastic/run.R', '--stage', 'build', '--out', str(out)]
    raise SystemExit(subprocess.call(cmd, cwd=snapshot, env=os.environ.copy()))
