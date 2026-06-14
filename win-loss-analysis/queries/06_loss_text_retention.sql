-- Loss text for closed-lost retention (SaaS Renewal) opps in the quarter.
-- For retention churn, the meaningful narrative lives on the ACCOUNT (churn_notes, churn_reason).
-- Sorted by lost ARR descending so the biggest churns surface first.
--
-- {{quarter_start}}, {{quarter_end}} = quarter bounds

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
ORDER BY o.amount DESC NULLS LAST;
