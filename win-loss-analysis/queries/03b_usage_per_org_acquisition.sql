-- Per-org product-usage activity for won acquisition orgs.
-- One row per won org. LEFT JOIN to fact_orders so zero-activity orgs still appear.
-- Used to classify each won org into one of:
--   * inactive:              engagements = 0  (org never appeared in fact_orders in the window)
--   * active_not_purchasing: engagements > 0 AND usage_value = 0
--   * purchasing:            usage_value > 0
--
-- {{usage_window_start}} = start of the quarter BEFORE the report quarter
-- {{quarter_start}}, {{quarter_end}} = bounds of the report quarter
-- {{report_date}}        = today, exclusive upper bound on activity

WITH won_orgs AS (
  SELECT DISTINCT
    a.name                          AS account_name,
    TRY_CAST(a.org_id AS NUMBER)    AS org_id
  FROM analytics.crm_opportunities o
  JOIN analytics.crm_accounts a ON o.account_id = a.id
  WHERE o.close_date >= '{{quarter_start}}'
    AND o.close_date <  '{{quarter_end}}'
    AND o.is_closed AND o.is_won
    AND o.record_type = 'New Logo'
    AND COALESCE(o.is_deleted, FALSE) = FALSE
),
activity AS (
  SELECT
    dc.organization_id                                       AS org_id,
    COUNT(DISTINCT fo.activity_id)                           AS engagements,
    ROUND(SUM((fo.unit_price - COALESCE(fo.unit_discount, 0)) * fo.quantity)) AS usage_value
  FROM analytics.fact_orders fo
  JOIN analytics.dim_customers dc
    ON fo.org_unit_id = dc.org_unit_id
  WHERE fo.activity_date >= '{{usage_window_start}}'
    AND fo.activity_date <  '{{report_date}}'
    AND (NOT dc.is_test_account OR dc.is_test_account IS NULL)
    AND fo.activity_id IS NOT NULL
    AND dc.organization_id IN (SELECT org_id FROM won_orgs WHERE org_id IS NOT NULL)
  GROUP BY dc.organization_id
)
SELECT
  w.account_name,
  w.org_id,
  COALESCE(act.engagements, 0)  AS engagements,
  COALESCE(act.usage_value, 0)  AS usage_value
FROM won_orgs w
LEFT JOIN activity act ON act.org_id = w.org_id
ORDER BY w.account_name;
