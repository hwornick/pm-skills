---
name: feature-request-digest
description: Produce a monthly (or any-window) digest of feature-request activity from an issue tracker — new tickets, newly-commented tickets, customer references, optional account-value lookup, theme clustering, and cross-cycle trend comparison. Use when the user asks for a "feature request digest", "feature request roundup", "what feature requests came in", "product feedback digest", or a recurring summary of an issue-tracker project that collects feature requests.
---

# Feature Request Digest

This skill turns raw feature-request tickets into an intelligence digest: what's new,
what's heating up, which customers are asking, and how much revenue sits behind the asks.
It runs on demand for a date window; to schedule it (cron + auto-publish + Slack), see
`references/automation.md`.

Each run is independent — it derives trends by reading prior reports, not from memory.

## Configure your sources

- **Issue tracker** — a project that collects feature requests, referenced by
  `<PROJECT_KEY>` (e.g. a Jira project key, a Linear team, or a GitHub Issues label).
  The skill is tracker-agnostic; the Jira JQL below is one concrete example. For Linear
  or GitHub Issues, swap in the equivalent query (by team/label, filtered on
  created/updated in the window).
- **(Optional) Data warehouse** — for the customer-ARR lookup in step 5. If you have no
  warehouse, skip step 5; the digest still produces themes, trends, and ticket detail.
- **Prior reports** — a directory of past cycle reports (one markdown file per cycle,
  named `YYYY-MM.md`) used for the cross-cycle comparison in step 6.

## 1. Determine the reporting window

Compute (in your local timezone):
- `report_month` = the prior calendar month (or whatever window the user asks for).
- `window_start` = first day of the window, 00:00:00
- `window_end`   = first day of the following month, 00:00:00
- `cycle_label`  = `YYYY-MM` for `report_month` (used as the report filename)

## 2. Query the tracker

Pull every ticket in `<PROJECT_KEY>` created OR updated in the window. Example Jira JQL:

```
project = <PROJECT_KEY>
AND (
  (created  >= "<window_start>" AND created  < "<window_end>")
  OR (updated >= "<window_start>" AND updated < "<window_end>")
)
ORDER BY updated DESC
```

Page through all results. For each issue, fetch (with comments + changelog expanded):
- key, summary, status, issue type, reporter, assignee
- created timestamp
- description (plain text)
- full comments list (author, created timestamp, body)

## 3. Classify each ticket

- **`new`** — `created` is within the window
- **`commented`** — `created` is before the window AND ≥1 comment has `created` within the
  window. Record `prior_comment_count` (comments before window) and `new_comment_count`
  (comments in window).
- **`stale_update`** — updated in window but neither of the above (likely a field-only
  change). De-prioritize: count only, no content.

## 4. Extract customer references

For each `new` and `commented` ticket, scan the description (new) or new comments
(commented) and extract candidate customer names. Customer-facing teams typically name
accounts as proper nouns ("the team at `<Customer>`", "`<Customer>` reached out"). Build
`(ticket_key → [customer_names])` and a deduped global set of unique customer names
referenced this cycle.

## 5. (Optional) Customer ARR / account-value lookup

*(Skip this step if you have no data warehouse.)*

Map each unique customer name to an account value with a TWO-STEP lookup. Do NOT join the
customer dimension to the transaction fact directly — the dimension has one row per
customer unit, so the join fans the fact table out and inflates the total.

### 5a. Resolve each unique customer name → org id (fuzzy match)

For each unique customer name, fuzzy-match it against the customer dimension. Example
(Snowflake `JAROWINKLER_SIMILARITY`; adapt to your engine):

```sql
WITH candidates AS (
  SELECT DISTINCT
    org_id,
    org_name,
    GREATEST(
      COALESCE(JAROWINKLER_SIMILARITY(LOWER(org_name), LOWER(:name)), 0),
      CASE WHEN LOWER(org_name) LIKE '%' || LOWER(:name) || '%' THEN 90 ELSE 0 END
    ) AS score
  FROM analytics.dim_customers
  WHERE org_id IS NOT NULL
)
SELECT org_id, org_name, score
FROM candidates
WHERE score >= 80
QUALIFY ROW_NUMBER() OVER (PARTITION BY org_id ORDER BY score DESC) = 1
ORDER BY score DESC
LIMIT 5;
```

