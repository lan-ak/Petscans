#!/usr/bin/env python3
"""Find spoken lines shared between creator packs.

Posts go out undisclosed, so two creators running matched phrasing is the
fingerprint that identifies a paid seed network — it is exactly how we
identified a competitor's network (~10 accounts, one template). Packs written
from the same outline drift into shared wording without anyone deciding to.

This parses each `build-*-pack.py` with `ast` and extracts only what is actually
*said on camera*:

  - the voiceover body of every `vo(doc, cue, text)` call
  - the "What you say" column of every `shotlist(doc, [(time, visual, audio)])`

Prose from the rules, briefs and filming notes is ignored — none of it is spoken,
so none of it can give the game away.

Usage:
  check-duplication.py                       # every pack under PetScans UGC/
  check-duplication.py <file.py> <file.py>   # specific builders
  check-duplication.py --n 6                 # phrase length (default 5 words)
"""

import argparse
import ast
import re
import sys
from itertools import combinations
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
UGC = REPO / "PetScans UGC"


def _str(node):
    """Literal string from a node, joining implicit concatenation."""
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    if isinstance(node, ast.JoinedStr):
        return "".join(v.value for v in node.values
                       if isinstance(v, ast.Constant) and isinstance(v.value, str))
    return None


def spoken_lines(path):
    """Every line a creator actually says, in order."""
    tree = ast.parse(Path(path).read_text())
    out = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or not isinstance(node.func, ast.Name):
            continue
        if node.func.id == "vo" and len(node.args) >= 3:
            s = _str(node.args[2])
            if s:
                out.append(s)
        elif node.func.id == "shotlist" and len(node.args) >= 2:
            rows = node.args[1]
            if isinstance(rows, (ast.List, ast.Tuple)):
                for row in rows.elts:
                    if isinstance(row, (ast.Tuple, ast.List)) and len(row.elts) >= 3:
                        s = _str(row.elts[2])
                        if s:
                            out.append(s)
    return out


def phrases(text, n):
    words = re.findall(r"[a-z']+", text.lower())
    return {" ".join(words[i:i + n]) for i in range(len(words) - n + 1)}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("builders", nargs="*", help="build-*-pack.py files (default: all)")
    ap.add_argument("--n", type=int, default=5, help="phrase length in words")
    args = ap.parse_args()

    files = [Path(b) for b in args.builders] or sorted(UGC.glob("*/build-*-pack.py"))
    if len(files) < 2:
        sys.exit("need at least two packs to compare")

    packs = {}
    for f in files:
        lines = spoken_lines(f)
        packs[f.parent.name] = lines
        print(f"{f.parent.name}: {len(lines)} spoken lines")

    worst = 0
    for (na, la), (nb, lb) in combinations(packs.items(), 2):
        # map each shared phrase back to the lines it came from
        pa = {}
        for line in la:
            for p in phrases(line, args.n):
                pa.setdefault(p, line)
        hits = {}
        for line in lb:
            for p in phrases(line, args.n):
                if p in pa:
                    hits.setdefault((pa[p], line), set()).add(p)

        print(f"\n{'=' * 74}\n{na}  vs  {nb}")
        if not hits:
            print("  no shared phrasing — clean")
            continue
        worst = max(worst, len(hits))
        # longest overlaps first: they're the most identifiable
        for (a, b), ps in sorted(hits.items(), key=lambda kv: -len(kv[1])):
            print(f"\n  [{len(ps)} shared {args.n}-word phrases]")
            print(f"    A: {a[:150]}")
            print(f"    B: {b[:150]}")

    if worst:
        print(f"\nRewrite the B-side lines above. Same facts and same driver are fine — "
              f"the wording has to be the creator's own.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
