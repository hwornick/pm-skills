# Tracker conventions — fill this in for your org

Replace every `<placeholder>`. Examples are Jira-flavored, but the same fields exist in Linear,
GitHub Issues, and most trackers. If a call fails on a field, status, or link name, re-check with
the tracker's metadata calls (for Jira: `getJiraProjectIssueTypesMetadata`,
`getTransitionsForJiraIssue`, `getIssueLinkTypes`) rather than guessing.

## Site
- Site / workspace: `<your-site>`; cloudId (Jira): `<cloud-id>`
- Ticket link format: `https://<your-site>/browse/<KEY>`
- Search results that include descriptions and comments often exceed the tool's output cap and get
  saved to a file. That's expected: query the file with `jq`, don't read it whole, and keep the
  requested fields lean.

## Feedback project
- **Project key:** `<FEEDBACK_KEY>`
- **Issue types:** `<e.g. Idea (default) / Problem / Epic / Sub-task>`
- **How asks are recorded:** `<e.g. one ticket per need; each customer's ask is a comment that
  starts with a link to the customer's account in your admin tool, then the ask. More customers
  wanting the same thing = more comments on the same ticket.>` Follow the existing convention when
  adding a new customer's ask.
- **Fields and labels to leave alone:** `<labels/fields your helpdesk integration manages>`
- **Statuses** (transition name → meaning):
  - `<Triage>` — not yet looked at
  - `<Collecting votes>` — parked until more customers ask
  - `<Evaluating>` — a PM is looking at fit and effort
  - `<Roadmap>` — planned
  - `<Declined>` — not planned
  - `<Building>` — in development
  - `<Shipped>`

  Suggested mapping (the PM decides): Ship → `<Building>` once the build ticket exists (or
  `<Shipped>` if it fully covers the ask and has shipped); Split → `<Building>` or `<Evaluating>`
  depending on which part dominates; Discuss → `<Evaluating>`; needs clarification → leave as is.

## Where build tickets go
- Default project: `<DELIVERY_KEY>`. Other projects by area: `<KEY: area>, <KEY: area>`. Say which you
  picked and why, and offer to move it.
- For coding-agent tickets: the agent's label `<agent-label>`, the priority field, and nothing else
  unless your agent needs more.

## Prioritization lens
`<What makes an ask matter more or less here: which segments are core, which flows are revenue
paths, and any scopes your org deliberately deprioritizes.>`

## Link types (Jira `createIssueLink` takes `type`, `inwardIssue`, `outwardIssue`)
Jira's convention: the **inwardIssue performs the outward verb on the outwardIssue** (for Blocks,
inwardIssue = the blocker). Read the others the same way, then **confirm by fetching one side's
links after linking.** Direction mistakes are easy.

| Use | Type | Reads as | inwardIssue | outwardIssue |
|---|---|---|---|---|
| Same ask, non-canonical ticket | `Duplicate` | X duplicates canonical C | X | C |
| Similar but different ask | `Relates` | relates to (symmetric) | either | either |
| Build ticket fully delivers the ask | `<Implements>` (if your instance has it) | BUILD-n implements FB-m | BUILD-n | FB-m |
| Build ticket delivers a slice | `Relates` | — | either | either |
| Sub-task A must land before B | `Blocks` | A blocks B | A | B |

Don't close duplicates as part of this flow unless the PM says to; linking is enough.

## Search patterns for duplicates
Run several variants; each returns different hits. Include closed tickets.

```
project = <FEEDBACK_KEY> AND text ~ "\"<exact phrase>\"" ORDER BY updated DESC
project = <FEEDBACK_KEY> AND (summary ~ "<stem>*" OR description ~ "<stem>*" OR comment ~ "<stem>*") ORDER BY updated DESC
project in (<DELIVERY_KEY>, <OTHER_KEY>) AND text ~ "\"<feature term>\"" ORDER BY updated DESC
```

Keep `fields` lean (`summary`, `status`, `issuetype`, `labels`, `created`, `updated`, `issuelinks`);
fetch `comment` only for the shortlist.

Search terms to try: the customer's own words, your product's UI terms (and the internal
abbreviations your team uses for them: `<list them>`), and the underlying concept (e.g. "edit after
archive", "lock", "undo").
