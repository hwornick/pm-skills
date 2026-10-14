-- Won + lost logos with industry/description signals, for the vertical-analysis appendix.
-- One row per closed-won or closed-lost New Logo opp in the quarter.

SELECT
  o.id                       AS opp_id,
  a.name                     AS account_name,
  o.is_won,
  o.amount                   AS arr,
  o.industry,
  o.product_info,
  o.biggest_pain_point,
  o.description              AS opp_description,
  o.purchasing_type,
  o.purchasing_system,
  a.industry_category        AS account_category,
  a.sub_category             AS account_sub_category,
  a.account_focus
FROM analytics.crm_opportunities o
JOIN analytics.crm_accounts a ON o.account_id = a.id
WHERE o.close_date >= '{{quarter_start}}'
  AND o.close_date <  '{{quarter_end}}'
  AND o.is_closed = TRUE
  AND o.record_type = 'New Logo'
  AND COALESCE(o.is_deleted, FALSE) = FALSE
ORDER BY o.is_won DESC, a.name;
