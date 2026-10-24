"""Verify archives, parents, every committed part and member before extraction."""
import argparse
import hashlib
import io
import json
import zipfile
from pathlib import Path, PurePosixPath


def restore(manifest, destination=None, seen=None):
    seen = set() if seen is None else seen
    assert manifest.resolve() not in seen, "Cyclic archive ancestry"
    seen.add(manifest.resolve())
    m = json.loads(manifest.read_text())
    parent = m.get("parent_manifest")
    parent_record = None
    if parent:
        path = Path(parent["path"])
        assert hashlib.sha256(path.read_bytes()).hexdigest() == parent["sha256"]
        parent_record = restore(path, destination, seen)
        newest = {r["path"] for r in m["members"]}
        inherited = {r["path"]: r for r in m["inherited_members"]}
        assert inherited == {p: r for p, r in parent_record["members"].items() if p not in newest}
    chunks = []
    for part in m["parts"]:
        b = Path(part["path"]).read_bytes()
        assert len(b) == part["bytes"] and hashlib.sha256(b).hexdigest() == part["sha256"]
        chunks.append(b)
    b = b"".join(chunks)
    assert len(b) == m["archive_bytes"] and hashlib.sha256(b).hexdigest() == m["archive_sha256"]
    combined = {} if parent_record is None else parent_record["members"].copy()
    with zipfile.ZipFile(io.BytesIO(b)) as z:
        assert z.testzip() is None
        assert set(z.namelist()) == {r["path"] for r in m["members"]}
        for member in m["members"]:
            path = PurePosixPath(member["path"])
            assert not path.is_absolute() and ".." not in path.parts
            data = z.read(member["path"])
            assert len(data) == member["bytes"] and hashlib.sha256(data).hexdigest() == member["sha256"]
            combined[member["path"]] = member
            if destination is not None:
                target = destination / member["path"]
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
    return dict(members=combined, parts=len(m["parts"]) + (0 if parent_record is None else parent_record["parts"]),
                archives=1 + (0 if parent_record is None else parent_record["archives"]))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("manifest", type=Path)
    p.add_argument("--destination", type=Path)
    a = p.parse_args()
    if a.destination:
        assert not a.destination.exists() or not any(a.destination.iterdir()), "Use an empty destination"
    record = restore(a.manifest, a.destination)
    print(json.dumps(dict(complete=True, verified_parts=record["parts"], verified_members=len(record["members"]),
                         verified_archives=record["archives"], extracted=a.destination is not None)))
