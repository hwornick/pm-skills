-- Trailing-12-month (TTM) product-usage retention for renewals.
-- ARR retention only tells you about the subscription. If your customers also generate
-- usage value (transactions, consumption, seats beyond the plan), this measures how much
-- of that value you kept:
--   numerator   = TTM usage value from accounts whose renewal closed WON in the quarter
--   denominator = TTM usage value from ALL accounts whose renewal CLOSED in the quarter
--
-- TTM is PER OPP: each opp's window is the 12 months ending at THAT opp's close_date,
-- not one shared window for the whole cohort. A renewal that closed in week 1 of the
-- quarter and one that closed in week 13 are each measured over their own prior year.
--
-- usage_value here = (unit_price - unit_discount) * quantity. If you track cost, swap in
-- margin ((price - discount - cost) * quantity) — it's the more honest number.
--
-- ORG ID: a.org_id must be the account's OWN product org, not a parent/ultimate-parent id.
-- See "Configure your data source" in SKILL.md.
--
-- {{quarter_start}}, {{quarter_end}} = quarter bounds
-- Apply step-0 exclusions with: AND o.id NOT IN (...)

WITH renewal_cohort AS (
  SELECT
    o.id                          AS opp_id,
    TRY_CAST(a.org_id AS NUMBER)  AS org_id,
    o.close_date,
    o.is_closed,
    o.is_won
  FROM analytics.crm_opportunities o
  JOIN analytics.crm_accounts a ON o.account_id = a.id
  WHERE o.close_date >= '{{quarter_start}}'
    AND o.close_date <  '{{quarter_end}}'
    AND o.record_type = 'SaaS Renewal'
    AND COALESCE(o.is_deleted, FALSE) = FALSE
    AND a.org_id IS NOT NULL
),
-- Broad window: 12 months before the earliest possible close (quarter_start) through the
-- latest possible close (quarter_end). The per-opp join below trims to each opp's window.
items AS (
  SELECT
    dc.organization_id                     AS org_id,
    fo.line_item_id,
    fo.activity_date,
    ANY_VALUE(fo.unit_price)               AS p,
    ANY_VALUE(COALESCE(fo.unit_discount, 0)) AS d,
    ANY_VALUE(fo.quantity)                 AS q
  FROM analytics.fact_orders fo
  JOIN analytics.dim_customers dc
    ON fo.org_unit_id = dc.org_unit_id
  WHERE fo.activity_date >= DATEADD('month', -12, DATE '{{quarter_start}}')
    AND fo.activity_date <  '{{quarter_end}}'
    AND (NOT dc.is_test_account OR dc.is_test_account IS NULL)
    AND fo.line_item_id IS NOT NULL
    AND dc.organization_id IN (SELECT org_id FROM renewal_cohort)
  GROUP BY dc.organization_id, fo.line_item_id, fo.activity_date
),
per_opp AS (
  SELECT
    rc.opp_id,
    rc.is_closed,
    rc.is_won,
    COALESCE(SUM((i.p - i.d) * i.q), 0) AS ttm_usage_value
  FROM renewal_cohort rc
  LEFT JOIN items i
    ON i.org_id = rc.org_id
   AND i.activity_date >= DATEADD('month', -12, rc.close_date)
   AND i.activity_date <  rc.close_date
  GROUP BY rc.opp_id, rc.is_closed, rc.is_won
)
SELECT
  ROUND(SUM(IFF(is_closed AND is_won, ttm_usage_value, 0))) AS retained_ttm_usage,
  ROUND(SUM(IFF(is_closed,            ttm_usage_value, 0))) AS total_closed_ttm_usage,
  ROUND(100.0
        * SUM(IFF(is_closed AND is_won, ttm_usage_value, 0))
        / NULLIF(SUM(IFF(is_closed,     ttm_usage_value, 0)), 0), 1) AS ttm_usage_retention_pct
FROM per_opp;
