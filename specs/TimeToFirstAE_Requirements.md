# Requirement: Time to First Adverse Event (proposed `kri0019` / `cou0019`)

**Status:** Implemented on branch `demo-timetoae` — see "What actually shipped" (§13)
**Author:** drafted with Claude Code, 2026-08-19
**Repos touched:** `gsm.kri` only (see §13 for why `gsm.core` was left alone)

## 1. Summary

Add a site-level metric that measures **how long subjects are on study before their
first adverse event is recorded**, and flags sites whose time-to-first-AE is
unexpectedly long or short relative to the rest of the study.

## 2. Rationale — why this is not `kri0001`

`kri0001` (Adverse Event Rate) measures AE *volume* per day on study. It is blind to
*onset timing*. A site can post a study-average AE rate over the full observation
window while recording nothing for the first three months. That pattern is a
recognised signal for:

| Long time to first AE (low hazard) | Short time to first AE (high hazard) |
|---|---|
| Delayed AE identification or data entry | Over-reporting / miscoding of non-AEs |
| Under-reporting in early visits | Protocol-deviant population (sicker at baseline) |
| Staff not trained on AE capture at activation | Different AE-vs-medical-history interpretation |

Both tails are actionable, so the metric must flag **two-sided** (as `kri0001`
already does with `Threshold: -2,-1,2,3`).

## 3. Metric definition

**Subject-level derivation**

- `t_ref` = reference start date. **Default: `firstparticipantdate`** from `Mapped_SUBJ`.
- `t_event` = earliest `aest_dt` in `Mapped_AE` for that subject.
- If the subject has ≥1 AE: `days_at_risk = t_event - t_ref`, `event = 1`.
- If the subject has no AE: `days_at_risk = timeonstudy`, `event = 0` (**right-censored**).

Censoring is the crux of this metric. Naively averaging "days to first AE" over only
the subjects who *had* an AE is badly biased — a site with short follow-up would look
like it has a long time to AE. Every subject must contribute time at risk.

**Site-level statistic**

Observed vs expected first-AE count under the study-wide hazard, i.e. an
Poisson model of first-event counts against accumulated exposure:

- Numerator = count of first AEs at the site
- Denominator = sum of `days_at_risk` across the site's subjects
- Model = `gsm.core::Analyze_Poisson` — **no new statistics code**
- Score = deviance residual, same shape as every other gsm metric

Note on the model, corrected during implementation: `gsm.core::Analyze_Poisson`
does *not* fit a true person-time offset. It fits `Numerator ~ log(Denominator)`
with the exposure coefficient free, so the expected count is
`exp(b0) x Denominator^b1` rather than proportional to exposure. This is
deliberate upstream (`Analyze_Poisson_PredictBounds` reads `coefficients[2]`), and
scores and bounds are mutually consistent, so the metric and its scatter plot agree.
But the clean "exponential survival equivalence" framing below is **wrong** and the
report says so explicitly. See §13.

## 4. Proposed `meta` block

```yaml
meta:
  Active: true
  Type: Analysis
  ID: kri0019            # see ID collision note in §8
  GroupLevel: Site
  Abbreviation: TTAE
  Metric: Time to First Adverse Event
  Numerator: Subjects with an Adverse Event
  Denominator: Days at Risk to First Adverse Event
  Model: Poisson
  Score: Adjusted Z-Score
  AnalysisType: rate
  Threshold: -2,-1,2,3
  Flag: "-2,-1,0,1,2"
  RiskScoreWeight: "32,16,0,1,2"   # mirrors kri0001: under-reporting weighted heaviest
  AccrualThreshold: 180            # PLACEHOLDER — person-days; calibrate on pilot studies
  AccrualMetric: Denominator
  GenerateRiskSignal: true
```

`cou0019` is the same with `GroupLevel: Country` and no `RiskScoreWeight`, matching the
existing `kri####`/`cou####` pairing.

## 5. Workflow steps

Identical to `kri0001` except the `Analysis_Input` step:

