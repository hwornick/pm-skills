# Optional: running the digest on a schedule

The digest works fine on demand. If you want it to run unattended every month and publish
itself, here's a pattern that's been battle-tested. It's optional, so wire up only the parts
you need.

The shape:

```
scheduled agent (cron)
  └─ generates cycles/<YYYY-MM>.md, opens a PR
       └─ CI workflow auto-merges report-only PRs
            └─ same CI run posts the digest to Slack
```

## 1. Schedule guard (run on the first weekday only)

Cron granularity is coarse, so a common trick is to fire on the 1st, 2nd, and 3rd of the
month and have the agent self-gate to the **first weekday**: compute the first Mon–Fri of
the current month; if today isn't it, exit immediately without writing or posting anything.
This makes the job idempotent across the three trigger days.

## 2. Let the agent generate + commit, let CI publish

Have the scheduled agent:
1. Run the digest (the steps in `SKILL.md`) and write `cycles/<cycle_label>.md`.
2. `git add cycles/<cycle_label>.md && git commit && git push` to a branch, opening a PR.

Then a CI workflow does the merge + notify. Two reasons to split it this way:

- **Don't post to Slack from the agent.** Many sandboxed agent runners block outbound
  traffic to arbitrary hosts (e.g. `hooks.slack.com` returns 403 "host not in allowlist").
  Firing the webhook from CI, which has open egress, sidesteps that entirely.
- **A report-only PR is trivially safe to auto-merge.** Gate the auto-merge on "this PR
  touches nothing but `cycles/YYYY-MM.md`", so a malformed or scope-creeping change never
  merges itself.

## 3. CI workflow (GitHub Actions example)

```yaml
name: Cycle pipeline (auto-merge + Slack notify)

# Combined workflow: GITHUB_TOKEN-authored pushes don't trigger downstream
# workflows, so doing merge + Slack in the same run sidesteps that.

on:
  pull_request:
    types: [opened, synchronize, reopened]
  workflow_dispatch:
    inputs:
      cycle:
        description: 'Cycle to notify about (YYYY-MM), for ad-hoc fires.'
        required: true
        type: string

permissions:
  contents: write
  pull-requests: write

jobs:
  pr-merge-and-notify:
    if: github.event_name == 'pull_request' && startsWith(github.head_ref, '<agent-branch-prefix>/')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Verify PR only touches cycles/YYYY-MM.md
        id: verify
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          FILES=$(gh pr view ${{ github.event.pull_request.number }} \
                    --json files --jq '.files[].path')
          if [ -z "$FILES" ] || echo "$FILES" | grep -vE '^cycles/[0-9]{4}-[0-9]{2}\.md$' | grep -q .; then
            echo "::warning::PR touches files outside cycles/YYYY-MM.md; not auto-merging."
            echo "safe=false" >> "$GITHUB_OUTPUT"
          else
            CYCLE_FILE=$(echo "$FILES" | head -1)
            echo "safe=true" >> "$GITHUB_OUTPUT"
            echo "report_file=$CYCLE_FILE" >> "$GITHUB_OUTPUT"
            echo "cycle_label=$(basename "$CYCLE_FILE" .md)" >> "$GITHUB_OUTPUT"
          fi

      - name: Merge PR
        if: steps.verify.outputs.safe == 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: gh pr merge ${{ github.event.pull_request.number }} --merge --delete-branch

      - name: Re-checkout main (now includes merged cycle file)
        if: steps.verify.outputs.safe == 'true'
        uses: actions/checkout@v4
        with:
          ref: main

      - name: Post to Slack
        if: steps.verify.outputs.safe == 'true'
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
          REPORT: ${{ steps.verify.outputs.report_file }}
          CYCLE: ${{ steps.verify.outputs.cycle_label }}
          TICKET_BASE_URL: ${{ vars.TICKET_BASE_URL }}
          TICKET_PREFIX: ${{ vars.TICKET_PREFIX }}
        run: python3 references/post-to-slack.py

  manual-notify:
    if: github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: main
      - name: Post to Slack
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
          REPORT: cycles/${{ inputs.cycle }}.md
          CYCLE: ${{ inputs.cycle }}
          TICKET_BASE_URL: ${{ vars.TICKET_BASE_URL }}
          TICKET_PREFIX: ${{ vars.TICKET_PREFIX }}
        run: python3 references/post-to-slack.py
```

## 4. The Slack poster

`references/post-to-slack.py` reads the merged report markdown and posts a trimmed digest
(headline stats, themes, trends) to a Slack incoming webhook. Configure it with env vars:
`SLACK_WEBHOOK_URL`, `REPORT`, `CYCLE`, `GITHUB_REPOSITORY` (auto-set by Actions), and
optionally `TICKET_BASE_URL` / `TICKET_PREFIX`.

### The auto-unfurl trick

If your tracker has a Slack integration, posting raw `<PREFIX>-NNN` ticket keys triggers a
dozen auto-unfurls per message and buries the digest. The poster defends against this two
ways: (1) it strips the `**Tickets:** ...` bullet lines from the themes section entirely,
and (2) for any ticket key left in prose, it inserts a zero-width non-joiner (U+200C)
between the prefix and the number. It's invisible to humans, but it breaks the tracker bot's
regex so the key doesn't unfurl. The clickable link still resolves because the ZWNJ is only
in the visible label, not the URL.
