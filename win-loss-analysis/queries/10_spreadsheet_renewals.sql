-- Per-opp data for the "Renewals" sheet of the raw-data spreadsheet.
-- One row per SaaS Renewal opp closed in the quarter (won + lost) PLUS pending
-- renewal opps whose close_date falls in the quarter. Pending rows are included
-- so the spreadsheet captures the full quarterly pipeline.
--
-- {{quarter_start}}, {{quarter_end}} = quarter bounds

SELECT
  a.name                                    AS account_name,
  TRY_CAST(a.org_id AS NUMBER)              AS org_id,
  o.amount                                  AS amount,
  o.stage_name                              AS stage,
  u.name                                    AS opportunity_owner,
  o.close_date,
  a.churn_notes,
  o.next_step
FROM analytics.crm_opportunities o
LEFT JOIN analytics.crm_accounts a ON o.account_id = a.id
LEFT JOIN analytics.crm_users     u ON o.owner_id  = u.user_id
WHERE o.close_date >= '{{quarter_start}}'
  AND o.close_date <  '{{quarter_end}}'
  AND o.record_type = 'SaaS Renewal'
  AND COALESCE(o.is_deleted, FALSE) = FALSE
ORDER BY a.name;
