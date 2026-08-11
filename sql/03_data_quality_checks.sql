-- 03_data_quality_checks.sql
--
-- Purpose: the "testing" layer for a SQL pipeline. There's no unit-test
-- framework for a GROUP BY — validation means checking the data actually
-- behaves the way the pipeline assumes it does. Run every block below
-- separately against real output and record the result (in docs/FINDINGS.md
-- or wherever you're tracking it) — including the checks that "obviously"
-- pass. This dataset is documented by Google as obfuscated, with some
-- placeholder values and "somewhat limited" internal consistency, so don't
-- assume a clean result without checking.


-- CHECK 1 — Is the session key actually unique?
-- Expect: total_rows = distinct_sessions. If not, something upstream in
-- 01_session_and_funnel_flags.sql needs fixing before any rate below can be
-- trusted — this is the single most important check in the whole project.
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT unique_session_id) AS distinct_sessions
FROM `your_project.your_dataset.session_funnel_flags`;


-- CHECK 2 — Date coverage: any silent gaps in the 3-month window?
-- Expect: one row per calendar day in range, no day with a suspiciously
-- near-zero count. Also run this FIRST, before Phase 0, to confirm the real
-- available range rather than assuming Nov 2020–Jan 2021 still holds.
SELECT
  event_date,
  COUNT(*) AS row_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY event_date
ORDER BY event_date;


-- CHECK 3 — Null segment values
-- Some nulls are normal (ad blockers, privacy settings, IP-geo lookup
-- misses). Decide up front whether to report them as their own "Unknown"
-- segment or exclude them — and say which you did in docs/FINDINGS.md.
-- Silently dropping them without saying so isn't a defensible choice.
SELECT
  COUNTIF(country IS NULL) AS null_country_sessions,
  COUNTIF(device_category IS NULL) AS null_device_sessions,
  COUNT(*) AS total_sessions
FROM `your_project.your_dataset.session_funnel_flags`;


-- CHECK 4 — Funnel monotonicity: flag, don't assume
-- If either count below is non-zero, that's a real, reportable path through
-- the funnel (e.g. a "buy now" flow that skips the cart) — not a bug to
-- quietly filter out to make the funnel chart look cleaner.
SELECT
  COUNTIF(reached_purchase = 1 AND reached_begin_checkout = 0)
    AS purchased_without_checkout_event,
  COUNTIF(reached_begin_checkout = 1 AND reached_add_to_cart = 0)
    AS checkout_without_cart_event,
  COUNT(*) AS total_sessions
FROM `your_project.your_dataset.session_funnel_flags`;


-- CHECK 5 — Segment table reconciles to the session table
-- Run this, then compare segment_table_total to Check 1's total_rows.
-- They must match exactly, or Query A in 02 has a grouping bug.
SELECT SUM(total_sessions) AS segment_table_total
FROM (
  SELECT country, device_category, COUNT(*) AS total_sessions
  FROM `your_project.your_dataset.session_funnel_flags`
  GROUP BY country, device_category
);


-- CHECK 6 — Outlier / bot-like sessions
-- A session with an implausible number of funnel events in a short window
-- is more likely a bot/crawler than a real shopper, and can drag rates down
-- artificially. This checks session *duration and event density* at the
-- source-event level, before the Phase 1 rollup collapses it away.
SELECT
  unique_session_id,
  COUNT(*) AS event_row_count,
  TIMESTAMP_DIFF(
    TIMESTAMP_MICROS(MAX(event_timestamp)),
    TIMESTAMP_MICROS(MIN(event_timestamp)),
    SECOND
  ) AS session_span_seconds
FROM (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST(
      (SELECT value.int_value FROM UNNEST(event_params) AS ep WHERE ep.key = 'ga_session_id')
      AS STRING)) AS unique_session_id,
    event_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)
GROUP BY unique_session_id
HAVING event_row_count > 100  -- adjust threshold once you see the real distribution
ORDER BY event_row_count DESC
LIMIT 50;


-- A note on numbers not matching the GA4 UI, if you ever compare:
-- the UI applies sampling/thresholding above certain volumes and uses the
-- property's reporting timezone; this export doesn't sample and is queried
-- in UTC by default. Small drift is expected and not a bug in this pipeline.
