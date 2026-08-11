-- 02_segment_and_trend_summary.sql
--
-- Purpose: roll session-level funnel flags up to the two shapes the project
-- actually needs — a country x device segment table (for Power BI) and a
-- weekly trend by device (for "friction trends," not just one snapshot).
--
-- Depends on: 01_session_and_funnel_flags.sql, materialized as a table.
-- Replace `your_project.your_dataset.session_funnel_flags` below with the
-- real table you saved.
--
-- Note: rates are deliberately NOT computed here — only counts. See
-- docs/PROJECT_SPEC.md §8 for why. Excel and Power BI compute the rates
-- independently, downstream.


-- ============================================================
-- QUERY A — Segment summary: country x device (feeds Power BI)
-- ============================================================
SELECT
  country,
  device_category,
  COUNT(*) AS total_sessions,
  SUM(reached_view_item) AS sessions_viewed_item,
  SUM(reached_add_to_cart) AS sessions_added_to_cart,
  SUM(reached_begin_checkout) AS sessions_began_checkout,
  SUM(reached_purchase) AS sessions_purchased
FROM `your_project.your_dataset.session_funnel_flags`
GROUP BY country, device_category
ORDER BY total_sessions DESC;


-- ==================================================================
-- QUERY B — Weekly trend by device category (feeds the trend line)
-- ==================================================================
-- session_date is a STRING in 'YYYYMMDD' format (matches GA4's event_date);
-- parse it before truncating to a week so DATE_TRUNC works correctly.
SELECT
  DATE_TRUNC(PARSE_DATE('%Y%m%d', session_date), WEEK(MONDAY)) AS week_start,
  device_category,
  COUNT(*) AS total_sessions,
  SUM(reached_purchase) AS sessions_purchased
FROM `your_project.your_dataset.session_funnel_flags`
GROUP BY week_start, device_category
ORDER BY week_start, device_category;


-- ======================================================================
-- QUERY C — Device-only benchmark (used ONLY for the Excel cross-check)
-- ======================================================================
-- Deliberately re-aggregated at a different, coarser grain than Query A.
-- In Excel, SUMIFS rolls Query A's country x device numbers up to
-- device-only and compares them against this query's numbers pasted
-- alongside. If they don't match exactly, the grouping logic in Query A
-- (or the SUMIFS formula) has a real bug — this is what actually tests the
-- pipeline, not just the arithmetic.
SELECT
  device_category,
  COUNT(*) AS total_sessions,
  SUM(reached_purchase) AS sessions_purchased
FROM `your_project.your_dataset.session_funnel_flags`
GROUP BY device_category
ORDER BY total_sessions DESC;
