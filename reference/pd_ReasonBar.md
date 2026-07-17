# Premature-death reason bar chart

\`r lifecycle::badge("experimental")\`

Renders a horizontal bar chart from a reason slice produced by
\[pd_ReasonByCountry()\] or derived inside \[pd_ReasonDist()\]. Each bar
is labelled with its count (placed inside the bar, or just outside when
the bar is too narrow to hold the label).

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

A \`plotly\` htmlwidget.
