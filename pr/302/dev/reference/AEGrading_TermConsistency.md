# Term-level AE grading consistency

\`r lifecycle::badge("experimental")\`

Evaluates how each site grades the most frequently reported preferred
terms relative to the study as a whole. For every qualifying site/term
pair the function compares the site's high-grade (Grade 3+) proportion
with the study-wide high-grade proportion \*for that same term\*, so
differences in a site's AE mix cannot masquerade as a grading
difference.

A site/term pair is flagged when the absolute difference exceeds
\`nDiffThreshold\` and both volume thresholds are met.

## Usage

``` r
AEGrading_TermConsistency(
  dfAE,
  dfSubj,
  strGroupCol = "invid",
  strTermCol = "mdrpt_nsv",
  nTopTerms = 10,
  nMinTermStudy = 50,
  nMinTermSite = 10,
  nDiffThreshold = 0.2,
  nZThreshold = 3
)
```

## Arguments

- dfAE:

  \`data.frame\` mapped AE data with \`subjid\`, \`aetoxgr\` and the
  term column named in \`strTermCol\`.

- dfSubj:

  \`data.frame\` mapped subject data with \`subjid\` and
  \`strGroupCol\`.

- strGroupCol:

  \`character\` site identifier column. Default: \`"invid"\`.

- strTermCol:

  \`character\` preferred term column. Default: \`"mdrpt_nsv"\`.

- nTopTerms:

  \`numeric\` number of most common preferred terms to evaluate.
  Default: \`10\`.

- nMinTermStudy:

  \`numeric\` minimum study-wide events for a term to be evaluated.
  Default: \`50\`.

- nMinTermSite:

  \`numeric\` minimum site-level events within a term for that site/term
  pair to be evaluated. Default: \`10\`.

- nDiffThreshold:

  \`numeric\` absolute difference in high-grade proportion required to
  flag a site/term pair. Default: \`0.20\`.

- nZThreshold:

  \`numeric\` absolute binomial z-score required for the supplementary
  \`FlaggedZ\` rule. The absolute-difference rule is insensitive to
  under-grading on terms whose study-wide high-grade proportion is
  already below \`nDiffThreshold\`; the z-score rule scales with volume
  and stays symmetric. Default: \`3\`.

## Value

\`data.frame\` with one row per evaluated site/term pair.
