-- Resolves the list of organization_ids for won acquisition (New Logo) opps in the quarter.
-- Used as the cohort for the product-usage + subscription rollups.
-- {{quarter_start}}, {{quarter_end}} = quarter bounds
-- ORG ID: a.org_id must be the account's OWN product org, not a parent/ultimate-parent id
-- (see "Configure your data source" in SKILL.md).
-- Apply step-0 overrides/exclusions here too (see "Applying overrides" in SKILL.md).

WITH won_opps AS (
  SELECT DISTINCT
    o.id                            AS opp_id,
    o.account_id,
    a.name                          AS account_name,
    a.org_id                        AS org_id_text,
    TRY_CAST(a.org_id AS NUMBER)    AS org_id
  FROM analytics.crm_opportunities o
  JOIN analytics.crm_accounts a
    ON o.account_id = a.id
  WHERE o.close_date >= '{{quarter_start}}'
    AND o.close_date <  '{{quarter_end}}'
    AND o.is_closed = TRUE
    AND o.is_won    = TRUE
    AND o.record_type = 'New Logo'
    AND COALESCE(o.is_deleted, FALSE) = FALSE
)
SELECT * FROM won_opps ORDER BY account_name;
