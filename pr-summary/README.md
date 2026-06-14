# pr-summary

**Turn a repo's merged PRs into a plain-English list of what shipped, grouped by product
initiative, in language a non-engineer can actually follow.**

## Why this exists

Every engineering org can produce a list of merged PRs. Almost none can hand a PM or exec
something they can actually read. The raw log is the wrong artifact for the audience: it's
written in `feat(api):` shorthand, it's ordered by merge time, and the obvious ways to
organize it all mislead —

- **Grouping by team** looks tidy but is wrong: one initiative pulls PRs from several
  teams, and one team touches several initiatives. The reader learns org structure, not
  what got built.
- **Grouping by service** (`frontend`, `api`, `billing-service`) means nothing to a non-engineer.
- **A flat list of titles** is too long, too jargony, and has no shape.

This skill encodes what actually works: cluster by **product initiative**, write 3–6 short
plain-English descriptions, pull out customer-launch unblockers as their own section, and
choose verbs deliberately so the reader can tell what changed.

**What it deliberately does *not* do:** assign value, impact, or positioning. That's the
PM's job. This skill produces the accurate factual layer (*what shipped*) and stops
there. The PM then adds "why it matters" and "how we'll talk about it" on top. Keeping
those layers separate is the whole point: a summary that editorializes is something the PM
has to undo before they can use it.

The result is a digest that fits one screen-scroll and is ready to drop into a sprint
review, an exec update, or a planning doc.

## What it produces

A markdown summary with highlighted initiatives (each a short paragraph), an optional
"Unblocking major launches" section, a tight "other product work" list, and a "skipped
pile" footer so you can spot-check what was filtered.

## How to use

1. Make sure the `gh` CLI is installed and authenticated for the target repo.
2. Invoke the skill with a **repo** (`owner/name`) and a **start date** (optional end date,
   defaults to today).
3. Fetch + filter PRs:
   ```bash
   python3 scripts/fetch_prs.py --repo owner/name --start 2026-04-24 [--end 2026-06-02]
   ```
4. The skill clusters the PRs by initiative, shows you the proposed structure for review
   (you have context the PRs don't), then writes the final plain-language summary.

See [`SKILL.md`](SKILL.md) for the full workflow and
[`references/style-guide.md`](references/style-guide.md) for the naming, jargon, and
framing conventions.
