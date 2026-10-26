#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location("verify_release", Path(__file__).with_name("verify-release.py"))
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class ReleasePrivacyTests(unittest.TestCase):
    def check_archive(self, name, data, rejected):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "release.zip"
            with zipfile.ZipFile(archive, "w") as output:
                output.writestr(name, data)
            if rejected:
                with self.assertRaises(ValueError):
                    verifier.verify(archive)
            else:
                verifier.verify(archive)

    def test_clean_bundle(self):
        self.check_archive("QuotaBar.app/Contents/MacOS/QuotaBar", b"/source/QuotaBar/main.swift", False)

    def test_private_paths_all_encodings(self):
        for path in ("/Users/example/project", "/private/var/folders/build", "/var/folders/build", "/tmp/build", "/private/tmp/build"):
            for encoding in ("utf-8", "utf-16-le", "utf-16-be"):
                with self.subTest(path=path, encoding=encoding):
                    self.check_archive("app/binary", path.encode(encoding), True)

    def test_apple_metadata(self):
        for name in ("__MACOSX/app", "app/._binary"):
            self.check_archive(name, b"metadata", True)
        self.check_archive("app/binary", b"com.apple.provenance", True)

    def test_unsafe_archive_names(self):
        for name in ("/absolute", "../outside", "app/../outside"):
            self.check_archive(name, b"data", True)

    def test_private_key(self):
        self.check_archive("app/config", b"-----BEGIN PRIVATE KEY-----", True)


unittest.main()
