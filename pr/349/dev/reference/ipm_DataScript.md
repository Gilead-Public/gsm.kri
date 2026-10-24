# Inline data block for the IP Monitoring filter script

\`r lifecycle::badge("experimental")\`

Serializes every precomputed chart slice into a JSON script tag that the
report's filter script reads. Each \`\<\` is escaped so no value can
close the block.

## Usage

``` r
ipm_DataScript(lData, strId = "ipc-data")
```

## Arguments

- lData:

  \`list\` Status rows and reason slices.

- strId:

  \`character\` Element id of the script tag.

## Value

An \`htmltools\` \`\<script type="application/json"\>\` tag with id
\`strId\`.
