import contextlib
import io
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

from sb_packer import main, pack_file


class PackerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)

    def assert_container(self, output, source, payload):
        data = output.read_bytes()
        magic, version, name_size, size = struct.unpack("<4sHHQ", data[:16])
        self.assertEqual((magic, version, size), (b"SBIN", 1, len(payload)))
        self.assertEqual(data[16:16 + name_size].decode("utf-8"), source.name)
        self.assertEqual(data[16 + name_size:], payload)
        self.assertEqual(output.parent, source.parent)
        self.assertEqual(source.read_bytes(), payload)

    def test_unicode_filename_and_text(self):
        source = self.folder / "한글 이름 🐍.txt"
        payload = "원본 내용\r\n둘째 줄\x00".encode("utf-8")
        source.write_bytes(payload)
        output = pack_file(source)
        self.assertEqual(output.name, source.name + ".sb")
        self.assert_container(output, source, payload)

    def test_empty_file_without_extension(self):
        source = self.folder / "empty"
        source.touch()
        self.assert_container(pack_file(source), source, b"")

    def test_binary_spanning_multiple_chunks(self):
        source = self.folder / "model.bin"
        payload = bytes(range(256)) * 10001
        source.write_bytes(payload)
        self.assert_container(pack_file(source), source, payload)

    def test_existing_results_are_preserved(self):
        source = self.folder / "sample.sb"
        source.write_bytes(b"source")
        first = pack_file(source)
        existing = self.folder / "sample.sb (1).sb"
        existing.write_bytes(b"keep this")
        output = pack_file(source)
        self.assertEqual(output.name, "sample.sb (2).sb")
        self.assertEqual(existing.read_bytes(), b"keep this")
        self.assert_container(first, source, b"source")
        self.assert_container(output, source, b"source")

    def test_folder_and_missing_file_are_rejected(self):
        for path in (self.folder, self.folder / "missing.txt"):
            with self.assertRaises(ValueError):
                pack_file(path)
        self.assertEqual(list(self.folder.iterdir()), [])

    def test_failed_write_removes_only_partial_output(self):
        source = self.folder / "data.txt"
        source.write_bytes(b"original")
        existing = self.folder / "data.txt.sb"
        existing.write_bytes(b"existing")
        with patch("sb_packer.copy_payload", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                pack_file(source)
        self.assertEqual(source.read_bytes(), b"original")
        self.assertEqual(existing.read_bytes(), b"existing")
        self.assertFalse((self.folder / "data.txt (1).sb").exists())

    def test_batch_continues_after_invalid_path(self):
        source = self.folder / "ok.dat"
        source.write_bytes(b"ok")
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            code = main([str(self.folder / "missing"), str(source)])
        self.assertEqual(code, 1)
        self.assert_container(self.folder / "ok.dat.sb", source, b"ok")


if __name__ == "__main__":
    unittest.main()
