# Header card of the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

The card at the top of the report: an optional context line, the title,
the study, snapshot, window length and participant flag rule, and the
collapsible "How to read" notes. \`rmFilters.js\` rewrites the rule text
(\`.rm-rule-text\`) when the reviewer changes the settings.

## Usage

``` r
rep_Header(lClass, strStudy, dSnapshotDate = NULL, strContext = "")
```

## Arguments

- lClass:

  \`list\` Output of \[rep_Classify()\].

- strStudy:

  \`character\` Study ID(s) shown in the header. The Study pill is
  omitted when \`NULL\`, \`NA\` or empty.

- dSnapshotDate:

  \`Date\` Snapshot date. Optional; omitted when \`NULL\`.

- strContext:

  \`character\` HTML for a line above the title, such as a link back to
  the page that embeds the report. Omitted when empty.

## Value

An \`htmltools\` tag.
