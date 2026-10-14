-- Loss text for closed-lost retention (SaaS Renewal) opps in the quarter.
-- For retention churn, the meaningful narrative lives on the ACCOUNT (churn_notes, churn_reason).
--
-- Also returns ttm_usage_value per lost account: product-usage value in the 12 months ending
-- at THAT opp's close_date (per-opp window, not a shared one). Sorted by TTM usage value,
-- then lost ARR, so the churns that cost the most total value surface first. If you have no
-- product-usage fact, drop the items/per_opp_ttm CTEs and sort by lost_arr.
--
-- ORG ID: a.org_id must be the account's OWN product org, not a parent/ultimate-parent id.
--
-- {{quarter_start}}, {{quarter_end}} = quarter bounds
-- Apply step-0 exclusions with: AND o.id NOT IN (...)

WITH lost_opps AS (
  SELECT
    o.id                            AS opp_id,
    a.id                            AS account_id,
    a.name                          AS account_name,
    TRY_CAST(a.org_id AS NUMBER)    AS org_id,
    o.amount                        AS lost_arr,
    o.close_date,
    a.churn_notes,
    a.churn_reason,
    a.churn_risk,
    a.date_churned,
    o.lost_reason_code              AS lost_reason_picklist,
    o.reason_for_win_loss,
    o.opportunity_notes
  FROM analytics.crm_opportunities o
  JOIN analytics.crm_accounts a ON o.account_id = a.id
  WHERE o.close_date >= '{{quarter_start}}'
    AND o.close_date <  '{{quarter_end}}'
    AND o.is_closed = TRUE
    AND o.is_won    = FALSE
    AND o.record_type = 'SaaS Renewal'
    AND COALESCE(o.is_deleted, FALSE) = FALSE
),
-- Broad window covering every lost opp's 12-month lookback; trimmed per opp below.
items AS (
  SELECT
    dc.organization_id                       AS org_id,
    fo.line_item_id,
    fo.activity_date,
    ANY_VALUE(fo.unit_price)                 AS p,
    ANY_VALUE(COALESCE(fo.unit_discount, 0)) AS d,
    ANY_VALUE(fo.quantity)                   AS q
  FROM analytics.fact_orders fo
  JOIN analytics.dim_customers dc
    ON fo.org_unit_id = dc.org_unit_id
  WHERE fo.activity_date >= DATEADD('month', -12, DATE '{{quarter_start}}')
    AND fo.activity_date <  '{{quarter_end}}'
    AND (NOT dc.is_test_account OR dc.is_test_account IS NULL)
    AND fo.line_item_id IS NOT NULL
    AND dc.organization_id IN (SELECT org_id FROM lost_opps WHERE org_id IS NOT NULL)
  GROUP BY dc.organization_id, fo.line_item_id, fo.activity_date
),
per_opp_ttm AS (
  SELECT
    lo.opp_id,
    ROUND(SUM((i.p - i.d) * i.q)) AS ttm_usage_value
  FROM lost_opps lo
  LEFT JOIN items i
    ON i.org_id = lo.org_id
   AND i.activity_date >= DATEADD('month', -12, lo.close_date)
   AND i.activity_date <  lo.close_date
  GROUP BY lo.opp_id
)
SELECT
  lo.*,
  pot.ttm_usage_value
FROM lost_opps lo
LEFT JOIN per_opp_ttm pot ON pot.opp_id = lo.opp_id
ORDER BY COALESCE(pot.ttm_usage_value, 0) DESC, lo.lost_arr DESC NULLS LAST;
