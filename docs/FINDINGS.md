# Findings — Checkout Funnel Optimization

All numbers below come from the real BigQuery run of `sql/01`–`sql/03`
against `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
(Nov 2020 – Jan 2021), cross-checked in the Excel workbook.

## Window analyzed

- Date range: **2020-11-01 to 2021-01-31** (92 daily tables, confirmed by
  MIN/MAX query on the live dataset — no gaps in per-day coverage)
- Total sessions: **77,317** (unique `user_pseudo_id` + `ga_session_id`)
- Segment table reconciles exactly: sum of `segment_summary.total_sessions`
  = 77,317 = session table row count (Check 1 and Check 5 both pass)
- Excel cross-check: SUMIFS rollup of the country × device table matches
  the independently-queried device-only benchmark to **0 on every device
  category** (desktop, mobile, tablet)

## Headline

- Overall conversion: **6.3%** — 4,848 purchases from 77,020 sessions that
  reached `view_item` (6.27% of all 77,317 sessions; the two denominators
  are 0.02pp apart because 297 sessions entered the funnel mid-way with no
  captured `view_item`)
- Weekly conversion over the window: **up through the holiday season, then
  down** — from 4.5% in the first full week (Nov 2) to a peak of 9.3% in
  the week of Dec 7 (Black Friday through early December), then back to
  4.4%–5.8% through January. Everything else below sits on top of this
  shape: volume and conversion both spike in December.

## Where the friction actually is

- **Stage with the largest drop-off, overall: `view_item → add_to_cart`** —
  61,832 of 77,020 sessions (80.3%) never added anything to cart. This is
  the dominant loss in absolute terms; cart→checkout loses another 4,002
  (73.1% of cart sessions continue), checkout→purchase loses 6,258 (43.7%
  of checkout sessions complete).
- **Country segments below the 6.3% overall rate, at ≥ 500 sessions:**
  Indonesia **3.96%** (657 sessions — the clearest underperformer),
  Italy 4.95% (1,111), Singapore 5.27% (1,044), `(not set)` 5.58% (609),
  South Korea 5.62% (925). The three largest countries — US 6.22% (34,051
  sessions), India 6.16% (7,292), Canada 6.65% (5,868) — all sit close to
  the overall rate; there is no large-country outlier in either direction.
- **Device comparison:** mobile converts best overall — 6.51% (1,995 /
  30,630) vs desktop 6.11% (2,749 / 44,982) and tablet 6.10% (104 / 1,705).
  Mobile leads at every stage ratio except cart→checkout, where tablet
  (74.8%) barely edges it (73.6%). The gaps are small (≤ 0.6pp): device
  category explains very little of the funnel loss — the view→cart step
  dominates on every device.
- Within-device view→cart rates barely differ (18.9%–19.9%), so the
  "biggest friction" finding is stable across segments: it is the step
  between viewing a product and adding it to cart, everywhere.

## What the data quality checks turned up

All six checks were run against real output:

- **Check 1 (session key uniqueness):** pass — 77,317 rows, 77,317
  distinct session keys.
- **Check 2 (date coverage):** pass — all 92 days present, no day below
  21,000 rows; no gaps.
- **Check 3 (null segments):** zero NULL country or device values. 609
  sessions (0.8%) carry a literal `(not set)` country and are kept as
  their own segment, not dropped. 218 of those are mobile sessions.
- **Check 4 (funnel order):** two real anomalies, recorded not filtered:
  - 5,145 sessions (6.7% of all) reached `begin_checkout` with no
    `add_to_cart` in the session — consistent with direct/dynamic
    checkout flows ("buy now"), but large enough that it also reflects
    this dataset's documented obfuscation/consistency limits.
  - 3 sessions produced a purchase with no `begin_checkout` event at all
    (0.004%) — negligible, but real.
  - 297 sessions entered the funnel with no `view_item` event (cart,
    checkout or purchase events only).
- **Check 5 (segment reconciliation):** pass — 77,317 exactly.
- **Check 6 (bot-like sessions):** 50 sessions had > 100 funnel events
  each (top: 1,007 events in a ~4.8h session — bot/crawler-shaped). That
  is 0.06% of sessions; they remain in the analysis since excluding them
  changes no rate by more than rounding, but they explain a small amount
  of the extreme small-sample country rates.

## Caveats

- Session ID is cookie-based (`user_pseudo_id` + `ga_session_id`) —
  undercounts users who clear cookies or switch devices. "Unique sessions"
  means sessions, not people.
- This is Google's *obfuscated* sample dataset — some fields contain
  placeholder values, and Google's own docs note internal consistency can
  be limited (Check 4's anomalies are the likely fingerprint of that).
  Findings describe patterns in this sample, not live production traffic.
- Funnel stage is "reached at some point," regardless of order or repeat
  count. An order-enforcing funnel would report *lower* conversion rates
  than shown here.
- The week of 2020-10-26 contains only Nov 1 (dataset starts then);
  weekly figures quoted above start with the first full week, Nov 2.
- Small-sample countries (roughly everything below ~500 sessions) produce
  noisy rates (e.g. 17.2% Georgia at 29 sessions, 0.0% for several
  sub-50-session countries) — not interpretable without volume, which is
  why the segment comparisons above are limited to ≥ 500 sessions.
- IP-derived geo (`geo.country`); VPN/proxy traffic can misattribute
  country — hence the `(not set)` bucket.

## One recommendation

The funnel's dominant loss — four of five sessions drop between viewing a
product and adding it to cart, on every device and in every large country —
points to the product-page → cart step as the highest-leverage surface:
start with the largest single segment, **US desktop (19,799 sessions)**, by
reviewing what happens between item view and cart add (browse depth,
session engagement, price/availability presentation) before touching
anything downstream. Second priority: the Indonesia mobile segment
(3.96% conversion at 657 sessions) is the worst real-country number at
usable volume and is a cheap follow-up test. No change should precede a
baseline re-measure in the same 92-day window.