# Style guide for pr-summary output

These are conventions for turning merged PRs into a plain-English list of completed work.
Apply them when you write the final summary. They were learned the hard way from real
"what shipped" write-ups; treat them as defaults rather than absolutes.

## What this output is (and isn't)

The job is to describe **what shipped**, accurately and in language a non-engineer can
follow. It is **not** a positioning document. The reader (usually a PM or exec) takes
this factual layer and adds the next layer themselves: value, impact, strategic meaning,
and go-to-market framing.

So:
- A line that reads as engineering-speak ("refactored the Transformer class") fails because the
  reader can't tell what changed.
- A line that hides what shipped behind a vague verb ("fixed some things") also fails.
- A line that editorializes ("this unlocks our enterprise motion") **also** fails because that's
  the reader's call to make, not the summary's. State what shipped; let them draw the
  conclusion.

The bar for every line: a non-engineer reads it and knows *what now exists or works that
didn't before*.

## Naming initiatives

- Name initiatives after the **project or product capability**, not the team
  that did the work. "Reporting v2", not "the frontend team's work". "Webhooks &
  public API", not "the platform team's PRs".
- Use language a non-engineer recognizes. Cross-reference the PR titles +
  bodies for the user-facing name (e.g. "Saved Views", "Bulk Export", "SSO") rather
  than inventing one.
- If multiple teams contributed to one initiative, that's normal. Collapse
  them under the one project name.

## Acronyms and jargon to expand or replace

Build your own term→plain-English table for your product. The point is to catch
internal shorthand before it reaches a non-engineer. Example shapes:

| Internal term | Why it lands badly | Better |
|---|---|---|
| An internal acronym (e.g. `RFC`) | Recipient may not know it | Spell it out on first use ("Regional Fulfillment Center") |
| A field abbreviation (e.g. `UoM`) | Looks like a typo | "Unit of measure" |
| A niche domain term | Reads as jargon | Pair with a 3–5 word clarifier |
| An ambiguous word (e.g. "Instances") | Means different things to different readers | Add a clarifier: "Instances & Sublocations (multi-site hierarchy)" |
| Commit-message scaffolding (`feat(...):`) | Not English | Strip entirely |
| Service/package names (`api`, `billing-service`, `notifications`) | Mean nothing to non-engineers | Replace with user-facing surfaces ("the reporting dashboard", "the public API", "the admin console") |

## Framing pitfalls

- **"Fix" is dangerous.** "We fixed X" implies "X was broken and people noticed." Sometimes
  that's the accurate message (especially if it resolved a customer-reported issue). But
  often the work is *polish*, *improvement*, or *expansion*. Choose the verb deliberately
  to match what actually happened.
- **Don't invent customer attribution.** If a PR doesn't mention a specific
  customer in title or body, don't claim it was done "for [Customer]" without
  confirming with the user. False attribution is worse than no attribution.
- **Don't pad.** If an initiative is one paragraph, leave it at one paragraph.
  If a bullet is one line, leave it at one line. The reader values brevity.
- **Don't editorialize impact or positioning.** Describe what shipped, full stop. The
  reader owns the "why it matters" and "how we'll talk about it" layer. Pre-empting it
  with your own framing just creates something they have to undo.

## Customer-launch unblocking

If PRs trace to a specific customer rollout (`<Customer A>`, `<Customer B>`,
etc.), surfacing that is useful context. Look for customer names in PR titles
and bodies. Common patterns:

- A PR title contains the customer name explicitly.
- A team ticket links to a customer rollout (less reliable, so confirm with user).
- A series of "implementation" PRs (e.g. "`<Customer>` implementation") points
  to one customer onboarding.

When you have a customer-launch story, give it its own section ("Unblocking
major launches") and group by customer if there are multiples. Still factual: "shipped
X, Y, Z to enable `<Customer>`'s rollout", not "a huge enterprise win."

## Support / customer-escalation fixes

PRs tagged with a support/escalation ticket prefix (e.g. `SUPPORT-*`) are
customer-escalated. Many of them are actually *follow-on polish on initiatives
already in flight*, not standalone miscellany. Before you dump them into
"miscellaneous fixes", check each one:

- Does it touch a surface that's already a highlighted initiative? Fold it in.
  ("The reporting dashboard got X polish based on customer feedback.")
- Does it cluster with other related escalation work? Make a tight sub-group.
- Only the truly orphan ones belong in a residual "customer-reported fixes" bullet.

## What to skip entirely

Don't include these in the final summary; mention them briefly under a
"skipped" footer so the user can spot-check:

- Dependabot/dep bumps (already filtered by the script)
- Bot-noise / automated error-fix PRs (already filtered by the script)
- Infrastructure-only PRs (Terraform / Nomad / Vault / cloud migrations):
  these belong in an eng-only update, not a product completed-work summary.
- SSH key onboarding for new engineers
- Codeowners updates, feature-flag archival chores, pure dev-tooling
- Reverts and bugfix-of-bugfix noise
- Dependency/framework version bumps, dev-seed fixes
- Local-dev workarounds

## Final output shape

The format that works in practice:

```markdown
# PR summary — <start> to <end>

## Highlighted initiatives

### 1. <Initiative name>
<3–5 sentence paragraph in plain English describing what shipped.>

PR count: <N>. Representative: #xxxx, #xxxx, #xxxx.

### 2. <Initiative name>
...

## Unblocking major launches  (only if applicable)

- **<Customer name>** — <one-line description of what shipped to enable them> (#xxxx, #xxxx)

## Other product work

- **<Theme>** — <one-line description> (#xxxx)
- ...

## Skipped pile

- <N> infrastructure PRs (Terraform / Nomad / etc.)
- <N> SSH-key onboarding PRs
- <N> reverts and follow-up noise
```

Aim for output that fits in one screen-scroll. If a section is empty, omit it.
