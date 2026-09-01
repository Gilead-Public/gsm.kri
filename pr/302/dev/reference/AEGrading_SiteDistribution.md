# AE severity grading distribution by site

\`r lifecycle::badge("experimental")\`

Summarizes the CTCAE grade distribution of adverse events for each site
and compares it to the study-wide distribution. This is the descriptive
backbone of the AE grading report and the visual companion to the
\`kri0016\` / \`kri0017\` grading KRIs.

## Usage

``` r
AEGrading_SiteDistribution(dfAE, dfSubj, strGroupCol = "invid", nMinAE = 20)
```

## Arguments

- dfAE:

  \`data.frame\` mapped AE data. Must contain \`subjid\` and
  \`aetoxgr\`.

- dfSubj:

  \`data.frame\` mapped subject data. Must contain \`subjid\` and the
  grouping column named in \`strGroupCol\`.

- strGroupCol:

  \`character\` site identifier column in \`dfSubj\`. Default:
  \`"invid"\`.

- nMinAE:

  \`numeric\` minimum number of graded AEs for a site to be included.
  Default: \`20\`.

## Value

\`data.frame\` with one row per site/grade combination and columns
\`GroupID\`, \`Grade\`, \`Count\`, \`SiteTotal\`, \`Proportion\`,
\`StudyProportion\`.
