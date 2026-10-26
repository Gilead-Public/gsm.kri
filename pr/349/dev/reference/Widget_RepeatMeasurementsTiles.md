# Participant Listing widget for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

A participant x vital tile grid: one row per participant, one tile per
KRI vital, filled by the participant's flag and labelled with the rate,
N/D or both. Clicking a participant or any of their tiles (or pressing
Enter or Space on one) dispatches a bubbling \`rm-tiles-select\` event
whose \`detail\` holds \`chartId\` and \`subjid\`; the report's filter
script uses it to toggle the participant filter. The rendered element
exposes the \`gsmChart\` API that the filter script calls (\`data\`,
\`helpers.updateData()\`, \`helpers.selectRow()\`,
\`helpers.clearSelection()\` and \`helpers.updateSpec()\` for the label
mode).

## Usage

``` r
Widget_RepeatMeasurementsTiles(
  dfTiles,
  strLabel = c("both", "rate", "nd"),
  strId = "rm-tiles",
  nPageSize = 50L
)
```

## Arguments

- dfTiles:

  \`data.frame\` Output of \[rm_ParticipantTiles()\].

- strLabel:

  \`character\` Initial tile label: \`"both"\`, \`"rate"\` or \`"nd"\`.

- strId:

  \`character\` Element ID of the widget.

- nPageSize:

  \`integer\` Participants per page.

## Value

An htmlwidget.
