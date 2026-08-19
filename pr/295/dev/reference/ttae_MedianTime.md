# Median event-free time from a Kaplan-Meier curve

\`r lifecycle::badge("experimental")\`

First time at which the Kaplan-Meier event-free probability drops to 0.5
or below. Returns \`NA\` when fewer than half of the subjects experience
the event, which is the honest answer rather than the largest observed
time.

## Usage

``` r
ttae_MedianTime(dfCurve)
```

## Arguments

- dfCurve:

  \`data.frame\` Output of \[ttae_KaplanMeier()\].

## Value

\`numeric\` Median event-free time, or \`NA_real\_\` if not reached.

## Examples

``` r
dfInput <- data.frame(
  Numerator = c(1, 1, 0, 1, 0),
  Denominator = c(5, 10, 12, 20, 30)
)
ttae_MedianTime(ttae_KaplanMeier(dfInput))
#> [1] 20
```
