# Participant Listing data for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

One tile per participant and KRI vital, with the three cell labels the
report switches between, and one detail row per measurement for the
expanded columns.

## Usage

``` r
rm_ParticipantTiles(lClass)
```

## Arguments

- lClass:

  \`list\` Output of \[rm_Classify()\].

## Value

A \`list\` with \`tiles\` (\`subjid\`, \`invid\`, \`country\`,
\`vital\`, \`column\`, \`flag\`, \`severity\`, \`Numerator\`,
\`Denominator\`, \`rate\`, \`n\`, \`label_rate\`, \`label_nd\`,
\`label_both\`), sorted by the participant's worst flag, then
participant; and \`detail\` (\`subjid\`, \`column\`, \`seq\`, \`value\`,
\`in_repeat_window\` ("Yes"/"No"), \`visit\`).
