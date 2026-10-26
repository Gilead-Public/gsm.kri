# Participant Listing data for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

One tile per participant and KRI vital, with the three tile labels the
report switches between. \[Widget_RepeatMeasurementsTiles()\] draws
them.

## Usage

``` r
rm_ParticipantTiles(lClass)
```

## Arguments

- lClass:

  \`list\` Output of \[rm_Classify()\].

## Value

A \`tibble\` with \`subjid\`, \`invid\`, \`country\`, \`vital\`,
\`column\`, \`flag\`, \`severity\`, \`Numerator\`, \`Denominator\`,
\`rate\`, \`n\`, \`label_rate\`, \`label_nd\` and \`label_both\`, sorted
by the participant's worst flag, then most repeating windows, then
participant.