Acceptance:
- Top score ≥ 90 → accept top match
- 80 ≤ top score < 90 AND (top − second) ≥ 10 → accept top match
- Otherwise → mark as **unresolved** (still listed in the report under "Unresolved
  customer references"; no ARR)

### 5b. Trailing-365d value for resolved orgs (batched)

```sql
SELECT
  org_id,
  COALESCE(SUM(transaction_margin), 0) AS annual_value
FROM analytics.fact_transactions
WHERE org_id IN (<comma-separated list>)
  AND transaction_date >= DATEADD('day', -364, CURRENT_DATE())
  AND transaction_date <  DATEADD('day',    1, CURRENT_DATE())
GROUP BY org_id;
```

Join results back to your `customer_name → org_id` map locally. (Swap
`transaction_margin` for ARR/revenue or whatever annualized value fits your business.)

## 6. Theme clustering (this cycle)

Cluster ticket content (descriptions for `new`, new comments for `commented`) into
**3–7 themes**. For each theme:
- Short name (e.g. "SSO / SAML support", "Bulk CSV export")
- One-line description of the underlying need
- Ticket keys
- Customer names in the cluster (resolved + unresolved)
- Total comment volume
- **Ticket count** (the number of `new` + `commented` tickets clustered in this theme)

**Sort themes by ticket count, descending** (biggest cluster first). When two themes tie
on count, sort by number of distinct customers referenced (descending).

## 7. Cross-cycle comparison

Read prior reports from the cycle-reports directory, sorted descending by filename (most
recent first). Use up to the **last 3 cycles**.

For each theme this cycle:
- `RECURRING` if a meaningfully-similar theme appears in any of the last 3 cycle reports —
  cite which cycle(s)
- `NEW` otherwise

Also identify:
- **Faded:** themes in the last 2–3 cycles, absent this cycle
- **Heating up:** themes in this cycle AND the immediately prior cycle, with more
  tickets/customers this cycle than last

If zero prior reports exist (first run), skip this section and note "First cycle on record."

## 8. Write the report

Write to `<cycle-reports-dir>/<cycle_label>.md` with this structure:

```markdown
# Feature Request Digest — <cycle_label>
_Generated <today's date>_

## Headline stats
- Tickets created: <n>
- Tickets updated (new comments): <n>
- Stale-only updates: <n>
- Total new comments added: <n>
- Unique customers referenced: <n>

## Customer ARR exposure (trailing 365 days)
| Customer | Matched org | Annual value |
|---|---|---|
| <name> | <org_name> | $<n> |
(sorted descending by annual_value)

**Unresolved customer references:** <names> (or "none")
**Total exposure this cycle:** $<sum>

(Omit this whole section if you skipped step 5.)

## Themes this cycle

(Emit themes in descending order of ticket count. Each theme heading carries the cluster
size in `[N tickets]` so readers can rank at a glance.)

### <Theme name> [<N> tickets] — [NEW | RECURRING (cf. 2026-03)]
- **Need:** <one-line>
- **Tickets:** <PREFIX>-123, <PREFIX>-456
- **Customers:** <Customer A>, <Customer B>
- **Comments added this cycle:** <n>
- **Notes:** <2–3 sentence intelligence summary>

(repeat per theme, largest ticket-count first)

## Trends
- **Recurring:** <theme> (also in 2026-03, 2026-02)
- **Heating up:** <theme> — 5 tickets this cycle vs 2 last cycle
- **Faded:** <theme> last seen 2026-02

## Ticket detail

### New this cycle
- **<PREFIX>-123** _<summary>_ — customer: <Customer A>. <2-sentence content summary>

### Updated this cycle (new comments)
- **<PREFIX>-456** _<summary>_ — prior comments: 4, new this cycle: 2. Customer: <Customer B>. <what's new in 1-2 sentences>

### Stale-only updates
- <PREFIX>-789 (1 stale update — no new content)
(list keys only)
```

## 9. Done

Print the path to the report and a one-line summary. If you want this to run on a schedule
and auto-publish to Slack, see `references/automation.md`.
