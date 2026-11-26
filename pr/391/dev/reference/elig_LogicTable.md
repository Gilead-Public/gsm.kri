# Eligibility logic table

\`r lifecycle::badge("experimental")\`

Basic mode shows the two Ineligible rules; pilot mode adds the two
Potentially Ineligible rules. The pilot flags are derived by the study's
own mapping, so the table describes what each flag means, not how a
study derives it.

## Usage

``` r
elig_LogicTable(bPilot = FALSE, lSetup = elig_Setup())
```

## Arguments

- bPilot:

  \`logical\` Pilot mode.

- lSetup:

  \`list\` from \[elig_Setup()\].

## Value

\`gt_tbl\`.
