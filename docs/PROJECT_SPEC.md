# Project Spec — Customer Checkout Funnel Optimization

`BigQuery SQL (GA4) | Excel | Power BI`

## 1. One-line summary

Reconstruct unique user sessions from 3 months of Google Merchandise Store GA4
event logs and compare checkout conversion across countries and device
categories to find where checkout friction actually concentrates.

## 2. Problem statement

Using the GA4 event export, reconstruct real user sessions and the checkout
funnel (`view_item → add_to_cart → begin_checkout → purchase`) at the session
level, then compare conversion and drop-off across country and device category.

No conclusion is decided in advance. The segment cuts, the size of any
friction, and whether a "trend" even exists are whatever the data shows once
the pipeline actually runs. A flat, unremarkable result is still a valid
result — see `docs/FINDINGS.md`.

## 3. Why this is a legitimate data analyst project

- GA4-to-BigQuery is the real production export schema — nested, repeated
  records (`ARRAY<STRUCT>`), not a tidy flat table. Reconstructing sessions
  from it is a genuine technical skill, not a toy exercise.
- Comparing conversion across country × device forces real segmentation
  judgment (small-sample countries, device-category quirks) instead of one
  global number.
- Power BI — not raw SQL output — is the actual artifact a stakeholder sees.
  This is where "can you turn a query into a decision-ready dashboard" gets
  tested.

## 4. Tools — deliberately matching the resume, nothing else

| Tool | Role |
|---|---|
| BigQuery SQL | All data engineering: `UNNEST`, CTEs, conditional aggregation |
| Excel | Independent cross-check of the SQL output — not the primary analysis engine |
| Power BI | Stakeholder-facing interactive dashboard; DAX measures compute the actual rates |

**Explicitly out of scope for the core deliverable:** Python, Jupyter,
SciPy/statsmodels, formal hypothesis testing, A/B test design. See §9 if you
want to go further later as a separate, clearly-optional extension — it
should never be required to explain a line on your resume.

## 5. Data source

