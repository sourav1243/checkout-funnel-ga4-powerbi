# Findings — Checkout Funnel Optimization

> Fill this in only after Phases 1–5 in `docs/PROJECT_SPEC.md` have actually
> been run against real BigQuery output. Every number below should be
> traceable back to `sql/02_segment_and_trend_summary.sql` output — if you
> can't point to where a number came from, it doesn't go in this file yet.

## Window analyzed

- Date range: `[fill in]`
- Total sessions: `[fill in]`

## Headline

- Overall conversion rate (view_item → purchase): `[fill in]`
- Weekly trend direction over the window: `[fill in — improving / worsening / flat]`

## Where the friction actually is

- Stage with the largest drop-off, overall: `[fill in]`
- Country segment(s) with conversion meaningfully below the overall rate,
  at a large enough sample size to trust: `[fill in]`
- Device category comparison: `[fill in]`

## What the data quality checks turned up

`[Summarize anything Check 3, 4, or 6 in sql/03_data_quality_checks.sql
found — null segments, funnel-order exceptions, outlier sessions. If
everything came back clean, say that explicitly rather than leaving this
section blank.]`

## Caveats

- Session ID is cookie-based (`user_pseudo_id` + `ga_session_id`) —
  undercounts users who clear cookies or switch devices. "Unique sessions"
  means sessions, not people.
- This is Google's *obfuscated* sample dataset — some fields may contain
  placeholder values, and Google's own docs note internal consistency can be
  limited. Findings describe patterns in this sample, not live production
  traffic.
- Small-sample country segments produce noisy rates — note which segments
  had low enough volume that the rate shouldn't be over-interpreted.

## One recommendation

`[A single, specific, data-grounded next step — e.g. "investigate the
[device] checkout flow in [country]" — only if the data actually points
somewhere. If nothing stands out, say that; a well-validated null result is
still a legitimate outcome for this kind of project.]`
