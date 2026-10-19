#!/usr/bin/env python3
"""Bundle the Studio place, source, tests and Swedish instructions."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

from build_place import ROOT, build


def package() -> Path:
    place = ROOT / "artifacts/Molnfiskarna-Prototype.rbxlx"
    build(place)
    output = ROOT / "artifacts/Molnfiskarna-Prototype.zip"
    files = [ROOT / "README.md", ROOT / ".gitignore"]
    for folder in ("src", "docs", "tools", "tests"):
        files.extend(path for path in (ROOT / folder).rglob("*")
                     if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc")
    with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
        archive.write(place, "Molnfiskarna-Prototype.rbxlx")
        for path in sorted(files):
            archive.write(path, path.relative_to(ROOT).as_posix())
    return output


if __name__ == "__main__":
    print(f"Packaged {package()}")
