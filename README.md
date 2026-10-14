# pm-skills

A small collection of **Claude Code / Agent skills** for product-management work. Each is a
self-contained skill (a `SKILL.md` plus its supporting scripts, queries, and references)
that encodes a real, hard-won workflow, not a toy demo.

These are genericized versions of skills I built and use. The methodology is intact; the
company-specific schema, names, and numbers have been replaced with placeholders you map to
your own stack.

## The skills

| Skill | What it does |
|---|---|
| [**pr-summary**](pr-summary/) | Summarizes a repo's merged PRs over a date range into a plain-English rollup of what shipped, grouped by product initiative. Built for PMs/execs: describes the work, leaving value and positioning to the reader. |
| [**win-loss-analysis**](win-loss-analysis/) | Assembles a quarterly win/loss report from a CRM + data warehouse: a data-quality preflight, win rates and ARR for Acquisition and Retention, product-adoption and usage-retention rollups, and loss-theme analysis that gets past the picklist (and, optionally, into each churned customer's account notes) to the real *why*. |
| [**feature-request-digest**](feature-request-digest/) | Turns an issue tracker's feature-request activity into a monthly digest: ranked themes, the customers (and revenue) behind each, and cross-cycle trend tracking. Runs on demand or on a schedule. |
| [**feature-request-intake**](feature-request-intake/) | Takes one customer request from a sales paraphrase to a decision: separates the need from the proposed solution, checks claims against the code, traces downstream impact, and recommends Ship / Split / Discuss, then records it once on the right feedback ticket. Includes a playbook for writing tickets an AI coding agent will accept and ship. |
| [**jira-triage**](jira-triage/) | Triages a few hundred open Jira tickets from any JQL query into urgent / important / backlog / close / ignore, using parallel subagents for the per-ticket reading, and proves every ticket made it into the report. |

## Using a skill

Each skill is a directory with a `SKILL.md` at its root. To use one with Claude Code, make
it discoverable as a skill (e.g. drop the directory under your skills path, or reference it
from a plugin/marketplace), then invoke it by name or by the phrases listed in its
`SKILL.md` description. Start with each skill's own `README.md` for the "why" and its
`SKILL.md` for the step-by-step.

## Configure for your stack

Every skill that touches an external system ships with **placeholders**, not live config:

- **win-loss-analysis** and **feature-request-digest** reference generic warehouse tables
  (`analytics.crm_opportunities`, `fact_orders`, `dim_customers`, …) and generic CRM/tracker
  fields. Each skill has a "Configure your data source" section — map the placeholders to
  your own schema before running.
- **jira-triage** and **feature-request-intake** each have a fill-in reference file
  (`references/org-context.md`, `references/tracker-conventions.md`) for your Jira site,
  custom fields, statuses, and the priority rules your team uses.
- BI drill-down URLs, issue-tracker base URLs, and Slack webhooks are all parameterized.

Nothing here is wired to a specific company; you bring your own data source.

## License

MIT — see [LICENSE](LICENSE).
