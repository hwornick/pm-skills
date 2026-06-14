-- Subscription tier + add-on breakdown for won acquisition orgs.
-- Returns one row per won org with its current subscription product string. The
-- orchestrator parses subscription_products to tally tiers (Starter/Standard/Pro)
-- and add-ons (e.g. paid integrations).
--
-- {{quarter_start}}, {{quarter_end}} = quarter bounds

WITH won_orgs AS (
  SELECT DISTINCT
    TRY_CAST(a.org_id AS NUMBER) AS org_id,
    a.name AS account_name
  FROM analytics.crm_opportunities o
  JOIN analytics.crm_accounts a ON o.account_id = a.id
  WHERE o.close_date >= '{{quarter_start}}'
    AND o.close_date <  '{{quarter_end}}'
    AND o.is_closed AND o.is_won
    AND o.record_type = 'New Logo'
    AND COALESCE(o.is_deleted, FALSE) = FALSE
)
SELECT
  w.account_name,
  w.org_id,
  dc.subscription_products,
  ROUND(dc.current_mrr, 2) AS current_mrr,
  ROUND(dc.addons_mrr, 2)  AS addons_mrr
FROM won_orgs w
LEFT JOIN analytics.dim_customers dc
  ON dc.organization_id = w.org_id
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY w.org_id
  ORDER BY dc.current_mrr DESC NULLS LAST
) = 1
ORDER BY w.account_name;
