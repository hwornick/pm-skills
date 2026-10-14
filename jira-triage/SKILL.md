---
name: jira-triage
description: >-
  Review, triage, and bucket a large set of open Jira tickets from a caller-supplied JQL query into
  urgent / important / backlog / close / ignore, then write a local markdown report that lists every
  ticket with a link and its bucket. Use this whenever the user wants to make sense of a Jira project's
  open issues at scale — "triage the SUPPORT backlog", "group these tickets", "what's actually urgent in
  PROJECT-X", "help me clean up our Jira", "bucket everything in this query", backlog grooming, or any
  request that involves reading many Jira issues (dozens to a few hundred) and sorting them by priority
  or theme. Triggers even when the user names a different project or gives their own JQL — the query,
  project, and output path are all parameters.
---

# Jira Triage

Turn a big, messy pile of open Jira tickets into a prioritized, bucketed markdown report the user can act on and edit. The work is too large for one context window to read every ticket's comments/dev-history directly, so the core trick is **fan out to parallel subagents for the heavy per-ticket reading, and keep only compact triage records in the main context for the final judgment call.**

Read this whole file first, then load `references/org-context.md` for the org-specific knobs (custom-field IDs, revenue paths, app areas, scope de-prioritizers). That file ships as a fill-in template: if it still has unfilled `<placeholders>`, fill it in with the user before the first run (it takes ten minutes and makes every later run sharper), or fall back to the generic bucket definitions below and say so in the report.

## Parameters (confirm with the user if unstated)

- **JQL** — the query defining the ticket set (required). The user usually supplies this verbatim; use it exactly, don't "improve" it.
- **Site / cloudId** — from `references/org-context.md`; otherwise resolve via `getAccessibleAtlassianResources`.
- **Output path** — defaults to `./<PROJECT>-triage-<YYYY-MM-DD>.md` in the working directory. The report is a file the user will edit, not chat output — always write it to disk unless told otherwise.
- **Scale expectation** — ask roughly how many issues to expect; it tells you if a page returned suspiciously few.

## Workflow

### 1. Load tools and resolve the site
Load the Atlassian MCP tools you'll need in one `ToolSearch` call (names are org-agnostic but the server id may differ — search by keyword if the literal names miss):
`searchJiraIssuesUsingJql`, `getJiraIssue`, `getJiraIssueRemoteIssueLinks`, `getAccessibleAtlassianResources`.
Call `getAccessibleAtlassianResources` to get the cloudId (or reuse the one in `references/org-context.md`).

### 2. Pull the full ticket set (expect token-limit-to-file)
Run `searchJiraIssuesUsingJql` with the JQL and a compact field list:
`["summary","status","issuetype","priority","created","updated","duedate","parent","labels","description"]`, `maxResults: 100`.

**These responses routinely exceed the tool's token cap and get saved to a file instead.** That's fine and expected — the error message gives you the file path. **Never** try to read the whole raw file into context. Instead use `jq` on it (see `scripts/jira_triage_helpers.sh`). Paginate with `nextPageToken` until `pageInfo.hasNextPage` is `false`, extracting each page to compact JSONL as you go, then concatenate. Sanity-check the total against the user's scale expectation.

