#!/usr/bin/env python3
"""Record verified work intervals; interrupted or idle time is never inferred.

Run ``resume`` on a new turn after any interruption, ``checkpoint --note ...``
while continuously working, and ``pause`` before yielding. Parallel agents do
not multiply the elapsed time. This utility is development tooling, not game code.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / "WORK_LOG.json"


def stamp():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def seconds(start, end):
    return int((datetime.fromisoformat(end) - datetime.fromisoformat(start)).total_seconds())


def duration(value):
    return f"{value // 3600}:{value % 3600 // 60:02}:{value % 60:02}"


def save(data):
    verified = sum(seconds(item["start"], item["end"]) for item in data["intervals"])
    STATE.write_text(json.dumps(data, indent=2) + "\n")
    lines = ["# Active development work log", "",
             "Request: 26 October 2026, at least two hours of active work on the premium directive.",
             "Only sealed intervals below count. Usage-limit pauses, idle time and gaps", 
             "between turns do not count. Parallel agent time is not multiplied.", "",
             f"Verified active work: **{duration(verified)}**. Remaining: **{duration(max(0, data['target_seconds'] - verified))}**.",
             "", "| Start (UTC) | End (UTC) | Active | Work |", "| --- | --- | --- | --- |"]
    for item in data["intervals"]:
        lines.append(f"| {item['start']} | {item['end']} | {duration(seconds(item['start'], item['end']))} | {item['note'].replace('|', '/')} |")
    lines += ["", "On resuming after an interruption, run `python tools/work_session.py resume`",
              "before checkpointing. The unsealed cursor is discarded; a pause is never",
              "counted just because the clock advanced. Seal a checkpoint regularly.", ""]
    (ROOT / "WORK_LOG.md").write_text("\n".join(lines))
    print(f"Verified active work {duration(verified)}; remaining {duration(max(0, data['target_seconds'] - verified))}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("resume", "checkpoint", "pause", "status"))
    parser.add_argument("--note", default="Active development and review")
    args = parser.parse_args()
    data = json.loads(STATE.read_text())
    current = stamp()
    if args.action == "resume":
        # An abandoned cursor is not proof of work during a long pause.
        data["running_since"] = current
    elif args.action in ("checkpoint", "pause"):
        start = data.get("running_since")
        if not start:
            raise SystemExit("Resume the work session before recording an interval.")
        if seconds(start, current) < 0:
            raise SystemExit("Clock moved backwards; no work time recorded.")
        data["intervals"].append({"start": start, "end": current, "note": args.note})
        data["running_since"] = current if args.action == "checkpoint" else None
    save(data)


if __name__ == "__main__":
    main()
