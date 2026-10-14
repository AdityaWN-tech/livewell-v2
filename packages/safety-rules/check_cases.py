"""Reference red-flag engine and test runner (Python).

The app has its own Dart engine (apps/mobile/lib/features/safety/); the
agents service (T-AGT-02) will reuse this logic. Both must pass cases.json.

Usage:  python check_cases.py            (exit code 1 on any failure)
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def normalise(text: str) -> str:
    t = text.lower().replace("’", "'").replace("‘", "'")
    t = re.sub(r"[^a-z0-9' ]", " ", t)
    return re.sub(r"\s+", " ", t).strip()


def load_rules():
    data = json.loads((HERE / "rules.json").read_text(encoding="utf-8"))
    priority = {c["id"]: c["priority"] for c in data["categories"]}
    compiled = [
        (r["id"], r["category"], [re.compile(p) for p in r["patterns"]])
        for r in data["rules"]
    ]
    return priority, compiled


def check(text: str, priority, compiled):
    """Returns (winning category or None, matched rule ids)."""
    t = normalise(text)
    matched = [(rid, cat) for rid, cat, pats in compiled if any(p.search(t) for p in pats)]
    if not matched:
        return None, []
    best = min(matched, key=lambda m: priority[m[1]])[1]
    return best, [rid for rid, _ in matched]


def main() -> int:
    priority, compiled = load_rules()
    cases = json.loads((HERE / "cases.json").read_text(encoding="utf-8"))["cases"]
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
