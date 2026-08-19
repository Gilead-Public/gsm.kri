# Derive time-to-first-event analysis input

\`r lifecycle::badge("experimental")\`

Builds a standard \`Analysis_Input\` data frame for a
time-to-first-event metric. Each subject contributes one row:
\`Numerator\` is a 0/1 indicator of whether the event was observed, and
\`Denominator\` is the number of days the subject was at risk (days to
the first event, or days of follow-up if the event never occurred). The
result is shaped for \[gsm.core::Transform_Rate()\] followed by
\[gsm.core::Analyze_Poisson()\], which compares each group's observed
event count against what the study-wide fit predicts for its accumulated
exposure.

## Usage

``` r
Input_TimeToEvent(
  dfSubjects,
  dfEvents,
  strSubjectCol = "subjid",
  strGroupCol = "invid",
  strGroupLevel = NULL,
  strEventDateCol = "aest_dt",
  strReferenceDateCol = "firstparticipantdate",
  strCensorCol = "timeonstudy",
  bIncludePreReferenceEvents = FALSE
)
```

## Arguments

- dfSubjects:

  \`data.frame\` One row per subject, containing \`strSubjectCol\`,
  \`strGroupCol\`, \`strReferenceDateCol\`, and \`strCensorCol\`.

- dfEvents:

  \`data.frame\` One row per event, containing \`strSubjectCol\` and
  \`strEventDateCol\`. Multiple events per subject are reduced to the
  earliest qualifying one.

- strSubjectCol:

  \`string\` Subject ID column, present in both inputs. Default:
  \`"subjid"\`.

- strGroupCol:

  \`string\` Grouping column in \`dfSubjects\`. Default: \`"invid"\`.

- strGroupLevel:

  \`string\` Value written to \`GroupLevel\`. Default: \`strGroupCol\`.

- strEventDateCol:

  \`string\` Event date column in \`dfEvents\`. Default: \`"aest_dt"\`.

- strReferenceDateCol:

  \`string\` Time-zero date column in \`dfSubjects\`. Default:
  \`"firstparticipantdate"\`.

- strCensorCol:

  \`string\` Numeric follow-up duration (days) in \`dfSubjects\`, used
  to censor subjects with no event. Default: \`"timeonstudy"\`.

- bIncludePreReferenceEvents:

  \`logical\` Keep events dated before the reference date, clamped to
  day 0? Default: \`FALSE\`.

## Value

\`data.frame\` with columns \`SubjectID\`, \`GroupID\`, \`GroupLevel\`,
\`Numerator\` (0/1 event indicator), \`Denominator\` (days at risk), and
\`Metric\`.

## Details

Subjects with no qualifying event are \*\*right-censored\*\* at
\`strCensorCol\` rather than dropped. This matters: summarizing
days-to-event over only the subjects who had an event biases groups with
short follow-up toward looking like they have long event-free times.

Events dated before the reference date are dropped by default
(\`bIncludePreReferenceEvents = FALSE\`), which is the usual
treatment-emergent definition — an AE recorded before enrollment is not
a post-enrollment event. Set \`bIncludePreReferenceEvents = TRUE\` to
clamp such events to day 0 instead.

A subject whose event falls on the reference date contributes
\`Denominator = 0\`. Those subjects still contribute to the group
numerator, so the exposure they add is zero rather than negative. A
group where \*every\* subject has zero days at risk is dropped
downstream by \[gsm.core::Transform_Rate()\].

## Examples

``` r
dfSubjects <- data.frame(
  subjid = c("S1", "S2", "S3"),
  invid = c("Site A", "Site A", "Site B"),
  firstparticipantdate = as.Date(c("2024-01-01", "2024-01-01", "2024-01-01")),
  timeonstudy = c(100, 100, 100)
)
dfEvents <- data.frame(
  subjid = c("S1", "S1", "S3"),
  aest_dt = as.Date(c("2024-01-11", "2024-02-01", "2023-12-01"))
)
Input_TimeToEvent(dfSubjects, dfEvents)
#> ℹ 1 event(s) dated before [ firstparticipantdate ] ignored.
#>   SubjectID GroupID GroupLevel Numerator Denominator Metric
#> 1        S1  Site A      invid         1          10    0.1
#> 2        S2  Site A      invid         0         100    0.0
#> 3        S3  Site B      invid         0         100    0.0
```
