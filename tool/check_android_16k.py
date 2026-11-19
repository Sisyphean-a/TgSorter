#!/usr/bin/env python3
"""Check every 64-bit ELF in an Android APK, plus the APK's ZIP alignment."""
import argparse
import struct
import subprocess
import sys
import zipfile
from pathlib import Path

PAGE = 16 * 1024
ABIS = {"arm64-v8a", "x86_64"}


def aligned(data):
    if len(data) < 64 or data[:6] != b"\x7fELF\x02\x01":
        return False
    offset = struct.unpack_from("<Q", data, 32)[0]
    size, count = struct.unpack_from("<HH", data, 54)
    if size < 56 or offset + size * count > len(data):
        return False
    loads = 0
    for i in range(count):
        head = offset + i * size
        if struct.unpack_from("<I", data, head)[0] != 1:
            continue
        loads += 1
        file_offset, address = struct.unpack_from("<QQ", data, head + 8)
        boundary = struct.unpack_from("<Q", data, head + 48)[0]
        if boundary < PAGE or (address - file_offset) % PAGE:
            return False
    return loads > 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--zipalign", default="zipalign")
    args = parser.parse_args()
    if args.artifact.suffix == ".so":
        if not aligned(args.artifact.read_bytes()):
            sys.exit(f"16 KB ELF check failed: {args.artifact}")
        print(f"16 KB ELF check passed: {args.artifact}")
        return
    with zipfile.ZipFile(args.artifact) as apk:
        entries = [n for n in apk.namelist()
                   if len(n.split("/")) == 3 and n.startswith("lib/")
                   and n.split("/")[1] in ABIS and n.endswith(".so")]
        if "lib/arm64-v8a/libtdjson.so" not in entries:
            sys.exit("APK missing arm64-v8a/libtdjson.so")
        errors = [n for n in entries if not aligned(apk.read(n))]
    if errors:
        sys.exit("16 KB ELF check failed:\n" + "\n".join(errors))
    subprocess.run([args.zipalign, "-c", "-P", "16", "4", str(args.artifact)], check=True)
    print(f"APK ZIP and {len(entries)} ELF files passed 16 KB alignment")


if __name__ == "__main__":
    main()
