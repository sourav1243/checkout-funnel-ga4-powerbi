-- 01_session_and_funnel_flags.sql
--
-- Purpose: reconstruct unique sessions from the raw GA4 event export and flag,
-- for each session, which funnel stages it reached.
--
-- Techniques: UNNEST (event_params is a repeated STRUCT, not a flat column),
-- CTEs (readable checkpoints you can run independently), conditional
-- aggregation (MAX(CASE WHEN ...) to pivot repeated event rows into one flag
-- column per session).
--
-- BEFORE RUNNING: confirm the real date range with
--   SELECT MIN(event_date), MAX(event_date)
--   FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`;
-- and set _TABLE_SUFFIX below to match. The range used here (2020-11-01 to
-- 2021-01-31) is what the dataset covers as of this writing — verify, don't
-- assume.

WITH events_base AS (
  SELECT
    event_date,
    event_timestamp,
    event_name,
    user_pseudo_id,
    -- ga_session_id lives inside the repeated event_params array, not as its
    -- own column — this is the standard way to pull a single keyed value out
    -- of a REPEATED RECORD field.
    (
      SELECT value.int_value
      FROM UNNEST(event_params) AS ep
      WHERE ep.key = 'ga_session_id'
    ) AS ga_session_id,
    device.category AS device_category,
    geo.country AS country
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'  -- set to your real window
    AND event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')
),

sessions AS (
  SELECT
    -- user_pseudo_id alone isn't unique across visits; pairing it with
    -- ga_session_id is what actually identifies one session.
    CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)) AS unique_session_id,
    event_date,
    event_name,
    device_category,
    country
  FROM events_base
  WHERE ga_session_id IS NOT NULL
),

session_funnel_flags AS (
  SELECT
    unique_session_id,
    MIN(event_date) AS session_date,

    -- device/country can in rare cases vary within one session (e.g. a VPN
    -- switching mid-session, or app+web overlap in edge-case identity
    -- stitching). ANY_VALUE picks one deterministically at the session grain
    -- rather than fanning the session out into multiple rows. This is a
    -- documented simplification, not an oversight — say so if asked.
    ANY_VALUE(device_category) AS device_category,
    ANY_VALUE(country) AS country,

    -- Conditional aggregation: many event rows -> one flag column per stage,
    -- in a single GROUP BY pass instead of four separate queries or a
    -- self-join per stage.
    MAX(CASE WHEN event_name = 'view_item' THEN 1 ELSE 0 END) AS reached_view_item,
    MAX(CASE WHEN event_name = 'add_to_cart' THEN 1 ELSE 0 END) AS reached_add_to_cart,
    MAX(CASE WHEN event_name = 'begin_checkout' THEN 1 ELSE 0 END) AS reached_begin_checkout,
    MAX(CASE WHEN event_name = 'purchase' THEN 1 ELSE 0 END) AS reached_purchase

  FROM sessions
  GROUP BY unique_session_id
)

SELECT *
FROM session_funnel_flags;

-- Save this output as a table before moving to 02, e.g.:
--   CREATE TABLE `your_project.your_dataset.session_funnel_flags` AS
--   <this query>
-- Re-running this as a CTE inside 02 every time works too, but materializing
-- it once is faster to iterate against and is what Phase 3's checks assume.
