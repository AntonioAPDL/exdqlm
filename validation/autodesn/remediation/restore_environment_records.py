"""Read frozen runtime records without extracting the 304 MB NHS archive.

Only touched parts and selected members are verified. This is deliberately not
a claim that the full archive's SHA256 was checked by this selective operation.
"""
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

root = Path('validation/autodesn/nonlinear_heteroscedastic/evidence')
manifest = json.loads((root/'archive_manifest.json').read_text())
work = Path('validation/autodesn/remediation/artifacts/environment_restore')
work.mkdir(parents=True, exist_ok=True)
archive = work/'selective_sparse.zip'
offsets = []
position = 0
for part in manifest['parts']:
    offsets.append(position)
    position += part['bytes']
assert position == manifest['archive_bytes']
loaded = set()
with archive.open('w+b') as output:
    output.truncate(position)

    def load(index):
        if index in loaded:
            return
        part = manifest['parts'][index]
        path = (root/part['name']).as_posix()
        data = subprocess.check_output(['git', 'cat-file', 'blob', 'HEAD:'+path])
        assert len(data) == part['bytes']
        assert hashlib.sha256(data).hexdigest() == part['sha256']
        output.seek(offsets[index]); output.write(data); output.flush()
        loaded.add(index)

    load(len(offsets)-1)
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        desired = [n for n in names if PurePosixPath(n).name in {
            'conda_explicit.txt', 'R_environment.txt', 'R_packages.csv',
            'manual_dependency_sources.json', 'Python_environment.json',
            'Julia_runtime.json', 'hardware.json', 'Project.toml', 'Manifest.toml',
            'SHA256.json'}]
        assert 'SHA256.json' in desired
        for name in desired:
            entry = z.getinfo(name)
            begin, end = entry.header_offset, entry.header_offset+entry.compress_size+len(entry.filename.encode())+len(entry.extra)+1024
            for i, start in enumerate(offsets):
                if start < end and start+manifest['parts'][i]['bytes'] > begin:
                    load(i)
        hashes = json.loads(z.read('SHA256.json'))
        records = []
        for name in desired:
            path = PurePosixPath(name)
            assert not path.is_absolute() and '..' not in path.parts
            data = z.read(name)
            sha = hashlib.sha256(data).hexdigest()
            if name != 'SHA256.json':
                assert hashes[name] == sha
            target = root/'restored'/name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            records.append(dict(path=str(target), sha256=sha, bytes=len(data)))
record = dict(complete=True, selected_members=records, verified_parts=[manifest['parts'][i] for i in sorted(loaded)], full_archive_sha256_checked=False, scope='Selected frozen runtime members against internal SHA256 manifest, ZIP CRC and touched committed-part hashes')
target = Path('validation/autodesn/remediation/evidence/environment_records_recovery.json')
target.write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(dict(complete=True, selected_members=len(records), verified_parts=len(loaded))))
