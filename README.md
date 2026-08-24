# Checkout Funnel Optimization — GA4 (BigQuery) × Excel × Power BI

Google Merchandise Store checkout analysis: 77,317 sessions, 92 days (2020-11-01 to 2021-01-31), one funnel from view to purchase.

## Summary

Reconstructed unique user sessions from the GA4 event export and tracked how they move through `view_item → add_to_cart → begin_checkout → purchase`. Overall conversion is 6.3% (4,848 purchases). The largest drop is between viewing a product and adding it to cart — about four in five sessions end there — and that pattern holds across countries and devices.

## Key findings

- **Where most sessions drop off:** view → add-to-cart. 61,832 of 77,020 sessions that viewed an item never added anything to cart (80.3%). Cart → checkout and checkout → purchase lose far fewer in comparison.
- **Country view (≥500 sessions):** Indonesia had the lowest conversion rate among countries with at least 500 sessions, at 3.96% (657 sessions). Most large countries sit close to the overall rate — US 6.22% (34,051), India 6.16% (7,292), Canada 6.65% (5,868).
- **Device:** mobile 6.5%, desktop 6.1%, tablet 6.1%. Differences are small. The view → cart step is the main friction on every device.
- **Trend:** conversion rose through November into early December, peaked around the week of Dec 7 (~9.3% on desktop), then fell back to 4–6% in January.

Important limitation: the analysis shows *where* users drop off, but the event data alone cannot tell *why*. Findings point to where to look next, not to a causal explanation.

## Dashboard

The dashboard compares conversion by country, device category, and funnel stage using DAX measures so rates stay correct under any filter.

![Checkout funnel — sessions by stage](images/funnel.png)
*77,317 sessions → 77,020 viewed an item → 15,188 added to cart → 11,106 began checkout → 4,848 purchased.*

![Top 10 countries by volume, annotated with conversion](images/country_conv.png)
*Top 10 countries by session volume. Indonesia at 3.96% is the lowest among those with ≥500 sessions.*

![Weekly trend by device](images/weekly_trend.png)
*December peak, then back to 4–6% in January. Tablet is more variable due to smaller volume.*

![Conversion by device](images/device_conv.png)
*Device explains very little of the difference.*

Build instructions: [Power BI build guide](powerbi/DASHBOARD_BUILD_GUIDE.md). The same measures are also available as TMDL in `powerbi/SemanticModel/tables/`.

## How it was built

**Data preparation & analysis:** GA4 event logs (nested `event_params` arrays) → sessions keyed by `user_pseudo_id` + `ga_session_id` → funnel flags per session with `UNNEST`, CTEs, and conditional aggregation in BigQuery SQL. Aggregated to country × device and to weekly trend by device.

**Dashboard:** Power BI with DAX measures (counts in SQL, rates in DAX). Keeps rates correct when filtering.

**Tools**

- SQL: BigQuery
- Spreadsheet: Excel
- BI: Power BI
- Visualization: Python / Matplotlib

## Validation

This is an independent check, not just a second calculation in the same tool.

- Segment-level counts were re-derived in Excel (SUMIFS roll-up of country × device vs. a separately-queried device-only benchmark) and matched to 0 on every device category.
- Six SQL data-quality checks were run against the real output: date coverage (92 days, no gaps), session-key uniqueness (77,317 = 77,317), null and `(not set)` handling, funnel-order anomalies, and segment reconciliation. See [Findings](docs/FINDINGS.md) for the actual numbers.

## Limitations

- Dataset is Google's obfuscated public GA4 sample ecommerce data — some fields contain placeholder values and internal consistency is limited (documented by Google).
- Covers 2020-11-01 to 2021-01-31. Weekly view is Monday-start weeks; the first week contains only Nov 1.
- Observational: drop-offs show where friction concentrates, not why.
- Country is IP-derived; VPN/proxy can misattribute. 609 sessions are `(not set)`.
- Small-sample countries produce noisy rates. Comparisons above use ≥500 sessions for that reason.
- Funnel stage is "reached at any point" in the session, not strictly ordered.

## Recommendations

- Prioritize the view → add-to-cart stage — it is the largest and most consistent loss across all large segments. Start with US desktop (19,799 sessions) before optimizing downstream steps.
- Look at Indonesia separately — meaningfully low at 3.96% with 657 sessions, so it is worth a focused check despite smaller volume than the US or India.
- Do not prioritize device-specific fixes from this analysis alone — desktop, mobile, and tablet are within 0.4 points of each other.
- Validate causes with additional data (behavioral, UX research, or an experiment) before changing the experience. The funnel shows where to investigate, not what to fix.

```
view_item  →  add_to_cart  →  begin_checkout  →  purchase
```

Data: `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` (92 daily tables). Details and known quirks: [Project spec §5](docs/PROJECT_SPEC.md#5-data-source).

## Repo structure

```
sql/        BigQuery SQL — run in order: 01 → 02 → 03
excel/      Independent cross-check workbook + instructions
powerbi/    Dashboard build guide (data model, DAX, layout)
docs/       Full project spec + findings write-up
images/     Charts from the query output
```

Key files:

- [Session & funnel SQL](sql/01_session_and_funnel_flags.sql)
- [Segment & trend SQL](sql/02_segment_and_trend_summary.sql)
- [Data-quality checks](sql/03_data_quality_checks.sql)
- [Project spec](docs/PROJECT_SPEC.md)
- [Findings](docs/FINDINGS.md)
- [Power BI build guide](powerbi/DASHBOARD_BUILD_GUIDE.md)

## Reproduction

### Requirements

- Google account with BigQuery access (Sandbox is enough, no billing needed)
- Microsoft Excel
- Power BI Desktop (for the dashboard)
- Python 3 with pandas and matplotlib (only for `images/` charts)

### Steps

1. In BigQuery, confirm the date window with [Check 2](sql/03_data_quality_checks.sql), then set the range at the top of [01](sql/01_session_and_funnel_flags.sql).
2. Run [01](sql/01_session_and_funnel_flags.sql) and save the output as `your_project.your_dataset.session_funnel_flags`.
3. Run [02](sql/02_segment_and_trend_summary.sql) against that table.
4. Run all checks in [03](sql/03_data_quality_checks.sql) and note the results.
5. Export the query results as CSV and paste into `excel/Checkout_Funnel_Analysis_Template.xlsx` (instructions on its first tab).
6. Charts in `images/` are built from those CSVs with Python/matplotlib.
7. Follow the [Power BI build guide](powerbi/DASHBOARD_BUILD_GUIDE.md) to build the dashboard.

Full phase plan and done-criteria: [Project spec §7](docs/PROJECT_SPEC.md#7-phase-by-phase-build-plan).

## Project status

- [x] BigQuery analysis completed
- [x] Data-quality checks completed
- [x] Excel cross-check completed
- [x] Python charts generated
- [x] Power BI dashboard completed (see build guide)
- [x] Findings documented

## License

MIT — see [LICENSE](LICENSE).
