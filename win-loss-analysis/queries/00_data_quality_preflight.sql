-- Data-quality preflight.
-- Scans every closed + pending opp in the quarter for records that would silently distort
-- the counts if left alone. Returns one row per flagged opp with the matched signal(s).
-- The orchestrator surfaces this list to the user and WAITS for confirmation before
-- applying any override or exclusion. Nothing here is auto-applied.
--
-- Checks:
--   1. segment_signals — the CRM says one segment, but the account/opp name implies another.
--      Example below: a commercial/public-sector split, where names like "University",
--      "Hospital", ".edu", "Department of" imply public sector / education. Swap the keyword
--      list for your own segments, or delete this check if you don't segment.
--   2. region_signals  — the account is tagged as your home market, but the name OR the
--      loss text says it's somewhere else (country names, "(UK)"-style suffixes,
--      "international" in the notes).
--   3. test_signals    — test accounts that inflate counts (usually $0 ARR).
--   4. dupe_signals    — duplicate opps that reps flagged in the loss text.
--
-- {{quarter_start}}, {{quarter_end}} = quarter bounds
-- {{home_country}} = your home-market ISO code, e.g. 'US'
-- Placeholder columns: a.segment (optional), a.country_code, a.is_test_account

WITH opps AS (
  SELECT
    o.id                     AS opp_id,
    o.name                   AS opp_name,
    o.record_type,
    o.is_closed,
    o.is_won,
    o.amount,
    a.id                     AS account_id,
    a.name                   AS account_name,
    a.segment,
    COALESCE(a.country_code, a.billing_country_code) AS country_code,
    a.is_test_account,
    UPPER(COALESCE(a.name, '') || ' ' || COALESCE(o.name, ''))                        AS name_text,
    UPPER(COALESCE(o.reason_for_win_loss, '') || ' ' || COALESCE(o.opportunity_notes, '')) AS loss_text
  FROM analytics.crm_opportunities o
  LEFT JOIN analytics.crm_accounts a ON o.account_id = a.id
  WHERE o.close_date >= '{{quarter_start}}'
    AND o.close_date <  '{{quarter_end}}'
    AND o.record_type IN ('New Logo', 'SaaS Renewal')
    AND COALESCE(o.is_deleted, FALSE) = FALSE
),
flagged AS (
  SELECT
    opp_id, account_id, account_name, opp_name, record_type,
    segment, country_code, is_closed, is_won, amount,

    -- 1. Segment signal (only for opps currently tagged Commercial — adapt the label)
    CASE WHEN segment = 'Commercial' THEN
      ARRAY_TO_STRING(ARRAY_COMPACT(ARRAY_CONSTRUCT(
        IFF(name_text LIKE '%UNIVERSITY%',      'university',     NULL),
        IFF(name_text LIKE '%COLLEGE%',         'college',        NULL),
        IFF(name_text LIKE '%HOSPITAL%',        'hospital',       NULL),
        IFF(name_text LIKE '%HEALTH SYSTEM%',   'health system',  NULL),
        IFF(name_text LIKE '%DEPARTMENT OF%',   'department of',  NULL),
        IFF(name_text LIKE '%MINISTRY OF%',     'ministry of',    NULL),
        IFF(name_text LIKE '%STATE OF %' OR name_text LIKE '%COUNTY OF %' OR name_text LIKE '%CITY OF %', 'state/county/city of', NULL),
        IFF(name_text LIKE '%.EDU%',            '.edu',           NULL),
        IFF(name_text LIKE '%FOUNDATION%',      'foundation (low confidence)', NULL)
      )), ', ')
    END AS segment_signals,

    -- 2. Region signal (only for opps currently tagged as the home market)
    --
    -- The parenthetical-suffix regex is an explicit allowlist of country codes. Leave out
    -- codes that collide with your home market's state/province abbreviations (for a US
    -- home market: CA, IL, IN, etc. read as states far more often than countries) and rely
    -- on the country-name LIKEs for those countries instead.
    CASE WHEN COALESCE(country_code, '{{home_country}}') = '{{home_country}}' THEN
      ARRAY_TO_STRING(ARRAY_COMPACT(ARRAY_CONSTRUCT(
        IFF(REGEXP_LIKE(name_text, '.*\\((UK|GB|FR|DE|JP|KR|CN|SG|CH|NL|BR|MX|AU|NZ|BE|SE|NO|DK|FI|ES|IT|AT|PL|IE|TW|HK|AE|ZA)\\).*'),
            'country-code suffix in name', NULL),
        IFF(name_text LIKE '%CANADA%'      OR loss_text LIKE '%CANADA%',      'Canada',      NULL),
        IFF(name_text LIKE '%GERMANY%'     OR loss_text LIKE '%GERMANY%',     'Germany',     NULL),
        IFF(name_text LIKE '%FRANCE%'      OR loss_text LIKE '%FRANCE%',      'France',      NULL),
        IFF(name_text LIKE '%UNITED KINGDOM%' OR loss_text LIKE '%UNITED KINGDOM%', 'UK',    NULL),
        IFF(name_text LIKE '%ISRAEL%'      OR loss_text LIKE '%ISRAEL%',      'Israel',      NULL),
        IFF(name_text LIKE '%INDIA%'       OR loss_text LIKE '%INDIA %',      'India',       NULL),
        IFF(name_text LIKE '%JAPAN%'       OR loss_text LIKE '%JAPAN%',       'Japan',       NULL),
        IFF(name_text LIKE '%KOREA%'       OR loss_text LIKE '%KOREA%',       'Korea',       NULL),
        IFF(name_text LIKE '%CHINA%'       OR loss_text LIKE '%CHINA%',       'China',       NULL),
        IFF(name_text LIKE '%SINGAPORE%'   OR loss_text LIKE '%SINGAPORE%',   'Singapore',   NULL),
        IFF(name_text LIKE '%AUSTRALIA%'   OR loss_text LIKE '%AUSTRALIA%',   'Australia',   NULL),
        IFF(name_text LIKE '%SWITZERLAND%' OR loss_text LIKE '%SWITZERLAND%', 'Switzerland', NULL),
        IFF(name_text LIKE '%NETHERLANDS%' OR loss_text LIKE '%NETHERLANDS%', 'Netherlands', NULL),
        IFF(name_text LIKE '%MEXICO%'      OR loss_text LIKE '%MEXICO%',      'Mexico',      NULL),
        IFF(name_text LIKE '%BRAZIL%'      OR loss_text LIKE '%BRAZIL%',      'Brazil',      NULL),
        IFF(loss_text LIKE '%INTERNATIONAL%' OR loss_text LIKE '% INTL%',     '"international" in loss text', NULL)
      )), ', ')
    END AS region_signals,

    -- 3. Test-account signal
    NULLIF(ARRAY_TO_STRING(ARRAY_COMPACT(ARRAY_CONSTRUCT(
      IFF(is_test_account,                                  'test-account flag', NULL),
      IFF(REGEXP_LIKE(name_text, '.*\\bTEST\\b.*'),         '"test" in name',    NULL)
    )), ', '), '') AS test_signals,

    -- 4. Duplicate-opp signal (reps usually say so in the notes)
    NULLIF(ARRAY_TO_STRING(ARRAY_COMPACT(ARRAY_CONSTRUCT(
      IFF(loss_text LIKE '%DUPLICATE%' OR REGEXP_LIKE(loss_text, '.*\\bDUPE\\b.*'), 'duplicate mentioned', NULL),
      IFF(loss_text LIKE '%DIDN''T MEAN TO CREATE%' OR loss_text LIKE '%CREATED BY MISTAKE%', 'created by mistake', NULL)
    )), ', '), '') AS dupe_signals
  FROM opps
)
SELECT *
FROM flagged
WHERE NULLIF(segment_signals, '') IS NOT NULL
   OR NULLIF(region_signals,  '') IS NOT NULL
   OR test_signals IS NOT NULL
   OR dupe_signals IS NOT NULL
ORDER BY record_type, account_name;
