#!/usr/bin/env python3
"""Reject local build paths and filesystem metadata before publishing an archive."""
import sys
import zipfile

FORBIDDEN = ("/Users/", "/private/var/folders/", "/var/folders/", "/private/tmp/", "/tmp/", "com.apple.provenance", "-----BEGIN PRIVATE KEY-----", "-----BEGIN RSA PRIVATE KEY-----")


def verify(path):
    with zipfile.ZipFile(path) as archive:
        for item in archive.infolist():
            parts = item.filename.split("/")
            if item.filename.startswith("/") or ".." in parts or "__MACOSX" in parts or any(p.startswith("._") for p in parts):
                raise ValueError("Archive contains unsafe paths or AppleDouble metadata")
            data = archive.read(item)
            for marker in FORBIDDEN:
                if any(marker.encode(encoding) in data for encoding in ("utf-8", "utf-16-le", "utf-16-be")):
                    raise ValueError("Archive contains private paths or sensitive metadata")


if __name__ == "__main__":
    try:
        verify(sys.argv[1])
    except (ValueError, zipfile.BadZipFile) as error:
        sys.exit(str(error))
    print("Release privacy verification passed")
