#!/usr/bin/env python3
"""Run the existing project checks with official standalone Luau and Python.

The full run captures the production world once and shares it between geometry
and streamed-material checks. --quick omits art/world/UI geometry checks.
These are source, analytic-geometry and event-double checks, not Roblox playtests.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
PROTOCOL_CHECKS = (
    "check_startup.py", "check_fishing_service.py", "check_fishing_client.py",
    "check_profile_store.py", "check_save_lifecycle.py", "check_fishing_flow.py",
)
PRESENTATION_CHECKS = (
    "check_travel.py", "check_portal_interface.py", "check_fishing_audio.py",
    "check_fishing_presentation.py", "check_catch_cinematic.py",
    "check_fish_models.py", "check_fishing_interface.py", "check_aquarium.py",
    "check_residents.py", "check_signs.py",
)


def executable(value: str) -> str:
    found = shutil.which(value)
    if not found:
        raise argparse.ArgumentTypeError(f"Executable not found: {value}")
    return str(Path(found).resolve())


def source_digest() -> str:
    """Identify the checked sources without relying on a clean Git worktree."""
    digest = hashlib.sha256()
    for directory in ("src", "tests", "tools"):
        for path in sorted((ROOT / directory).rglob("*")):
            if path.suffix not in (".luau", ".py", ".json") or "__pycache__" in path.parts:
                continue
            digest.update(path.relative_to(ROOT).as_posix().encode() + b"\0")
            digest.update(path.read_bytes() + b"\0")
    return digest.hexdigest()


def run_check(label: str, command: list[str], timeout: int) -> dict:
    started = time.monotonic()
    print(f"Checking {label}...", flush=True)
    # POSIX process ownership also covers nested Luau children on a timeout.
    environment = dict(os.environ, PYTHONUTF8="1", PYTHONIOENCODING="utf-8")
    timed_out = False
    exit_code = None
    # File-backed output avoids a Windows reader thread waiting indefinitely
    # on a pipe inherited by a nested Luau child after its parent has exited.
    with tempfile.TemporaryFile() as captured:
        try:
            process = subprocess.Popen(command, cwd=ROOT, stdout=captured,
                                       stderr=subprocess.STDOUT, env=environment,
                                       start_new_session=os.name == "posix")
        except OSError as error:
            output = f"Could not start check: {error}"
        else:
            try:
                process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                if os.name == "posix":
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                else:
                    # Best effort for the owned checker and its Luau children;
                    # native Windows tree termination is not tested here.
                    try:
                        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                       timeout=10, check=False)
                    except (OSError, subprocess.TimeoutExpired):
                        pass
                    if process.poll() is None:
                        process.kill()
                process.wait(timeout=5)
            exit_code = process.returncode
            captured.seek(0)
            output = captured.read().decode("utf-8", errors="replace")
    passed = exit_code == 0 and not timed_out
    elapsed = round(time.monotonic() - started, 3)
    print(f"{'PASS' if passed else 'FAIL'} {label} ({elapsed:.2f}s)", flush=True)
    if not passed:
        print(output, flush=True)
        if timed_out:
            print(f"Exceeded the {timeout}-second check deadline.", flush=True)
    return {"name": label, "command": command, "passed": passed,
            "exit_code": exit_code, "timed_out": timed_out,
            "elapsed_seconds": elapsed, "output": output}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True, type=executable)
    parser.add_argument("--compiler", type=executable,
                        help="Defaults to luau-compile next to the Luau executable or on PATH")
    parser.add_argument("--quick", action="store_true", help="Only compile, pure rules, export and protocol/save checks")
    parser.add_argument("--timeout", type=int, default=300, help="Maximum seconds per check (default 300)")
    parser.add_argument("--report", type=Path, help="Optional JSON report outside the checked source folders")
    args = parser.parse_args()
    if args.timeout < 1:
        parser.error("--timeout must be positive")
    if args.report:
        report_path = args.report.resolve()
        checked_roots = [ROOT / name for name in ("src", "tests", "tools")]
        if report_path.suffix.lower() != ".json":
            parser.error("--report requires a .json filename")
        if report_path == ROOT / "WORK_LOG.json" or any(report_path.is_relative_to(path) for path in checked_roots):
            parser.error("--report must not overwrite checked sources or the active work ledger")
    compiler = args.compiler
    if compiler is None:
        candidate = Path(args.luau).with_name("luau-compile" + Path(args.luau).suffix)
        try:
            compiler = executable(str(candidate) if candidate.is_file() else "luau-compile")
        except argparse.ArgumentTypeError as error:
            parser.error(str(error))

    initial_digest = source_digest()
    results = []
    report = {"started_utc": datetime.now(timezone.utc).isoformat(),
              "scope": "quick" if args.quick else "full", "source_sha256": initial_digest,
              "native_roblox_tested": False, "checks": results}

    def check(label: str, command: list[str]) -> bool:
        result = run_check(label, command, args.timeout)
        results.append(result)
        return result["passed"]

    def python_check(name: str, *arguments: str) -> bool:
        return check(name, [sys.executable, str(ROOT / "tools" / name), *arguments])

    sources = sorted((ROOT / "src").rglob("*.luau"))
    suites = sorted((ROOT / "tests").glob("*.luau"))
    check(f"compile {len(sources)} production files and {len(suites)} suites",
          [compiler, "--null", *map(str, sources), *map(str, suites)])
    check("Python place export tests", [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v"])
    for suite in suites:
        check(suite.name, [args.luau, str(suite)])
    for name in PROTOCOL_CHECKS:
        python_check(name, "--luau", args.luau)
    if not args.quick:
        for name in PRESENTATION_CHECKS:
            python_check(name, "--luau", args.luau)
        with tempfile.TemporaryDirectory(prefix="cloud-anglers-check-") as temporary:
            capture = str(Path(temporary) / "world.json")
            captured = python_check("preview_world.py", "--luau", args.luau, "--output", capture)
            if captured:
                python_check("check_world.py", capture)
                python_check("check_details.py", capture)
                python_check("check_world_craft.py", capture, "--mutations")
                python_check("check_scenery.py", "--luau", args.luau, "--capture", capture)
            else:
                report["skipped_due_to_capture_failure"] = ["check_world.py", "check_details.py", "check_world_craft.py", "check_scenery.py"]
    report["source_unchanged"] = source_digest() == initial_digest
    report["passed"] = all(item["passed"] for item in results) and report["source_unchanged"]
    report["finished_utc"] = datetime.now(timezone.utc).isoformat()
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    passed = sum(item["passed"] for item in results)
    print(f"{passed}/{len(results)} checks passed. Source unchanged during run: {report['source_unchanged']}.")
    print("Native Roblox rendering, input, audio, physics, DataStore and device performance remain untested.")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