```yaml
  - output: Analysis_Input
    name: gsm.core::Input_TimeToEvent      # NEW
    params:
      dfSubjects: Mapped_SUBJ
      dfEvents: Mapped_AE
      strSubjectCol: subjid
      strGroupCol: invid
      strGroupLevel: GroupLevel
      strEventDateCol: aest_dt
      strReferenceDateCol: firstparticipantdate
      strCensorCol: timeonstudy
  - output: Analysis_Transformed
    name: gsm.core::Transform_Rate
  - output: Analysis_Analyzed
    name: gsm.core::Analyze_Poisson
  # Flag / Summarize / lAnalysis unchanged
```

**No `gsm.mapping` changes required.** `AE.yaml` already maps `aest_dt`, and
`SUBJ.yaml` already maps `firstparticipantdate`, `firstdosedate`, and `timeonstudy`.

## 6. New code

`gsm.core::Input_TimeToEvent(dfSubjects, dfEvents, ...)` — returns the standard
`Analysis_Input` shape (`SubjectID`, `GroupID`, `GroupLevel`, `Numerator`,
`Denominator`) where `Numerator` is the 0/1 event indicator and `Denominator` is days
at risk. This is the only new function; it is metric-agnostic and reusable for any
future time-to-event KRI (time to first query, time to first lab, time to discontinuation).

## 7. Sign convention — **open decision, needs a call**

The Poisson score is on the **hazard** scale, so the sign is inverted relative to the
metric's name:

- Unexpectedly **long** time to first AE → **low** hazard → **negative** z-score
- Unexpectedly **short** time to first AE → **high** hazard → **positive** z-score

This is actually consistent with the rest of gsm (negative = under-reporting = heaviest
risk weight), so **recommendation: keep the hazard-scale score and do not invert.**
But the metric label says "Time to..." while the score moves the other way, which will
confuse reviewers. Two options:

1. Keep hazard scale, document explicitly in the report footnote. *(recommended)*
2. Negate the score so it reads on the time scale, and reverse `RiskScoreWeight`.

## 8. Open questions

