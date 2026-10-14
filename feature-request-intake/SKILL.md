---
name: feature-request-intake
description: >-
  Process a single customer feature request end to end: understand what's really being asked and
  why, check whether the product already does it (or used to), judge whether the PM can approve a
  change alone (→ a ready-to-build ticket for an AI coding agent or an engineer) or whether it needs
  product/design/engineering decisions, resolve or document those questions, and record everything
  on the right feedback ticket (find/pick/create, link duplicates and related asks). Use whenever the
  user pastes a feature request from sales or support (email, Slack, call notes), points at a new
  feedback ticket or a new comment on one, or says things like "process this feature request", "a
  customer is asking for…", "sales sent this over", "can we just build this?", or invokes
  /feature-request-intake.
---

# Feature request intake

One request per run. The goal is to move a customer ask to the right next state with the least
product overhead:

- **Ship it** — a ready-to-build ticket the PM can approve alone,
- **Split it** — ship a safe slice now and document the rest, or
- **Park it with clear questions** — documented on the feedback ticket for a design/engineering
  discussion.

Either way, make sure the ask is recorded **once**, on the right feedback ticket, linked to its
siblings.

**Reference example.** A customer asked to (1) rename tags on archived projects and (2) move
archived projects into another workspace. Renaming tags touched nothing but the tag label, so it
shipped as one small ticket. Moving workspaces changed who could see the project and how seats
were counted, so it was parked with concrete questions for design and engineering. The **split**
outcome is common; look for it.

## Before you start

- Load your issue-tracker tools in one `ToolSearch` call (for Jira: `searchJiraIssuesUsingJql`,
  `getJiraIssue`, `addCommentToJiraIssue`, `createJiraIssue`, `editJiraIssue`, `createIssueLink`,
  `getTransitionsForJiraIssue`, `transitionJiraIssue`).
- Read `references/tracker-conventions.md`: the feedback project, issue types, statuses, link
  types, where build tickets go, and search patterns. It ships as a fill-in template; if it's still
  unfilled, fill it in with the user first.
- Read `references/coding-agent-tickets.md`: Ship outcomes usually become tickets for an AI coding
  agent, and its acceptance bar shapes how you scope the work from step 2 on.
- Read `references/templates.md` when you get to writing.
- You need read access to the product's codebase. Work read-only or in a worktree; **this skill never
  changes code itself.**

## Input

Exactly one of:
- **A feedback-ticket key** (optionally "the latest comment" / a specific comment). Fetch the issue
  with description, comments, links, labels, status, and reporter. On many feedback boards the
  description is thin and each customer's ask is a **comment**. If pointed at a new comment, that
  comment is the request; the rest of the ticket is context.
- **Pasted text from sales or support.** Note who it's from and which customer, if stated.

If the paste contains several distinct asks, list them one line each and ask the user which one this
run is for. Don't process several at once.

## Step 1 — Understand the request

Write a short restatement the user can correct, with these parts:

- **Who:** customer, segment, and the role of the person asking (end user, admin, budget owner,
  buyer).
- **The underlying need (the "why"):** the job they're trying to get done and what it costs them
  today (workarounds, errors, time). Separate this from…
- **…their proposed solution (the "what"):** customers and sales reps often describe a solution.
  Keep it, but don't treat it as the requirement. Example: "a Slack message every morning listing new
  tickets from my accounts" is a proposed solution; the need is "account managers want to hear
  the same day when one of their customers reports a problem."
- **Current behavior:** what the product does today in this area. Check the code (and staging, if the
  user can confirm). Test the claims in the ask specifically:
  - **"We can't do X."** Is X actually possible but hard to find (e.g. a saved filter with an
    email subscription)? If so, part of the answer may be discoverability or education, not a build.
  - **"It used to work and went away."** Check `git log` / `git log -S '<string>'` for the change. A
    real regression is a **bug** and goes to the bug tracker instead of (or as well as) the feedback
    board. Say so explicitly.
  - **Visual or environment issues** (a layout gap on one browser) are usually bugs, not feature
    requests. Flag and route them; don't run the rest of this flow on them unless the user wants.
- **Open clarity questions**, split in two:
  1. **The PM can probably answer** from market knowledge (how customers in this segment typically
     work, whether this pattern is common). Ask these right away with `AskUserQuestion`, best-guess
     answer as the first option.
  2. **Needs the sales rep or customer.** Draft them as a short, plain-language list the user can
     paste into Slack/email, or that goes on the feedback-ticket comment.

**Start the duplicate search (step 4) in the background now.** Earlier asks for the same thing often
clarify the need, show how many customers want it, and sometimes include a past product decision.
Use a subagent, or run the searches yourself while you read code.

**Gate:** if the need is still genuinely unclear after the user's input (you can't say what success
looks like for the end user), stop here. Output the questions for sales/customer, then skip to
step 4 to record the ask with those questions attached. Don't speculate a solution into a ticket.

## Step 2 — Feasibility: can the PM approve this alone?

