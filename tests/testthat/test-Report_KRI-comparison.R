test_that("Report_KRI forwards comparison score configuration (#280)", {
  captured <- NULL
  testthat::local_mocked_bindings(
    RenderRmd = function(...) {
      captured <<- list(...)
      invisible("report.html")
    },
    .package = "gsm.kri"
  )

  Report_KRI(
    lCharts = list(),
    dfResults = data.frame(),
    dfMetrics = data.frame(),
    dfGroups = data.frame(),
    strOutputFile = "report.html",
    strComparisonRiskMetric = "Analysis_custom_srs",
    strComparisonRiskLabel = "Comparison Score",
    strGroupSubset = "all"
  )

  expect_equal(
    captured$lParams$strComparisonRiskMetric,
    "Analysis_custom_srs"
  )
  expect_equal(
    captured$lParams$strComparisonRiskLabel,
    "Comparison Score"
  )
  expect_equal(captured$lParams$strGroupSubset, "all")
})

test_that("Report_KRI can disable and validates comparison scores (#280)", {
  captured <- NULL
  testthat::local_mocked_bindings(
    RenderRmd = function(...) {
      captured <<- list(...)
      invisible("report.html")
    },
    .package = "gsm.kri"
  )

  Report_KRI(
    strOutputFile = "report.html",
    strComparisonRiskMetric = NULL
  )
  expect_null(captured$lParams$strComparisonRiskMetric)

  expect_error(
    Report_KRI(
      strOutputFile = "report.html",
      strComparisonRiskMetric = character()
    ),
    "strComparisonRiskMetric.*must be NULL"
  )
  expect_error(
    Report_KRI(
      strOutputFile = "report.html",
      strComparisonRiskLabel = NA_character_
    ),
    "strComparisonRiskLabel.*must be a single"
  )
  expect_error(
    Report_KRI(
      strOutputFile = "report.html",
      strGroupSubset = "unknown"
    ),
    "strGroupSubset.*must be NULL"
  )
})
test_that("Report_KRI forwards risk score detail (#280)", {
  captured <- NULL
  testthat::local_mocked_bindings(
    RenderRmd = function(...) {
      captured <<- list(...)
      invisible("report.html")
    },
    .package = "gsm.kri"
  )

  detail <- data.frame(GroupID = "1", MetricID = "Analysis_kri0001")
  Report_KRI(strOutputFile = "report.html", dfRiskScoreDetail = detail)
  expect_equal(captured$lParams$dfRiskScoreDetail, detail)

  Report_KRI(strOutputFile = "report.html")
  expect_null(captured$lParams$dfRiskScoreDetail)
})

test_that("dated action detail selects priority labels and is optional in workflows (#280)", {
  captured <- NULL
  testthat::local_mocked_bindings(
    RenderRmd = function(...) {
      captured <<- list(...)
      invisible("report.html")
    },
    MakeCharts = function(...) list(),
    .package = "gsm.kri"
  )
  detail <- data.frame(
    GroupID = "1001", MetricID = "Analysis_kri0001", ActionWindowDays = 90
  )
  Report_KRI(strOutputFile = "report.html", dfRiskScoreDetail = detail)
  expect_equal(captured$lParams$strComparisonRiskLabel, "Review Priority Score")
  Report_KRI(
    strOutputFile = "report.html", dfRiskScoreDetail = detail,
    strComparisonRiskLabel = "Custom priority"
  )
  expect_equal(captured$lParams$strComparisonRiskLabel, "Custom priority")

  workflow <- yaml::read_yaml(system.file(
    "workflow/4_modules/report_kri_site.yaml", package = "gsm.kri"
  ))
  workflow$steps[[length(workflow$steps)]]$params$strOutputFile <- "report.html"
  domains <- list(
    Reporting_Results = gsm.core::reportingResults,
    Reporting_Metrics = gsm.core::reportingMetrics,
    Reporting_Groups = gsm.core::reportingGroups,
    Reporting_Bounds = gsm.core::reportingBounds
  )
  workr::RunWorkflow(workflow, lData = domains)
  expect_null(captured$lParams$dfRiskScoreDetail)
  domains$Analysis_ActionRiskScoreDetail <- detail
  workr::RunWorkflow(workflow, lData = domains)
  expect_equal(captured$lParams$dfRiskScoreDetail, detail)
  expect_equal(captured$lParams$strComparisonRiskLabel, "Review Priority Score")
})

