# Power BI Dashboard — Build Guide

This is a build guide, not a `.pbix` file. Power BI's file format isn't
something that can be authored outside Power BI Desktop itself, so this
walks through exactly what to build — data model, every DAX measure, and
page layout — so the result matches what the resume line claims: *"an
interactive Power BI dashboard to compare checkout conversion performance
across countries and device categories, enabling identification of
high-friction stages."*

## 1. Get the data in

Two options, either is defensible:

- **Import from CSV** — run `sql/02` Query A and Query B in BigQuery, export
  each result as CSV, `Get Data → Text/CSV` in Power BI. Simplest, and
  matches a one-time analysis deliverable.
- **Import via the native BigQuery connector** — `Get Data → More → Google
  BigQuery`, sign in with your GCP account, navigate to your dataset/table.
  Use **Import** mode (not DirectQuery) — this is aggregated, small data;
  DirectQuery only earns its complexity if the dashboard needs to reflect
  live, constantly-changing data, which a static 3-month analysis doesn't.

Load two tables:
- `segment_summary` — Query A's output (country, device_category, and the
  four count columns)
- `weekly_trend` — Query B's output (week_start, device_category, the two
  count columns)

**Do not import `session_funnel_flags` directly.** Keeping raw session-level
data out of Power BI is a deliberate choice — it keeps the file light and
matches the design decision in `docs/PROJECT_SPEC.md` §8 that BigQuery
computes counts, and Power BI/Excel compute ratios.

## 2. Data model

Two independent tables, no relationship needed between them for this
dashboard (both are pre-aggregated at different grains and used on
different visuals) — don't force a fake join just because Power BI's model
view expects one.

## 3. DAX measures

Import **counts only**; every rate is a measure, so it recalculates
correctly under any slicer combination instead of being frozen at the SQL
query's grain.

```dax
Total Sessions = SUM(segment_summary[total_sessions])
Sessions Viewed Item = SUM(segment_summary[sessions_viewed_item])
Sessions Added to Cart = SUM(segment_summary[sessions_added_to_cart])
Sessions Began Checkout = SUM(segment_summary[sessions_began_checkout])
Sessions Purchased = SUM(segment_summary[sessions_purchased])

View-to-Cart Rate =
DIVIDE([Sessions Added to Cart], [Sessions Viewed Item])

Cart-to-Checkout Rate =
DIVIDE([Sessions Began Checkout], [Sessions Added to Cart])

Checkout-to-Purchase Rate =
DIVIDE([Sessions Purchased], [Sessions Began Checkout])

Overall Conversion Rate =
DIVIDE([Sessions Purchased], [Total Sessions])
```

`DIVIDE()` instead of `/` specifically because some segments will have zero
sessions at a given stage — `DIVIDE` returns blank instead of erroring the
whole visual.

For the weekly trend page, against the `weekly_trend` table:

```dax
Weekly Sessions = SUM(weekly_trend[total_sessions])
Weekly Purchases = SUM(weekly_trend[sessions_purchased])
Weekly Conversion Rate = DIVIDE([Weekly Purchases], [Weekly Sessions])
```

## 4. Page 1 — Overview

- **KPI cards** (top row): Total Sessions, Overall Conversion Rate, Sessions
  Purchased.
- **Funnel visual**: the four stage totals (`Sessions Viewed Item` →
  `Sessions Added to Cart` → `Sessions Began Checkout` → `Sessions
  Purchased`) — this is the single chart that answers "where does the
  biggest drop happen," at a glance.
- **Line chart**: `Weekly Conversion Rate` by `week_start`, one line per
  `device_category` — this is what actually shows a *trend*, not just a
  snapshot. Add a slicer for device category.

## 5. Page 2 — Segment Comparison

- **Matrix visual**: rows = `country`, columns = `device_category`, values =
  `Cart-to-Checkout Rate` (or whichever stage-to-stage rate you want to lead
  with). Apply conditional formatting (background color scale) so it reads
  as a heatmap — this is the "identify high-friction stages" deliverable
  from the resume line, made literally visible.
- **Always show `Total Sessions` next to the rate** — either as a second
  matrix values column or a tooltip. A 100% or 0% rate from a 3-session
  country is noise, not a finding; showing the volume alongside the rate is
  what keeps the dashboard honest.
- **Bar chart**: Top 10 countries by `Total Sessions`, to give scale context
  before anyone starts reading rates.
- Slicers: `device_category`, and a country search/filter if the list is
  long.

## 6. Formatting notes

- One consistent color per device category across both pages (set it once
  in a theme, don't let Power BI auto-assign different colors per visual).
- Format every rate measure as a percentage (right-click the measure →
  Format → Percentage), not a raw decimal.
- Sort the segment matrix by session volume by default, not alphabetically
  or by rate — otherwise tiny, noisy segments float to the top just because
  their rate looks extreme.
- Skip 3D visuals, gauges, and gratuitous card counts — the resume claims a
  *focused* dashboard; a cluttered one undercuts that claim on sight.

## 7. Before calling it done

Cross-check at least 5 segments' numbers on this dashboard against the
Excel workbook's independent formulas (`excel/README.md`). If they
disagree anywhere, find out why before publishing — see
`docs/PROJECT_SPEC.md` §7, Phase 5.
