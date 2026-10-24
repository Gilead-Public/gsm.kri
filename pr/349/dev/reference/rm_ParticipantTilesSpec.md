# gsm.viz tiles spec for the Repeat Measurements Participant Listing

\`r lifecycle::badge("experimental")\`

Fill is the participant's flag for the vital; clicking a vital header
expands it into one column per measurement, repeat-window values
highlighted.

## Usage

``` r
rm_ParticipantTilesSpec(dfDetail, strLabel = c("both", "rate", "nd"))
```

## Arguments

- dfDetail:

  \`data.frame\` \`detail\` from \[rm_ParticipantTiles()\].

- strLabel:

  \`character\` Initial cell label: \`"both"\`, \`"rate"\` or \`"nd"\`.

## Value

A named \`list\` for \[gsm.vizr::tiles()\].
