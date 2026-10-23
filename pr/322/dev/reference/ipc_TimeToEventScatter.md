# IP Compliance time-to-event scatter

\`r lifecycle::badge("experimental")\`

Days since enrollment (y) against days to event (x), one trace per
status; the legend follows the stack order. Participants without an
event sit on the dashed diagonal. Square markers are dosed participants,
circles are not dosed. The report's filter script registers the widget
on render and redraws it on filter and legend changes.

## Usage

``` r
ipc_TimeToEventScatter(dfIPC, nMaxDays, strId)
```

## Arguments

- dfIPC:

  \`data.frame\` Output of \[ipc_ClassifyParticipants()\].

- nMaxDays:

  \`numeric\` Largest day count in the study, so the three scatters
  share one range.

- strId:

  \`character\` Scatter id handed to the filter script.

## Value

A \`plotly\` htmlwidget.
