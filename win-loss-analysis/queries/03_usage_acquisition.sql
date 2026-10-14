-- Product-usage rollup for won acquisition orgs.
-- Window: start of the PRIOR quarter through report_date. Starts one quarter early
-- to catch trial / onboarding activity that precedes the won opp's close date.
-- Distinct-ID aggregation handled via subqueries to avoid join fan-out.
--
-- {{usage_window_start}} = start of the quarter BEFORE the report quarter, e.g. '2025-10-01' for Q1 2026
-- {{quarter_start}}, {{quarter_end}} = bounds of the report quarter (used to identify won opps)
-- {{report_date}}        = today, exclusive upper bound of the activity window
-- ORG ID: a.org_id must be the account's OWN product org, not a parent/ultimate-parent id
-- (see "Configure your data source" in SKILL.md).
-- Apply step-0 overrides/exclusions here too (see "Applying overrides" in SKILL.md).

WITH won_orgs AS (
  SELECT DISTINCT TRY_CAST(a.org_id AS NUMBER) AS org_id
  FROM analytics.crm_opportunities o
  JOIN analytics.crm_accounts a ON o.account_id = a.id
  WHERE o.close_date >= '{{quarter_start}}'
    AND o.close_date <  '{{quarter_end}}'
    AND o.is_closed AND o.is_won
    AND o.record_type = 'New Logo'
    AND COALESCE(o.is_deleted, FALSE) = FALSE
),
base AS (
  SELECT
    fo.line_item_id,
    fo.activity_id,
    fo.unit_price,
    COALESCE(fo.unit_discount, 0) AS unit_disc,
    fo.quantity,
    dc.organization_id AS dim_org_id,
    du.user_id         AS dim_user_id
  FROM analytics.fact_orders fo
  JOIN analytics.dim_customers dc
    ON fo.org_unit_id = dc.org_unit_id
  LEFT JOIN analytics.dim_users du
    ON fo.user_unit_id = du.org_unit_user_id
  JOIN won_orgs w
    ON dc.organization_id = w.org_id
  WHERE fo.activity_date >= '{{usage_window_start}}'
    AND fo.activity_date <  '{{report_date}}'
    AND (NOT dc.is_test_account OR dc.is_test_account IS NULL)
    AND fo.activity_id IS NOT NULL
),
distinct_items AS (
  SELECT
    line_item_id,
    ANY_VALUE(unit_price) AS p,
    ANY_VALUE(unit_disc)  AS d,
    ANY_VALUE(quantity)   AS q
  FROM base WHERE line_item_id IS NOT NULL
  GROUP BY line_item_id
)
SELECT
  (SELECT COUNT(DISTINCT dim_org_id) FROM base)                                AS active_orgs,
  (SELECT COUNT(DISTINCT dim_user_id) FROM base WHERE dim_user_id IS NOT NULL) AS users,
  (SELECT ROUND(SUM((p - d) * q)) FROM distinct_items)                         AS usage_value;