### 3. Discover the custom-field IDs (once)
Custom-field IDs differ per Jira instance, so don't hard-code them blindly. Fetch one issue with `expand=names` and read the `names` map to find the fields that carry triage signal — typically: a **support-ticket count** and **support-ticket IDs** (fields your helpdesk integration populates when agents link tickets), **Team/Squad**, **Expected Behavior**, **Steps to Reproduce**, **Actual Behavior**. Record the `customfield_XXXXX` → label mapping; you'll hand it to the subagents. (Record your instance's IDs in `references/org-context.md`, and re-verify them each run rather than trusting them — they drift.)

### 4. Build the digest and batches
With the helper script: extract the combined compact JSONL, then split into batches of ~20 tickets. Also generate a human-readable digest (summaries + truncated descriptions).

**Read the digest yourself.** The descriptions alone carry most of the signal, and reading them gives you the domain fluency to sanity-check the subagents' buckets and catch duplicates/clusters they'll miss. Do this while the subagents run — it's the best use of the wait.

### 5. Fan out enrichment subagents (one per batch, in parallel)
Spawn `general-purpose` subagents — all in a single message so they run concurrently. Give each the prompt in `assets/enrichment-agent-prompt.md`, filled in with: the batch file path, the output path (`results/batchN.json`), the cloudId, the field-ID map, and the org context block from `references/org-context.md`.

Each subagent fetches per-ticket detail (comments, support-ticket count, repro/expected/actual, issuelinks, and — only when a dev signal is hinted — remote links), extracts signals, proposes a bucket, and **writes a compact JSON array to its results file**. It returns only a short confirmation, not the JSON, so your context stays lean.

> **Known MCP quirk (important):** some Jira MCP endpoints intermittently return a *different* (recently-viewed) issue than the key requested. The subagent prompt already instructs agents to compare the returned `key` to the requested key and re-fetch on mismatch. A couple of tickets may still fail after retries — those get classified from the batch/description data alone and flagged; call this out in the report's caveats.

### 6. Merge and validate coverage
Merge the `results/batchN.json` files, then verify with the helper script: total record count matches the query, no duplicate keys, and **no key from the query is missing**. Coverage is non-negotiable — the user asked for every ticket to be examined and listed.

### 7. Synthesis pass — your judgment, not the subagents'
The subagents gather signal and propose buckets; **you make the final call.** Apply:

- **Tighten "urgent" hard.** Urgent should be *few or none*. Demote anything that's revenue-*adjacent* but narrow, config-specific, or already mitigated. Group genuinely-urgent tickets into clusters (e.g. "billing", "sync") so they read as workstreams, not scattered items.
- **Apply the org's scope de-prioritizers** from `references/org-context.md` (e.g. a bug confined to a scope your org deprioritizes → down-weight; a bug scoped only to a rare view/config → down-weight; but don't discount high-value segments). When you move something, scan the whole set for others the same logic touches and note the ones that *don't* qualify and why.
- **Collapse duplicates.** If two tickets are the same bug, say so and recommend which to keep vs close.
- **Close bar = "somewhere in between" by default.** Close on clear evidence (comment/status says fixed/deployed, confirmed duplicate, feature removed, or fix is In QA). For incident-level or high-support-volume tickets that look stale, use *close-with-verify* — tell the user what to confirm first. Don't silently close things with real customer pain.

If the user gave explicit steers (how aggressive to close, what counts as urgent), honor them over these defaults.

### 8. Write the report
Follow `assets/report-template.md`. Requirements that matter most:
- **Every ticket appears exactly once**, under its bucket, with a clickable link (`https://<site>/browse/<KEY>`), its status/signal, and a one-line rationale. Urgent items get two lines; everything else stays terse.
- Lead with an exec summary: a count table and the 2-4 themes/clusters that matter (this is what makes it actionable).
- Group `important` by theme (it's usually the biggest bucket — that's expected; it's the "aggregate friction → smoothness step-change" set). Surface a **quick-wins / demo-path** sub-group when cosmetic-but-visible bugs exist.
- Group `backlog` by app area so the user can revisit alongside the relevant feature.
- End with a **caveats appendix**: coverage stats, the MCP wrong-issue quirk and any tickets it affected, and note that you made no changes to Jira.

### 9. Validate the report
Grep the finished markdown for `<PROJECT>-\d+` keys and diff against the query's key list — confirm all are present and no stray/typo'd keys slipped in (cross-references to *closed* related tickets are fine, just don't mis-count them as classified entries).

## Bucket definitions

Generalize these against the org's revenue paths and high-traffic areas (see `references/org-context.md`):

1. **urgent** — impacts revenue (purchase, checkout, and payment flows; billing sync), OR a severe bug (data loss/corruption, security, wrong data shown to customers, broad breakage of a core workflow), OR was clearly critical but got lost. *Expect few or none.*
2. **important** — adds friction to popular/high-traffic areas, OR is a visible/embarrassing glitch on the standard sales-demo path. Individually small, collectively a noticeable "smoothness" step-change. Escalated (customer-linked) tickets with real friction lean here.
3. **backlog** — keep open, revisit later; lower impact, niche, edge-case, or tied to a feature not under active work. Group by app area.
4. **close** — likely already fixed / In QA / not reproducible / confirmed duplicate / impacts an area that no longer exists.
5. **ignore** — Platform/infra: security vulnerabilities, dependency/version upgrades, component migrations, flaky tests, error-monitoring config. Not user-facing. (If the user's query already tries to filter these out, this bucket catches the leftovers.) **Watch out:** some infra-looking work is explicitly *not* ignore — see the org's UP-prioritizers (e.g. feature-flag archival, product-analytics pipeline issues). Check `references/org-context.md` before dropping something here.

## Don't

- Don't modify Jira (no comments, labels, or transitions) unless the user explicitly asks. Deliver analysis; offer the mutations as a follow-up.
- Don't dump raw search results or full `getJiraIssue` payloads into your context — they blow the token cap. Route through files + `jq` + subagents.
- Don't let "urgent" bloat. If you have 15 urgents, you haven't finished the synthesis pass.
