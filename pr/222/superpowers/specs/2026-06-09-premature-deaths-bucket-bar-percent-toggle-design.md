# Premature Deaths Bucket-Bar Count ↔ % Toggle — Design

**Date:** 2026-06-09
**Package:** `gsm.kri`
**Issue:** #223
**Status:** Approved (design)

## Problem

The Premature Deaths report (`inst/report/Report_PrematureDeaths.Rmd`) renders the
bucket bar (`pd_BucketBar`) three times — Study, Country, Site — each as a stacked
bar of the three RAG buckets (`<=30d`, `31-Wd`, `Alive at Wd`) with the y-axis
showing **absolute subject counts**. Reviewers want to switch the same charts to
**percentages** to compare group composition independent of group size (a small
site and a large site become directly comparable).

## Requirements (resolved during brainstorming)

- **Scope:** all three bucket bars (Study, Country, Site). *Not* the
  `pd_RandToDeathScatter` or `pd_ReasonDist` charts.
- **Trigger:** a **single global** `Count | %` control at the top of the report that
  flips all three bucket bars together.
- **% basis:** **per-group composition** — each bar normalizes to 100%; a bucket's
  height is its share of that group's own enrolled subjects
  (`n_bucket / group_total`). This matches the denominator already used in the
  tooltip's `(X% of group total)` line. *Not* % of total enrolled, *not* % of
  premature only.
- **Default mode:** `count` (today's behavior).
- **Tooltip:** unchanged — it already shows both the count and the per-group %.

## Approach

**Percent computed in R and carried inside `customdata`; a thin JS toggle selects
which array drives `y`; `applyMode` re-runs after every `Plotly.react`.**

The keystone is that the report's existing client-side filter code already
reindexes each trace's `customdata` point-by-point (Rmd `filterPlotlyChart`, the
`newTrace.customdata = indices.map(...)` line). If `pd_BucketBar` packs the percent
and the count *into* `customdata`, both values ride through every filter/dim cycle
**with no change to the reindex loop**. The toggle then derives `y` from
`customdata` on demand, so it is stateless and cannot drift out of sync with the
filtered data.

Because the chosen % basis is *per-group composition*, the percent of a
(group, bucket) cell depends only on that group's own totals — it is **invariant
to filtering other groups out**. Filtering removes whole x-categories, never
buckets within a group, so a cached percent value stays correct after any filter.
This is what makes the carry-in-`customdata` approach correct by construction.

### Rejected alternatives

- **JS derives percent live from visible counts (counts stay the only R data).**
  No R math change, but moves the normalization into untested JS, must recompute
  per-category column sums on every toggle *and* after every `Plotly.react`, and
  needs a counts stash to toggle back. More fragile JS for less R. (This was the
  explicit Approach-2 the user declined.)
- **Native per-chart Plotly `updatemenus` buttons.** Self-contained and pure-R, but
  the buttons' baked-in `args` restore the full unfiltered dataset and fight the
  Country/Site `Plotly.react` filter. Also not a single global control. Ruled out.
- **Two pre-rendered chart variants (count + percent) toggled by show/hide.** Doubles
  the DOM per slot and forces the filter JS (which targets specific container ids)
  to manage both copies. Rejected.

## Component design

### `R/pd_BucketBar.R` — `pd_BucketBar`

`pd_BucketBar` computes `GroupTotal = sum(n)` per `GroupID` and a per-group
composition percent:

- `Pct = if_else(GroupTotal > 0, 100 * n / GroupTotal, 0)`
  (the `GroupTotal > 0` guard is purely defensive against impossible zero-division).
- Each point's `customdata` carries a **2-element numeric `[count, pct]`** pair.
  Index `0` is the count, index `1` is the percent. There is no text column in
  `customdata`; the tooltip string moved to `text` (permanent on-bar label) and is
  independent of the toggle.
- Hover template: `Bucket: <bk><br>Subjects: %{customdata[0]} (%{customdata[1]:.1f}%)<extra></extra>`.

