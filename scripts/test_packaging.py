#!/usr/bin/env python3
"""Exercise real signatures and archive delivery without running the app."""

import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

import package


class PackagingTests(unittest.TestCase):
    def test_same_executable_produces_identical_archives(self):
        with tempfile.TemporaryDirectory(prefix="hotforkeys-repeat-", dir="/tmp") as folder:
            first, second = Path(folder) / "first.zip", Path(folder) / "second.zip"
            package.create_archive(self.binary, first)
            package.create_archive(self.binary, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            self.assertEqual(first.read_bytes(), self.delivered.read_bytes())
            print("Deterministic archive SHA-256:", hashlib.sha256(first.read_bytes()).hexdigest())

    def test_delivered_archive_verifies_and_detects_plist_tampering(self):
        with tempfile.TemporaryDirectory(prefix="hotforkeys-delivery-test-", dir="/tmp") as folder:
            app = package.extract_archive(self.delivered, folder)
            self.assertTrue((app / "Contents/_CodeSignature/CodeResources").is_file())
            self.assertEqual((app / "Contents/MacOS/HotForKeys").stat().st_mode & 0o777, 0o755)
            plist = app / "Contents/Info.plist"
            plist.write_bytes(plist.read_bytes() + b"\n")
            result = subprocess.run(
                ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)],
                text=True, capture_output=True,
            )
            self.assertNotEqual(result.returncode, 0, "Changed Info.plist must invalidate the seal")
            self.assertIn("Info.plist", result.stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--archive", required=True, type=Path)
    args = parser.parse_args()
    PackagingTests.binary = args.binary.resolve()
    PackagingTests.delivered = args.archive.resolve()
    unittest.main(argv=[__file__], verbosity=2)
