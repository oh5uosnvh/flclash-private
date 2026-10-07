#!/usr/bin/env python3
"""Fail CI unless every private-protocol marker is linked into the built core."""

from __future__ import annotations

import io
import pathlib
import sys
import zipfile

MARKERS = {
    b"x365: invalid response magic": "x365",
    b"Chrome/120.0.0.0 Safari/537.36": "x365 official XHTTP User-Agent",
    b"xhttp: response magic not found": "Blackstone type=xhttp",
    b"#viewTurbo": "ViewTurbo trigger",
    b"2n6LtY0nIPV2": "ViewTurbo auth",
    b"sing-anytls/0.0.11": "Shanlian AnyTLS client/session compatibility",
    b"oppa: peer certificate hash mismatch": "oppa outbound (NekoBoxYF oppa)",
}


def candidates(path: pathlib.Path):
    if path.is_file():
        yield path.name, path.read_bytes()
        if path.suffix.lower() in {".zip", ".apk"}:
            try:
                with zipfile.ZipFile(path) as archive:
                    for name in archive.namelist():
                        lower = name.lower()
                        if lower.endswith((".so", ".exe", ".dll", ".zip", ".apk")):
                            data = archive.read(name)
                            yield f"{path.name}!{name}", data
                            if lower.endswith((".zip", ".apk")):
                                try:
                                    with zipfile.ZipFile(io.BytesIO(data)) as nested:
                                        for nested_name in nested.namelist():
                                            if nested_name.lower().endswith((".so", ".exe", ".dll")):
                                                yield f"{path.name}!{name}!{nested_name}", nested.read(nested_name)
                                except zipfile.BadZipFile:
                                    pass
            except zipfile.BadZipFile:
                pass


def main() -> int:
    roots = [pathlib.Path(value) for value in sys.argv[1:]] or [pathlib.Path("dist")]
    blobs: list[tuple[str, bytes]] = []
    for root in roots:
        if root.is_file():
            blobs.extend(candidates(root))
        elif root.exists():
            for path in root.rglob("*"):
                if path.is_file():
                    blobs.extend(candidates(path))
    found = {marker: [] for marker in MARKERS}
    for name, data in blobs:
        for marker in MARKERS:
            if marker in data:
                found[marker].append(name)
    print(f"scanned {len(blobs)} files/embedded binaries")
    missing = []
    for marker, label in MARKERS.items():
        locations = found[marker]
        if locations:
            print(f"PASS {label}: {locations[0]}")
        else:
            print(f"FAIL {label}: marker {marker!r} absent", file=sys.stderr)
            missing.append(label)
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
