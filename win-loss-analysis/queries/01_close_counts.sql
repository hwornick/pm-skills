-- Close counts for the quarter, split into Acquisition (new logos) and Retention (renewals).
-- Win rate denominator includes pending (close-date in quarter, not yet closed).
-- Replace {{quarter_start}} (inclusive) and {{quarter_end}} (exclusive) with quarter bounds.
--   e.g. Q1 2026 -> '2026-01-01' / '2026-04-01'
--
-- Optional: to break this out by a market segment (e.g. SMB / Mid / Enterprise, or region),
-- join crm_accounts, add your segment column to the SELECT, and add it to GROUP BY.

WITH opps AS (
  SELECT
    o.id,
    o.record_type,
    o.is_closed,
    o.is_won,
    o.amount
  FROM analytics.crm_opportunities o
  WHERE o.close_date >= '{{quarter_start}}'
    AND o.close_date <  '{{quarter_end}}'
    AND o.record_type IN ('New Logo', 'SaaS Renewal')
    AND COALESCE(o.is_deleted, FALSE) = FALSE
),
classified AS (
  SELECT
    CASE
      WHEN record_type = 'New Logo'     THEN 'Acquisition'
      WHEN record_type = 'SaaS Renewal' THEN 'Retention'
    END AS bucket,
    is_closed, is_won, amount
  FROM opps
)
SELECT
  bucket,
  COUNT_IF(is_closed AND is_won)         AS wins,
  COUNT_IF(is_closed AND NOT is_won)     AS losses,
  COUNT_IF(NOT is_closed)                AS pending,
  COUNT(*)                               AS total,
  ROUND(100.0 * COUNT_IF(is_closed AND is_won) / NULLIF(COUNT(*), 0), 0) AS win_rate_pct,
  ROUND(SUM(IFF(is_closed AND is_won,     amount, NULL)), 0) AS won_arr,
  ROUND(SUM(IFF(is_closed AND NOT is_won, amount, NULL)), 0) AS lost_arr,
  ROUND(SUM(IFF(NOT is_closed,            amount, NULL)), 0) AS pending_arr
FROM classified
GROUP BY bucket
ORDER BY CASE bucket WHEN 'Acquisition' THEN 1 WHEN 'Retention' THEN 2 ELSE 3 END;
