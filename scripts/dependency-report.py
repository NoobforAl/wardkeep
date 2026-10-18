#!/usr/bin/env python3
"""Which dependencies have newer versions: Go modules, Dart packages and Rust crates.

Writes a Markdown report to stdout (or to --out). With --github-output FILE it also writes `outdated=<n>` (how
many things need a look, a check that could not run counting as one each) for the workflow to read.
Used by .github/workflows/dependencies.yml once a month; run it by hand the same way:

    python scripts/dependency-report.py

Tools come from the environment: GO, FLUTTER and CARGO name the commands to use (defaults: go, flutter, cargo).
Nothing is changed in the repository.
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GO = os.environ.get("GO", "go")
FLUTTER = os.environ.get("FLUTTER", "flutter")
CARGO = os.environ.get("CARGO", "cargo")


def run(cmd, cwd=ROOT):
    """Runs a command; returns (output, None) or (None, why it failed)."""
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=900, shell=(os.name == "nt" and cmd[0].endswith(".bat")))
    except FileNotFoundError:
        return None, f"`{cmd[0]}` is not installed"
    except OSError as e:
        return None, f"`{cmd[0]}` could not be started: {e}"
    except subprocess.TimeoutExpired:
        return None, f"`{' '.join(cmd[:3])}` took longer than 15 minutes"
    if p.returncode != 0:
        lines = [l.strip() for l in (p.stderr or p.stdout).splitlines() if l.strip()]
        return None, f"`{' '.join(cmd[:3])}` failed: " + " / ".join(lines[:2])
    return p.stdout, None


def parts(v):
    """The numbers of a version (v1.2.3, 1.2.3+4, 1.2.3-rc1) for comparing which part changed."""
    nums = re.findall(r"\d+", re.split(r"[-+]", v.lstrip("v"), maxsplit=1)[0])
    return [int(n) for n in nums[:3]] + [0] * (3 - len(nums[:3]))


def kind(old, new):
    a, b = parts(old), parts(new)
    if a[0] != b[0]:
        # 0.x versions treat the minor number as the breaking one
        return "major"
    if a[0] == 0 and a[1] != b[1]:
        return "major (0.x)"
    return "minor" if a[1] != b[1] else "patch"


def go_modules():
    out, err = run([GO, "list", "-m", "-u", "-json", "all"])
    if err:
        return None, err
    rows, dec, i = [], json.JSONDecoder(), 0
    while i < len(out):
        while i < len(out) and out[i].isspace():
            i += 1
        if i >= len(out):
            break
        mod, i = dec.raw_decode(out, i)
        if mod.get("Main") or mod.get("Indirect"):
            continue
        if mod.get("Update"):
            rows.append((mod["Path"], mod["Version"], mod["Update"]["Version"], kind(mod["Version"], mod["Update"]["Version"])))
        elif mod.get("Deprecated"):
            rows.append((mod["Path"], mod["Version"], "-", "deprecated: " + mod["Deprecated"].strip().splitlines()[0]))
    return rows, None


def dart_packages():
    out, err = run([FLUTTER, "pub", "outdated", "--json"], cwd=os.path.join(ROOT, "app"))
    if err:
        return None, err
    start = out.find("{")
    if start < 0:
        return None, "`flutter pub outdated` printed no JSON"
    rows = []
    for p in json.loads(out[start:]).get("packages", []):
        if p.get("kind") not in ("direct", "dev"):
            continue
        cur = (p.get("current") or {}).get("version")
        latest = (p.get("latest") or {}).get("version")
        if p.get("isDiscontinued"):
            rows.append((p["package"], cur or "-", latest or "-", "discontinued"))
        elif cur and latest and cur != latest:
            blocked = (p.get("upgradable") or {}).get("version") == cur
            rows.append((p["package"], cur, latest, kind(cur, latest) + (" (the constraints in pubspec.yaml hold it back)" if blocked else "")))
    return rows, None


def rust_crates():
    out, err = run([CARGO, "outdated", "--root-deps-only", "--format", "json"], cwd=os.path.join(ROOT, "tor"))
    if err:
        return None, err
    rows = []
    start = out.find("{")
    for d in (json.loads(out[start:]).get("dependencies", []) if start >= 0 else []):
        latest = d.get("latest")
        if latest and latest != "---" and latest != d["project"]:
            rows.append((d["name"], d["project"], latest, kind(d["project"], latest)))
    return rows, None


SECTIONS = [
    ("Go modules (direct, `go.mod`)", go_modules),
    ("Dart packages (direct, `app/pubspec.yaml`)", dart_packages),
    ("Rust crates (direct, `tor/Cargo.toml`)", rust_crates),
]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", help="write the report here instead of to stdout")
    ap.add_argument("--github-output", help="append outdated=<n> to this file (the GITHUB_OUTPUT of a workflow)")
    args = ap.parse_args()

    needs, blocks = 0, []
    for title, fn in SECTIONS:
        rows, err = fn()
        if err:
            needs += 1
            blocks.append(f"## {title}\n\n> **Could not be checked:** {err}\n")
        elif rows:
            needs += len(rows)
            lines = [f"## {title}: {len(rows)}\n", "| Package | Now | Newer | What kind |", "|---|---|---|---|"]
            lines += [f"| `{n}` | {a} | {b} | {k} |" for n, a, b, k in sorted(rows)]
            blocks.append("\n".join(lines) + "\n")
        else:
            blocks.append(f"## {title}\n\nUp to date.\n")

    head = f"# Dependency check, {datetime.date.today().isoformat()}\n\n"
    if needs:
        head += f"**{needs}** thing{'s' if needs != 1 else ''} to look at.\n\n"
    else:
        head += "Everything is up to date.\n\n"
    foot = (
        "Nothing here is applied automatically. Update what is worth updating, run the tests "
        "(`make test`, `make app-test`, `make tor`), and close this issue. Checked by "
        "`.github/workflows/dependencies.yml` (`scripts/dependency-report.py`) on the 1st of every month; "
        "GitHub Actions are kept current by Dependabot and are not listed here.\n"
    )
    report = head + "\n".join(blocks) + "\n" + foot
    if args.out:
        with open(args.out, "w", encoding="utf-8", newline="\n") as f:
            f.write(report)
    else:
        sys.stdout.reconfigure(encoding="utf-8")
        print(report)
    if args.github_output:
        with open(args.github_output, "a", encoding="utf-8") as f:
            f.write(f"outdated={needs}\n")


if __name__ == "__main__":
    main()
