#!/usr/bin/env python3
"""Read a cycle report markdown file and post a digest summary to Slack.

Required env vars:
  SLACK_WEBHOOK_URL  - incoming webhook
  REPORT             - path to cycle markdown (e.g. cycles/2026-04.md)
  CYCLE              - cycle label (e.g. 2026-04)
  GITHUB_REPOSITORY  - org/repo (provided automatically by GitHub Actions)
Optional env vars:
  TICKET_BASE_URL    - base URL for ticket links (e.g. https://example.atlassian.net/browse
                       for Jira, or https://linear.app/team/issue for Linear). If unset,
                       ticket references are left as plain text.
  TICKET_PREFIX      - ticket key prefix to detect in prose (default: TICKET). e.g. FR, ENG.

Design choices:
- Includes Headline stats, Customer list, Themes (full body), Trends.
- Drops Ticket detail (too verbose for Slack).
- Drops "**Tickets:** ..." bullet lines from the Themes section so the
  channel's issue-tracker automation doesn't unfurl a dozen tickets per post.
- For any remaining <PREFIX>-NNN references in theme prose, inserts a
  zero-width non-joiner (U+200C) between the prefix and the number. Invisible to
  humans; breaks the tracker bot regex that triggers auto-unfurl.
- Converts markdown bold and ### headers into Slack mrkdwn.
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.request

ZWNJ = "‌"
TICKET_BASE_URL = os.environ.get("TICKET_BASE_URL", "").rstrip("/")
TICKET_PREFIX = os.environ.get("TICKET_PREFIX", "TICKET")
SLACK_BLOCK_TEXT_LIMIT = 2900  # leave headroom under Slack's 3000-char block limit


def required_env(name: str) -> str:
    val = os.environ.get(name)
    if not val:
        print(f"::error::Missing required env var {name}", file=sys.stderr)
        sys.exit(2)
    return val


def extract_section(md: str, name_prefix: str) -> str:
    """Return the body of `## <name_prefix>...` up to the next `## ` header."""
    pattern = rf"^## {re.escape(name_prefix)}[^\n]*\n(.*?)(?=\n## |\Z)"
    m = re.search(pattern, md, flags=re.MULTILINE | re.DOTALL)
    return m.group(1).strip() if m else ""


def md_to_mrkdwn(s: str) -> str:
    """Convert a subset of CommonMark to Slack mrkdwn."""
    # Drop bullet lines that list ticket keys (they trigger tracker auto-unfurl).
    s = re.sub(r"^\s*-\s*\*\*Tickets:\*\*.*$\n?", "", s, flags=re.MULTILINE)
    # `### Heading` -> bold line. Slack mrkdwn has no real headers.
    s = re.sub(r"^###\s+(.*)$", r"*\1*", s, flags=re.MULTILINE)
    # Markdown `**bold**` -> Slack `*bold*`.
    s = re.sub(r"\*\*(.+?)\*\*", r"*\1*", s)
    # Wrap remaining <PREFIX>-NNN ticket references. When a base URL is set, render
    # a Slack link whose URL resolves in the tracker; the visible label has a ZWNJ
    # between prefix and number so the tracker's Slack bot regex misses it
    # (belt-and-suspenders, in case it scans label text regardless of link state).
    def _wrap_ticket(m: re.Match[str]) -> str:
        prefix, num = m.group(1), m.group(2)
        label = f"{prefix}{ZWNJ}-{num}"
        if TICKET_BASE_URL:
            url = f"{TICKET_BASE_URL}/{prefix}-{num}"
            return f"<{url}|{label}>"
        return label

    s = re.sub(rf"\b({re.escape(TICKET_PREFIX)})-(\d+)\b", _wrap_ticket, s)
    return s.strip()


def chunk_for_slack(text: str, limit: int = SLACK_BLOCK_TEXT_LIMIT) -> list[str]:
    """Split text on blank-line boundaries into Slack-block-sized chunks."""
    if len(text) <= limit:
        return [text]
    chunks: list[str] = []
    current: list[str] = []
    current_len = 0
    for para in text.split("\n\n"):
        added = len(para) + (2 if current else 0)
        if current and current_len + added > limit:
            chunks.append("\n\n".join(current))
            current = [para]
            current_len = len(para)
        else:
            current.append(para)
            current_len += added
    if current:
        chunks.append("\n\n".join(current))
    return chunks


def main() -> int:
    webhook = required_env("SLACK_WEBHOOK_URL")
    report_path = required_env("REPORT")
    cycle = required_env("CYCLE")
    github_repo = required_env("GITHUB_REPOSITORY")

    if not os.path.isfile(report_path):
        print(f"::error::Report file {report_path!r} not found", file=sys.stderr)
        return 1

    with open(report_path, encoding="utf-8") as f:
        md = f.read()

    stats = extract_section(md, "Headline stats")
    themes_raw = extract_section(md, "Themes this cycle")
    trends_raw = extract_section(md, "Trends")

    stats_text = md_to_mrkdwn(stats) if stats else ""
    themes_text = md_to_mrkdwn(themes_raw) if themes_raw else ""
    trends_text = md_to_mrkdwn(trends_raw) if trends_raw else ""

    report_url = f"https://github.com/{github_repo}/blob/main/{report_path}"

    blocks: list[dict] = [
        {
            "type": "header",
            "text": {"type": "plain_text", "text": f":mag: Feature Request Digest — {cycle}"},
        }
    ]
    if stats_text:
        blocks.append({"type": "section", "text": {"type": "mrkdwn", "text": stats_text}})

    if themes_text:
        blocks.append({"type": "divider"})
        for i, chunk in enumerate(chunk_for_slack(themes_text)):
            prefix = "*Themes this cycle*\n\n" if i == 0 else ""
            blocks.append(
                {"type": "section", "text": {"type": "mrkdwn", "text": prefix + chunk}}
            )

    if trends_text:
        blocks.append({"type": "divider"})
        blocks.append(
            {
                "type": "section",
                "text": {"type": "mrkdwn", "text": f"*Trends*\n\n{trends_text}"},
            }
        )

    blocks.append(
        {
            "type": "context",
            "elements": [{"type": "mrkdwn", "text": f"<{report_url}|Full report on GitHub>"}],
        }
    )

    payload = {
        "text": f"Feature Request Digest — {cycle}",
        "blocks": blocks,
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        webhook, data=data, headers={"Content-Type": "application/json"}, method="POST"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            print(f"Slack HTTP: {resp.status}")
            print(body)
        return 0
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace") if e.fp else ""
        print(f"Slack HTTP: {e.code}", file=sys.stderr)
        print(body, file=sys.stderr)
        return 1
    except urllib.error.URLError as e:
        print(f"::error::Could not reach Slack: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
