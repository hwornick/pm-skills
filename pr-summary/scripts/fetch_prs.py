#!/usr/bin/env python3
"""
Fetch + filter + compact merged PRs from a GitHub repo for a date range.

Why this script exists:
- The `gh` API call + pagination + JSON shape parsing is deterministic and
  the same every run. Bundling it means each invocation skips reinventing it.
- The dependabot / bot-noise filter rules are decisions, not judgment calls.
  Bundling them keeps every run consistent.
- The output is a small text bundle the calling agent can read into context
  to do the actual judgment work (clustering, naming, plain-language framing).

Usage:
    python fetch_prs.py --repo owner/name --start 2026-04-24                 # end = today
    python fetch_prs.py --repo owner/name --start 2026-04-24 --end 2026-06-02
    python fetch_prs.py --repo owner/name --start 2026-04-24 --out /tmp/prs.txt
    python fetch_prs.py --repo owner/name --start 2026-04-24 --base release   # non-default base

Output:
    Writes a compact text file (one entry per PR, sorted by merge date) to
    the --out path (default /tmp/pr-summary-prs.txt) and prints a one-line
    summary (count, date range, top contributors) to stdout.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import Counter
from datetime import date, datetime
from pathlib import Path
from urllib.parse import quote_plus

DEPENDABOT_LOGIN = "dependabot[bot]"
# Bot-noise titles to drop from a completed-work summary. Customize these patterns for your
# repo (e.g. error-monitoring bots, automated changelog PRs, release bots).
BOT_NOISE_RE = re.compile(r"\[BOT\]", re.IGNORECASE)
HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)


def default_branch(repo: str) -> str:
    """Look up the repo's default branch (e.g. main / master / trunk)."""
    result = subprocess.run(
        ["gh", "api", f"repos/{repo}", "--jq", ".default_branch"],
        capture_output=True, text=True, check=False,
    )
    if result.returncode != 0 or not result.stdout.strip():
        sys.stderr.write(
            f"Could not look up the default branch of {repo}. "
            "Is `gh` installed and authenticated, and does the repo exist?\n"
        )
        sys.stderr.write(result.stderr)
        sys.exit(1)
    return result.stdout.strip()


def run_gh_search(repo: str, base: str, start: str, end: str) -> list:
    """Use the GitHub search API to get all merged PRs in the window.

    Search-API is preferred over /repos/.../pulls because it supports
    server-side date filtering on merged_at -- no need to over-fetch and
    filter client-side.

    The query MUST be URL-encoded: unencoded spaces in the path make
    `gh api` hang instead of erroring.
    """
    query = quote_plus(
        f"repo:{repo} is:pr is:merged base:{base} "
        f"merged:{start}..{end}"
    )
    cmd = [
        "gh", "api", "--paginate",
        f"search/issues?q={query}&per_page=100",
        "--jq",
        ".items[] | {number, title, user: .user.login, "
        "merged_at: .pull_request.merged_at, url: .html_url, body}",
    ]
    result = subprocess.run(
        cmd, capture_output=True, text=True, check=False
    )
    if result.returncode != 0:
        sys.stderr.write(
            "gh command failed. Is `gh` installed and authenticated?\n"
        )
        sys.stderr.write(result.stderr)
        sys.exit(1)

    prs = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        prs.append(json.loads(line))
    return prs


def filter_noise(prs):
    """Drop dependency bumps and bot-noise PRs.

    Returns (kept_prs, filter_counts).
    """
    kept = []
    counts = {"dependabot": 0, "bot_noise": 0}
    for p in prs:
        if p.get("user") == DEPENDABOT_LOGIN:
            counts["dependabot"] += 1
            continue
        if BOT_NOISE_RE.search(p.get("title") or ""):
            counts["bot_noise"] += 1
            continue
        kept.append(p)
    return kept, counts


def trim_body(body, max_chars: int = 500) -> str:
    """Strip HTML comments and excess whitespace; cap at max_chars."""
    if not body:
        return ""
    body = HTML_COMMENT_RE.sub("", body)
    body = body.replace("\r", "")
    body = re.sub(r"\n{3,}", "\n\n", body).strip()
    return body[:max_chars]


def write_compact(prs, out_path: Path) -> None:
    """Write one entry per PR, sorted by merge date ascending."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w") as f:
        for p in sorted(prs, key=lambda x: x.get("merged_at") or ""):
            merged_day = (p.get("merged_at") or "")[:10]
            f.write(f"#{p['number']} | {merged_day} | {p['title']}\n")
            body = trim_body(p.get("body"))
            if body:
                indented = "\n".join("    " + line for line in body.splitlines())
                f.write(indented + "\n")
            f.write("\n")


def print_summary(prs, counts, out_path: Path) -> None:
    if not prs:
        print(f"No qualifying PRs found. Output: {out_path}")
        return
    merged = [p["merged_at"][:10] for p in prs if p.get("merged_at")]
    authors = Counter(p["user"] for p in prs).most_common(5)
    print(f"PRs written: {len(prs)}")
    print(f"Date range:  {min(merged)} -> {max(merged)}")
    print(
        f"Filtered out: {counts['dependabot']} dependabot, "
        f"{counts['bot_noise']} bot-noise"
    )
    print("Top authors: " + ", ".join(f"{u} ({n})" for u, n in authors))
    print(f"Output:      {out_path}")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--repo", required=True, help="GitHub repo as owner/name")
    p.add_argument(
        "--base",
        default=None,
        help="Only count PRs merged into this branch. Defaults to the repo's default branch.",
    )
    p.add_argument("--start", required=True, help="Start date YYYY-MM-DD (inclusive)")
    p.add_argument("--end", default=None, help="End date YYYY-MM-DD (inclusive). Defaults to today.")
    p.add_argument(
        "--out",
        default="/tmp/pr-summary-prs.txt",
        help="Path to write the compact PR file (default: /tmp/pr-summary-prs.txt)",
    )
    return p.parse_args()


def validate_date(s: str, label: str) -> str:
    try:
        datetime.strptime(s, "%Y-%m-%d")
    except ValueError:
        sys.exit(f"Error: --{label} must be YYYY-MM-DD, got: {s}")
    return s


def main() -> None:
    args = parse_args()
    start = validate_date(args.start, "start")
    end = validate_date(args.end, "end") if args.end else date.today().isoformat()

    if end < start:
        sys.exit(f"Error: --end ({end}) is before --start ({start})")

    base = args.base or default_branch(args.repo)
    raw = run_gh_search(args.repo, base, start, end)
    kept, counts = filter_noise(raw)
    out_path = Path(args.out)
    write_compact(kept, out_path)
    print_summary(kept, counts, out_path)


if __name__ == "__main__":
    main()
