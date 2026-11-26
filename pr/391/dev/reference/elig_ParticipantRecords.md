# Records behind each flagged participant's status

\`r lifecycle::badge("experimental")\`

One row per record: the level 2 records when delivered. A participant's
PD or EDC eCRF source without level 2 records falls back to
\`Mapped_EXCLUSION\`: one Protocol Deviation row per PD date/term pair
and one EDC eCRF row per criterion code.

## Usage

``` r
elig_ParticipantRecords(dfElig, dfRecords = NULL, lSetup = elig_Setup())
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

- dfRecords:

  \`data.frame\` Level 2 records, or \`NULL\`.

- lSetup:

  \`list\` from \[elig_Setup()\].

## Value

\`data.frame\` with \`subjid\`, \`source\`, \`ID\`, \`Date\` and the key
fields.
