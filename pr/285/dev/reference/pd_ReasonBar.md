# Premature-death reason bar chart

\`r lifecycle::badge("experimental")\`

Renders the horizontal reason distribution from a reason slice produced
by \[pd_ReasonByCountry()\] or derived inside \[pd_ReasonDist()\], via
the \`gsm.viz\` reason widget.

## Usage

``` r
pd_ReasonBar(slice)
```

## Arguments

- slice:

  A named \`list\` with \`reason\`, \`n\`, and \`hover\` vectors, as
  returned by the internal kernel \`pd_ReasonSlice\` or elements of the
  list returned by \[pd_ReasonByCountry()\].

## Value

A \`Widget_PrematureDeathReasonBar\` htmlwidget.
