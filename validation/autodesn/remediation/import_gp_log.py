"""Verify an explicit GP log bundle before extracting into a fresh directory."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import zipfile


def decode(log, seed, expected_commit, destination=None):
    begin = re.findall(r'AUTODESN_GP_EXPORT_BEGIN (\d+) (\d+) ([0-9a-f]{64})\s*$', log, re.M)
    end = re.findall(r'AUTODESN_GP_EXPORT_END (\d+) ([0-9a-f]{64})\s*$', log, re.M)
    assert len(begin) == len(end) == 1 and int(begin[0][0]) == int(end[0][0]) == seed
    assert begin[0][2] == end[0][1] and int(begin[0][1]) <= 25_000_000
    parts = re.findall(r'AUTODESN_GP_EXPORT_PART (\d+) (\d+) ([A-Za-z0-9+/=]+)\s*$', log, re.M)
    assert parts and all(int(p[0]) == seed for p in parts)
    assert [int(p[1]) for p in parts] == list(range(len(parts)))
    data = base64.b64decode(''.join(p[2] for p in parts), validate=True)
    assert len(data) == int(begin[0][1]) and hashlib.sha256(data).hexdigest() == begin[0][2]
    with zipfile.ZipFile(io.BytesIO(data)) as bundle:
        manifest = json.loads(bundle.read('remote_execution_manifest.json'))
        assert manifest['seed'] == seed and manifest['checkout_sha'] == expected_commit
        assert manifest['native_pin'] == '2ad372db2b8bea176e3b32a769bfb5d6cff80866'
        members = manifest['members']
        assert sum(m['bytes'] for m in members) <= 20_000_000
        names = {m['path'] for m in members} | {'remote_execution_manifest.json'}
        assert len(bundle.namelist()) == len(names) and set(bundle.namelist()) == names
        for member in members:
            path = PurePosixPath(member['path'])
            assert not path.is_absolute() and '..' not in path.parts
            assert path.parts[:3] == ('validation', 'autodesn', 'remediation')
            content = bundle.read(member['path'])
            assert len(content) == member['bytes'] and hashlib.sha256(content).hexdigest() == member['sha256']
        if destination is not None:
            assert not destination.exists(), 'Never overwrite an earlier imported run'
            destination.mkdir(parents=True)
            for name in names:
                target = destination / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(bundle.read(name))
    return dict(verified=True, seed=seed, checkout_sha=expected_commit, bundle_sha256=begin[0][2],
                members=len(members), posterior_qualified=False, extracted=destination is not None)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('log', type=Path)
    parser.add_argument('--seed', type=int, required=True)
    parser.add_argument('--expected-commit', required=True)
    parser.add_argument('--destination', type=Path)
    args = parser.parse_args()
    print(json.dumps(decode(args.log.read_text(), args.seed, args.expected_commit, args.destination)))
