# Plot term-level grading deviation as a site-by-term heatmap

\`r lifecycle::badge("experimental")\`

Shows, for each site and each of the most common preferred terms, how
far the site's Grade 3+ proportion sits from the study-wide proportion
for that term. Cells are blank where the site did not report enough
events of that term to evaluate.

## Usage

``` r
Visualize_TermGradingHeatmap(
  dfTermConsistency,
  nMinFlaggedTerms = 1,
  strTitle = "Site vs. study Grade 3+ proportion, by preferred term"
)
```

## Arguments

- dfTermConsistency:

  \`data.frame\` output of \[AEGrading_TermConsistency()\].

- nMinFlaggedTerms:

  \`numeric\` restrict the plot to sites flagged on at least this many
  terms. Set to \`0\` to show all evaluated sites. Default: \`1\`.

- strTitle:

  \`character\` plot title.

## Value

\`ggplot\` object.
