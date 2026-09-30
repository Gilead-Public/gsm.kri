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
#>                          Param             Value                   Description
#> 1                      studyid    AA-AA-000-0000                       Studyid
#> 2                     nickname            OAK-38                      Nickname
#> 3               protocol_title  Protocol Title P                Protocol Title
#> 4                       status            Active                        Status
#> 5                num_plan_site               150                 Num Plan Site
#> 6                num_plan_subj              1000                 Num Plan Subj
#> 7                     act_fpfv        2012-01-02                      Act Fpfv
#> 8                     est_fpfv        2012-01-07                      Est Fpfv
#> 9                     est_lplv        2012-07-22                      Est Lplv
#> 10                    est_lpfv        2012-03-24                      Est Lpfv
#> 11                  db_lock_dt        2012-03-29                    Db Lock Dt
#> 12            therapeutic_area          Virology              Therapeutic Area
#> 13         protocol_indication        Hematology           Protocol Indication
#> 14                       phase                P2                         Phase
#> 15                     product   Product Name 14                       Product
#> 16                  SiteTarget               150                   Site Target
#> 17           ParticipantTarget              1000            Participant Target
#> 18            ParticipantCount               760         Participants Enrolled
#> 19                   SiteCount               148                Sites Enrolled
#> 20       PercentSitesActivated              98.7       Percent Sites Activated
#> 21              SiteActivation 148 / 150 (98.7%)               Site Activation
#> 22 PercentParticipantsEnrolled                76 Percent Participants Enrolled
#> 23       ParticipantEnrollment  760 / 1000 (76%)        Participant Enrollment
MakeStudyInfo(gsm.core::reportingGroups, list(SiteCount = "# Sites"))
#>                          Param             Value                   Description
#> 1                      studyid    AA-AA-000-0000                       Studyid
#> 2                     nickname            OAK-38                      Nickname
#> 3               protocol_title  Protocol Title P                Protocol Title
#> 4                       status            Active                        Status
#> 5                num_plan_site               150                 Num Plan Site
#> 6                num_plan_subj              1000                 Num Plan Subj
#> 7                     act_fpfv        2012-01-02                      Act Fpfv
#> 8                     est_fpfv        2012-01-07                      Est Fpfv
#> 9                     est_lplv        2012-07-22                      Est Lplv
#> 10                    est_lpfv        2012-03-24                      Est Lpfv
#> 11                  db_lock_dt        2012-03-29                    Db Lock Dt
#> 12            therapeutic_area          Virology              Therapeutic Area
#> 13         protocol_indication        Hematology           Protocol Indication
#> 14                       phase                P2                         Phase
#> 15                     product   Product Name 14                       Product
#> 16                  SiteTarget               150                   Site Target
#> 17           ParticipantTarget              1000            Participant Target
#> 18            ParticipantCount               760             Participant Count
#> 19                   SiteCount               148                       # Sites
#> 20       PercentSitesActivated              98.7       Percent Sites Activated
#> 21              SiteActivation 148 / 150 (98.7%)               Site Activation
#> 22 PercentParticipantsEnrolled                76 Percent Participants Enrolled
#> 23       ParticipantEnrollment  760 / 1000 (76%)        Participant Enrollment
```
