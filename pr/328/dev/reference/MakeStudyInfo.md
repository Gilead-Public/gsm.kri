# Generate a study information data.frame for use in reports

\`r lifecycle::badge("stable")\`

Generate a study info table summarizing study metadata.

## Usage

``` r
MakeStudyInfo(dfGroups, lStudyLabels = NULL, lStudy = deprecated())
```

## Arguments

- dfGroups:

  \`data.frame\` Group-level metadata dictionary. Created by passing
  CTMS site and study data to \[MakeLongMeta()\]. Expected columns:
  \`GroupID\`, \`GroupLevel\`, \`Param\`, \`Value\`.

- lStudyLabels:

  \`list\` A list containing study labels. Default is NULL.

- lStudy:

  \`deprecated\` Study information as a named list.

## Value

A data.frame containing study metadata.

## Examples

``` r
MakeStudyInfo(gsm.core::reportingGroups)
#>                          Param                 Value
#> 1                      studyid        AA-AA-000-0000
#> 2                     nickname                OAK-99
#> 3               protocol_title      Protocol Title L
#> 4                       status                Active
#> 5                num_plan_site                   150
#> 6                num_plan_subj                  1000
#> 7                     act_fpfv            2012-02-11
#> 8                     est_fpfv            2012-02-22
#> 9                     est_lplv            2012-05-29
#> 10                    est_lpfv            2012-04-05
#> 11                  db_lock_dt            2012-04-28
#> 12            therapeutic_area              Virology
#> 13         protocol_indication Cardiovascular Health
#> 14                       phase                    P4
#> 15                     product        Product Name 2
#> 16                  SiteTarget                   150
#> 17           ParticipantTarget                  1000
#> 18            ParticipantCount                   754
#> 19                   SiteCount                   141
#> 20       PercentSitesActivated                    94
#> 21              SiteActivation       141 / 150 (94%)
#> 22 PercentParticipantsEnrolled                  75.4
#> 23       ParticipantEnrollment    754 / 1000 (75.4%)
#>                      Description
#> 1                        Studyid
#> 2                       Nickname
#> 3                 Protocol Title
#> 4                         Status
#> 5                  Num Plan Site
#> 6                  Num Plan Subj
#> 7                       Act Fpfv
#> 8                       Est Fpfv
#> 9                       Est Lplv
#> 10                      Est Lpfv
#> 11                    Db Lock Dt
#> 12              Therapeutic Area
#> 13           Protocol Indication
#> 14                         Phase
#> 15                       Product
#> 16                   Site Target
#> 17            Participant Target
#> 18         Participants Enrolled
#> 19                Sites Enrolled
#> 20       Percent Sites Activated
#> 21               Site Activation
#> 22 Percent Participants Enrolled
#> 23        Participant Enrollment
MakeStudyInfo(gsm.core::reportingGroups, list(SiteCount = "# Sites"))
#>                          Param                 Value
#> 1                      studyid        AA-AA-000-0000
#> 2                     nickname                OAK-99
#> 3               protocol_title      Protocol Title L
#> 4                       status                Active
#> 5                num_plan_site                   150
#> 6                num_plan_subj                  1000
#> 7                     act_fpfv            2012-02-11
#> 8                     est_fpfv            2012-02-22
#> 9                     est_lplv            2012-05-29
#> 10                    est_lpfv            2012-04-05
#> 11                  db_lock_dt            2012-04-28
#> 12            therapeutic_area              Virology
#> 13         protocol_indication Cardiovascular Health
#> 14                       phase                    P4
#> 15                     product        Product Name 2
#> 16                  SiteTarget                   150
#> 17           ParticipantTarget                  1000
#> 18            ParticipantCount                   754
#> 19                   SiteCount                   141
#> 20       PercentSitesActivated                    94
#> 21              SiteActivation       141 / 150 (94%)
#> 22 PercentParticipantsEnrolled                  75.4
#> 23       ParticipantEnrollment    754 / 1000 (75.4%)
#>                      Description
#> 1                        Studyid
#> 2                       Nickname
#> 3                 Protocol Title
#> 4                         Status
#> 5                  Num Plan Site
#> 6                  Num Plan Subj
#> 7                       Act Fpfv
#> 8                       Est Fpfv
#> 9                       Est Lplv
#> 10                      Est Lpfv
#> 11                    Db Lock Dt
#> 12              Therapeutic Area
#> 13           Protocol Indication
#> 14                         Phase
#> 15                       Product
#> 16                   Site Target
#> 17            Participant Target
#> 18             Participant Count
#> 19                       # Sites
#> 20       Percent Sites Activated
#> 21               Site Activation
#> 22 Percent Participants Enrolled
#> 23        Participant Enrollment
```