- `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
- Google Merchandise Store, obfuscated. Covers **2020-11-01 to 2021-01-31**
  (92 daily tables) — confirm this still holds with a `MIN`/`MAX(event_date)`
  query before hardcoding a date range; public datasets occasionally change.
- Access: BigQuery Sandbox, free tier, no credit card, up to 1TB queried/month.
- **Known limitation, stated up front:** this is *obfuscated* sample data.
  Google's own documentation notes some fields contain placeholder values
  (`<Other>`, `NULL`, `''`) and that "internal consistency of the dataset
  might be somewhat limited." Don't be surprised if a data-quality check in
  §7 Phase 3 turns up something odd — that's the obfuscation, not necessarily
  your query. Note it in `docs/FINDINGS.md` rather than quietly patching
  around it.

## 6. Definitions

Fixing these precisely up front means "session" and "friction" mean one
specific thing for the rest of the project.

- **Unique session ID:** `user_pseudo_id` + `ga_session_id` (the latter lives
  inside the repeated `event_params` array, not as its own column — GA4
  doesn't ship a ready-made session key). This is the standard GA4 session
  identity. It's cookie-based, so it undercounts real humans who clear
  cookies, use incognito, or switch devices — state this as a defined scope,
  not an apology, in `docs/FINDINGS.md`.
- **Funnel stage reached:** the session contains at least one event of that
  type, regardless of order or repeat count. A stricter, order-enforcing
  definition is a legitimate variant, listed as optional in §9.
- **Segment:** `geo.country` × `device.category`, exactly as GA4 recorded
  them (IP-derived country, so VPNs/proxies can misattribute it — expect and
  report a real `(not set)`/null bucket rather than dropping it silently).
- **Timezone:** `event_date` is bucketed in the property's reporting
  timezone; raw `event_timestamp` is UTC microseconds. Use `event_date` for
  day/week grouping rather than deriving your own date from the timestamp, to
  avoid an off-by-one-day mismatch against anything else built from this
  dataset.

## 7. Phase-by-phase build plan

### Phase 0 — Setup
- Confirm GCP project + BigQuery Sandbox access.
- Run the date-range check (`sql/03`, Check 2); lock in the real 3-month
  window.
- **Done when:** the exact `_TABLE_SUFFIX` range is confirmed and written into
  `sql/01_session_and_funnel_flags.sql`.

### Phase 1 — Session + funnel reconstruction (`sql/01`)
- `UNNEST(event_params)` to pull `ga_session_id`.
- CTE chain: raw events → session grain.
- Conditional aggregation (`MAX(CASE WHEN event_name = 'X' THEN 1 ELSE 0
  END)`) to flag which funnel stages each session reached, in one pass.
- **Done when:** the output has exactly one row per `unique_session_id`
  (verified in Phase 3, Check 1) — not before.

### Phase 2 — Segment + trend rollup (`sql/02`)
- Aggregate session flags to country × device (**counts only** — see §8 for
  why rates aren't computed here).
- Separate weekly rollup by device category, since the resume says "trends,"
  not just a single snapshot.
- A third, coarser device-only summary — this becomes the independent
  benchmark the Excel cross-check reconciles against.
- **Done when:** the segment table's total session count reconciles exactly
  to Phase 1's row count (Phase 3, Check 5).

### Phase 3 — Data quality validation (`sql/03`)
- Run every check in the file — including the ones that "obviously" pass.
- Anything unexpected (e.g. a purchase with no prior `begin_checkout` event)
  gets written down as a real finding, not silently filtered out.
- **Done when:** every check has been run once against real output and the
  result is recorded (pass, or explained).

### Phase 4 — Excel cross-check
- Paste the country × device export and the device-only benchmark export
  into the two "paste here" tabs of `excel/Checkout_Funnel_Analysis_Template.xlsx`.
- `SUMIFS` rolls the country × device numbers up to device-only and compares
  them against the separately-queried benchmark — this tests the *grouping*
  logic, not just arithmetic.
- Independent formulas recompute the three stage-to-stage rates and the
  overall rate, to cross-check the DAX measures built in Phase 5.
- **Done when:** the reconciliation column reads 0 everywhere, and at least 5
  segments' rates have been spot-checked against Power BI.

### Phase 5 — Power BI dashboard
- Follow `powerbi/DASHBOARD_BUILD_GUIDE.md`: import counts, not rates; build
  rates as DAX measures (§8).
- Two pages — Overview (KPIs + funnel + weekly trend) and Segment Comparison
  (country × device matrix).
- **Done when:** every number on the dashboard has been checked against the
  Excel cross-check for at least one segment.

### Phase 6 — Findings
- Fill in `docs/FINDINGS.md` using only what actually came out of Phases 1–5.
- State the real biggest-friction segment(s), the real stage where most
  drop-off happens, and the real trend direction — whatever they turn out to
  be. If nothing notable turns up, say that plainly; it's still a real result.

### Phase 7 — Repo polish + publish
- README, LICENSE, clean commit history, `.gitignore` (already scaffolded).
- Push to your own GitHub — this step needs *your* credentials, not an
  agent's. See "Publishing" in the README.

## 8. Design decision: rates live in Excel/Power BI, not in BigQuery

Counts (`total_sessions`, `sessions_added_to_cart`, etc.) are computed once in
SQL and treated as the source of truth. Rates are computed **downstream**,
independently, in Excel (formulas) and Power BI (DAX) — so a rate always
recomputes correctly no matter how it's later sliced or re-aggregated, and so
two independent implementations of the same math have to agree before either
is trusted. If asked in an interview "why not just `SELECT` the conversion
rate straight out of BigQuery," this is the honest answer.

## 9. Optional extensions — not required, not on the resume

Only worth adding after the core project above is real, run, and understood:

- A stricter, order-enforcing funnel definition (session must hit stages in
  sequence, not just "at some point").
- A single, lightweight significance check on the weekly trend, if you want
  one data point of statistical reasoning for interviews — a two-proportion
  z-test comparing two specific weeks is a much smaller ask than a full
  experiment design, and doesn't require Python (a z-test is one formula).
- A full A/B test design for a specific fix, kept as a separate
  "experimentation" writing sample rather than folded into this project.

## 10. Note for autonomous/agentic execution

Each phase above has an explicit "done when" condition and a specific input/
output file, so it can be picked up as a discrete task (task id = phase
number). Phases are sequential — each depends on the previous phase's output
table. Re-run Phase 3's checks after *any* change to `sql/01` or `sql/02`,
not just once at the end.
