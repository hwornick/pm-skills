# Org context — fill this in for your org

The workflow in `SKILL.md` is org-agnostic. Everything specific to *your* product, Jira
instance, and priorities lives here, so it's easy to see what to change. Replace every
`<placeholder>`. The examples show the *shape* of a good answer; delete them once yours are in.

The enrichment subagents get a copy of the "What we are" through "Ignore heuristics"
sections, so write them for a smart reader with no context on your company.

## Jira site
- Site: `<your-site>.atlassian.net`
- cloudId: `<cloud-id>` (find it with `getAccessibleAtlassianResources`)
- Ticket link format: `https://<your-site>.atlassian.net/browse/<KEY>`

## Custom-field IDs (verify with `expand=names` each run — these drift)
| Field | ID | Signal |
|---|---|---|
| Support Ticket Count | `customfield_<NNNNN>` | # of linked helpdesk tickets = breadth of customer pain (>1 is notable) |
| Support Ticket IDs | `customfield_<NNNNN>` | the linked helpdesk ticket(s) |
| Team / Squad | `customfield_<NNNNN>` | owning team — informational only, never a priority signal |
| Expected Behavior | `customfield_<NNNNN>` | bug repro field |
| Steps to Reproduce | `customfield_<NNNNN>` | bug repro field |
| Actual Behavior | `customfield_<NNNNN>` | bug repro field |

Other useful signals:
- **Escalation label:** `<label your support team adds when escalating>` (set `ESCALATED_LABEL`
  for the helper script).
- `comment` (fetch via `fields: ["comment"]`), `issuelinks`, and statuses like `In QA` /
  `In Progress` as dev signals.
- The Jira "Development" panel (PR links) is generally **not** exposed by the Jira MCP. Infer
  dev progress from status, comments, and issuelinks.

## What we are (for severity judgment)
<One paragraph: what the product does, who uses it, the main surfaces (customer app, admin
console, mobile, internal tools), and the integrations that carry money or data.>

> Example shape: "B2B SaaS for scheduling field-service crews. Surfaces: the web app for
> dispatchers, a mobile app for technicians, and an internal ops console. Billing runs through
> Stripe; invoices sync to the customer's accounting system."

### Revenue paths (→ urgent when broken)
<List the flows where a bug costs money or blocks a purchase: signup/checkout, plan
upgrades, seat changes, payments, invoicing, billing/accounting sync, any marketplace or
ordering flow.>

### High-traffic areas (→ friction here leans important)
<List the screens and workflows most users touch every day, plus the standard sales-demo
path. A visible glitch on the demo path is "important" even when it's cosmetic.>

### Other projects worth recognizing
<Other Jira project keys that tickets link to (feature teams, feedback, epics). Useful for
spotting duplicates and "already fixed" signals (a linked issue that's closed).>

Remember: team/project prefixes tell you *who* owns a ticket, not *what initiative* it
belongs to or how much it matters.

## Scope de-prioritizers (apply in the synthesis pass)
<Patterns that should drop a ticket one bucket even when the bug is real. Write each with
the *reason*, so the model can judge siblings.>

> Example shapes:
> - **Deprioritized scope ⇒ down-weight.** "<Scope your org deliberately deprioritizes, and why>,
>   so a bug confined to it drops a bucket."
> - **Rare view / rare config only ⇒ down-weight.** "A bug reachable only from <uncommon
>   view> is lower priority than one on the default path."
> - **Name what does NOT qualify.** Write down the near-misses ("<core segment> is not a
>   de-prioritizer on its own"). When you down-weight one ticket, scan for siblings and note
>   the ones that look similar but *don't* qualify, and why.

## UP-prioritizers — internal hygiene that is NOT "ignore"
<Infra-looking work your org treats as important even with no direct customer impact.
Route these to **important**, not ignore/backlog, and flag borderline siblings for the user
to decide.>

> Example shapes:
> - **Cleanup that prevents future incidents** (e.g. retiring stale configuration or dead code).
> - **Data-quality problems in the pipelines your team makes decisions from.** Bad data quietly
>   breaks every decision made from it.

## Ignore heuristics
Route to **ignore** unless the user says otherwise: security-scan and pentest findings,
dependency / language-version upgrades, framework or component migrations, flaky-test
tickets, error-monitoring config. **Do not** auto-ignore anything on the UP-prioritizer list.
Exception: if a "vulnerability" is an active, unmitigated, unauthenticated data exposure,
flag it for a look rather than burying it.
