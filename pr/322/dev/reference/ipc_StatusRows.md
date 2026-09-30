# Long status rows for the IP Compliance status charts

\`r lifecycle::badge("experimental")\`

Participant counts per group and status, once for every dosed filter
(\`"all"\`, \`"Y"\`, \`"N"\`), so the report's filter script only picks
rows. Participants whose dosed flag is unrecognised appear under
\`"all"\` only.

## Usage

``` r
ipc_StatusRows(dfIPC, strLevel = c("study", "country", "site"))
```

## Arguments

- dfIPC:

  \`data.frame\` Output of \[ipc_ClassifyParticipants()\].

- strLevel:

  \`character\` \`"study"\`, \`"country"\` or \`"site"\`.

## Value

A \`tibble\` with \`Dosed\`, \`GroupID\`, \`OuterGroupID\` (country for
site rows, else \`NA\`), \`Status\`, \`n\` and \`Level\`. Only non-zero
cells.
