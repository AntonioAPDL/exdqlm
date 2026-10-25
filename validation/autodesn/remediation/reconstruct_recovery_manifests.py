"""Reconstruct independently replayable manifests, explicitly retaining loss.

These are new manifests from Git identities/ZIP CRC verified recovered bytes.
Their SHA256 is not claimed to match either unavailable original manifest.
"""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path('validation/autodesn/remediation')
inventory = json.loads((root/'evidence/environment_loss_recovery_inventory.json').read_text())
parent = root/'evidence/checkpoints/remediation_checkpoint_004.manifest.json'
for label, observation in [('remediation_checkpoint_005', 'archive005_recovery.json'), ('remediation_checkpoint_006', 'archive006_prefix_recovery.json')]:
    prior = json.loads(parent.read_text())
    previous = {r['path']: r for r in prior.get('inherited_members', []) + prior['members']}
    recovered = json.loads((root/'evidence'/observation).read_text())
    archive = next(a for a in inventory['archives'] if a['label'] == label)
    parts = []
    digest = hashlib.sha256()
    total = 0
    for row in archive['entries']:
        value = subprocess.check_output(['git', 'cat-file', 'blob', row['sha']])
        assert hashlib.sha1(b'blob '+str(len(value)).encode()+b'\0'+value).hexdigest() == row['sha']
        digest.update(value); total += len(value)
        parts.append(dict(path=row['path'], bytes=len(value), sha256=hashlib.sha256(value).hexdigest()))
    assert total == recovered['uploaded_prefix_bytes']
    assert digest.hexdigest() == recovered['uploaded_prefix_sha256']
    members = [{k: r[k] for k in ['path', 'bytes', 'sha256']} for r in recovered['members']]
    new = {r['path'] for r in members}
    manifest = dict(label=label+'_recovered', archive_bytes=total, archive_sha256=digest.hexdigest(), archive_complete=archive['parts_complete'], original_expected_archive_bytes=archive['expected_bytes'], parts=parts, members=members, inherited_members=[r for p, r in previous.items() if p not in new], parent_manifest=dict(path=str(parent), sha256=hashlib.sha256(parent.read_bytes()).hexdigest()), original_manifest_recovered=False, reconstruction_observation=str(root/'evidence'/observation), posterior_qualified=False, scope='New reconstruction manifest from previously uploaded Git blobs and verified complete ZIP entries; incomplete archive006 remains explicitly incomplete and excludes its truncated trace4 payload.')
    if not archive['parts_complete']:
        manifest['prefix_stop'] = recovered['stop']
    target = root/'evidence/checkpoints'/(label+'_recovered.manifest.json')
    if target.exists():
        assert json.loads(target.read_text()) == manifest
    else:
        target.write_text(json.dumps(manifest, indent=2)+'\n')
    print(json.dumps(dict(path=str(target), complete_payload=archive['parts_complete'], members=len(members))))
    parent = target
