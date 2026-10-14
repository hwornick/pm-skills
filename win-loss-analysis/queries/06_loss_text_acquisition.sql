-- Loss text for closed-lost acquisition opps in the quarter.
-- Returns one row per lost opp with all three signals for clustering:
--   lost_reason_code     (low-weight, single-select picklist)
--   reason_for_win_loss  (high-weight, free text)
--   opportunity_notes    (high-weight, free text)
--
-- {{quarter_start}}, {{quarter_end}} = quarter bounds
-- ORG ID: a.org_id must be the account's OWN product org, not a parent/ultimate-parent id
-- (see "Configure your data source" in SKILL.md).
-- Apply step-0 overrides/exclusions here too (see "Applying overrides" in SKILL.md).

SELECT
  o.id                            AS opp_id,
  a.name                          AS account_name,
  a.id                            AS account_id,
  TRY_CAST(a.org_id AS NUMBER)    AS org_id,
  o.amount                        AS arr,
  o.close_date,
  o.lost_reason_code              AS lost_reason_picklist,
  o.reason_for_win_loss,
  o.opportunity_notes,
  o.lost_details,
  o.purchasing_type,
  o.purchasing_system,
  o.software_competitors,
  o.competitors,
  o.industry
FROM analytics.crm_opportunities o
JOIN analytics.crm_accounts a ON o.account_id = a.id
WHERE o.close_date >= '{{quarter_start}}'
  AND o.close_date <  '{{quarter_end}}'
  AND o.is_closed = TRUE
  AND o.is_won    = FALSE
  AND o.record_type = 'New Logo'
  AND COALESCE(o.is_deleted, FALSE) = FALSE
ORDER BY o.amount DESC NULLS LAST;
