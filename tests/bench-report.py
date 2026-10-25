#!/usr/bin/env python3
"""Build the interactive benchmark report from a benchmark CSV.

    python3 tests/bench-report.py [results.csv]

Fills tests/bench/report.html (the page) with every measured design, its name,
description, tags and whether it is enabled or animated (from Designs.js), and
the LEGACY allow-list from tests/standards.test.cjs. Writes <name>-report.html
next to the CSV, so the recorded tests/bench-results/full-1080p.csv gets
tests/bench-results/full-1080p-report.html. It is a single file that opens in
any browser: CPU against GPU, the spread in the standards.md bins, and every
design ranked. No dependencies beyond Python.

tests/bench-lock-load.sh runs this at the end of every benchmark, so each run's
CSV comes with its report.
"""
import csv, json, os, re, sys

root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
path = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(root, "tests/bench-results/full-1080p.csv")

meta = {}
for line in open(os.path.join(root, "Designs.js")).read().split("\n"):
    m = re.match(r'\s*(//)?\s*\{ id: "([^"]+)", file:', line)
    if not m:
        continue
    field = lambda k: (re.search(k + r': "([^"]*)"', line) or [None, ""])[1]
    tags = re.search(r'tags: \[([^\]]*)\]', line)
    meta[m.group(2)] = {
        "name": field("name"),
        "desc": field("description"),
        "tags": re.findall(r'"([^"]+)"', tags.group(1)) if tags else [],
        "anim": bool(re.search(r'\b(anim|clip): true', line)),
        "enabled": not m.group(1),
    }

rows = []
for r in csv.DictReader(open(path)):
    d = meta.get(r["design"], {"name": r["design"], "desc": "", "tags": [], "anim": False, "enabled": False})
    rows.append({"id": r["design"], "cpu": float(r["cpu_pct"]), "gpu": float(r["gpu_pct"]),
                 "mb": int(float(r["rss_mb"])), **d})

test = open(os.path.join(root, "tests/standards.test.cjs")).read()
block = re.search(r'const LEGACY = \{(.*?)\n\};', test, re.S)
legacy = re.findall(r'^\s*([a-z0-9_-]+):\s*\{', block.group(1), re.M) if block else []

page = open(os.path.join(root, "tests/bench/report.html")).read()
page = page.replace("__DATA__", json.dumps(rows, separators=(",", ":"))).replace("__LEGACY__", json.dumps(legacy))
# The header names the CSV: repo-relative when it is in the repo, else just its name.
rel = os.path.relpath(path, root)
page = page.replace("__SOURCE__", rel if not rel.startswith("..") else os.path.basename(path))
out = os.path.splitext(path)[0] + "-report.html"
open(out, "w").write(page)
print(f"Report: {out}")
