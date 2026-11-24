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
#>   GroupID                 Param       Value GroupLevel
#> 1   0X031                  City Foster City       Site
#> 2   0X031               Country          US       Site
#> 3   0X031 InvestigatorFirstName        John       Site
#> 4   0X031  InvestigatorLastName        Deer       Site
#> 5   0X031                 invid       0X031       Site
#> 6   0X031      ParticipantCount           2       Site
MakeParamLabels(head(gsm.core::reportingGroups))
#>   GroupID                 Param       Value GroupLevel                   Label
#> 1   0X031                  City Foster City       Site                    City
#> 2   0X031               Country          US       Site                 Country
#> 3   0X031 InvestigatorFirstName        John       Site Investigator First Name
#> 4   0X031  InvestigatorLastName        Deer       Site  Investigator Last Name
#> 5   0X031                 invid       0X031       Site                   Invid
#> 6   0X031      ParticipantCount           2       Site       Participant Count
MakeParamLabels(
  head(gsm.core::reportingGroups),
  list(ParticipantCount = "Number of Participants")
)
#>   GroupID                 Param       Value GroupLevel                   Label
#> 1   0X031                  City Foster City       Site                    City
#> 2   0X031               Country          US       Site                 Country
#> 3   0X031 InvestigatorFirstName        John       Site Investigator First Name
#> 4   0X031  InvestigatorLastName        Deer       Site  Investigator Last Name
#> 5   0X031                 invid       0X031       Site                   Invid
#> 6   0X031      ParticipantCount           2       Site  Number of Participants
MakeParamLabelsList(head(gsm.core::reportingGroups$Param))
#> $City
#> [1] "City"
#> 
#> $Country
#> [1] "Country"
#> 
#> $InvestigatorFirstName
#> [1] "Investigator First Name"
#> 
#> $InvestigatorLastName
#> [1] "Investigator Last Name"
#> 
#> $invid
#> [1] "Invid"
#> 
#> $ParticipantCount
#> [1] "Participant Count"
#> 
```
