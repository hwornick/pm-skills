# Enrichment subagent prompt template

Spawn one `general-purpose` subagent per batch, all in a single message so they run concurrently.
Fill in the `{{PLACEHOLDERS}}` before sending. Paste the org context block from
`references/org-context.md` into `{{ORG_CONTEXT}}` so the agent judges severity correctly.

---

You are triaging Jira tickets for {{ORG_NAME}}.

{{ORG_CONTEXT}}
<!-- ^ what the product is, its revenue paths, high-traffic areas, and scope de-prioritizers -->

## Your input
Read this file — each line is one ticket (key, type, status, priority, created, updated, duedate, parent, labels, summary, description). This is your list (~20 tickets):
`{{BATCH_FILE}}`

## Load tools first
Call ToolSearch ONCE: `select:mcp__<SERVER>__getJiraIssue,mcp__<SERVER>__getJiraIssueRemoteIssueLinks`
cloudId: `{{CLOUD_ID}}`

## Field-ID map (this instance)
{{FIELD_MAP}}
<!-- e.g. customfield_NNNNN=Support Ticket Count, customfield_NNNNN=Support Ticket IDs,
     customfield_NNNNN=Team, customfield_NNNNN=Expected, customfield_NNNNN=Steps, customfield_NNNNN=Actual -->

## For EACH ticket in the batch file
Call `getJiraIssue` with `issueIdOrKey=<key>`, `responseContentFormat="markdown"`, and
`fields: ["comment","issuelinks","status","updated","created","duedate","watches", <the custom-field IDs above>]`.

**Verify the returned `key` matches the key you requested.** This Jira MCP intermittently returns a
different (recently-viewed) issue. On mismatch, re-fetch that key individually until it matches (up to
~3 tries). If it never matches, classify from the batch-file/description data alone and put "fetch failed"
in `latestSignal`.

Only if `issuelinks` is non-empty OR a comment mentions a PR/GitHub/deploy/fix, also call
`getJiraIssueRemoteIssueLinks` for dev/PR links. Otherwise skip it to save time.

Read: summary, description, expected/actual/steps, ALL comments (especially the LATEST — look for
"fixed / deployed / can't reproduce / duplicate of X / won't fix / works now / PR" signals), the
support-ticket count (>1 = broader pain), created/updated dates, and status. Note if attachments
(images/videos) are referenced but do NOT try to open them.

## Bucketing — assign each ticket ONE `proposedBucket`
- **urgent** — revenue path (purchase/checkout/payment flows, billing sync — see the org context), OR severe
  (data loss/corruption, security, wrong data shown to customers, broad core-workflow breakage), OR
  clearly critical but lost. Be selective — expect few.
- **important** — friction on popular/high-traffic areas, OR a visible/embarrassing glitch on the sales-demo
  path. Escalated tickets with real friction lean here.
- **backlog** — keep open, revisit later; lower impact, niche, edge-case, feature not under active work.
- **close** — likely fixed / In QA / not reproducible / confirmed duplicate / area no longer exists.
- **ignore** — Platform/infra: vulnerabilities, dependency/version upgrades, migrations, flaky tests,
  error-monitoring config. Not user-facing. BUT respect the org context's UP-prioritizers above: some
  infra-looking work (e.g. temporary feature-flag archival, product-analytics pipeline issues)
  is **important**, not ignore. When unsure between ignore and important for internal-hygiene work,
  choose **important** and note it in the rationale.

When torn between important and backlog, decide by how visible/frequent the friction is in everyday use.
Use judgment; don't default everything to backlog.

## Output
Write a JSON array to `{{OUTPUT_FILE}}`. One object per ticket, EXACTLY these keys:
```
{
  "key": "PROJ-XXXX",
  "summary": "<=12-word condensed summary",
  "type": "Bug|Task|Story|...",
  "status": "<status name>",
  "team": "<owning team or null>",
  "appArea": "<best-fit area from the org's high-traffic list, or 'Other'>",
  "created": "YYYY-MM",
  "updated": "YYYY-MM",
  "supportTicketCount": <int or 0>,
  "commentCount": <int>,
  "latestSignal": "<short phrase: 'no comments' | 'comment says fixed in PR' | 'cant repro' | 'duplicate of PROJ-x' | 'still open, users complaining' | 'fetch failed'>",
  "devSignal": "<'none' | 'in QA' | 'in progress' | 'PR referenced' | 'linked to PROJ-x'>",
  "severity": "<one line: what breaks and who it affects>",
  "revenueImpact": true|false,
  "demoRisk": true|false,
  "proposedBucket": "urgent|important|backlog|close|ignore",
  "rationale": "<1-2 sentences justifying the bucket>"
}
```
Return ONLY a short confirmation: how many tickets you processed and the count per proposedBucket. Do NOT
paste the JSON in your reply — it's saved to the file.
