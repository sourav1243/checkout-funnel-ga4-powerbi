# Excel Cross-Check — Instructions

## What Excel is actually doing in this project

Not the primary analysis engine — BigQuery is. Excel's job is to be an
**independent second implementation** of the same aggregation and rate math,
so a bug in one tool doesn't quietly become "the finding." If Excel and
Power BI ever disagree on the same segment, that's a real bug to chase down,
not a rounding footnote.

Two things happen in `Checkout_Funnel_Analysis_Template.xlsx`:

1. **Re-aggregation check** — `sql/02` Query A gives you sessions by country
   × device. `SUMIFS` in this workbook rolls that back up to device-only
   totals, and compares it against Query C's numbers (queried independently,
   at a different grain) pasted alongside. This tests whether the BigQuery
   `GROUP BY` logic is actually correct — not just whether a formula divides
   correctly.
2. **Rate re-calculation** — the three stage-to-stage conversion rates and
   the overall rate, computed with plain formulas from the same raw counts
   that feed the Power BI DAX measures. A second, independent implementation
   of the exact same math.

## How to use it

1. Run `sql/02_segment_and_trend_summary.sql`, Query A. Export as CSV.
2. Open the **Raw_CountryDevice** tab. Delete the single example row (row 2,
   filled in blue) and paste your real export starting at row 2.
3. Run Query C from the same file. Export as CSV.
4. Open the **BQ_DeviceOnly_Benchmark** tab. Delete the example row and paste
   your real export starting at row 2.
5. Open the **CrossCheck** tab. Every formula recalculates automatically.
   The **Difference** column should read `0` for every device category. If
   it doesn't, something upstream needs fixing before you trust the
   dashboard.
6. Spot-check a handful of the rate columns on **Raw_CountryDevice** against
   what the same segment shows in Power BI.

## Color legend (used throughout the workbook)

- **Blue text** — the one example/hardcoded row showing the expected format.
  Delete it before pasting real data.
- **Yellow fill** — paste your real data starting here.
- **Black text** — formulas. Don't overwrite these.
