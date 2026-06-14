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
| [**win-loss-analysis**](win-loss-analysis/) | Assembles a quarterly win/loss report from a CRM + data warehouse: win rates and ARR for Acquisition and Retention, product-adoption rollups for won logos, and loss-theme analysis that gets past the picklist to the real *why*. |
| [**feature-request-digest**](feature-request-digest/) | Turns an issue tracker's feature-request activity into a monthly digest: ranked themes, the customers (and revenue) behind each, and cross-cycle trend tracking. Runs on demand or on a schedule. |

## Using a skill

Each skill is a directory with a `SKILL.md` at its root. To use one with Claude Code, make
it discoverable as a skill (e.g. drop the directory under your skills path, or reference it
from a plugin/marketplace), then invoke it by name or by the phrases listed in its
`SKILL.md` description. Start with each skill's own `README.md` for the "why" and its
`SKILL.md` for the step-by-step.

## Configure for your stack

Two of the skills touch external systems and ship with **placeholders**, not live config:

- **win-loss-analysis** and **feature-request-digest** reference generic warehouse tables
  (`analytics.crm_opportunities`, `fact_orders`, `dim_customers`, …) and generic CRM/tracker
  fields. Each skill has a "Configure your data source" section — map the placeholders to
  your own schema before running.
- BI drill-down URLs, issue-tracker base URLs, and Slack webhooks are all parameterized.

Nothing here is wired to a specific company; you bring your own data source.

## License

MIT — see [LICENSE](LICENSE).
