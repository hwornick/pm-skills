---
name: pr-summary
description: Summarize what shipped in a GitHub repo over a given date range into a plain-English rollup grouped by product initiative (not by engineering team). The output describes the completed work in language a non-engineer can follow — it is NOT positioning or messaging; the reader (usually a PM or exec) adds value, impact, and framing on top. Use this skill whenever the user asks "what did we ship", "what got done since [date]", "what merged in the last N weeks", for a sprint review, an exec/eng update, or a stakeholder-facing list of completed work from merged PRs.
---

# PR summary for a GitHub repo

This skill produces a **plain-English summary of what shipped** in a GitHub repo for a
date range, grouped by **product initiative or project** rather than by engineering team.

What this skill does and doesn't do:

- **It does:** translate merged-PR activity into a clear, de-jargoned list of completed
  work that a non-engineer can understand, organized by initiative.
- **It doesn't:** assign value, impact, strategic meaning, or go-to-market positioning.
  That's the reader's job. The audience is typically a **PM or exec** who needs an accurate
  picture of what was built; the PM then layers on "why it matters" and "how we'll position
  it." Don't pre-empt that — describe what shipped, factually and plainly.

## Inputs

- **Repo** (required, `owner/name`): the GitHub repository to summarize.
- **Start date** (required, YYYY-MM-DD): inclusive.
- **End date** (optional, YYYY-MM-DD): inclusive; defaults to today.

If the user doesn't give you a repo or dates, ask. If they give a fuzzy phrase
like "the last 6 weeks", compute the start from today and confirm before fetching.

## Prerequisites

- `gh` CLI installed and authenticated as a user with read access to the target
  repo. If `gh auth status` fails, surface the error and ask the user to run
  `gh auth login`.

## Why the process matters

Several tempting approaches produce worse summaries:
- **Grouping by team prefix** (if PR titles carry prefixes like `TEAM-123`):
  looks tidy but misleads, because the prefixes are *teams*, not initiatives.
  A single initiative pulls PRs from multiple teams; one team spans several
  initiatives.
- **Grouping by service** (e.g. `frontend` / `api` / `billing-service` / `notifications`):
  same problem, plus the names mean nothing to non-engineers.
- **A flat list of PR titles**: too long, full of jargon, no narrative.

The shape that works is: **3–6 highlighted initiatives** (each with a short
plain-English description), an **"unblocking major launches"** section when applicable,
and a short **"other product work"** bullet list. See `references/style-guide.md` for the
full convention.

## Workflow

### Step 1 — Fetch and filter PRs

Run the bundled script:

```bash
python3 scripts/fetch_prs.py --repo <owner/name> --start <YYYY-MM-DD> \
    [--end <YYYY-MM-DD>] [--base <branch>] [--out /tmp/pr-summary-prs.txt]
```

The script:
- Queries the GitHub search API for PRs merged in the window into the repo's default
  branch (looked up automatically; pass `--base` to summarize a different branch, e.g. a
  long-lived release branch). PRs merged into feature branches are excluded, so work isn't
  double-counted when the feature branch later lands.
- Filters out dependabot dep-bumps and bot-noise PRs (neither belongs in a
  completed-work summary). The bot-noise patterns are configurable in the script.
- Writes a compact text file: one entry per PR with title and a body excerpt.
- Prints a one-line summary (count, date range, top authors) to stdout.

Always use the script — don't reinvent the API call inline. It keeps the
filter rules consistent and the output format stable.

### Step 2 — Read the compact file and cluster

Read the output file. For each PR, the line shape is:

```
#16946 | 2026-06-02 | feat(api): Add bulk CSV export to the reporting dashboard - TEAM-2459
    <body excerpt, indented>
```

Cluster the PRs by **project/initiative**, using titles and bodies as your
source. If titles carry a team/ticket prefix (like `TEAM-123`), it tells you the
*team* — useful for spotting related work, but never a stand-in for the
initiative name.

Common initiative patterns to look for (these are illustrative generic B2B SaaS
examples — your real initiatives change cycle to cycle):

- Reporting & dashboards (new charts, saved views, scheduled exports)
- Public API & webhooks
- SSO / access control / roles & permissions
- Billing & invoicing
- Bulk import/export and data management
- Notifications & in-app messaging
- Mobile app work
- Third-party integrations (Slack, calendar, storage providers, etc.)
- Customer-launch unblockers (look for customer names in titles/bodies)

### Step 3 — Identify customer-launch unblockers

Scan PRs for explicit customer names (e.g. `<Customer A>`, `<Customer B>`). If a
series of PRs traces to a customer onboarding (often named like
"`<Customer>` implementation" or "`<Customer>` launch"), that's worth its own section —
a PM or account team will care which work unblocked which customer.

**Don't invent customer attribution.** If a PR doesn't name a customer in
title or body, don't claim it was done for that customer without confirming
with the user first.

### Step 4 — Re-examine support/escalation tickets before bucketing as "other"

PRs tagged with your support/escalation ticket prefix (e.g. `SUPPORT-*`) are
usually customer escalations. Many of them are actually *follow-on polish on
initiatives already in flight* — not standalone misc fixes. For each such PR,
check whether it touches a surface already in a highlighted initiative; if so,
fold it in there ("the reporting dashboard got X polish based on customer feedback")
rather than dumping it in a residual list.

### Step 5 — Present the cluster proposal for review

Before writing the final summary, show the user the proposed structure:

- The list of highlighted initiatives with proposed names, PR counts, and a
  one-line description each
- A short "other product work" preview
- Any customer-launch unblocker candidates
- A "skipped pile" tally for spot-checking

Ask whether to merge/split/rename initiatives, whether to move items between
"highlight" and "other", and whether customer-launch attributions are correct.
This step is important — the user has external context the PRs don't capture
(which work unblocked which customer, which projects matter to leadership
this cycle, etc.).

### Step 6 — Write the final summary in plain language

After the user confirms the structure, write the polished summary following the
conventions in `references/style-guide.md`. Key reminders:

- Plain English. Strip `feat(...)` prefixes, service names, and acronyms.
- Don't pad. One paragraph per initiative is fine if that's all it merits.
- Describe **what shipped** — not what it means for strategy and not how to position it.
  Leave value/impact/framing to the reader.
- Watch the verbs: "fix" can read as an apology. Use "improved", "expanded",
  "resolved", or just describe the concrete change.

### Step 7 — Save the output

Save the final markdown to `~/pr-summaries/<start>_to_<end>.md` (create
the directory if missing) and also print it in the chat. Tell the user the
file path so they can pull it into a doc / Slack / wiki.

## Reference files

- `references/style-guide.md` — naming, jargon, framing, structure, and
  the list of categories to skip. Read this on Step 6.

## Bundled scripts

- `scripts/fetch_prs.py` — fetch + filter + compact. Always use it; don't
  inline an alternative.
