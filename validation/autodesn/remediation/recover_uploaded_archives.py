"""Recover only verified complete ZIP members from uploaded Git blob prefixes.

This does not recreate the unavailable original member/SHA256 manifest and never
calls an incomplete archive complete. For streaming deflate entries, the actual
deflate EOF locates the descriptor; its CRC and both lengths must then agree.
"""
import argparse
import binascii
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import struct
import subprocess
import zipfile
import zlib


def safe_name(name):
    p = PurePosixPath(name)
    if not name or "\\" in name or p.is_absolute() or ".." in p.parts or str(p) != name:
        raise ValueError("Unsafe or noncanonical member path")
    return p


def prefix_members(data):
    """Return CRC-verified complete local entries and the exact stopping reason."""
    offset = 0
    members = []
    seen = set()
    while offset < len(data):
        if len(data) - offset < 4:
            return members, dict(offset=offset, reason="truncated_signature")
        sig = struct.unpack_from("<I", data, offset)[0]
        if sig in (0x02014B50, 0x06054B50, 0x06064B50):
            return members, dict(offset=offset, reason="central_directory")
        if sig != 0x04034B50:
            raise ValueError("Invalid local ZIP signature at " + str(offset))
        if len(data) - offset < 30:
            return members, dict(offset=offset, reason="truncated_header")
        _, _, flags, method, _, _, crc, compressed, size, nlen, xlen = struct.unpack_from("<IHHHHHIIIHH", data, offset)
        if flags & 1 or method not in (0, 8) or (flags & 8 and method != 8):
            raise ValueError("Encrypted or unsupported ZIP member")
        descriptor64 = size == 0xFFFFFFFF or compressed == 0xFFFFFFFF
        begin = offset + 30 + nlen + xlen
        if begin > len(data):
            return members, dict(offset=offset, reason="truncated_name_or_extra")
        name = data[offset + 30:offset + 30 + nlen].decode("utf-8" if flags & 2048 else "cp437")
        safe_name(name)
        if name in seen:
            raise ValueError("Duplicate member")
        extra = data[offset + 30 + nlen:begin]
        if size == 0xFFFFFFFF or compressed == 0xFFFFFFFF:
            pos = 0
            found = False
            while pos + 4 <= len(extra):
                tag, length = struct.unpack_from("<HH", extra, pos)
                value = extra[pos + 4:pos + 4 + length]
                if len(value) != length:
                    raise ValueError("Truncated extra field")
                if tag == 1:
                    needed = 8 * ((size == 0xFFFFFFFF) + (compressed == 0xFFFFFFFF))
                    if len(value) < needed:
                        raise ValueError("Truncated ZIP64 sizes")
                    p = 0
                    if size == 0xFFFFFFFF:
                        size = struct.unpack_from("<Q", value, p)[0]; p += 8
                    if compressed == 0xFFFFFFFF:
                        compressed = struct.unpack_from("<Q", value, p)[0]
                    found = True
                pos += 4 + length
            if not found:
                raise ValueError("Missing ZIP64 sizes")
        if flags & 8:
            decoder = zlib.decompressobj(-15)
            value = decoder.decompress(data[begin:], 1024**3 + 1)
            if len(value) > 1024**3 or decoder.unconsumed_tail:
                raise ValueError("Member exceeds recovery memory bound")
            if not decoder.eof:
                return members, dict(offset=offset, reason="truncated_deflate_payload", member=name)
            compressed = len(data) - begin - len(decoder.unused_data)
            size = len(value)
            calculated_crc = binascii.crc32(value) & 0xFFFFFFFF
            end = begin + compressed
            length = 20 if descriptor64 else 12
            candidates = []
            for skip in (0, 4):
                if skip and data[end:end + 4] != b"PK\x07\x08":
                    continue
                if len(data) - end < skip + length:
                    continue
                values = struct.unpack_from("<IQQ" if descriptor64 else "<III", data, end + skip)
                if values == (calculated_crc, compressed, size):
                    candidates.append(end + skip + length)
            if not candidates:
                if len(data) - end < length + 4:
                    return members, dict(offset=offset, reason="truncated_descriptor", member=name)
                raise ValueError("ZIP descriptor CRC or length disagreement: " + name)
            if len(candidates) != 1:
                raise ValueError("Ambiguous ZIP descriptor")
            seen.add(name)
            members.append((dict(path=name, bytes=size, sha256=hashlib.sha256(value).hexdigest(), local_header_offset=offset), value))
            offset = candidates[0]
            continue
        end = begin + compressed
        if end > len(data):
            return members, dict(offset=offset, reason="truncated_payload", member=name, available=len(data)-begin, required=compressed)
        if size > 1024**3:
            raise ValueError("Member exceeds recovery memory bound")
        payload = data[begin:end]
        if method == 8:
            decoder = zlib.decompressobj(-15)
            value = decoder.decompress(payload, size + 1)
            if not decoder.eof or decoder.unused_data or decoder.unconsumed_tail:
                raise ValueError("Invalid or oversized deflate payload")
        else:
            value = payload
        if len(value) != size or binascii.crc32(value) & 0xFFFFFFFF != crc:
            raise ValueError("ZIP size or CRC disagreement: " + name)
        seen.add(name)
        members.append((dict(path=name, bytes=size, sha256=hashlib.sha256(value).hexdigest(), local_header_offset=offset), value))
        offset = end
    return members, dict(offset=offset, reason="prefix_ends_at_member_boundary")


def read_parts(entries):
    chunks = []
    for e in entries:
        b = subprocess.check_output(["git", "cat-file", "blob", e["sha"]])
        actual = hashlib.sha1(b"blob " + str(len(b)).encode() + b"\0" + b).hexdigest()
        if actual != e["sha"]:
            raise ValueError("Git blob identity disagreement")
        chunks.append(b)
    return b"".join(chunks)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("inventory", type=Path)
    p.add_argument("label", choices=["remediation_checkpoint_005", "remediation_checkpoint_006"])
    p.add_argument("destination", type=Path)
    p.add_argument("--record", type=Path, required=True)
    a = p.parse_args()
    inventory = json.loads(a.inventory.read_text())
    archive = next(x for x in inventory["archives"] if x["label"] == a.label)
    assert not a.destination.exists() or not any(a.destination.iterdir()), "Use empty destination"
    data = read_parts(archive["entries"])
    members, stop = prefix_members(data)
    if archive["parts_complete"]:
        assert len(data) == archive["expected_bytes"]
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            assert z.testzip() is None
            assert z.namelist() == [x[0]["path"] for x in members]
            for meta, value in members:
                assert z.read(meta["path"]) == value
    for meta, value in members:
        target = a.destination.joinpath(*safe_name(meta["path"]).parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(value)
        assert hashlib.sha256(target.read_bytes()).hexdigest() == meta["sha256"]
    result = dict(archive=a.label, archive_complete=archive["parts_complete"], verified_git_parts=len(archive["entries"]), uploaded_prefix_bytes=len(data), uploaded_prefix_sha256=hashlib.sha256(data).hexdigest(), recovered_complete_members=len(members), stop=stop, members=[m for m, _ in members], original_member_manifest_recovered=False, scope="Git identity and ZIP local-header/deflate/CRC verified recovery; newly computed SHA256 values, not the unavailable original manifest")
    a.record.parent.mkdir(parents=True, exist_ok=True)
    a.record.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k:v for k,v in result.items() if k != "members"}))


if __name__ == "__main__":
    main()
