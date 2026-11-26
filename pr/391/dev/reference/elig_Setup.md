# Eligibility report settings

\`r lifecycle::badge("experimental")\`

Settings of the Eligibility report. \`NULL\` \`dfSources\` and
\`vCriterionColors\` take the defaults. The result is accepted back by
this function unchanged.

## Usage

``` r
elig_Setup(
  dfSources = NULL,
  strRateMetricID = "Analysis_qtl0001",
  vCriterionColors = NULL,
  strInvestigatorLevel = "Site",
  vInvestigatorParams = c("InvestigatorFirstName", "InvestigatorLastName")
)
```

## Arguments

- dfSources:

  \`data.frame\` Flag sources with columns \`flag\`, \`label\` (chart
  name), \`listing_label\` (listing column) and \`record_source\`
  (record table in the expanded row). Only \`flag\` is required; each
  passed row overrides the defaults of that flag for the passed columns.
  Passing all six flags sets their display order. Both PD split flags
  use the \`record_source\` of \`flag_pd\`. Defaults:

  |  |  |  |  |
  |----|----|----|----|
  | \`flag\` | \`label\` | \`listing_label\` | \`record_source\` |
  | \`flag_pd\` | Protocol Deviation | PD | Protocol Deviation |
  | \`flag_pd_important\` | Important PD | Important PD | Protocol Deviation |
  | \`flag_pd_nonimportant\` | Non-important PD | Non-important PD | Protocol Deviation |
  | \`flag_ecrf\` | EDC eCRF | EDC eCRF | EDC eCRF |
  | \`flag_edc_query\` | EDC Query | EDC Query | EDC Query |
  | \`flag_edc_pd\` | EDC PD | EDC PD | EDC PD |

- strRateMetricID:

  \`character\` Analysis metric charted as the eligibility rate.
  \`workflow/4_modules/report_eligibility.yaml\` queries only
  \`Analysis_qtl0001\`, so the setting matters for direct callers.
  Default: \`"Analysis_qtl0001"\`.

- vCriterionColors:

  Named \`character\` Colours by criterion type; passed names replace
  the defaults, stack order stays \`Inclusion\`, \`Exclusion\`, \`Not
  classified\`. Defaults: \`"#3C587F"\`, \`"#8FB3DE"\`, \`"#B8C4D6"\`.

- strInvestigatorLevel:

  \`character\` Group level of the investigator parameters. Default:
  \`"Site"\`.

- vInvestigatorParams:

  \`character\` Parameters joined into the investigator name. Default:
  \`c("InvestigatorFirstName", "InvestigatorLastName")\`.

## Value

\`list\` with \`dfSources\`, \`strRateMetricID\`, \`vCriterionColors\`,
\`strInvestigatorLevel\` and \`vInvestigatorParams\`.
