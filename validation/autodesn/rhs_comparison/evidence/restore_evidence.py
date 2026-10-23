"""Reassemble the numeric evidence and verify every internal SHA256 entry."""
from pathlib import Path
import hashlib, json, zipfile
root=Path(__file__).resolve().parent
archive=root/"C1_numeric_evidence.zip"
parts=sorted(root.glob("C1_numeric_evidence.zip.part-*"))
assert len(parts)==2, "Both committed archive parts are required"
with archive.open("wb") as w:
    for part in parts:
        w.write(part.read_bytes())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    manifest=json.loads(z.read("SHA256.json"))
    for name, expected in manifest.items():
        assert hashlib.sha256(z.read(name)).hexdigest()==expected, name
print("Verified",len(manifest),"evidence files in",archive)