Both branches share a **manual `add_bars`-per-bucket loop** — the high-level
`color = ~Bucket` split is dropped for both:

- **Flat branch (Study):** uses the same `add_bars` loop as the multicategory
  branch. `color = ~Bucket` was dropped because it (i) errors on a multi-column
  `customdata` data.frame with "compatible sizes" and (ii) auto-unbox-flattens a
  single-point trace's customdata to `[v0,v1]`, which JS misreads as two points.
- **Multicategory branch (Country / Site):** unchanged in structure; was already a
  per-bucket `add_bars` loop.

The `customdata` value for each bucket trace is wrapped as
`I(Map(function(cnt, pct) list(cnt, pct), d$n, d$Pct))` so single-point traces
serialize as nested `[[count, pct]]` rather than the flat `[count, pct]` that
auto-unbox would produce. RAG colors are set per-trace via
`marker = list(color = unname(rag_colors[bk]))`, and `insidetextfont = white` +
the inside-label `style()` settings are applied explicitly for both branches via a
single `plotly::style()` call after the loop.

No new parameter and no signature change — the chart still renders counts by
default; index `1` in `customdata` is inert until the toggle reads it.

### `inst/report/Report_PrematureDeaths.Rmd`

**1. Give the Study chart a container id.** The `study-buckets` chunk currently
emits `pd_BucketBar(...)` with no wrapper, so the toggle can't target it. Wrap it:
`htmltools::div(id = "pd-study-buckets", pd_BucketBar(...))`. (Country and Site
already have `pd-country-buckets` / `pd-site-buckets`.)

**2. Add the global toggle control** under `## Overview`, before `## Study`, only
when `has_premature` (hidden otherwise so an empty report shows no dead control).
Two inline-styled buttons matching the existing `#1a73e8` reset buttons:
`Count` (active by default) and `%`, calling `pdSetMode('count')` / `pdSetMode('pct')`.

**3. Add the toggle JS** (inside the existing `filter-js` script IIFE so it shares
scope with `getPlotlyDiv`):

- `var pdMode = 'count';`
- `var PD_BUCKET_CHARTS = ['pd-study-buckets', 'pd-country-buckets', 'pd-site-buckets'];`
- `applyMode(el)` — reads `slot = pdMode === 'pct' ? 1 : 0` and for every trace
  derives `y = customdata.map(cd => cd[slot])`, then calls a **single**
  `Plotly.update(el, {y: ys}, layoutUpdate, traceIndices)` (one atomic redraw):
  - `pct`  → `layoutUpdate = { 'yaxis.title.text': '% of group', 'yaxis.ticksuffix': '%', 'yaxis.range': [0, 100] }`
  - `count`→ `layoutUpdate = { 'yaxis.title.text': 'Subjects', 'yaxis.ticksuffix': '', 'yaxis.autorange': true, 'yaxis.range': null }` (`range: null` clears the fixed `[0,100]` so `autorange` recomputes the subjects scale)

  `y` is **always** re-derived from `customdata` (indices `0` = count, `1` = pct),
  so `applyMode` never depends on what `Plotly.react` last wrote and a stale `y` in
  the `originalData` cache is harmless.
- `window.pdSetMode(mode)` — set `pdMode`, update the two buttons' active styling,
  then call `applyMode(getPlotlyDiv(id))` for each id in `PD_BUCKET_CHARTS`
  (each guarded by `getPlotlyDiv` returning null → no-op).

**4. Re-apply the mode after every `Plotly.react`.** The call
`if (PD_BUCKET_CHARTS.indexOf(containerId) >= 0) applyMode(el);` is **unconditional**
(not `if (pdMode === 'pct')`) at the tail of `filterPlotlyChart` and
`resetPlotlyChart`, immediately after their `Plotly.react`. This ensures that a
`originalData` cache seeded while `%` mode was active (which holds `%`-mode `y`
values) is immediately corrected for the **current** mode — count or pct — after
every react. The dim/highlight paths restyle only `marker.opacity` and are
unaffected.

