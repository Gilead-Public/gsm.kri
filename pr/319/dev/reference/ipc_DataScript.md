# Inline data block for the IP Compliance filter script

\`r lifecycle::badge("experimental")\`

Serializes every precomputed chart slice into a JSON script tag that the
report's filter script reads. Each \`\<\` is escaped so no value can
close the block.

## Usage

``` r
ipc_DataScript(lData)
```

## Arguments

- lData:

  \`list\` Status rows and reason slices.

## Value

An \`htmltools\` \`\<script type="application/json" id="ipc-data"\>\`
tag.
