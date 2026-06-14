---
name: win-loss-analysis
description: Generate a quarterly win/loss report for the prior complete quarter. Pulls CRM opportunity counts and ARR (split into Acquisition and Retention), product-usage activity from won logos, subscription-tier breakdowns, and loss-text clustering from a data warehouse. Use when the user says "win/loss report", "quarterly win loss", or invokes /win-loss-analysis.
---

# Quarterly Win/Loss Report

This skill assembles a quarterly win/loss report for a B2B SaaS business. The output is
markdown matching `template.md`. It is built for a CRM (opportunities + accounts) landed
in a data warehouse, with optional product-usage and subscription facts for measuring
how won logos actually adopt the product.

The report has two top-level sections — **Acquisition** (new logos) and **Retention**
(renewals). ARR (deal value) is the single revenue metric throughout.

## How to invoke

The user will typically say one of:
- "generate the quarterly win/loss report"
- "win/loss report for Q1 2026"
- `/win-loss-analysis`

If no quarter is specified, default to the **prior complete quarter** based on today's date.

## Configure your data source

This skill ships with parameterized SQL in `queries/`. The queries reference generic
table and column names; map them to your warehouse before running. The defaults assume a
Snowflake warehouse reached via an MCP `run_snowflake_query` tool, but any SQL warehouse
works — adjust dialect-specific functions (`DATEADD`, `QUALIFY`, `ANY_VALUE`, `IFF`,
`COUNT_IF`) as needed.

