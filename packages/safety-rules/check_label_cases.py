"""Runs label_cases.json against label_rules.json (T-GOL-03c).

Usage: python check_label_cases.py  (exit 1 on any failure)
Same normalisation as check_cases.py. The shared red-flag rules run first in
the app; these cases cover only the short-label rules.
"""

import json
import re
import sys
from pathlib import Path

from check_cases import normalise

HERE = Path(__file__).parent


def load_label_rules():
    data = json.loads((HERE / "label_rules.json").read_text(encoding="utf-8"))
    priority = {k: i for i, k in enumerate(data["kinds"])}
    compiled = [
        (r["id"], r["kind"], [re.compile(p) for p in r["patterns"]])
        for r in data["rules"]
    ]
    return priority, compiled


def check(text: str, priority, compiled):
    """Returns (winning kind or None, matched rule ids)."""
    t = normalise(text)
    matched = [(rid, kind) for rid, kind, pats in compiled if any(p.search(t) for p in pats)]
    if not matched:
        return None, []
    best = min(matched, key=lambda m: priority[m[1]])[1]
    return best, [rid for rid, _ in matched]


def main() -> int:
    priority, compiled = load_label_rules()
    cases = json.loads((HERE / "label_cases.json").read_text(encoding="utf-8"))["cases"]
    failures = 0
    for c in cases:
        got, ids = check(c["text"], priority, compiled)
        if got != c["expected"]:
            failures += 1
            tag = "CRITICAL" if c["critical"] else "minor"
            print(f"[{tag}] {c['text']!r}: expected {c['expected']}, got {got} {ids}")
    print(f"{len(cases) - failures}/{len(cases)} cases pass")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