test_that("site report demo actions match actual flagged snapshots (#280)", {
  testthat::local_mocked_bindings(
    MakeCharts = function(...) list(), .package = "gsm.kri"
  )
  testthat::local_mocked_bindings(
    knit_child = function(...) character(), .package = "knitr"
  )
  source_path <- testthat::test_path("..", "..", "pkgdown", "menus", "examples", "Example_SiteReport.Rmd")
  skip_if_not(file.exists(source_path), "Pkgdown examples are excluded from built packages")
  script <- tempfile(fileext = ".R")
  knitr::purl(source_path, output = script, quiet = TRUE)
  example <- new.env(parent = asNamespace("gsm.kri"))
  example_warnings <- character()
  withCallingHandlers(
    sys.source(script, envir = example),
    warning = function(condition) {
      example_warnings <<- c(example_warnings, conditionMessage(condition))
      invokeRestart("muffleWarning")
    }
  )
  expect_equal(example_warnings, character())
  actions <- example$demo_action_log
  keys <- c("StudyID", "SnapshotDate", "GroupLevel", "GroupID", "MetricID")
  actual <- gsm.core::reportingResults[, c(keys, "Flag")]
  matched <- merge(actions, actual, by = keys, suffixes = c("", "_actual"))
  expect_equal(nrow(matched), nrow(actions))
  expect_true(all(!is.na(matched$Flag_actual) & matched$Flag_actual != 0))
  reviewed <- !is.na(matched$ActionedDate)
  expect_equal(matched$ActionedFlag[reviewed], as.numeric(matched$Flag_actual[reviewed]))
  expect_true(all(actions$State %in% c("Open Action", "Closed Action", "Awaiting Triage", "No Action")))
  expect_true(all(c("Open Action", "Closed Action", "Awaiting Triage", "No Action") %in% actions$State))
  expect_true(all(actions$ActionedDate >= actions$SnapshotDate, na.rm = TRUE))
  expect_true(all(actions$ActionedDate <= example$latest_snapshot, na.rm = TRUE))
  expect_equal(anyDuplicated(stats::na.omit(actions$ActionID)), 0L)
  pending <- actions$State == "Awaiting Triage"
  expect_true(any(pending))
  expect_true(all(is.na(actions$ActionID[pending]) & is.na(actions$ActionedDate[pending])))
  expect_true(all(is.na(actions$ActionResolvedDate[actions$State == "Open Action"])))
  closed <- actions$State == "Closed Action"
  expect_true(all(actions$ActionResolvedDate[closed] >= actions$ActionCreatedDate[closed]))
  current <- example$current_kri_results
  detail <- example$action_score_detail
  expect_equal(nrow(detail), nrow(current))
  expect_false(any(detail$RecentlyAddressed[is.na(detail$Flag)]))
  reviewed_green <- detail[!is.na(detail$Flag) & detail$Flag == 0 & !is.na(detail$LastActionedDate), ]
  expect_gt(nrow(reviewed_green), 0L)
  expect_lte(nrow(reviewed_green), 12L)
  expect_true(all(reviewed_green$ActionState == "Closed Action"))
  expect_true(all(reviewed_green$ActionedFlag != 0))
  expect_true(all(reviewed_green$ActionSignalSnapshotDate < reviewed_green$SnapshotDate))
  expect_true(all(reviewed_green$LastActionedDate < reviewed_green$SnapshotDate))
  expect_true(all(reviewed_green$DaysSinceAction >= 0 & reviewed_green$DaysSinceAction <= 90))
  expect_true(all(reviewed_green$ActionReason == "Previously flagged; reviewed"))
  expect_true(all(is.na(reviewed_green$EffectiveWeight) | reviewed_green$EffectiveWeight == 0))
  expect_true(all(detail$ActionState[!is.na(detail$LastActionedDate)] %in% c("Open Action", "Closed Action", "No Action")))
  weighted_detail <- detail[!is.na(detail$Weight), ]
  expect_true(all(weighted_detail$ActionPolicy == "disposition"))
  retained <- weighted_detail$ActionState %in% c("Open Action", "Closed Action", "Awaiting Triage")
  expect_equal(weighted_detail$EffectiveWeight[retained], weighted_detail$Weight[retained])
  dismissed <- weighted_detail$ActionState == "No Action" & weighted_detail$RecentlyAddressed
  expect_true(any(dismissed & weighted_detail$Weight > 0, na.rm = TRUE))
  expect_true(all(weighted_detail$EffectiveWeight[dismissed] == 0))
  expect_true(all(actions$ActionedDate >= min(gsm.core::reportingResults$SnapshotDate), na.rm = TRUE))
  expect_true(any(detail$RecentlyAddressed))
  expect_true(any(detail$ActionState == "Awaiting Triage"))
  expect_true(any(example$action_weighted_score$Numerator > 0))
  site_metric <- c("StudyID", "GroupLevel", "GroupID", "MetricID")
  active <- gsm.core::reportingMetrics
  active <- active$MetricID[active$GroupLevel == "Site" & active$Active %in% TRUE]
  expect_true(all(actions$MetricID %in% active))
  current_flagged <- current[!is.na(current$Flag) & current$Flag != 0, site_metric]
  expect_equal(nrow(merge(unique(actions[site_metric]), current_flagged, by = site_metric)), nrow(current_flagged))
  current_actions <- merge(actions, current_flagged, by = site_metric)
  expect_true(all(vapply(split(current_actions$State, current_actions$MetricID), function(states) {
    length(states) == 1L || length(unique(states)) > 1L
  }, logical(1))))
  without_green <- CalculateActionRiskScore(
    example$weighted_kri_results, example$weights, current_actions,
    intActionWindowDays = 90, bActionHistoryComplete = TRUE, strActionPolicy = "disposition"
  )
  score_columns <- c("GroupID", "Numerator", "Denominator", "Score")
  expect_equal(example$action_weighted_score[score_columns], without_green[score_columns])
})