**Connection:** set `<warehouse>` and `<role>` (or your engine's equivalent) to a
read-only analytics context.

**Tables** (schema prefix `analytics.` is a placeholder — repoint to your own):

| Placeholder | What it is |
|---|---|
| `analytics.crm_opportunities` | one row per CRM opportunity (deals) |
| `analytics.crm_accounts` | one row per CRM account |
| `analytics.crm_users` | CRM user/owner lookup |
| `analytics.fact_orders` | product-usage / transactional activity, line-item grain |
| `analytics.dim_customers` | customer/org dimension (maps usage to an org) |
| `analytics.dim_users` | end-user dimension |

**Key columns** (rename in the SQL to match your schema):

| Placeholder column | Meaning |
|---|---|
| `record_type` | opp record type, e.g. `New Logo` (acquisition) / `SaaS Renewal` (retention) |
| `amount` | opp ARR / deal value — the single revenue metric |
| `org_id` | account → org identifier that joins CRM to the warehouse dimensions |
| `is_closed`, `is_won`, `is_deleted` | standard opp flags (`is_deleted` is optional soft-delete) |
| `lost_reason_code` | single-select loss picklist (low weight — often misleading) |
| `reason_for_win_loss`, `opportunity_notes` | free-text loss signals (high weight) |
| `churn_notes`, `churn_reason` | account-level retention/churn narrative |
| `industry`, `industry_category`, `sub_category` | fields used to classify verticals/ICP |
| usage columns on `fact_orders` | `activity_id` (engagement event), `line_item_id`, `unit_price`, `unit_discount`, `quantity`, `activity_date`, `org_unit_id`, `user_unit_id` |

If you do **not** have a product-usage fact (`fact_orders`) — e.g. a pure-SaaS business
with no transactional component — skip steps 2 and 2a; the win-rate, loss-clustering,
vertical, and spreadsheet steps still work from CRM data alone.

**Optional: market segmentation.** This report is segment-agnostic by default. If you
segment your market (e.g. SMB / Mid-Market / Enterprise, or by region or industry), you can
add a segment dimension: join `crm_accounts`, add your segment column to each query's
`SELECT` and `GROUP BY`, and render the Acquisition / Retention sections once per segment.
Keep it off unless you need it — the single-cohort view is simpler and reads better.

## Inputs to determine first

1. **Quarter** — pick the prior complete quarter. Set these values once and reuse:
   - `quarter_label` — e.g. `Q1 2026`
   - `quarter_start` — first day of quarter, e.g. `2026-01-01` (inclusive)
   - `quarter_end` — first day of next quarter, e.g. `2026-04-01` (exclusive)
   - `usage_window_start` — first day of the quarter BEFORE the report quarter, e.g. `2025-10-01` for Q1 2026 (used as the product-usage activity lower bound — see step 2)
2. **Report date** — today's date in `YYYY-MM-DD`, used as the usage-window upper bound.

Substitute these into each `{{placeholder}}` in the `.sql` files before running. Read the SQL file, do a literal string replace, then pass the rendered SQL to your warehouse query tool.

## BI drill-down links

The report renders drill-down links so readers can open the underlying records in your BI
tool. Define a URL template per explore/dashboard with a filter on the org-id field, e.g.:

```
https://<your-bi-host>/explore/usage?f[org_id]={ORG_IDS}
https://<your-bi-host>/explore/subscriptions?f[org_id]={ORG_IDS}
```

After resolving the won-org list (step 2a), build a comma-separated `org_id` list and
substitute it into `{ORG_IDS}`. Populate `acq_bi_usage_url` and `acq_bi_subs_url`. If you
have no BI tool, set these placeholders to empty and drop the link markup.

## Segment definitions

| Bucket | Record type |
|---|---|
| Acquisition | `record_type = 'New Logo'` |
| Retention | `record_type = 'SaaS Renewal'` |

ARR = `opportunity.amount`.

**Pending policy:** Opps with a close date in the quarter that are *not yet closed* stay in the denominator and inflate the count as "pending". Win rate = wins / (wins + losses + pending). Do not drop them.

**Pending rendering:**
- **Acquisition:** append ` (N pending)` to the counts line when pending > 0, otherwise the inline field is empty.
- **Retention:** always render `... + N pending` inline on the counts line (even when N = 0), and render an italic `*{pct}% pending*` line directly beneath the win rate when pending > 0 (omitted when 0). See step 1 for the placeholder mapping.

## Steps

### 1. Counts + ARR (one query, fills both sections)

Run `queries/01_close_counts.sql`. Output has one row per bucket (`Acquisition`, `Retention`) with: `wins`, `losses`, `pending`, `total`, `win_rate_pct`, `won_arr`, `lost_arr`, `pending_arr`.

Fill into template:
- `acq_wins`, `acq_losses`, `acq_closed` (wins+losses), `acq_win_rate`, `acq_won_arr`, `acq_lost_arr`
- Same for `ret_*`
- **Acquisition:** `acq_pending_inline` — empty string if pending = 0, else ` (N pending)` with leading space.
- **Retention:** `ret_pending` = raw pending count (always shown inline: `... + N pending`). When pending = 0, render `+ 0 pending`.
- **Retention:** `ret_pending_pct_line` — italic line rendered beneath the win rate. When pending > 0 set it to `*{pct}% pending*` where pct = `round(100 * pending / (wins + losses + pending))`. When pending = 0 set it to an empty string so the line disappears.
- **Retention:** `ret_won_arr` (ARR renewed), `ret_arr_pct` = `round(100 * won_arr / (won_arr + lost_arr))` (ARR retention rate), `ret_churned_arr` = `lost_arr`.

`acq_arr_per_logo` = `acq_won_arr / acq_wins`, rounded to nearest $100.

### 2. Product-usage rollup for won logos

*(Skip this step if you have no product-usage fact.)*

Run `queries/03_usage_acquisition.sql`. Use `usage_window_start` (start of the *prior* quarter) as the lower bound and the report date as `report_date` (exclusive upper bound). The window starts one quarter early to catch trial/onboarding activity that precedes the won opp's close date.

Output has one row with: `active_orgs`, `users`, `usage_value`.

Fill: `acq_active_orgs`, `acq_users`, `acq_usage_value`. (`usage_value` is a product-usage
signal — how much the won logos actually transacted/used — distinct from ARR. It measures
adoption, not revenue.)

#### 2a. Per-org adoption breakdown

Run `queries/03b_usage_per_org_acquisition.sql` with the same window. Returns **one row per won org** with `account_name`, `org_id`, `engagements`, `usage_value` — zero-activity orgs included via `LEFT JOIN`.

Classify each won org into one of three buckets:

| Bucket | Condition | Meaning |
|---|---|---|
| `inactive` | `engagements = 0` | Won opp but never engaged with the product in the activity window |
| `active_not_purchasing` | `engagements > 0 AND usage_value = 0` | Engaging but no purchase/usage conversion |
| `purchasing` | `usage_value > 0` | Adopted |

Compute three counts:
- `acq_total` = total won orgs (== `acq_wins`)
- `acq_active` = count where `engagements > 0`
- `acq_purchasing` = count where `usage_value > 0`

Note `purchasing ≤ active ≤ total`.

**Build BI URLs.** Use the comma-separated list of all won-org `org_id` values from this query (skip NULLs) to populate `{ORG_IDS}` in the two BI URL templates. Set `acq_bi_usage_url`, `acq_bi_subs_url`.

**Render the callouts block** (`acq_adoption_callouts`). Rendered as additional nested bullets at the END of the usage bullet block (this position lets the placeholder safely be empty without breaking the bullet list). Build a nested-bullet block listing only the non-empty sub-buckets, indented two spaces (`  *`). Omit a line entirely when its count is 0. Do NOT include a trailing newline.

```
  * Inactive (N): Acme Co, Beta Co, Gamma Co
  * Engaging but not purchasing (M): Delta Co, Epsilon Co
```

If both sub-buckets are empty (everyone is active and purchasing), set the placeholder to an empty string. After substitution, also strip the surrounding blank line so the bullet list remains contiguous (do a `\n\n` → `\n` pass on the usage block after substitution if the placeholder was empty).

**Render the adoption summary** (`acq_adoption_summary`). One short sentence summarizing adoption, picked from these patterns based on the active / purchasing ratios (use judgment for the thresholds):

- Both active and purchasing high (≥80% of total) → "Strong adoption — most won logos are active and purchasing."
- Active high (≥80%) with low purchasing (<50%) → "Purchase conversion isn't happening — most are engaging but not buying."
- Both low (<60%) → "Adoption is weak — a large share of won logos never engaged."
- In-between → write a short bespoke sentence matching the numbers.

Validation: `acq_active` should equal `acq_active_orgs` from step 2 (both count distinct orgs with any activity in the same window). If they diverge by more than 1, surface this to the user before continuing.

### 3. Subscription tiers for won logos

Run `queries/04_subscriptions_acquisition.sql`. Each row has a `subscription_products`
string like `Standard: [Starter] Add-on: [Integration]` (adapt the parse to your own
subscription-product encoding).

Parse:
- **Tier** — extract the plan name. Example tiers: `Starter`, `Standard`, `Pro`. Tally counts.
- **Add-on** — extract add-on names. Split on commas. Tally per add-on; the report calls out paid integration add-ons specifically.
- **Integration count** = orgs with any paid integration add-on.
- Orgs with `subscription_products = NULL` are not yet subscribed — note them by name in the summary line.

Render `acq_subs_summary` as a short multi-line bullet block. Indent each line with two spaces so it nests under the "Subscription Info" parent bullet that the template renders with a BI link (`acq_bi_subs_url`). Fill `acq_integration_count`.

Example contents of `acq_subs_summary`:
```
  * 12x Starter (7 with a paid integration)
  * 1x Standard
  * 4x Pro (1 with a paid integration)
  * 1 not yet subscribed: Acme Co
```

### 4. Company research (acquisition only)

Applies only to new logos. Renewals are handled by the churn-notes path in step 6.

**Goal:** for each closed acquisition opp (won + lost) in the quarter, produce one row with: one-line description, ICP classification, funding stage, last round date/amount, employee count, public/private, and an external-factor flag. Output feeds (a) the loss segmentation block (step 5), (b) the per-loss bullets in product gaps (step 5 — `{vertical} / {funding_stage} / {employees}` tag), and (c) the always-on vertical-analysis appendix (step 8).

**Workflow:**

1. **Pull CRM context.** Run `queries/07_won_logos_for_vertical.sql` for the quarter. Already returns `industry`, `product_info`, `biggest_pain_point`, `opp_description`, `industry_category`, `sub_category`, `account_focus`.

2. **Seed ICP from CRM.** Map your CRM's `industry_category` to your ICP buckets. Define the mapping once for your business; example shape:

   | CRM category (example) | ICP bucket (example) |
   |---|---|
   | `<core_vertical_a>` | ICP — Vertical A |
   | `<core_vertical_b>` | ICP — Vertical B |
   | `<adjacent_vertical>` | ICP — Adjacent (note feature gaps) |
   | `<out_of_market_a>` | Non-ICP — Category A |
   | `<out_of_market_b>` | Non-ICP — Category B |
   | `uncategorized`, null | Run LLM step |

   **Future-shift toggle:** if exec strategy adds a new vertical to ICP, flip the bucket for that category going forward.

3. **Parallel subagent research.** Split closed acquisition opps into batches of ~10. Spawn one `general-purpose` subagent per batch with a self-contained prompt asking for the structured row per account (description, funding stage, last round date+amount, employees, public/private, source notes). Subagents use WebSearch as needed. Aim for ≤12 subagents to keep coordination simple. Concatenate the rows.

   Subagent prompt template (adapt with the batch list):

   > For each company below, return one structured row with: (1) a one-line description of what they do (industry, what they sell), (2) funding stage (Pre-seed/Seed/Series A-D/Public/Acquired/Private-PE/Bootstrapped), (3) last funding round amount + month/year if known, (4) approximate employee count (e.g. "~30" or "~5K"), (5) public/private. Use WebSearch — prioritize Crunchbase, company About pages, LinkedIn employee count, recent press. If a company is unfamiliar, say so explicitly rather than guessing. Return as a markdown table. Companies: [list].

4. **Derive external-factor flag** for each lost opp. Default is **product gap (our fault)** for acquisition losses. Promote to external factor only when there is explicit textual evidence:
   - Loss text (`lost_reason_code`, `reason_for_win_loss`, `opportunity_notes`) mentions "no budget", "lost funding", "too small", "too early", "not the right time", "pre-revenue", etc.
   - Web research confirms: company is at seed AND mentioned budget concerns, recent layoffs reported, etc.
   - Funding/size signals alone (e.g. ~5 employees, no recent round) are NOT enough — they're context, not the basis.

   Tag the row's `external_factor` field with the supporting quote/source so the report can cite it.

5. **Save** the assembled table to `research/{quarter_label}.md` for audit. No caching across quarters — every run is fresh.

**Schema:**

| Column | Notes |
|---|---|
| `opp_id` | from CRM |
| `account_name` | from CRM |
| `is_won` | from CRM |
| `description` | one line, neutral tone |
| `icp_bucket` | one of: ICP — <vertical>; Non-ICP — <category>; Unknown |
| `funding_stage` | Pre-seed / Seed / Series A..D / Public / Private-PE / Acquired / Bootstrapped / Unknown |
| `last_round` | "$30M (Mar 2024)" or "—" |
| `employees` | "~30" or "~5K" or "Unknown" |
| `is_public` | Public / Private / Acquired |
| `external_factor` | null OR `{flag}: {quote from loss text}` |
| `sources` | brief citation list |

### 5. Loss theme grouping (acquisition)

Run `queries/05_loss_text_acquisition.sql`. This is the most analytical step in the report — slow down here. The goal is not to summarize what reps wrote but to understand the **WHY** behind each loss, looking past surface-level objections.

#### Analysis approach (two passes)

**Pass 1: per-loss analysis.** For every lost opp, read all signals together:
- `lost_reason_code` (single-select picklist — **low weight, often misleading**)
- `reason_for_win_loss` (free text — high weight)
- `opportunity_notes` (free text — high weight)
- Company research row (step 4) — funding, stage, size, public/private

For each loss, determine:
- **Surface reason** — what the rep recorded
- **Underlying reason** — what actually drove the loss decision (may or may not match surface)
- **Primary category** — Product Gap / Positioning-GTM Gap / Other-External
- **Product area** (if applicable) — map to your own product surfaces (e.g. Reporting & Analytics / Integrations & API / Access Control & Admin / Collaboration / Pricing-Packaging / Mobile / Other)

Critical-thinking criteria for distinguishing surface from underlying:

| Surface reason | Treat as external (truthful) when... | Treat as our issue (excuse) when... |
|---|---|---|
| "No budget / lost funding" | Company research shows recent layoffs, no funding in >24mo, pre-revenue with no runway, or loss text explicitly cites a funding event | Company recently raised, well-funded for size, OR price was discussed but value-prop wasn't conveyed clearly in the notes |
| "Too small (2-3 employees)" | Pre-product / solo founder / not yet a real buyer | Functional team of 5-10 using free tools — we didn't show value at their scale |
| "Switching to X / chose competitor" | Always our issue — note which competitor and why they won. Could be product gap or positioning gap. | (always) |
| "DIY / internal tool" | Always external-ish — flag as "Other" | If notes show we never engaged with the buyer's actual workflow, treat as positioning gap |
| "Not the right time" | Specific blocker mentioned (e.g. ERP migration, M&A in flight) | Generic — usually means we didn't establish urgency |

A loss can have multiple contributing reasons. Pick the **one with the most weight in the decision** as the primary; mention others as secondary in the per-loss summary.

**Pass 2: aggregate analysis.** Look for overlap within each product area:
- For each area with ≥3 losses, ask: are these the **same** pain point, **similar** pain points (e.g. 3 features that are really 1 complete solution), or **distinct** features? This is the difference between "build 1 thing, win 5 deals" and "build 5 things, win 5 deals."
- Quantify overlap explicitly in the output: e.g. *"6 reporting losses; 4 cluster on one coherent feature set (high signal); 2 are reporting-only evals (lower signal)."*

#### Output structure for `acq_loss_themes`

Three top-level sections matching the three lenses. Within Product Gaps, group by product area. Per-loss bullets stay but each gets a one-line analytical lead (surface → underlying).

**Per-loss bullet format.** End each per-loss bullet with a company-context tag drawn from the research table (step 4): `{vertical} / {funding_stage} / {employees}`. Vertical = `icp_bucket` (drop the `ICP — ` / `Non-ICP — ` prefix when rendering, just keep the name). Drop ARR — it carried less context than the company snapshot. If any of the three values is "Unknown" or null, omit it (e.g. `Vertical A / ~75 employees` when funding stage is unknown). If all three are unknown, omit the trailing tag entirely.

```
**Product Topics from Losses**

[2-3 sentence overall synthesis. What's the WHY this quarter? Which lens dominates?
 Example: "Reporting is the highest-signal area this quarter with 6 of 40 losses clustering on
 a coherent feature set. Integration losses are more distributed across distinct features (lower
 signal). Several losses appear to be positioning failures rather than product gaps."]

* **Product Gaps** — where the data points to needed builds

  * *Reporting & Analytics* — 6 losses; 4 cluster on one coherent feature set (high signal); 2 reporting-only evals
    * Acme Co: wanted custom dashboards + scheduled exports — Vertical A / Public / ~5K employees
    * Beta Co: wanted drill-down on a core metric — Vertical B / Private-PE / ~120 employees
    * ...

  * *Integrations & API* — 4 losses across distinct features (a specific connector, webhooks, ...). Less concentrated signal — each loss points to a different gap.
    * Gamma Co: surface "evaluating as enterprise"; underlying — looked like a great fit, possible exec/political block — Vertical A / Public / ~400 employees
    * Delta Co: needed a connector we don't have — Vertical B / Series B / ~75 employees

  * *Core Workflow* — 2 losses; a specific multi-step flow
    * Epsilon Co: surface "workflow clunky"; underlying — feature exists but wasn't positioned for this use case — Vertical A / Series A / ~25 employees
    * Zeta Co: needed bulk actions — Vertical A / Private / ~50 employees

* **Positioning / GTM Gaps** — where the data points to messaging, pitch, packaging, or process

  * *Pricing perception* — 3 losses citing alternative pricing (Acme Co, Beta Co, Gamma Co). Probably value-comm not actual pricing.
  * *Packaging* — Delta Co balked at the per-seat fee at their scale. May need a different tier.
  * *Trial conversion* — N losses where a free trial concluded without buyer commitment, suggesting trial-to-paid handoff is weak.

* **Other / External** — outside our direct control, or where loss-text evidence supports external attribution

  * *DIY / internal tools*: Epsilon Co, Zeta Co chose internal systems
  * *Geographic scope*: Eta Co needs a region we don't serve
  * *Acquisitions / M&A in flight*: …
  * *Genuine budget*: …  (per the critical-thinking criteria above)
```

**Loss segmentation block (rendered above Product Topics).** Render `acq_loss_segmentation` as:
- `* X non-ICP opps in [industries]` — losses where `icp_bucket` starts with `Non-ICP` (from company research)
- `* Y deals attributed to external factors` — losses categorized as Other/External in pass 1
- `* That leaves Z deals where we probably had a real shot` — losses in Product Gaps + Positioning. These are the ones analyzed in detail in Product Topics.

### 6. Loss theme grouping (retention / churn)

Run `queries/06_loss_text_retention.sql`. Returns one row per lost renewal with churn notes and `lost_arr`, sorted by lost ARR descending.

**Framing for retention losses:** unlike acquisition, "business change" (company shutting down, acquired, ran out of funding, pivoted) is **common and expected**. The default attribution for a retention loss is business change if the churn notes support it. **Don't go as deep as acquisition** — no three-lens framework, no company research. Web research only if churn notes are too vague to extract a destination or reason.

**Required callouts:**

1. **High-value churn** — call out the top 3 lost accounts by `lost_arr`. These are flagged as **follow-up research targets** — the biggest revenue losses of the quarter deserve a "did we really understand why we lost them?" review later. Render at the top of the loss themes section as:

   ```
   **High-value churn — flagged for follow-up research:**
   * <Account>: $XXk ARR lost. Stated reason: "<short paraphrase of churn notes>"
   ```

2. **Switching destinations** — when churn notes name the system the customer is switching to (a competitor, a generic spreadsheet, an internal/custom build, etc.), call it out explicitly with the destination. This is the most useful competitive signal in the report.

**Output structure for `ret_loss_themes`** (with high-value callout added):

```
**High-value churn — flagged for follow-up research:**
* <Account>: $XXk ARR. Stated reason: ...
* ...

**Loss reasons:**
* N due to business change: <names>  — company shut down, acquired, ran out of funding, etc.
* N switching systems:
  * <Account> → competitor
  * <Account> → spreadsheet
  * <Account> → internal system
* N other — catch-all when needed.
```

Don't elaborate beyond what the churn notes say — for retention, terse is better.

### 7. Churn Risk

Leave blank — the user writes this section by hand. Render the `# Churn Risk` heading only; the body is empty.

### 8. New-logo vertical analysis appendix (always-on)

This appendix is **default-on for every run**. Do not skip it.

Run `queries/07_won_logos_for_vertical.sql` (already filtered to closed New Logo opps in the quarter) and combine with the research table from step 4 (`icp_bucket`, `funding_stage`, `employees`, `description`).

Group wins + losses by vertical, using the rendering name of `icp_bucket`. For each vertical list won accounts and lost accounts separately with a one-line context per row (`account_name — {description}; {funding_stage} / {employees}`). Sum ARR per vertical.

Render the full block into `{{vertical_analysis_appendix}}` with this header:

```
# Appendix: New Logo Vertical Analysis
```

If `acq_wins + acq_losses == 0` for the quarter (no new-logo activity), set the placeholder to an empty string. Otherwise the appendix always renders.

### 9. Raw-data spreadsheet (always-on)

Generate an XLSX alongside the markdown report. Two sheets, one row per opp:

**Sheet 1 — "New Logos"**: run `queries/08_spreadsheet_new_logos.sql`. Includes won + lost + pending New Logo opps with `close_date` in the quarter. Column order and header labels (exactly as below):

| Column header | Source field |
|---|---|
| Opportunity Name | `opportunity_name` |
| Reason for Win/Loss | `reason_for_win_loss` |
| Opportunity Notes | `opportunity_notes` |
| Stage Name | `stage_name` |
| Org ID | `org_id` |
| Org Name | `org_name` |
| Org Country | `org_country` |
| Opp or Account Owner | `opp_or_account_owner` |
| New ARR or Amount | `new_arr_or_amount` |
| Opportunity Lost Reason | `opportunity_lost_reason` |

**Sheet 2 — "Renewals"**: run `queries/09_spreadsheet_renewals.sql`. Includes won + lost + pending SaaS Renewal opps with `close_date` in the quarter.

| Column header | Source field |
|---|---|
| Account Name | `account_name` |
| Org ID | `org_id` |
| Amount | `amount` |
| Stage | `stage` |
| Opportunity Owner | `opportunity_owner` |
| Close Date | `close_date` |
| Churn Notes | `churn_notes` |
| Next Step | `next_step` |

**Build the XLSX** using the `anthropic-skills:xlsx` skill (or any spreadsheet library). Both sheets get a frozen header row (row 1) and auto-widened columns. Output path: `~/Downloads/Q<N> <YYYY> Win_Loss Raw Data.xlsx` (mirroring the markdown report path).

Substitute the final path into `{{spreadsheet_path}}` in the template so the assembled markdown links to it.

## Assembly

1. Read `template.md`.
2. Do literal `{{placeholder}}` substitution with the values gathered above.
3. Write the assembled report to a new file (default path: `~/Downloads/Q<N> <YYYY> Win_Loss Report.md`, but confirm with the user).
4. Save the XLSX alongside it (default path: `~/Downloads/Q<N> <YYYY> Win_Loss Raw Data.xlsx`).
5. Show the rendered markdown to the user in the response, and tell them both the markdown path and the spreadsheet path.

## Validation notes

When testing changes to this skill, run against a known prior quarter and sanity-check the
internal consistency of the numbers rather than memorizing absolute figures:

- `wins + losses + pending == total` for both Acquisition and Retention.
- Win rate == `round(100 * wins / total)`.
- Step 2a `acq_active` should match step 2 `active_orgs` (same distinct-org count, same window) — diverging by more than 1 signals a join or filter mismatch.
- `purchasing ≤ active ≤ total`.
- Retention `ret_arr_pct` between 0 and 100; `ret_churned_arr == ret_lost_arr`.

Spot-check a few opps end-to-end (CRM → warehouse → report line) before trusting a run.
