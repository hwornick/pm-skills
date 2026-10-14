# jira-triage

**Turn a few hundred open Jira tickets into a short, bucketed, linkable report you can act on:
what's actually urgent, what's worth fixing as a set, what to park, and what to close.**

## Why this exists

Every long-lived Jira project turns into a pile: support escalations, half-fixed bugs, and
duplicates nobody linked. The backlog view can't tell you which of 300 tickets matter, and
reading them yourself takes days. A one-shot "summarize this query" prompt fails too: the raw
ticket payloads blow past the model's context window long before the comments, which hold the
"actually this was fixed in March" signal, get read.

This skill encodes a method that scales:

- **Fan out, then judge.** Parallel subagents each read ~20 tickets in full (comments,
  repro fields, support-ticket counts, links) and write compact triage records to disk. The
  main agent keeps only those records and makes the final call, so it can see the whole set
  at once.
- **Never read oversized payloads into context.** Jira search results routinely exceed the
  MCP tool's token cap and get saved to a file; the skill shrinks them with `jq` instead.
- **Coverage is non-negotiable.** Every ticket in the query appears exactly once in the
  report, and a validation step diffs the report against the query to prove it.
- **"Urgent" stays small.** A synthesis pass demotes the revenue-*adjacent*, applies your
  org's scope rules (deprioritized scopes, rare views), collapses duplicates, and groups the
  real urgents into workstreams. If you have 15 urgents, the pass isn't done.
- **It survives a known MCP quirk.** Some Jira MCP endpoints occasionally return a
  *different* issue than the key you asked for. The subagents check every key and re-fetch.

## What it produces

A markdown report: an exec summary (count table + the 2–4 themes that matter), then every
ticket under one of five buckets (🔴 urgent, 🟠 important, 🟡 backlog, ⚪ close, ⚙️ ignore) with a
link and a one-line rationale. Important is grouped by theme, backlog by app area, and close
splits "already fixed" from "verify first". A caveats appendix covers method and coverage. It
makes **no changes to Jira**.

## How to use

1. **Fill in [`references/org-context.md`](references/org-context.md)** once: your Jira site,
   custom-field IDs, revenue paths, high-traffic areas, and the scope rules your team uses.
   This is what turns generic buckets into *your* priorities.
2. Make sure the Atlassian MCP server is connected and `jq` is installed.
3. Invoke it with a JQL query, e.g. *"triage `project = SUPPORT AND statusCategory != Done`"*.
4. It pulls the set, fans out the enrichment, runs the synthesis pass, writes
   `./<PROJECT>-triage-<date>.md`, and validates coverage.

The full workflow is in [`SKILL.md`](SKILL.md); the subagent prompt and report skeleton are
in [`assets/`](assets/); the `jq` helpers are in
[`scripts/jira_triage_helpers.sh`](scripts/jira_triage_helpers.sh).
