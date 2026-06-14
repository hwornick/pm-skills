# win-loss-analysis

**A quarterly win/loss report that gets past the loss-reason picklist to the actual *why*,
and ties every win to whether the customer actually adopted the product.**

## Why this exists

Most win/loss reviews are a bar chart of the CRM loss-reason field. That field is the least
trustworthy signal in the whole dataset: it's a single-select a rep clicked on the way out
the door, and it systematically hides the real story. "No budget" is sometimes true and
sometimes a polite way of saying we never conveyed value. "Too small" is sometimes a
solo founder and sometimes a ten-person team we failed to show up for.

This skill encodes a more honest method:

- **Surface reason vs. underlying reason.** Every loss is read across the free-text fields,
  the notes, and live company research (funding stage, headcount, public/private) to
  separate what the rep wrote from what actually drove the decision.
- **Three lenses, not one bucket.** Losses sort into *product gaps* (build this), *positioning/GTM
  gaps* (say it better, price it better), and *external* (genuinely out of our control),
  because those three demand completely different responses.
- **Overlap quantified.** Within each product area it asks: are these five losses the *same*
  gap or five *different* gaps? That's the difference between "build one thing, win five
  deals" and "build five things to win five deals."
- **Wins measured by adoption, not signatures.** It rolls won logos forward into real
  product-usage data (who's active, who's purchasing, who signed and then ghosted) so a
  "win" that never adopted doesn't get to hide.

The report splits into **Acquisition** (new logos) and **Retention** (renewals), uses ARR
as its business metric, and outputs a polished markdown report plus a two-sheet
raw-data spreadsheet.

## What it produces

A markdown report (matching [`template.md`](template.md)) with win rates and ARR for
Acquisition and Retention, a product-adoption rollup for won logos, a subscription-tier breakdown,
a deeply-analyzed loss-themes section, a new-logo vertical-analysis appendix, and a linked XLSX 
of the underlying opportunities.

## How to use

1. **Configure your data source.** The bundled SQL in [`queries/`](queries/) uses generic
   table/column placeholders (`analytics.crm_opportunities`, `fact_orders`, `dim_customers`,
   etc.). Map them to your warehouse — see the "Configure your data source" section of
   [`SKILL.md`](SKILL.md). If you have no product-usage fact, the adoption steps are
   skippable and the rest still works. Market segmentation (SMB/Mid/Enterprise, region,
   etc.) is off by default and documented as an optional add-on.
2. Invoke the skill (e.g. "generate the quarterly win/loss report"). It defaults to the
   prior complete quarter.
3. It pulls counts and loss text, researches the new logos, clusters the losses, and
   assembles the report + spreadsheet.

The full step-by-step lives in [`SKILL.md`](SKILL.md).

> Built for a Snowflake + Salesforce-style stack but written to be repointed at any SQL
> warehouse and CRM.
