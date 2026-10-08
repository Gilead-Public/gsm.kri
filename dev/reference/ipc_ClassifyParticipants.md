# Classify enrolled participants for the IP Compliance report

\`r lifecycle::badge("experimental")\`

One row per enrolled participant with their status, dosed flag, event
date and day counts. Every chart, the overview and the listing read this
frame. Data conflicts are reported as warnings naming the participants.

## Usage

``` r
ipc_ClassifyParticipants(
  dfIPNS,
  dfSubj = NULL,
  dfStudComp = NULL,
  dSnapshotDate
)
```

## Arguments

- dfIPNS:

  \`data.frame\` \`Mapped_IPNS\`.

- dfSubj:

  \`data.frame\` \`Mapped_SUBJ\`, the source of the premature treatment
  discontinuation fields. \`NULL\`, or a frame without
  \`drv_treatment_discontinuation_dt\`, runs without them.

- dfStudComp:

  \`data.frame\` \`Mapped_STUDCOMP\`, or \`NULL\`.

- dSnapshotDate:

  \`Date\` "Today" for the day counts.

## Value

A \`tibble\` with one row per participant.
