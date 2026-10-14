# Templates

Markdown bodies. Adapt the section headings to the request; these are shapes, not forms.

## Engineering ticket (for a human engineer)

An engineer will likely work this with their own AI assistant, so be careful what you present as
settled. Describe the problem precisely; describe the solution as an outcome.

```
## Background
The customer need and why it matters, in two or three sentences. Link the feedback ticket.

## Current behavior
What happens today, technically (for a bug: the root cause as far as you traced it).

## Desired outcome
What the user should be able to do or see afterward. Roles, states, and surfaces it applies to.

## Acceptance criteria
- User-observable outcomes, one per bullet
- What must NOT change

## Open questions
Anything you couldn't settle, with the facts you found.

## Option to consider (not a decision)
Only if a technical approach really needs sharing. Label it this way so nobody's AI assistant
treats it as the agreed fix. The engineer makes the final call.
```

## Coding-agent ticket

Written so an agent can execute without coming back with questions. Full technical detail
belongs here. Check scope against `coding-agent-tickets.md` first. If it's more than one surgical
change, write a parent story (shared context and outcome, no agent label) and use this template
once per sub-task.

**Summary:** the user-visible outcome, e.g. "Allow admins to rename tags on archived projects".

```
## PR title
Review urgency: Medium. Put the tag right after the conventional-commit prefix:
`feat(web): [Medium] <short description> <TICKET-KEY>`
(Critical / High / Medium / Low, matching this ticket's priority field.)

## Background
Customer ask and why it matters, in two or three sentences. Link the feedback ticket.

## Current behavior
What happens today and where it's enforced in code (file paths with line numbers). Why it is this
way, if git history says.

## Change
Exactly what should change: roles, states, and every surface (e.g. the settings page AND the bulk-edit
modal). Every write path that must agree.

## Out of scope
What stays as-is, explicitly (e.g. "archived projects still can't change workspace").

## Acceptance criteria
- User-observable outcomes, one per bullet
- What must NOT change (other roles, other fields, downstream records)
- Tests to update or add

## Edge cases
Each one found during investigation and how it should behave.

## Relevant code
Paths, functions, test fixtures.

## How to verify
Steps the PM can run on staging (no integrations needed, unless noted).
```

## Feedback-ticket comment (readable by sales and support)

Plain language, no file paths. Skip any section that's empty.

```
[Customer name](<link to the account in your admin tool>) — via <sales rep>, <date>   ← only when adding a new customer's ask

**What they're asking for:** the need in one or two sentences, plus their proposed solution if they
gave one.

**Where it stands:**
- Shipping now: <slice> — <BUILD-KEY>
- Not yet: <rest>, because <the decisions it needs, in one line>

**Open product/design questions:**
- …

**Questions for the customer / sales rep:**
- …

**Related:** <FB-KEY>, <FB-KEY>
```

Notes:
- If part of the ask is already possible today, say how ("Save a filter for your accounts and
  turn on its daily email"), so sales can relay it.
- Don't promise timelines.

## New feedback ticket (only when no existing ticket fits)

- **Type:** the default "idea" type (use "problem" only for a pain point with no clear feature shape).
- **Summary:** the need, generalized beyond this customer, in the user's terms ("Account managers
  hear about their customers' new issues the same day"), not the proposed solution ("daily Slack
  digest").
- **Description:** two or three sentences on the generalized need, the current workaround, and who
  has it (segment / role). Keep customer-specific detail out of the description.
- **Then add the customer's ask as the first comment** using the comment template above.
