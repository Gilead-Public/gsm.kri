# Summarize term-level grading inconsistency by site

\`r lifecycle::badge("experimental")\`

Rolls \[AEGrading_TermConsistency()\] up to one row per site, counting
how many of the evaluated preferred terms the site grades
inconsistently. Sites that deviate on several independent terms are the
ones worth investigating: a single discrepant term is easily explained
by case mix or chance, a pattern across terms points at how the site
applies the grading criteria.

## Usage

``` r
AEGrading_SiteTermSummary(dfTermConsistency, nMinFlaggedTerms = 2)
```

## Arguments

- dfTermConsistency:

  \`data.frame\` output of \[AEGrading_TermConsistency()\].

- nMinFlaggedTerms:

  \`numeric\` number of inconsistent terms required to flag the site for
  investigation. Default: \`2\`.

## Value

\`data.frame\` with one row per site.
