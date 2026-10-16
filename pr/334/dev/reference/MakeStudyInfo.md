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
#> 1             ParticipantCount                   754
#> 2        ParticipantEnrollment    754 / 1000 (75.4%)
#> 3            ParticipantTarget                  1000
#> 4  PercentParticipantsEnrolled                  75.4
#> 5        PercentSitesActivated                    94
#> 6               SiteActivation       141 / 150 (94%)
#> 7                    SiteCount                   141
#> 8                   SiteTarget                   150
#> 9                     act_fpfv            2012-02-11
#> 10                  db_lock_dt            2012-04-28
#> 11                    est_fpfv            2012-02-22
#> 12                    est_lpfv            2012-04-05
#> 13                    est_lplv            2012-05-29
#> 14                    nickname                OAK-99
#> 15               num_plan_site                   150
#> 16               num_plan_subj                  1000
#> 17                       phase                    P4
#> 18                     product        Product Name 2
#> 19         protocol_indication Cardiovascular Health
#> 20              protocol_title      Protocol Title L
#> 21                      status                Active
#> 22                     studyid        AA-AA-000-0000
#> 23            therapeutic_area              Virology
#>                      Description
#> 1          Participants Enrolled
#> 2         Participant Enrollment
#> 3             Participant Target
#> 4  Percent Participants Enrolled
#> 5        Percent Sites Activated
#> 6                Site Activation
#> 7                 Sites Enrolled
#> 8                    Site Target
#> 9                       Act Fpfv
#> 10                    Db Lock Dt
#> 11                      Est Fpfv
#> 12                      Est Lpfv
#> 13                      Est Lplv
#> 14                      Nickname
#> 15                 Num Plan Site
#> 16                 Num Plan Subj
#> 17                         Phase
#> 18                       Product
#> 19           Protocol Indication
#> 20                Protocol Title
#> 21                        Status
#> 22                       Studyid
#> 23              Therapeutic Area
MakeStudyInfo(gsm.core::reportingGroups, list(SiteCount = "# Sites"))
#>                          Param                 Value
#> 1             ParticipantCount                   754
#> 2        ParticipantEnrollment    754 / 1000 (75.4%)
#> 3            ParticipantTarget                  1000
#> 4  PercentParticipantsEnrolled                  75.4
#> 5        PercentSitesActivated                    94
#> 6               SiteActivation       141 / 150 (94%)
#> 7                    SiteCount                   141
#> 8                   SiteTarget                   150
#> 9                     act_fpfv            2012-02-11
#> 10                  db_lock_dt            2012-04-28
#> 11                    est_fpfv            2012-02-22
#> 12                    est_lpfv            2012-04-05
#> 13                    est_lplv            2012-05-29
#> 14                    nickname                OAK-99
#> 15               num_plan_site                   150
#> 16               num_plan_subj                  1000
#> 17                       phase                    P4
#> 18                     product        Product Name 2
#> 19         protocol_indication Cardiovascular Health
#> 20              protocol_title      Protocol Title L
#> 21                      status                Active
#> 22                     studyid        AA-AA-000-0000
#> 23            therapeutic_area              Virology
#>                      Description
#> 1              Participant Count
#> 2         Participant Enrollment
#> 3             Participant Target
#> 4  Percent Participants Enrolled
#> 5        Percent Sites Activated
#> 6                Site Activation
#> 7                        # Sites
#> 8                    Site Target
#> 9                       Act Fpfv
#> 10                    Db Lock Dt
#> 11                      Est Fpfv
#> 12                      Est Lpfv
#> 13                      Est Lplv
#> 14                      Nickname
#> 15                 Num Plan Site
#> 16                 Num Plan Subj
#> 17                         Phase
#> 18                       Product
#> 19           Protocol Indication
#> 20                Protocol Title
#> 21                        Status
#> 22                       Studyid
#> 23              Therapeutic Area
```
