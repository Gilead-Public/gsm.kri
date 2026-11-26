# Eligibility study overview cards

\`r lifecycle::badge("experimental")\`

Basic mode: Total Enrolled, Ineligible Participants and No Eligibility
Risk. Pilot mode: Total Enrolled, Total risk, Ineligible Participants
and Potentially Ineligible.

## Usage

``` r
elig_OverviewCards(dfElig, bPilot = FALSE)
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

- bPilot:

  \`logical\` Pilot mode.

## Value

\`htmltools\` tag.
