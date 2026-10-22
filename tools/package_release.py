#!/usr/bin/env python3
"""Bundle the Studio place, source, tests and Swedish instructions."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

from build_place import ROOT, PLACE_NAME, build


def package() -> Path:
    place = ROOT / "artifacts" / PLACE_NAME
    build(place)
    output = ROOT / "artifacts/Cloud-Anglers-v1.0.zip"
    files = [ROOT / "README.md", ROOT / ".gitignore"]
    for folder in ("src", "docs", "tools", "tests"):
        files.extend(path for path in (ROOT / folder).rglob("*")
                     if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc")
    with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
        archive.write(place, PLACE_NAME)
        for path in sorted(files):
            archive.write(path, path.relative_to(ROOT).as_posix())
    return output


if __name__ == "__main__":
    print(f"Packaged {package()}")