No other Rmd changes — the existing `country_site_map` / filter wiring is untouched.

## Edge cases

| Case | Behavior |
|---|---|
| No premature deaths (`!has_premature`) | Charts not rendered; toggle control hidden; `applyMode`/`pdSetMode` no-op via the null guard. |
| `GroupTotal == 0` | `Pct` guarded to `0`; no `NaN` reaches `y`. |
| Single study (flat one-bar chart) | 100%-stack still correct; bar fills to 100%. |
| `%` active, then country/site filter applied | Re-apply hook keeps the filtered chart in `%`. |
| `%` active, then reset | Re-apply hook re-derives `%` for the restored full chart. |

## Testing & verification

Per `gsm.kri/AGENTS.md` (test-first, 100% file-level coverage, issue-tagged tests):

- **R — `tests/testthat/test-pd_BucketBar.R`:**
  - Assert `customdata` carries a **2-element `[count, pct]`** pair per point
    (count at index `0`, pct at index `1`). Verified via JSON serialization:
    e.g. the Study `<=30d` bucket (`1` of `4` enrolled → `25%`) must produce
    `"customdata":[[1,25]]`, and the `Alive at 90d` bucket (`2` of `4` → `50%`)
    must produce `"customdata":[[2,50]]`.
  - Assert a single-point trace serializes as the nested form `[[count,pct]]` not
    the flat `[count,pct]` (the `I(Map(...))` unbox guard).
  - Assert the hover template references `%{customdata[0]}` (count) and
    `%{customdata[1]:.1f}%` (pct).
  - All new `test_that()` descriptions carry the **`{#223}`** local issue tag.
- **Playwright — `tests/playwright/pd-multicategory.spec.js` (or a sibling spec):**
  - Regenerate the fixture (`render-fixture.R` re-renders the Rmd, picking up the
    toggle control automatically).
  - Click `%` → assert a bucket chart's per-group `y` values sum to ~100 and the
    y-axis title flips to "% of group".
  - Then apply a country filter (the existing `emit('plotly_click', …)` pattern) →
    assert the chart is **still** in `%` mode (the re-apply hook), proving the
    toggle coexists with filtering.
- Run `air format .`, then `devtools::test(reporter = "check")` and
  `devtools::check(error_on = "warning")`. Update roxygen only if wording changes
  (no signature change), then `devtools::document()`.

## Risks

- **Flat-branch `customdata` under `color = ~Bucket` — RESOLVED.** Empirical
  probing showed the high-level `color = ~Bucket` split (i) errors with
  "compatible sizes" when `customdata` is a multi-column data frame, and (ii)
  auto-unbox-flattens a single-point trace's `customdata` to `[v0, v1]`, which JS
  misreads as two points rather than one `[count, pct]` pair. The chosen fix drops
  `color = ~Bucket` for both branches and uses a manual `add_bars`-per-bucket loop
  with `customdata = I(Map(function(cnt, pct) list(cnt, pct), d$n, d$Pct))`, which
  sidesteps both issues. The two previously-cited flat-branch tests were updated to
  assert the new one-trace-per-bucket structure rather than the color-split structure.

## Out of scope

- `pd_RandToDeathScatter` and `pd_ReasonDist` (no toggle).
- The patient listing (`pd_PatientListing`).
- Any change to the metrics/workflow YAMLs or the premature-death window logic.
- Per-chart or per-section toggles, and any persistence of the chosen mode across
  report reloads.

## Branch note

This feature was implemented on `feature-223-pd-pct-toggle`, cut from `fix-221`
(not `dev`): it is part of the in-progress `fix-221` effort, so it merges back
into `fix-221` rather than opening a `dev`-targeted PR. This intentionally
overrides the default gsm contributing flow, per user direction. Linked to #223.
