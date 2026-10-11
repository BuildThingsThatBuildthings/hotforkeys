#!/usr/bin/env python3
"""Package local macOS builds without credentials, launching, or installation."""

import argparse
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import subprocess
import tempfile
import zipfile


APP_NAME = "HotForKeys.app"
PROJECT_ROOT = Path(__file__).resolve().parent.parent
ZIP_DATE = (1980, 1, 1, 0, 0, 0)


def verify_bundle(app):
    subprocess.run(
        ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)],
        check=True,
    )


def extract_archive(archive, destination):
    """Extract content and executable modes only into a fresh private directory."""
    destination = Path(destination)
    if any(destination.iterdir()):
        raise ValueError("Extraction directory must be empty")
    with zipfile.ZipFile(archive) as source:
        seen = set()
        for entry in source.infolist():
            path = PurePosixPath(entry.filename)
            kind = stat.S_IFMT(entry.external_attr >> 16)
            if (path.is_absolute() or ".." in path.parts or not path.parts
                    or path.parts[0] != APP_NAME or entry.filename in seen
                    or kind not in (stat.S_IFDIR, stat.S_IFREG)):
                raise ValueError(f"Unexpected archive entry: {entry.filename}")
            seen.add(entry.filename)
            target = destination.joinpath(*path.parts)
            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                target.chmod(0o755)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read(entry))
                target.chmod(0o755 if entry.external_attr >> 16 & 0o111 else 0o644)
    app = destination / APP_NAME
    verify_bundle(app)
    return app


def create_archive(binary, output):
    """Sign the complete staged bundle, archive it, then verify a fresh extraction."""
    binary, output = Path(binary).resolve(), Path(output).resolve()
    if not binary.is_file():
        raise ValueError(f"Missing release executable: {binary}")
    if binary == output:
        raise ValueError("Archive output cannot replace the executable")
    # /tmp is deliberately outside Documents/Desktop file-provider locations.
    # Only new files are created; source metadata and security attributes are untouched.
    with tempfile.TemporaryDirectory(prefix="hotforkeys-package-", dir="/tmp") as work:
        work = Path(work)
        app = work / APP_NAME
        (app / "Contents/MacOS").mkdir(parents=True)
        (app / "Contents/Resources").mkdir()
        executable = app / "Contents/MacOS/HotForKeys"
        shutil.copyfile(binary, executable)
        executable.chmod(0o755)
        shutil.copyfile(PROJECT_ROOT / "Resources/Info.plist", app / "Contents/Info.plist")
        (app / "Contents/PkgInfo").write_bytes(b"APPL????")
        subprocess.run(
            ["/usr/bin/codesign", "--force", "--sign", "-", "--timestamp=none", str(app)],
            check=True,
        )
        verify_bundle(app)

        staged_archive = work / "HotForKeys-local.zip"
        with zipfile.ZipFile(staged_archive, "w", compression=zipfile.ZIP_DEFLATED,
                             compresslevel=9) as archive:
            for path in sorted([app, *app.rglob("*")]):
                name = path.relative_to(work).as_posix()
                is_dir = path.is_dir()
                info = zipfile.ZipInfo(name + ("/" if is_dir else ""), ZIP_DATE)
                info.create_system = 3
                mode = stat.S_IFDIR | 0o755 if is_dir else stat.S_IFREG | (
                    0o755 if path.stat().st_mode & 0o111 else 0o644)
                info.external_attr = mode << 16 | (0x10 if is_dir else 0)
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, b"" if is_dir else path.read_bytes(), compresslevel=9)

        with tempfile.TemporaryDirectory(prefix="hotforkeys-verify-", dir="/tmp") as check:
            extract_archive(staged_archive, check)
        output.parent.mkdir(parents=True, exist_ok=True)
        # The delivered archive contains no filesystem metadata or variable timestamps.
        with tempfile.NamedTemporaryFile(prefix=".hotforkeys-", dir=output.parent,
                                         delete=False) as delivered:
            temporary_output = Path(delivered.name)
        try:
            shutil.copyfile(staged_archive, temporary_output)
            os.replace(temporary_output, output)
        finally:
            temporary_output.unlink(missing_ok=True)
        # Verify bytes read back from the delivery location, not just the staged ZIP.
        with tempfile.TemporaryDirectory(prefix="hotforkeys-delivery-", dir="/tmp") as check:
            extract_archive(output, check)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    package = commands.add_parser("package", help="Create a verified ad-hoc development archive")
    package.add_argument("binary", type=Path)
    package.add_argument("--output", type=Path, default=PROJECT_ROOT / "HotForKeys-local.zip")
    extract = commands.add_parser("extract", help="Extract to a new private /tmp location and verify")
    extract.add_argument("archive", type=Path)
    args = parser.parse_args()
    if args.command == "package":
        print(create_archive(args.binary, args.output))
    else:
        destination = Path(tempfile.mkdtemp(prefix="hotforkeys-local-", dir="/tmp"))
        try:
            app = extract_archive(args.archive, destination)
        except Exception:
            shutil.rmtree(destination)
            raise
        # Kept for an explicitly authorized manual evaluation; never opened here.
        print(app)


if __name__ == "__main__":
    main()
