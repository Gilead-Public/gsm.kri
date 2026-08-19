# Kaplan-Meier estimate for a time-to-event analysis input

\`r lifecycle::badge("experimental")\`

Product-limit (Kaplan-Meier) estimate of the event-free probability over
time, computed from the subject-level frame produced by
\[Input_TimeToEvent()\]. Used by \[Report_TimeToAE()\] to show the shape
of the time-to-first-AE distribution, which a single site-level rate
cannot convey.

## Usage

``` r
ttae_KaplanMeier(dfInput)
```

## Arguments

- dfInput:

  \`data.frame\` Subject-level frame with \`Numerator\` (0/1 event
  indicator) and \`Denominator\` (time at risk), as returned by
  \[Input_TimeToEvent()\].

## Value

\`data.frame\` with one row per distinct event time, plus a leading row
at time 0. Columns: \`Time\`, \`NRisk\`, \`NEvent\`, \`NCensored\`, and
\`Survival\` (event-free probability).

## Details

Implemented directly rather than via \`survival::survfit()\` to avoid
adding a dependency for one curve. Subjects censored at the same time as
an event are treated as still at risk at that time, the standard
convention.

## Examples

``` r
dfInput <- data.frame(
  Numerator = c(1, 1, 0, 1, 0),
  Denominator = c(5, 10, 12, 20, 30)
)
ttae_KaplanMeier(dfInput)
#>   Time NRisk NEvent NCensored Survival
#> 1    0     5      0         0      1.0
#> 2    5     5      1         0      0.8
#> 3   10     4      1         0      0.6
#> 4   20     2      1         0      0.3
#> 5   30     0      0         1      0.3
```
