# gsm.viz spec for the Repeat Measurements distribution charts

\`r lifecycle::badge("experimental")\`

The IP Monitoring status bar (\[ipm_StatusBarSpec()\]) recoloured by
flag: a 100% stacked bar of evaluable participants per group, in the
order given. Country and site charts zoom and pan; the zoom is the
requirement's site slider.

## Usage

``` r
rm_DistributionSpec(
  strLevel = c("study", "country", "site"),
  vOrder = NULL,
  strTitle = "Evaluable participants by flag"
)
```

## Arguments

- strLevel:

  \`character\` \`"study"\`, \`"country"\` or \`"site"\`.

- vOrder:

  \`character\` Group order, highest percent flagged first.

- strTitle:

  \`character\` Chart title.

## Value

A named \`list\` for \[gsm.vizr::bars()\].
