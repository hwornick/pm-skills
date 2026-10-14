# feature-request-intake

**Take one customer feature request from "sales sent this over" to a decision: ship it, ship
part of it, or park it with the exact questions that block it, recorded once on the right
feedback ticket.**

## Why this exists

Feature requests arrive as a sales rep's paraphrase of a customer's proposed solution. Handled
badly, they go one of two ways: a ticket that builds exactly what was described (often the wrong
thing), or a feedback ticket that sits forever because nobody worked out what's blocking it. Both
waste time, and the second one means asking the same customer the same questions again a quarter
later.

This skill encodes the PM work in between:

- **Need vs. proposed solution.** It restates the job the customer is trying to get done,
  separately from the feature they asked for, so the build answers the need.
- **It checks claims against the code.** "We can't do X" is often "X exists but is hard to find."
  "It used to work" gets checked against git history, and a real regression is routed as a bug, not
  a feature request.
- **It traces what the change would touch.** Parallel subagents trace every downstream area
  (permissions and every write path, billing, notifications, audit trail, analytics). Only
  then does it recommend **Ship**, **Split**, or **Discuss**. The split case is common: one safe
  slice ships now while the risky part waits for a design decision.
- **Questions someone can decide.** Not "how should we handle permissions?" but "do old
  members (a) lose access, (b) keep read-only access, or (c) move with the project?" Those go to
  the PM in chat or onto the ticket for design and engineering.
- **One home per ask.** It searches the feedback board across all statuses (including closed and
  "won't do"), links duplicates, and adds the customer to the existing ticket instead of opening a
  new one.
- **Nothing is written without a yes.** It drafts every ticket, comment, link, and status change,
  shows the full plan, and waits for approval.

## Tickets for an AI coding agent

Small, well-specified work usually goes to an autonomous coding agent: it watches for a label,
posts a verdict on each ticket, and opens a PR for the ones it accepts.
[`references/coding-agent-tickets.md`](references/coding-agent-tickets.md) is the playbook for
writing tickets it will actually take:

- **The acceptance bar**, inferred from the agent's own verdicts: a pinned root cause, fully
  decided behavior, roughly 1–5 files, testable, and no hard-excluded surfaces (search index,
  auth, schema migrations). It also lists the observed reasons for rejection.
- **Split up front.** The agent rejects a whole ticket over one risky piece, so a big change
  becomes a parent story plus self-contained sub-tasks, and only the qualifying ones get the
  label.
- **Review urgency in the PR title.** The agent opens PRs faster than people can review them,
  so every ticket sets a Critical / High / Medium / Low level that the agent puts in the PR
  title, right after the conventional-commit prefix. Reviewers can then pick the important
  ones first.
- **Re-triggering.** A plain-text `@<coding-agent>` comment gets it to re-evaluate after you
  answer its question or revise the ticket.

## What it produces

A recommendation (Ship / Split / Discuss / needs clarification / actually a bug) with the
evidence, then, after you approve: build ticket(s) for an engineer or a coding agent, a feedback-ticket
comment that sales can read, links to duplicates and related asks, and a suggested status.

## How to use

1. Fill in [`references/tracker-conventions.md`](references/tracker-conventions.md): your feedback
   project, statuses, where build tickets go, and your prioritization lens.
2. Give the agent read access to your product's codebase and connect your issue tracker (e.g. the
   Atlassian MCP server).
3. Paste a request or point at a feedback ticket: *"process this feature request: …"*.

See [`SKILL.md`](SKILL.md) for the full workflow and
[`references/templates.md`](references/templates.md) for the ticket and comment shapes.
