# Deep dive listing data

\`r lifecycle::badge("experimental")\`

One row per flagged participant and one column per source. Each cell
lists the participant's records as \`\[record id\] date\` followed by
the source's key fields; a blank cell means no records.

## Usage

``` r
elig_DeepDiveData(dfElig, dfRecords)
```

## Arguments

- dfElig:

  \`data.frame\` from \[elig_ClassifyParticipants()\].

- dfRecords:

  \`data.frame\` Level 2 records: \`studyid\`, \`subjid\`, \`source\`,
  \`record_id\`, \`record_date\` and key fields.

## Value

\`data.frame\`.
