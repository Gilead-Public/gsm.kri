# Report Study Information

\`r lifecycle::badge("stable")\`

This function generates a table summarizing study metadata as an
interactive \[gt::gt()\] wrapped in HTML.

## Usage

``` r
Report_StudyInfo(
  dfGroups,
  lStudyLabels = NULL,
  strId = "study_table",
  tagHeader = htmltools::h2("Study Status"),
  lStudy = deprecated()
)
```

## Arguments

- dfGroups:

  \`data.frame\` Group-level metadata dictionary. Created by passing
  CTMS site and study data to \[MakeLongMeta()\]. Expected columns:
  \`GroupID\`, \`GroupLevel\`, \`Param\`, \`Value\`.

- lStudyLabels:

  \`list\` A list containing study labels. Default is NULL.

- strId:

  \`character\` A string to identify the output table.

- tagHeader:

  \`shiny.tag\` An HTML tag or tags to use as a header for the table.

- lStudy:

  \`deprecated\` Study information as a named list.

## Value

A \[htmltools::tagList()\] to display a table of study information.
