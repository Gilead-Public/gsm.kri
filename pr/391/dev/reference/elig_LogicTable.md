# Eligibility logic table

\`r lifecycle::badge("experimental")\`

Basic mode shows today's two rules; pilot mode shows rules 2.4-2.7 of
the \#113 business requirement.

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
