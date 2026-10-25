"""Independent ZIP writer plus truncation, corruption and path rejection."""
import io
import struct
import unittest
import zipfile
from recover_uploaded_archives import prefix_members


class StreamingBuffer(io.BytesIO):
    def seek(self, *args):
        raise io.UnsupportedOperation()


def fixture(names=("a/one.bin", "b/two.bin"), zip64=False, streaming=False):
    f = StreamingBuffer() if streaming else io.BytesIO()
    with zipfile.ZipFile(f, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for i, name in enumerate(names):
            if zip64:
                with z.open(name, "w", force_zip64=True) as out:
                    out.write(bytes(range(256)) * (i + 1))
            else:
                z.writestr(name, bytes(range(256)) * (i + 1))
    return f.getvalue()


class RecoveryTest(unittest.TestCase):
    def test_complete_and_zip64(self):
        for zip64 in (False, True):
            for streaming in (False, True):
                b = fixture(zip64=zip64, streaming=streaming)
                members, stop = prefix_members(b)
                self.assertEqual(len(members), 2)
                self.assertEqual(stop["reason"], "central_directory")
                with zipfile.ZipFile(io.BytesIO(b)) as z:
                    for meta, value in members:
                        self.assertEqual(value, z.read(meta["path"]))

    def test_every_truncation(self):
        for zip64 in (False, True):
            for streaming in (False, True):
                b = fixture(zip64=zip64, streaming=streaming)
                complete, _ = prefix_members(b)
                for end in range(len(b)):
                    m, _ = prefix_members(b[:end])
                    self.assertEqual(m, complete[:len(m)])
                    self.assertLessEqual(len(m), 2)

    def test_corrupt_crc_and_unsafe_paths(self):
        b = bytearray(fixture()); b[14] ^= 1
        with self.assertRaises(ValueError):
            prefix_members(b)
        for name in ("../bad", "/bad", "a/../bad", "a\\bad"):
            with self.assertRaises(ValueError):
                prefix_members(fixture((name,)))

    def test_descriptor_corruption_and_duplicate_rejected(self):
        b = bytearray(fixture(streaming=True))
        pos = b.index(b"PK\x07\x08")
        b[pos + 4] ^= 1
        with self.assertRaises(ValueError):
            prefix_members(b)
        with self.assertWarns(UserWarning):
            b = fixture(("a", "a"))
        with self.assertRaises(ValueError):
            prefix_members(b)


if __name__ == "__main__":
    unittest.main()
