# Classify enrolled participants for the IP Monitoring report

\`r lifecycle::badge("experimental")\`

One row per enrolled participant with their status, dosed flag, event
date and day counts. Every chart, the overview and the listing read this
frame. Data conflicts are reported as warnings naming the participants.

## Usage

``` r
ipm_ClassifyParticipants(
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

  \`data.frame\` \`Mapped_SUBJ\`, the source of \`drv_drg_completion\`
  and the treatment discontinuation date and reason. \`NULL\`, or a
  frame without \`drv_drg_completion\`, leaves every dosed participant
  Unrecognized.

- dfStudComp:

  \`data.frame\` \`Mapped_STUDCOMP\`, or \`NULL\`.

- dSnapshotDate:

  \`Date\` "Today" for the day counts.

## Value

A \`tibble\` with one row per participant.
