-- Per-opp data for the "New Logos" sheet of the raw-data spreadsheet.
-- One row per New Logo opp closed in the quarter (won + lost) PLUS pending New Logo
-- opps whose close_date falls in the quarter. Pending rows are included so the
-- spreadsheet captures the full quarterly pipeline.
--
-- {{quarter_start}}, {{quarter_end}} = quarter bounds

SELECT
  o.name                                    AS opportunity_name,
  o.reason_for_win_loss,
  o.opportunity_notes,
  o.stage_name,
  TRY_CAST(a.org_id AS NUMBER)              AS org_id,
  a.name                                    AS org_name,
  COALESCE(a.country_code, a.billing_country_code, a.billing_country) AS org_country,
  COALESCE(u_opp.name, a.account_owner_name) AS opp_or_account_owner,
  o.amount                                  AS new_arr_or_amount,
  o.lost_reason_code                        AS opportunity_lost_reason
FROM analytics.crm_opportunities o
LEFT JOIN analytics.crm_accounts a     ON o.account_id = a.id
LEFT JOIN analytics.crm_users      u_opp ON o.owner_id  = u_opp.user_id
WHERE o.close_date >= '{{quarter_start}}'
  AND o.close_date <  '{{quarter_end}}'
  AND o.record_type = 'New Logo'
  AND COALESCE(o.is_deleted, FALSE) = FALSE
ORDER BY o.is_closed, o.is_won DESC, a.name;
