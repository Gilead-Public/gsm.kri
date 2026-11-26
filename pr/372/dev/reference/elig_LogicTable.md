# Eligibility logic table

\`r lifecycle::badge("experimental")\`

Basic mode shows the two Ineligible rules; pilot mode adds the two
Potentially Ineligible rules. The pilot flags are derived by the study's
own mapping, so the table describes what each flag means, not how a
study derives it.

## Usage

``` r
elig_LogicTable(bPilot = FALSE)
```

## Arguments

- bPilot:

  \`logical\` Pilot mode.

## Value

\`gt_tbl\`.