1. **Metric ID collision in the existing backlog.** `kri0016` is claimed by both
   [#231](https://github.com/Gilead-Public/gsm.kri/issues/231) (Duplicate Weight) and
   [#258](https://github.com/Gilead-Public/gsm.kri/issues/258) (IP Non-Starters), and
   `kri0017`/`kri0018` by [#232](https://github.com/Gilead-Public/gsm.kri/issues/232).
   `kri0019` is proposed here but ID assignment needs an owner.
2. **Reference date:** `firstparticipantdate` (enrollment) or `firstdosedate`
   (treatment)? Enrollment captures pre-dose AEs; first dose is the more clinically
   meaningful zero for treatment-emergent AEs. Recommend enrollment for Phase 1,
   configurable via the workflow param.
3. **AE scope:** all AEs, or restrict to serious (`aeser`) / grade ≥3 (`aetoxgr`)?
   Recommend all AEs for Phase 1; a serious-only variant is a cheap follow-on metric
   reusing the same input helper.
4. **Accrual gate:** person-days alone may pass a site with one long-follow-up subject.
   Consider a secondary minimum on subject count.

## 9. Edge cases for unit tests

- AE start date **before** the reference date (negative time at risk) → clamp to 0 or drop; decide and test
- Missing `aest_dt` on an otherwise valid AE record → subject stays at risk (censored); flag the bias in docs
- `timeonstudy` = 0 (enrolled, no follow-up) → excluded from denominator
- Site where **no** subject has an AE → Poisson zero-count, must produce a valid negative score, not `NA`
- Subject with multiple AEs on the same day → single first event
- Site below `AccrualThreshold` → not flagged

## 10. Reporting

- Reuse `Visualize_Scatter` / `Widget_ScatterPlot`: x = person-days at risk, y = observed
  first-AE count, with Poisson prediction bounds via `Analyze_Poisson_PredictBounds`.
  No new widget needed for Phase 1.
- **Phase 2 (optional):** a Kaplan-Meier overlay (site vs study) would communicate this
  metric far better than a scatter. Any new widget must be built on **gsm.vizr**, not the
  vendored `gsm.viz` bundle, which is being retired
  ([#288](https://github.com/Gilead-Public/gsm.kri/issues/288),
  [#291](https://github.com/Gilead-Public/gsm.kri/issues/291)).

## 11. QC approach

- [ ] Qualification test via double programming (independent survival-based
      implementation, e.g. `survival::survfit` / Cox, to confirm the Poisson
      approximation agrees on the pilot studies)
- [ ] Unit tests on `Input_TimeToEvent` covering every edge case in §9
- [ ] User test: render the example KRI report and visually confirm flagging

## 12. Rough sizing

| Task | Size |
|---|---|
| `Input_TimeToEvent` + unit tests (`gsm.core`) | M |
| `kri0019.yaml` / `cou0019.yaml` + workflow tests | S |
| Report + example data integration | S |
| Qualification test via double programming | M |
| Phase 2 KM widget on gsm.vizr | L |

---

## 13. What actually shipped (branch `demo-timetoae`)

Implemented and verified against `gsm.core::lSource`. Deviations from the draft
above, and why:

| Draft said | Shipped as | Why |
|---|---|---|
| `gsm.core::Input_TimeToEvent()` | `gsm.kri::Input_TimeToEvent()` | Keeps the change to a single repo and a single reviewable PR. Promote to `gsm.core` when a second time-to-event metric needs it — the function is already metric-agnostic. |
| `AnalysisType: rate` | `AnalysisType: poisson` | `gsm.reporting::MakeBounds()` dispatches on this field; `rate` would have produced normal-approximation bounds under a Poisson score. |
| `AccrualThreshold: 180` (placeholder) | `AccrualThreshold: 10` | Calibrated against `kri0001` on `lSource`: exposure here (days *at risk to first AE*) totals ~8.6k person-days vs `kri0001`'s ~26k days-on-study, so 10 is comparable in stringency to `kri0001`'s 30. |
| Report reuses `Visualize_Scatter` | Report calls `MakeCharts()` + `Report_MetricCharts()` | Gives the standard tabbed Scatter / Bar / Metric Table complement for free, and routes htmlwidget JS dependencies through the path the package already tests. |
| Phase 2 KM curve "optional" | Shipped in Phase 1 | Implemented as `ttae_KaplanMeier()` in ~40 lines with no new dependency (validated against `survival::survfit`), and it is the only view that shows the low-hazard tail at all. |

### Results on `gsm.core::lSource`

758 enrolled participants, 540 (71%) with a post-enrollment AE, Kaplan-Meier
median time to first AE 10 days, 8,602 total days at risk. Of 145 sites: 7 red
(`Flag = -2`, all zero-event sites), 20 amber low, 1 amber high, 9 below the
accrual gate. Comparable in volume to `kri0001`, which flags 14 amber on the same
data.

### Decisions taken

- **Sign convention**: kept on the event-rate scale (option 1 in §7) — negative
  score means unexpectedly long time to first AE. The report states this in a
  callout above the first chart, because it is the single most misreadable thing
  about the metric.
- **Metric ID**: `kri0019` / `cou0019`, avoiding the live `kri0016`–`kri0018`
  collision in the backlog (§8.1). Still needs an owner to ratify.
- **Reference date**: `firstparticipantdate`, configurable via the workflow param.
- **AE scope**: all AEs. A serious-only variant is a cheap follow-on.

### Data-quality finding in `lSource`

395 of 660 first AE records in `lSource` are dated **before** the participant's
enrollment date; `aest_dt` is simulated against the study window rather than
per-subject enrollment. The treatment-emergent definition (ignore AEs before time
zero) handles this correctly, but it is worth knowing that a naive
`aest_dt - firstparticipantdate` on this dataset is negative for the majority of
participants. `timeonstudy` is internally consistent: `firstparticipantdate +
timeonstudy` equals 2012-03-29 for every enrolled subject.

### Still open

- `gsm.core::Analyze_Poisson`'s free exposure elasticity (see the note in §3)
  deserves an upstream issue: the `stats::offset()` wrapper and log message both
  read as if exposure were a fixed offset, and with only two groups the model is
  saturated so every score is exactly 0. `tests/testthat/test-kri0019-workflow.R`
  pins that behaviour so no future fixture is written with two groups.
- Double-programming qualification test not written; unit tests cover
  `Input_TimeToEvent`, the KM helpers, both workflows, and the report.
