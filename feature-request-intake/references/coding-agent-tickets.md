# Tickets for an AI coding agent

How we hand build tickets to an autonomous coding agent: a bot that watches for a label
(`<coding-agent>` below), evaluates each labeled ticket, posts a verdict comment ("can do / can't
do", plus its reasoning), and opens a PR for the ones it accepts. Much of our small, well-specified
work ships this way, so a feature request that lands as **Ship** usually becomes an agent ticket.

The acceptance patterns below were inferred by reading the agent's first comment on every recent
ticket it was given. Your agent's bar will differ in the details, so **refresh this file from
your own agent's history** (see "Refreshing this list").

## The acceptance bar

The agent is deliberately conservative. It **rejects any ticket it can't finish entirely on its
own**, including one where most of the work is safe but one piece isn't. A rejected ticket sits
unassigned, so the safe part doesn't ship either.

The agent describes its own standard as "surgical, high-confidence, low-risk." In practice:
- **Root cause is pinned** in the code, not a hypothesis. The ticket names the files and logic.
- **Desired behavior is fully specified.** No product decisions are left in the ticket.
- **Small and single-surface:** roughly 1–5 files, one service or one frontend area. CSS-only and
  copy changes are easy yeses.
- **Verifiable with automated tests** or an obvious UI check.
- **Doesn't touch a hard-excluded surface** (see below).

## Why it says no (observed patterns)

| Reason | Example shape |
|---|---|
| **Hard-excluded surface:** search-index queries, auth / session / tokens, database schema / foreign keys / migrations. Its risk notes also call out API schema changes and the payment provider. | "Fix the typeahead ranking" (search index); "Refresh tokens expire early" (auth); "Add a foreign key so deletes cascade" (schema) |
| **Behavior not decided.** The ticket leaves a product choice open. | "Either block the delete or unlink the dependent records" |
| **Needs evidence code can't provide:** prod logs, a prod data query, an index check, or a repro in one customer's account | "Only happens for one customer; check their data"; "needs a session replay to reproduce" |
| **Root cause is still a hypothesis.** | "Probably a race condition in the sync job" |
| **Too broad.** Several components, or a change to a shared UI building block used across many screens, with high regression risk ("a mini-project, not one surgical patch"). | "Make every table screen-reader accessible" (six acceptance criteria across many files); "Redesign the shared filter dropdown" |
| **One safe fix bundled with one risky fix.** It rejects the whole ticket and says the safe part "would likely qualify" if split out. | A frontend-only fix plus a search-index fix in one ticket |

**Partial yeses happen too.** The agent sometimes does the scoped part and leaves one acceptance
criterion for a human (e.g. skips the one that needs a prod query). Writes to an external
accounting system can still get a yes, with a note that a human who knows that integration must
review the PR. Don't depend on partial acceptance; **split up front instead.**

**Temporary gates.** The agent (or the people running it) sometimes posts a temporary rule, such as
"changes to search or the status bar need staging testing before merging to prod until <date>."
Check its recent comments for any gate that's currently active before writing a ticket in that
area.

**Refreshing this list.** Query your tracker for the agent's label, newest first, with the
`comment` field (e.g. JQL `labels = <coding-agent> ORDER BY created DESC`, fields
`["summary","status","comment"]`). The response will likely be saved to a file: use `jq` to pull
the agent's first comment on each ticket rather than reading the payload. Compare its rejections
against the table above and update this file.

## How this shapes the tickets you write

- **Break big changes into sub-tasks.** Create a parent story that holds the shared context and the
  overall outcome (no agent label). Under it, create one sub-task per independently shippable piece.
  Label **only** the sub-tasks that clear the bar on their own. Pieces that fail it stay
  unlabeled, as sub-tasks or separate tickets for engineers, written as engineering tickets (see
  `templates.md`).
- **Each sub-task stands on its own.** The agent evaluates only the ticket it's given, so every
  sub-task repeats the essential background, file paths, acceptance criteria, and verification
  steps. Never write "see parent" for anything load-bearing.
- **Order matters.** If one sub-task depends on another landing first, say so in both and add a
  Blocks link.
- **Pull out what code can't answer.** If an acceptance criterion needs a prod query, a log pull,
  or a customer repro, make that a separate human sub-task, or drop it from the criteria.
- **Never leave a decision in the ticket.** If you catch yourself writing "either (a) or (b)," it
  isn't ready. Get the PM to pick one first, or move that piece to the Discuss list.
- **Fields:** the agent label plus the priority field (below). Nothing else: no assignee, sprint,
  or components. The agent picks the ticket up from the label.

## Review urgency (required on every agent ticket)

The agent ships PRs faster than the team can review them, so reviewers pick what to review from a
tag in the PR title ("I have an hour — which ones first?"). Every agent ticket gets an urgency
level, in two places:

1. **The tracker's priority field**, using the same word (e.g. Jira `{"priority": {"name": "High"}}`).
2. **A `## PR title` section in the description** telling the agent to put the same word as a tag
   **right after the conventional-commit prefix**, e.g.
   `fix(web): [Critical] restore default sort on the cases table PROJ-123`. The agent writes its own
   PR titles and won't add the tag unless told. The tag can't go first because the repo's PR-title
   check requires titles to start with `fix` / `feat` / etc.

**Scale**, by cost of delay (who is hurt or waiting while the PR sits unreviewed):

| Level | Review | When |
|---|---|---|
| `Critical` | first, today | Customers are broken right now: purchasing, checkout, or approvals blocked; money, prices, or order data wrong; or a live deal or launch blocked. |
| `High` | within a couple of days | A customer-facing bug with no good workaround, or something promised to a specific customer, sales deal, or dated launch. |
| `Medium` | normal review rotation | A bug with a workaround, or an improvement nobody is waiting on by a date. **Most tickets land here.** If everything is High, the tag is useless. |
| `Low` | when the queue is empty | Cosmetic, copy, internal cleanup, test-only fixes. |

- **Always tag, even Medium,** so a missing tag means "forgot," not "Medium."
- **Weigh business impact:** anything on the revenue path leans higher; issues confined to scopes
  your org deprioritizes, or to rarely seen views, lean lower.
- **Sub-tasks each get their own level.**
- **Say which level you picked and why, in one line,** so the PM can override it.
- This urgency is separate from any `P0`–`P3` summary prefixes a launch-readiness board might use.
  Don't add a P-prefix by default.

## Getting the agent to re-evaluate

If the agent rejects a ticket or asks a question, nudge it with a tracker comment whose text
includes `@<coding-agent>` as **plain text**, not a formal user-mention. The ticket must still have
the agent label; no label changes are needed. (If your agent instead re-runs when the label is
removed and re-added, use that.)
- **Answering its question:** put the answer in the `@<coding-agent>` comment.
- **After revising the description:** edit the ticket first, then post an `@<coding-agent>` comment
  that says what changed relative to its verdict and asks it to re-evaluate.
- Don't mention the agent's human operators on these tickets unless the PM asks.

**Wait for the verdict before moving anything else.** Only transition the related feedback ticket
(e.g. to "building") after the agent has accepted the build ticket.
