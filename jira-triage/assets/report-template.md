# Report template

Structure for the output markdown. Adapt headings to the actual findings — this is a skeleton, not a
straitjacket. The non-negotiables: (1) every ticket listed once under its bucket with a link + bucket +
one-liner; (2) an exec summary with a count table and the key themes; (3) a caveats appendix.

```markdown
# <PROJECT> Triage — <YYYY-MM-DD>

Review of **N open <PROJECT> issues** (<one-line description of the JQL filter>). Every ticket was
examined in detail — summary, description, repro/expected/actual, comments, support-ticket count, dates, dev
signals — and is listed below under a suggested bucket with a link.

| Bucket | Count | What it is |
|---|---|---|
| 🔴 **Urgent** | n | Revenue / access blockers or severe defects to surface now |
| 🟠 **Important** | n | Everyday friction + visible/demo glitches — fix the set for a smoothness step-change |
| 🟡 **Backlog** | n | Keep open, revisit with the relevant feature area |
| ⚪ **Close** | n | Likely fixed / in-QA / superseded — verify & close |
| ⚙️ **Ignore** | n | Platform/infra (vulns, upgrades, flaky tests, telemetry) |

**Themes worth knowing before you read:**
- <the 2-4 clusters/patterns that make this actionable — e.g. "billing cluster", "table-refresh cluster">
- <any scope de-prioritizers applied and why>

> **Data caveats** (see appendix): <MCP wrong-issue quirk + any tickets classified from description only>.

---

## 🔴 Urgent (n)
<!-- Few or none. Group into clusters/workstreams where related. 2 lines each. -->
### Standalone blockers — act first
- **[PROJ-XXXX](url)** — <what breaks, who's hit, why now>. <dev/fix signal>.
### Cluster A — <name> (revenue; one workstream)
- **[PROJ-XXXX](url)** — <one-liner>.
> ⚠️ Also verify: **[PROJ-XXXX](url)** filed under Close — <what to confirm; if not resolved it jumps to urgent>.

## 🟠 Important (n)
<!-- Usually the biggest bucket — that's expected. Group by theme; each ticket appears once. -->
### Group I — <theme, e.g. table refresh/filter correctness>
- **[PROJ-XXXX](url)** — <one-liner> (support tickets n / status).
### Group … — Cosmetic / demo-smoothness quick wins
- **[PROJ-XXXX](url)** — <one-liner>.

## 🟡 Backlog (n)
<!-- Group by app area so the user can revisit with the feature. One line each. -->
**<App area>**
- **[PROJ-XXXX](url)** — <one-liner> (flag "stale, consider closing" where apt).

## ⚪ Close (n) — verify, then close
**Fix built / In QA:**
- **[PROJ-XXXX](url)** — <what> — *In QA.*
**Comment/status evidence it's resolved:**
- **[PROJ-XXXX](url)** — <what> — <evidence>.
**Verify-first:**
- **[PROJ-XXXX](url)** — <why it needs a check before closing>.

## ⚙️ Ignore (n) — Platform / infra
- **[PROJ-XXXX](url)** — <one-liner>. <flag any active-security exception worth a look>.

---

## Appendix — method & caveats
- **Coverage:** all N tickets examined individually; parallel review + a consolidation/synthesis pass.
- **Bucket tally:** Urgent n · Important n · Backlog n · Close n · Ignore n = **N**.
- **Changes to the first pass:** <what you re-adjudicated, e.g. urgent trimmed X→Y; scope de-prioritizers applied>.
- **MCP data quirk:** the API intermittently returned the wrong issue for a key; mismatches were detected
  and re-fetched. Classified from description only (verify if acting on them): <keys>.
- **No changes made to Jira** (no comments/labels/transitions). Offer to apply a triage label per bucket
  or post close rationales as a follow-up.
```
