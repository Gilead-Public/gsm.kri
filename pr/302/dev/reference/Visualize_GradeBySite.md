# Plot the AE grade distribution by site

\`r lifecycle::badge("experimental")\`

Renders a 100 by the proportion of high-grade (Grade 3+) events. A
dashed reference line marks the study-wide high-grade proportion, so
sites whose bars break away from that line are the ones grading
differently from the rest of the study.

## Usage

``` r
Visualize_GradeBySite(
  dfDistribution,
  dfFlagged = NULL,
  strTitle = "AE severity grade distribution by site"
)
```

## Arguments

- dfDistribution:

  \`data.frame\` output of \[AEGrading_SiteDistribution()\].

- dfFlagged:

  \`data.frame\` optional site-level results with \`GroupID\` and
  \`Flag\` columns (for example \`Analysis_Flagged\` from \`kri0016\`).
  Flagged sites are called out on the axis. Default: \`NULL\`.

- strTitle:

  \`character\` plot title.

## Value

\`ggplot\` object.
