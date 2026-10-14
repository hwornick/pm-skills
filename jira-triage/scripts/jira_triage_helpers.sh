#!/usr/bin/env bash
# Helper commands for the jira-triage skill. These are copy/paste snippets, not a single
# entrypoint — run the pieces you need. They assume `jq` is available.
#
# WHY: searchJiraIssuesUsingJql and getJiraIssue responses routinely blow the MCP token cap
# and get written to a file. Never read those raw files into context — jq them into compact
# JSONL and work from that.

set -euo pipefail

# Label your support team adds when escalating a ticket to engineering (shown in the digest).
ESCALATED_LABEL="${ESCALATED_LABEL:-escalated}"

# ---------------------------------------------------------------------------
# 1) Extract one saved search-result page to compact JSONL.
#    $1 = path to the saved tool-result file (from the token-limit error message)
#    $2 = output .jsonl path
#    Appends nothing to context; keeps only the fields that carry triage signal.
extract_page () {
  local SRC="$1" OUT="$2"
  jq -c '.issues.nodes[] | {
    key,
    type:     .fields.issuetype.name,
    status:   .fields.status.name,
    cat:      .fields.status.statusCategory.name,
    priority: .fields.priority.name,
    created:  .fields.created,
    updated:  .fields.updated,
    duedate:  .fields.duedate,
    parent:   (.fields.parent.key // null),
    labels:   .fields.labels,
    summary:  .fields.summary,
    description: .fields.description
  }' "$SRC" >> "$OUT"
}

# Grab the pagination cursor / whether more pages exist:
#   jq '.issues.pageInfo' "$SRC"
# Re-call searchJiraIssuesUsingJql with nextPageToken=<endCursor> until hasNextPage=false,
# calling extract_page for each page into the SAME $OUT file.

# ---------------------------------------------------------------------------
# 2) Quick landscape of the combined set.
#    $1 = combined all.jsonl
summarize () {
  local ALL="$1"
  echo "total: $(wc -l < "$ALL")"
  echo "--- dup keys (should be empty) ---"; jq -r '.key' "$ALL" | sort | uniq -d
  echo "--- by type ---";     jq -r '.type'     "$ALL" | sort | uniq -c
  echo "--- by status ---";   jq -r '.status'   "$ALL" | sort | uniq -c
  echo "--- by priority ---"; jq -r '.priority' "$ALL" | sort | uniq -c
  echo "--- created range ---"; jq -r '.created[0:10]' "$ALL" | sort | (head -1; tail -1)
  echo "--- updated range ---"; jq -r '.updated[0:10]' "$ALL" | sort | (head -1; tail -1)
  echo "--- top labels ---";  jq -r '.labels[]?' "$ALL" | sort | uniq -c | sort -rn | head -20
}

# ---------------------------------------------------------------------------
# 3) Human-readable digest to read yourself (summaries + truncated descriptions).
#    $1 = all.jsonl  $2 = digest.txt
digest () {
  local ALL="$1" OUT="$2"
  jq -r --arg esc "$ESCALATED_LABEL" '"\n===== \(.key) [\(.type)/\(.status)] esc=\((.labels|index($esc))!=null) created=\(.created[0:10]) updated=\(.updated[0:10]) parent=\(.parent // "-") =====\nSUM: \(.summary)\nDESC: \((.description // "")|gsub("\n";" ")|.[0:900])"' "$ALL" > "$OUT"
  echo "wrote $OUT ($(wc -l < "$OUT") lines)"
}

# ---------------------------------------------------------------------------
# 4) Split into batches of ~20 for parallel subagents.
#    $1 = all.jsonl  $2 = batches dir
make_batches () {
  local ALL="$1" DIR="$2"
  mkdir -p "$DIR"
  split -d -l 20 "$ALL" "$DIR/batch"
  local i=0
  for f in "$DIR"/batch[0-9]*; do mv "$f" "$DIR/batch${i}.jsonl"; i=$((i+1)); done
  echo "batches:"; for f in "$DIR"/batch*.jsonl; do echo "  $f: $(wc -l < "$f") tickets"; done
}

# ---------------------------------------------------------------------------
# 5) Merge subagent results and VALIDATE full coverage.
#    $1 = results dir (batch0.json..batchN.json)  $2 = all.jsonl (source of truth)  $3 = merged.json out
merge_validate () {
  local RES="$1" ALL="$2" OUT="$3"
  jq -s 'add' "$RES"/batch*.json > "$OUT"
  echo "merged records: $(jq 'length' "$OUT")   query tickets: $(wc -l < "$ALL")"
  echo "--- duplicate keys in merged (should be empty) ---"
  jq -r '.[].key' "$OUT" | sort | uniq -d
  echo "--- MISSING from merged (query keys not classified — MUST be empty) ---"
  comm -23 <(jq -r '.key' "$ALL" | sort -u) <(jq -r '.[].key' "$OUT" | sort -u)
  echo "--- bucket distribution (subagents' proposal, before your synthesis) ---"
  jq -r '.[].proposedBucket' "$OUT" | sort | uniq -c
}

# ---------------------------------------------------------------------------
# 6) Dump merged records for a bucket, for your synthesis read.
#    $1 = merged.json  $2 = bucket name
show_bucket () {
  jq -r --arg b "$2" '.[] | select(.proposedBucket==$b) |
    "\n[\(.key)] \(.type)/\(.status) | area=\(.appArea) | ST=\(.supportTicketCount) cmts=\(.commentCount) | rev=\(.revenueImpact) demo=\(.demoRisk) | \(.created)->\(.updated)\n  \(.summary)\n  SEV: \(.severity)\n  SIGNAL: \(.latestSignal) | DEV: \(.devSignal)\n  WHY: \(.rationale)"' "$1"
}

# ---------------------------------------------------------------------------
# 7) Validate the finished report contains every key.
#    $1 = report.md  $2 = all.jsonl  $3 = project prefix (e.g. SUPPORT)
validate_report () {
  local DOC="$1" ALL="$2" PFX="$3"
  echo "--- query keys NOT in report (must be empty) ---"
  comm -23 <(jq -r '.key' "$ALL" | sort -u) <(grep -oE "${PFX}-[0-9]+" "$DOC" | sort -u)
  echo "--- keys in report but NOT in query (cross-refs to closed tickets are OK) ---"
  comm -13 <(jq -r '.key' "$ALL" | sort -u) <(grep -oE "${PFX}-[0-9]+" "$DOC" | sort -u)
}

echo "jira-triage helpers loaded. Functions: extract_page summarize digest make_batches merge_validate show_bucket validate_report"
