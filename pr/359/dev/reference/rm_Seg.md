# Segmented control for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

A group of toggle buttons, one per value, with \`aria-pressed\` on the
selected one. \`rmFilters.js\` finds the buttons by their data
attribute.

## Usage

``` r
rm_Seg(
  strLabel,
  vValues,
  strSelected,
  strAttr,
  strGroup = NULL,
  strIdPrefix = NULL
)
```

## Arguments

- strLabel:

  \`character\` Accessible label of the group.

- vValues:

  \`character\` Button labels, named by value.

- strSelected:

  \`character\` The value pressed initially.

- strAttr:

  \`character\` Data attribute the script reads, such as
  \`"data-rm-ov"\`.

- strGroup:

  \`character\` Optional. When given, every button sets \`strAttr\` to
  \`strGroup\` and carries its value in \`value\`; otherwise \`strAttr\`
  holds the value.

- strIdPrefix:

  \`character\` Optional prefix of each button's \`id\`, followed by its
  value.

## Value

An \`htmltools\` tag.
