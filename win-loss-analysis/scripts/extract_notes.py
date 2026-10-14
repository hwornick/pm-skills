#!/usr/bin/env python3
"""Extract the notes section of a customer account-notes doc (everything above the transcripts).

Usage:
    python3 extract_notes.py <path> [--max-chars N] [--cut-heading TEXT]

<path> is either a file your doc connector saved a large read result to (JSON with a
"fileContent" key) or a plain-text / markdown dump of the doc.

Many teams keep one running doc per customer: a header of links and template tables, then
dated call notes (newest first), then a big "Transcripts" section of raw meeting
transcripts. The transcripts are usually most of the doc and mostly repeat the notes, so
this script cuts at the first heading matching --cut-heading (default: "transcripts").

Prints a short header (total chars, notes chars, whether the cut heading was found, the
date markers spotted, in doc order), then the notes text with link-only lines,
struck-through checklist items, and runs of blank lines removed.
"""
import argparse
import json
import re
import sys

DATE_RES = [
    re.compile(r"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.? \d{1,2},? \d{4}\b"),
    re.compile(r"\b\d{1,2}/\d{1,2}/\d{2,4}\b"),
    re.compile(r"\b\d{1,2}\.\d{1,2}\.\d{2,4}\b"),
    re.compile(r"\b\d{4}-\d{2}-\d{2}\b"),
]

# Lines that are only a markdown link (dashboard / CRM / admin links in the doc header).
LINK_ONLY_RE = re.compile(r"^\s*(\*\*[^*]*\*\*)?\s*\[[^\]]*\]\([^)]*\)\s*$")
STRUCK_RE = re.compile(r"~~.*?~~")


def cut_heading_re(text: str) -> re.Pattern:
    # Markdown heading of any level, tolerant of bold markers and case: "# Transcripts",
    # "## transcripts", "# **Transcripts** **".
    return re.compile(
        r"^[ \t]*#{1,6}[ \t]*\**[ \t]*" + re.escape(text) + r"s?\b",
        re.IGNORECASE | re.MULTILINE,
    )


def load_text(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        raw = f.read()
    try:
        data = json.loads(raw)
    except ValueError:
        return raw
    if isinstance(data, dict) and "fileContent" in data:
        return data["fileContent"]
    return raw


def clean(notes: str) -> str:
    out = []
    for line in notes.splitlines():
        if LINK_ONLY_RE.match(line):
            continue
        out.append(STRUCK_RE.sub("", line).rstrip())
    text = "\n".join(out)
    return re.sub(r"\n\s*\n(\s*\n)+", "\n\n", text).strip()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--max-chars", type=int, default=0, help="truncate notes output (0 = no limit)")
    ap.add_argument("--cut-heading", default="transcript",
                    help='heading text where the notes end (default: "transcript", matches "Transcripts")')
    args = ap.parse_args()

    text = load_text(args.path)
    m = cut_heading_re(args.cut_heading).search(text)
    notes = text[: m.start()] if m else text
    cleaned = clean(notes)

    seen = []
    for rx in DATE_RES:
        for d in rx.finditer(notes):
            if d.group(0) not in seen:
                seen.append(d.group(0))

    print(f"total_chars={len(text)} notes_chars={len(notes)} cleaned_chars={len(cleaned)} "
          f"cut_heading_found={'yes' if m else 'no'}")
    print(f"date_markers (first 15): {', '.join(seen[:15]) or 'none'}")
    print("-" * 60)
    if args.max_chars and len(cleaned) > args.max_chars:
        print(cleaned[: args.max_chars])
        print(f"\n[... truncated at {args.max_chars} chars]")
    else:
        print(cleaned)


if __name__ == "__main__":
    sys.exit(main())