test_that("Report_KRI renders without an action-weighted score (#280)", {
  skip_if_not(rmarkdown::pandoc_available())

  metric_ids <- c("Analysis_kri0001", "Analysis_kri0002", "Analysis_srs0001")
  results <- gsm.core::reportingResults %>%
    dplyr::filter(.data$MetricID %in% metric_ids)
  metrics <- gsm.core::reportingMetrics %>%
    dplyr::filter(.data$MetricID %in% metric_ids)
  bounds <- gsm.core::reportingBounds %>%
    dplyr::filter(.data$MetricID %in% metric_ids)
  # Site risk scores have no thresholds to chart.
  kri_ids <- setdiff(metric_ids, "Analysis_srs0001")
  charts <- MakeCharts(
    dfResults = results %>% dplyr::filter(.data$MetricID %in% kri_ids),
    dfGroups = gsm.core::reportingGroups,
    dfMetrics = metrics %>% dplyr::filter(.data$MetricID %in% kri_ids),
    dfBounds = bounds
  )
  detail <- data.frame(
    GroupID = unique(results$GroupID)[1],
    MetricID = "Analysis_kri0001",
    Weight = 4,
    EffectiveWeight = 0,
    ActionState = "No Action"
  )

  output_dir <- withr::local_tempdir()
  for (report_detail in list(NULL, detail)) {
    output_file <- Report_KRI(
      lCharts = charts,
      dfResults = results,
      dfMetrics = metrics,
      dfGroups = gsm.core::reportingGroups,
      strOutputDir = output_dir,
      strOutputFile = "no_srs0002.html",
      dfRiskScoreDetail = report_detail
    )
    html <- paste(readLines(file.path(output_dir, "no_srs0002.html"), warn = FALSE), collapse = "\n")
    expect_true(grepl("Widget_GroupOverview", html, fixed = TRUE))
    # Detail for a score that is not displayed never reaches the widget.
    expect_false(grepl("No Action", html, fixed = TRUE))
  }
})
