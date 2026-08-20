#!/usr/bin/env python3
"""
Generate BUILD-STATUS.md for The Last Tide.

BUILD-STATUS.md is DERIVED - never edit it by hand. Everything it reports comes from a file that
already owns that fact, so the board cannot disagree with reality:

    docs/features/*/feature.md   frontmatter: id, name, area, status, priority   -> planned work
    assets/registry/assets.yaml  asset + graybox status                          -> art pipeline
    Jobs/NNN/                    intake.md title + final-summary.md present?      -> delivered work
    docs/build/*.md              the build manifest group files                   -> the big list

Run:  python tools/build-status.py          (writes BUILD-STATUS.md)
      python tools/build-status.py --check  (exit 1 if stale - for CI or a pre-commit hook)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "BUILD-STATUS.md"

# Order the areas appear on the board. Anything unlisted is appended alphabetically and flagged.
AREA_ORDER = [
    "sea", "boat", "atmosphere", "islands", "lobby",
    "navigation", "combat", "crew", "character", "audio", "ui", "infra",
]

# The status ladder from docs/development-workflow.md, weakest first.
LADDER = ["IDEA", "PLANNED", "READY", "IN_PROGRESS", "IMPLEMENTED", "VERIFIED"]
TERMINAL = ["DEFERRED", "REMOVED"]
BAR = {
    "IDEA": ".....", "PLANNED": "#....", "READY": "##...", "IN_PROGRESS": "###..",
    "IMPLEMENTED": "####.", "VERIFIED": "#####", "DEFERRED": "~~~~~", "REMOVED": "-----",
}


def parse_frontmatter(text):
    m = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n", text, re.S)
    if not m:
        return {}
    out = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip()
    return out


def read_features():
    feats = []
    for p in sorted((ROOT / "docs" / "features").glob("0*/feature.md")):
        f = parse_frontmatter(p.read_text(encoding="utf-8"))
        if not f:
            continue
        f["_folder"] = p.parent.name
        f.setdefault("area", "unassigned")
        f.setdefault("status", "IDEA")
        f.setdefault("priority", "")
        feats.append(f)
    return feats


def read_assets():
    """Return (status counts, graybox entries). Hand-parsed so pyyaml is not required."""
    p = ROOT / "assets" / "registry" / "assets.yaml"
    counts = {}
    graybox = []
    if not p.exists():
        return counts, graybox
    current = {}
    entries = []
    # Key whose value is still being accumulated across continuation lines, and its indent.
    folding = None
    fold_indent = 0
    for raw in p.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        indent = len(raw) - len(raw.lstrip())
        if line.startswith("#") or not line:
            continue
        # A continuation line: more indented than the key that opened it, and not a new key.
        # Handles both YAML folded scalars (`notes: >-`) and plain wrapped values, which the
        # first-line-only version truncated mid-sentence.
        if folding and indent > fold_indent and not line.startswith("- "):
            # A YAML key is `word:` followed by whitespace or end of line. Requiring that avoids
            # mistaking a URL for a key - `rbxasset://...` has a colon and broke the naive check.
            looks_like_key = re.match(r"^[a-z_][a-z0-9_]*:(\s|$)", line) is not None
            if not looks_like_key:
                current[folding] = (current.get(folding, "") + " " + line).strip()
                continue
        folding = None
        if line.startswith("- id:"):
            if current:
                entries.append(current)
            current = {"id": line.split(":", 1)[1].strip()}
        elif ":" in line and current:
            k, v = line.split(":", 1)
            k, v = k.strip(), v.strip()
            if v in (">-", ">", "|-", "|"):
                # folded/literal scalar: the value lives on the following lines
                current.setdefault(k, "")
                folding, fold_indent = k, indent
            else:
                current.setdefault(k, v)
                folding, fold_indent = k, indent
    if current:
        entries.append(current)
    for e in entries:
        st = e.get("status", "UNKNOWN")
        counts[st] = counts.get(st, 0) + 1
        if st == "GRAYBOX":
            graybox.append(e)
    return counts, graybox


def read_jobs():
    """(number, title, delivered) - delivered means final-summary.md exists."""
    jobs = []
    jdir = ROOT / "Jobs"
    if not jdir.exists():
        return jobs
    for d in sorted(p for p in jdir.iterdir() if p.is_dir() and p.name.isdigit()):
        intake = d / "intake.md"
        title = d.name
        if intake.exists():
            for line in intake.read_text(encoding="utf-8").splitlines():
                m = re.match(r"^#\s*Job\s*#\d+:\s*(.+)$", line.strip())
                if m:
                    title = m.group(1).strip()
                    break
        jobs.append((d.name, title, (d / "final-summary.md").exists()))
    return jobs


def read_manifest():
    """(file, title, one-line Group: summary) for docs/build/NN-*.md."""
    out = []
    bdir = ROOT / "docs" / "build"
    if not bdir.exists():
        return out
    for p in sorted(bdir.glob("[0-9][0-9]-*.md")):
        title, summary, items = p.stem, "", ""
        lines = p.read_text(encoding="utf-8").splitlines()
        for line in lines:
            if line.startswith("# "):
                title = line[2:].strip()
                break
        # **Group:** and **Items:** values may wrap onto following lines; join until the next
        # bold key or a blank line.
        collecting = None
        parts = []
        for line in lines + [""]:
            st = line.strip()
            m = re.match(r"^\*\*(Group|Items):\*\*\s*(.*)$", st)
            if m:
                if collecting:
                    val = " ".join(x for x in parts if x)
                    if collecting == "Group":
                        summary = val
                    else:
                        items = val
                collecting, parts = m.group(1), [m.group(2).strip()]
                continue
            if collecting is not None:
                if not st or st.startswith("**") or st.startswith("#"):
                    val = " ".join(x for x in parts if x)
                    if collecting == "Group":
                        summary = val
                    else:
                        items = val
                    collecting, parts = None, []
                else:
                    parts.append(st)
        out.append((p.name, title, summary, items))
    return out


def build():
    feats = read_features()
    asset_counts, graybox = read_assets()
    jobs = read_jobs()
    manifest = read_manifest()

    L = []
    L.append("# Build Status - The Last Tide")
    L.append("")
    L.append("> **Generated file - do not edit.** Run `python tools/build-status.py`.")
    L.append("> Status lives in each feature's own frontmatter; this board only reports it, so the two")
    L.append("> cannot disagree. Change a status in `docs/features/<id>/feature.md` and re-run.")
    L.append("")
    L.append("`VERIFIED` requires a real Studio/playtest check - never award it for code merely written.")
    L.append("")

    L.append("## Features by area")
    L.append("")
    by_area = {}
    for f in feats:
        by_area.setdefault(f["area"], []).append(f)
    ordered = [a for a in AREA_ORDER if a in by_area] + sorted(a for a in by_area if a not in AREA_ORDER)
    for area in ordered:
        rows = sorted(by_area[area], key=lambda r: r.get("id", ""))
        flag = "" if area in AREA_ORDER else "  (!) unknown area"
        L.append("### " + area + flag)
        L.append("")
        L.append("| | Feature | Id | Status | Pri |")
        L.append("|---|---|---|---|---|")
        for r in rows:
            bar = BAR.get(r["status"], "?????")
            link = "[" + r.get("name", "?") + "](docs/features/" + r["_folder"] + "/feature.md)"
            L.append("| `" + bar + "` | " + link + " | " + r.get("id", "") + " | " + r["status"] + " | " + r.get("priority", "") + " |")
        L.append("")

    L.append("## Roll-up")
    L.append("")
    tally = {s: sum(1 for f in feats if f["status"] == s) for s in LADDER + TERMINAL}
    L.append("| Status | Features |")
    L.append("|---|---|")
    for s in LADDER + TERMINAL:
        if tally[s]:
            L.append("| " + s + " | " + str(tally[s]) + " |")
    L.append("| **total** | **" + str(len(feats)) + "** |")
    L.append("")

    if manifest:
        L.append("## The build manifest - what actually needs making")
        L.append("")
        L.append("Groups are sized to be taken one at a time. See [docs/build/README.md](docs/build/README.md).")
        L.append("")
        L.append("| Group | Covers | Items |")
        L.append("|---|---|---|")
        for fname, title, summary, items in manifest:
            L.append("| [" + title + "](docs/build/" + fname + ") | " + (summary or "-") + " | " + (items or "-") + " |")
        L.append("")

    L.append("## Assets")
    L.append("")
    if asset_counts:
        L.append("| Status | Count |")
        L.append("|---|---|")
        for st, n in sorted(asset_counts.items()):
            L.append("| " + st + " | " + str(n) + " |")
    else:
        L.append("_No assets registered yet._")
    L.append("")
    L.append("### Graybox placeholders awaiting real art")
    L.append("")
    if graybox:
        L.append("| Placeholder | Stands in for | Place | Note |")
        L.append("|---|---|---|---|")
        for g in graybox:
            L.append("| `" + g["id"] + "` | " + g.get("represents", "(!) unset") + " | " + g.get("place", "?") + " | " + g.get("notes", "") + " |")
        L.append("")
        L.append("Verify against the live places with `tools/audit-graybox.luau` - it catches placeholders")
        L.append("that exist in Studio but were never registered.")
    else:
        L.append("_None registered._ Anything grey standing in for real art belongs here - see")
        L.append("[assets/README.md](assets/README.md).")
    L.append("")

    L.append("## Delivered (jobs with a final summary)")
    L.append("")
    if jobs:
        for num, title, done in jobs:
            mark = "x" if done else " "
            L.append("- [" + mark + "] **" + num + "** " + title)
        L.append("")
        L.append("An unchecked job is still in flight.")
    else:
        L.append("_No jobs yet._")
    L.append("")
    return "\n".join(L) + "\n"


def main():
    text = build()
    if "--check" in sys.argv:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != text:
            print("BUILD-STATUS.md is stale - run: python tools/build-status.py")
            return 1
        print("BUILD-STATUS.md is current.")
        return 0
    OUT.write_text(text, encoding="utf-8")
    print("wrote " + str(OUT.relative_to(ROOT)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
