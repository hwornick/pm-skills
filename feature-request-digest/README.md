# feature-request-digest

**Turn a pile of feature-request tickets into product intelligence: what's new,
what's heating up, which customers are asking, and how much revenue sits behind each ask.**

## Why this exists

Feature requests accumulate in a tracker faster than anyone can read them, and the backlog
view tells you nothing about momentum. By the time a theme is obvious, you've been losing
deals to it for too long. The questions that actually matter aren't answerable by staring at a ticket list: *what's gaining steam
this month? which asks come from your biggest accounts? is this a new pattern or the same
one we keep deferring?*

This skill does the synthesis a PM would do by hand if they had the time:

- **Classifies activity, not just existence.** New tickets, newly-commented old tickets, and
  field-only "stale" updates are treated differently. e.g. a three-month-old ticket that just
  got five new customer comments is a signal, not noise.
- **Pulls the customers out of the prose.** It extracts the accounts named in descriptions
  and comments, then (optionally) fuzzy-matches them to your data warehouse to attach a
  trailing-12-month account value. So "five customers want this" becomes "five customers
  worth $1.2M want this."
- **Clusters into themes and ranks them.** 3–7 themes, sorted by ticket count, each with the
  underlying need and the customers behind it.
- **Tracks momentum across cycles.** By reading prior reports it labels each theme NEW or
  RECURRING, and flags what's *heating up* and what's *faded* (the trend line, not just the
  snapshot).

Run it on demand for any window, or wire it to a schedule so a digest lands in Slack the
first weekday of every month (see [`references/automation.md`](references/automation.md)).

## What it produces

A markdown digest with headline stats, a customer-ARR-exposure table, ranked themes (each
tagged NEW/RECURRING), a trends section (recurring / heating up / faded), and full ticket
detail. All ready to read or auto-post to Slack.

## How to use

1. Point it at an issue-tracker project that collects feature requests (`<PROJECT_KEY>`).
   It's tracker-agnostic: Jira JQL is shown as the worked example; Linear / GitHub Issues
   work with the equivalent query.
2. (Optional) Configure a data warehouse for the customer-value lookup. Skip it and the
   digest still produces themes, trends, and detail.
3. Invoke the skill for a window (defaults to the prior calendar month). It classifies,
   clusters, compares against prior cycles, and writes `cycles/<YYYY-MM>.md`.

The full method is in [`SKILL.md`](SKILL.md); the optional cron + CI + Slack automation
(including a neat trick to stop the tracker bot from unfurling a dozen tickets per Slack
post) is in [`references/automation.md`](references/automation.md).
