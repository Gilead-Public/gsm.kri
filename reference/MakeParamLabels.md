# Create Labels for Parameters

\`r lifecycle::badge("stable")\`

Convert a vector of parameters to labels in Title Case.
\`MakeParamLabels\` adds a \`Labels\` column to a \`data.frame\` that
has a \`Params\` column (such as \`dfGroups\`), while
\`MakeParamLabelsList\` returns just the list of named parameters.

## Usage

``` r
MakeParamLabels(dfGroups, lParamLabels = NULL)

MakeParamLabelsList(chrParams, lParamLabels = NULL)
```

## Arguments

- dfGroups:

  \`data.frame\` Group-level metadata dictionary. Created by passing
  CTMS site and study data to \[MakeLongMeta()\]. Expected columns:
  \`GroupID\`, \`GroupLevel\`, \`Param\`, \`Value\`.

- lParamLabels:

  \`list\` Labels for parameters, with the parameters as names, and the
  label as value.

- chrParams:

  A character vector of parameters, or a list that can be coerced to a
  character vector.

## Value

\`dfGroups\` with an added \`Label\` column, or a list of labeled
parameters.

## Examples

``` r
head(gsm.core::reportingGroups)
#>          GroupID          Param            Value GroupLevel
#> 1 AA-AA-000-0000        studyid   AA-AA-000-0000      Study
#> 2 AA-AA-000-0000       nickname           OAK-38      Study
#> 3 AA-AA-000-0000 protocol_title Protocol Title P      Study
#> 4 AA-AA-000-0000         status           Active      Study
#> 5 AA-AA-000-0000  num_plan_site              150      Study
#> 6 AA-AA-000-0000  num_plan_subj             1000      Study
MakeParamLabels(head(gsm.core::reportingGroups))
#>          GroupID          Param            Value GroupLevel          Label
#> 1 AA-AA-000-0000        studyid   AA-AA-000-0000      Study        Studyid
#> 2 AA-AA-000-0000       nickname           OAK-38      Study       Nickname
#> 3 AA-AA-000-0000 protocol_title Protocol Title P      Study Protocol Title
#> 4 AA-AA-000-0000         status           Active      Study         Status
#> 5 AA-AA-000-0000  num_plan_site              150      Study  Num Plan Site
#> 6 AA-AA-000-0000  num_plan_subj             1000      Study  Num Plan Subj
MakeParamLabels(
  head(gsm.core::reportingGroups),
  list(ParticipantCount = "Number of Participants")
)
#>          GroupID          Param            Value GroupLevel          Label
#> 1 AA-AA-000-0000        studyid   AA-AA-000-0000      Study        Studyid
#> 2 AA-AA-000-0000       nickname           OAK-38      Study       Nickname
#> 3 AA-AA-000-0000 protocol_title Protocol Title P      Study Protocol Title
#> 4 AA-AA-000-0000         status           Active      Study         Status
#> 5 AA-AA-000-0000  num_plan_site              150      Study  Num Plan Site
#> 6 AA-AA-000-0000  num_plan_subj             1000      Study  Num Plan Subj
MakeParamLabelsList(head(gsm.core::reportingGroups$Param))
#> $studyid
#> [1] "Studyid"
#> 
#> $nickname
#> [1] "Nickname"
#> 
#> $protocol_title
#> [1] "Protocol Title"
#> 
#> $status
#> [1] "Status"
#> 
#> $num_plan_site
#> [1] "Num Plan Site"
#> 
#> $num_plan_subj
#> [1] "Num Plan Subj"
#> 
```