Find where the behavior lives, then trace what depends on it. For anything beyond a trivial UI
tweak, fan out 2–4 `Explore`/`general-purpose` subagents in parallel, one per downstream area, for
example:
- permissions/roles and **every write path** (REST, GraphQL, imports, bulk actions, mobile) — do they
  all enforce the same rules?
- billing and integrations (invoices, external syncs, exports) — what gets snapshotted vs.
  read live?
- notifications and emails, approvals and workflow state
- audit trail / edit history, search indexing, analytics events, reporting

**Verify load-bearing claims yourself** before relying on a subagent's report (spot-check the
file/line). Use `git log` on the relevant rules to learn *why* the current behavior exists. A
deliberate product rule and an accident of history call for different answers.

Then classify, and say which and why:

- **Ship** — the PM can sign off alone. All of these hold:
  - the behavior change is unambiguous: one obvious UX, no new screens or patterns that need design
  - every edge case you found is either handled by the change or genuinely doesn't matter
  - no unhandled risk to money, external syncs, compliance, or data integrity
  - small and reversible
  - the PM can verify it themselves (if part of the verification needs an integration the PM
    can't reach on staging, that's a strike against Ship)
  - if it's going to the AI coding agent (the usual path for Ship), it also clears the agent's acceptance bar
    (`references/coding-agent-tickets.md`). Something can be safe for the PM to approve and still
    be wrong for an agent; then it goes to an engineer instead.
- **Split** — a slice meets the Ship bar and the rest doesn't. Name the slice precisely and what's
  explicitly out of scope.
- **Discuss** — needs product, design, or engineering decisions before anything ships.

Present this as a recommendation with the evidence; **the user makes the call.** Apply the org's
prioritization lens from `references/tracker-conventions.md` (e.g. segments or regions that matter
more or less, whether the ask touches a revenue path).

If you find an unrelated problem along the way (e.g. a permission gap on another write path),
mention it and offer a separate ticket. Don't fold it into this request.

## Step 3 — Product and design questions

For whatever isn't Ship, list the decisions that block it. Good questions are concrete and
decidable: "When an archived project moves to another workspace, do its old members (a) lose
access, (b) keep read-only access, or (c) get added to the new workspace?" — not "how should we
handle permissions?"

- Ask the user the ones that look answerable in chat (`AskUserQuestion`, ≤4 per call, recommended
  option first). An answer can move a slice from Discuss to Ship; re-check the Ship bar if it does.
- Document the rest grouped by **product**, **design**, and **engineering**, with the options you
  see and any facts from the code that bear on each. These go on the feedback ticket.

## Step 4 — Feedback ticket: find, pick or create, link

**Search** (patterns in `references/tracker-conventions.md`) with several keyword variants: the
customer's words, your product's UI terms, and the underlying concept. Search across **all
statuses, including closed**: closed tickets may be duplicates already resolved, or a past "won't
do" decision worth knowing. Also check the delivery projects for work already done or in flight.

Classify each hit: **same ask** (duplicate), **related but different**, or **noise**. Then:
- **Already working from a feedback ticket:** it's the home. Link duplicates and related tickets to
  it. If an older ticket is clearly the better canonical home (more history, more customers),
  suggest consolidating there instead and let the user choose.
- **From pasted text:** pick the best existing ticket and add this customer's ask as a comment, or
  create a new feedback ticket if none fits. Link the others.
- Use the link types from the conventions file (Duplicate for the same ask, Relates for
  similar-but-different). Link direction is easy to get backwards; fetch one side's links after
  linking to confirm.

## Step 5 — Write it up (confirm first)

Draft everything, show the user the **full plan of tracker writes in one message**, and wait for a
yes before creating, commenting, linking, or transitioning anything. Typical set:

1. **Build ticket(s)** (Ship or Split only), per `references/templates.md`:
   - **For an engineer:** describe the problem and current behavior in technical terms, but write
     the solution and acceptance criteria from the user's point of view. If you must share a
     technical approach, label it an *option to consider, not a decision*. The engineer makes the
     final call.
   - **For an AI coding agent:** complete technical detail (problem, root cause/current behavior
     with file paths, the change, explicit out-of-scope, acceptance criteria, edge cases, how to
     verify). Follow `references/coding-agent-tickets.md`: split big changes into self-contained
     sub-tasks and set a review-urgency level. State the level you picked and why in one line so
     the user can override it.
2. **Feedback-ticket comment**, readable by sales and support: the need as understood, what's
   shipping (link the build ticket) or why it's not shipping yet, open product/design questions,
   and questions for the customer or sales rep.
3. **New feedback ticket**, only if no existing one fits.
4. **Links**: feedback ticket ↔ build ticket, feedback ticket ↔ duplicates/related.
5. **Status**: suggest one (see the conventions file); only transition if the user agrees. If a
   coding agent first has to accept the ticket, wait for its verdict before moving the feedback
   ticket's status.

If the user is already on an existing ticket and says "write a ticket," ask whether they mean
updating that ticket or creating a new one.

## Finish

End with a short summary: the outcome (Ship / Split / Discuss / Needs clarification / Actually a
bug), links to every ticket created or changed, questions still waiting on sales or the customer,
and anything flagged as a separate issue.
