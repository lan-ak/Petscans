#!/usr/bin/env python3
"""
Competitor App Store review mining.

Why this exists: paid UA is buying installs at a healthy CPI, and the money is being lost
after the install, when trials cancel within minutes. That is an expectations problem, and
the cheapest place to read it is other people's one-star reviews — the competitors in this
category are small enough that their reviews are mostly about the paywall, not the product.

Apple's public review RSS is used rather than Firecrawl: it is free, structured, returns the
star rating as a field instead of something to be inferred, and paginates deterministically.
Spending scrape credits to re-derive that from rendered HTML would be worse data at a price.
Capped at 10 pages because the feed stops returning new entries past roughly 500 reviews.
"""

import json
import re
import sys
import time
import urllib.request
from collections import Counter
from pathlib import Path
from typing import Optional

OUT = Path(__file__).resolve().parent / "competitor-reviews.json"
REPORT = Path(__file__).resolve().parent / "competitor-intel.md"

# Direct competitors first, then the human-food analogs the category's users already know.
# Bobby Approved and Olive are not in metadata/aso-plan.md and were found while resolving ids;
# at 159k and 40k ratings they are the volume leaders in the adjacent space.
APPS = [
    ("Pawdi", 6738991905, "direct"),
    ("Hapu", 6748929220, "direct"),
    ("Yuka", 1092799236, "analog"),
    ("Bobby Approved", 1571725006, "analog"),
    ("Olive", 6739765789, "analog"),
    ("Fig", 1564434726, "analog"),
    ("Spoonful", 1481914232, "analog"),
]

# Themes worth separating. Ordered most to least specific: a review matching several is filed
# under the first, so "paywall" beats the generic "value" wording it usually also contains.
THEMES = [
    ("paywall", r"\b(paywall|free trial|no trial|subscription|subscribe|pay to|paid|price|expensive|charge|refund|cancel|scam|money|\$)\b"),
    ("scan_limit", r"\b(one scan|1 scan|limited scan|out of scans|scan limit|only.{0,12}scans?|zero scans|0 scans)\b"),
    ("database_gaps", r"\b(not in (the )?database|couldn.?t find|can.?t find|no results|not found|doesn.?t recognize|unrecognized|barcode.{0,20}(not|fail))\b"),
    ("accuracy", r"\b(wrong|inaccurate|incorrect|misleading|bad (data|info)|rating.{0,15}(off|wrong)|questionable)\b"),
    ("bugs", r"\b(crash|freeze|frozen|bug|glitch|won.?t open|broken|error|stuck|slow)\b"),
]


def fetch_reviews(app_id: int, pages: int = 10) -> list:
    out, seen = [], set()
    for page in range(1, pages + 1):
        url = f"https://itunes.apple.com/us/rss/customerreviews/page={page}/id={app_id}/sortby=mostrecent/json"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=30) as r:
                feed = json.load(r).get("feed", {})
        except Exception as e:
            print(f"    page {page}: {e}", file=sys.stderr)
            break

        entries = feed.get("entry", [])
        # Page 1's first entry is the app itself, not a review.
        if isinstance(entries, dict):
            entries = [entries]
        fresh = 0
        for e in entries:
            if "im:rating" not in e:
                continue
            rid = e.get("id", {}).get("label", "")
            if rid in seen:
                continue
            seen.add(rid)
            fresh += 1
            out.append({
                "rating": int(e["im:rating"]["label"]),
                "title": e.get("title", {}).get("label", ""),
                "content": e.get("content", {}).get("label", ""),
                "version": e.get("im:version", {}).get("label", ""),
                "author": e.get("author", {}).get("name", {}).get("label", ""),
            })
        if not fresh:
            break
        time.sleep(0.4)
    return out


def theme_of(text: str) -> Optional[str]:
    low = text.lower()
    for name, pat in THEMES:
        if re.search(pat, low):
            return name
    return None


def lifetime(app_id: int) -> dict:
    """Store-level rating, so the report can separate lifetime standing from recent sentiment."""
    url = f"https://itunes.apple.com/lookup?id={app_id}&country=us"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=30) as r:
            res = json.load(r)["results"][0]
        return {"lifetime_avg": round(res.get("averageUserRating", 0), 2), "lifetime_count": res.get("userRatingCount", 0)}
    except Exception:
        return {"lifetime_avg": None, "lifetime_count": None}


def main() -> None:
    data = {}
    for name, app_id, kind in APPS:
        print(f"  {name} ({app_id})…", file=sys.stderr)
        reviews = fetch_reviews(app_id)
        low = [r for r in reviews if r["rating"] <= 3]
        themes = Counter()
        for r in low:
            t = theme_of(f"{r['title']} {r['content']}")
            if t:
                themes[t] += 1
        data[name] = {
            "app_id": app_id,
            "kind": kind,
            "reviews": reviews,
            "count": len(reviews),
            "low_star": len(low),
            "avg": round(sum(r["rating"] for r in reviews) / len(reviews), 2) if reviews else None,
            "themes": dict(themes.most_common()),
            **lifetime(app_id),
        }
        print(f"    {len(reviews)} reviews, {len(low)} at <=3 stars, themes={dict(themes.most_common(3))}", file=sys.stderr)

    OUT.write_text(json.dumps(data, indent=2))

    lines = ["# Competitor review intelligence", ""]
    lines.append("Source: Apple public review RSS, most recent first (~500 review cap per app).")
    lines.append("")
    lines.append("The RSS returns most-recent-first, so the `<=3 stars` column is *recent* sentiment.")
    lines.append("It is deliberately shown next to the lifetime store rating: where the two diverge, the")
    lines.append("app has changed something recently, and a paywall is the usual something.")
    lines.append("")
    lines.append("| App | Kind | Recent reviews | <=3 stars | Recent avg | Lifetime avg | Lifetime ratings | Top complaint themes |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for name, d in data.items():
        top = ", ".join(f"{k} ({v})" for k, v in list(d["themes"].items())[:3]) or "—"
        pctlow = f"{d['low_star']} ({round(100*d['low_star']/d['count'])}%)" if d["count"] else "—"
        lines.append(
            f"| {name} | {d['kind']} | {d['count']} | {pctlow} | {d['avg']} | {d['lifetime_avg']} | "
            f"{d['lifetime_count']:,} | {top} |" if d["lifetime_count"] is not None else
            f"| {name} | {d['kind']} | {d['count']} | {pctlow} | {d['avg']} | — | — | {top} |"
        )
    lines.append("")

    for name, d in data.items():
        low = [r for r in d["reviews"] if r["rating"] <= 3]
        if not low:
            continue
        lines.append(f"## {name} — verbatim low-star reviews")
        lines.append("")
        for r in low[:12]:
            body = " ".join(r["content"].split())[:300]
            lines.append(f"- **{r['rating']}★ {r['title']}** — {body}")
        lines.append("")

    REPORT.write_text("\n".join(lines))
    print(f"\nwrote {OUT}\nwrote {REPORT}", file=sys.stderr)


if __name__ == "__main__":
    main()
