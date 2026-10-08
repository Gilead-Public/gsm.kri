# gsm.viz spec for the IP Compliance status charts

\`r lifecycle::badge("experimental")\`

A 100 shows: "62.3 chart is one horizontal bar; the country and site
charts zoom and pan.

## Usage

``` r
ipc_StatusBarSpec(strLevel = c("study", "country", "site"))
```

## Arguments

- strLevel:

  \`character\` \`"study"\`, \`"country"\` or \`"site"\`.

## Value

A named \`list\` for \[gsm.vizr::bars()\].
