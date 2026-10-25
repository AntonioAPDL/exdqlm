"""Verify archives, parents, every committed part and member before extraction."""
import argparse
import hashlib
import io
import json
import subprocess
import zipfile
from pathlib import Path, PurePosixPath


def restore(manifest, destination=None, seen=None, git_ref="HEAD"):
    seen = set() if seen is None else seen
    assert manifest.resolve() not in seen, "Cyclic archive ancestry"
    seen.add(manifest.resolve())
    m = json.loads(manifest.read_text())
    parent = m.get("parent_manifest")
    parent_record = None
    if parent:
        path = Path(parent["path"])
        assert hashlib.sha256(path.read_bytes()).hexdigest() == parent["sha256"]
        parent_record = restore(path, destination, seen, git_ref)
        newest = {r["path"] for r in m["members"]}
        inherited = {r["path"]: r for r in m["inherited_members"]}
        assert inherited == {p: r for p, r in parent_record["members"].items() if p not in newest}
    chunks = []
    for part in m["parts"]:
        path = Path(part["path"])
        assert not path.is_absolute() and ".." not in path.parts
        # Verified committed archives need not also occupy the working tree.
        b = path.read_bytes() if path.exists() else subprocess.check_output(
            ["git", "cat-file", "blob", f"{git_ref}:{path.as_posix()}"])
        assert len(b) == part["bytes"] and hashlib.sha256(b).hexdigest() == part["sha256"]
        chunks.append(b)
    b = b"".join(chunks)
    del chunks
    assert len(b) == m["archive_bytes"] and hashlib.sha256(b).hexdigest() == m["archive_sha256"]
    combined = {} if parent_record is None else parent_record["members"].copy()
    is_prefix = m.get("archive_complete") is False
    def accept(member, data):
        path = PurePosixPath(member["path"])
        assert not path.is_absolute() and ".." not in path.parts
        assert len(data) == member["bytes"] and hashlib.sha256(data).hexdigest() == member["sha256"]
        combined[member["path"]] = member
        if destination is not None:
            target = destination / member["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)

    if is_prefix:
        from recover_uploaded_archives import prefix_members
        recovered, stop = prefix_members(b)
        assert stop == m["prefix_stop"]
        assert [{k: row[k] for k in ("path", "bytes", "sha256")} for row, _ in recovered] == m["members"]
        for member, (_, data) in zip(m["members"], recovered):
            accept(member, data)
    else:
        with zipfile.ZipFile(io.BytesIO(b)) as z:
            assert z.testzip() is None
            assert set(z.namelist()) == {r["path"] for r in m["members"]}
            # Keep at most one decoded member instead of materializing every
            # old training trace at once while other bounded jobs run.
            for member in m["members"]:
                accept(member, z.read(member["path"]))
    return dict(members=combined, parts=len(m["parts"]) + (0 if parent_record is None else parent_record["parts"]),
                archives=1 + (0 if parent_record is None else parent_record["archives"]),
                prefix_archives=int(is_prefix) + (0 if parent_record is None else parent_record["prefix_archives"]))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("manifest", type=Path)
    p.add_argument("--destination", type=Path)
    p.add_argument("--git-ref", default="HEAD", help="Read omitted committed parts from this local Git revision; no network fetch")
    a = p.parse_args()
    if a.destination:
        assert not a.destination.exists() or not any(a.destination.iterdir()), "Use an empty destination"
    record = restore(a.manifest, a.destination, git_ref=a.git_ref)
    print(json.dumps(dict(complete=True, verified_parts=record["parts"], verified_members=len(record["members"]),
                         verified_archives=record["archives"], verified_prefix_archives=record["prefix_archives"],
                         all_archive_payloads_complete=record["prefix_archives"] == 0, extracted=a.destination is not None)))
