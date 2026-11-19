testthat::test_that("Widget_CrossStudyRiskScore creates an htmlwidget (#71)", {
  dfResults <- data.frame(
    MetricID = "Analysis_srs0001",
    Value = 0.75
  )

  dfMetrics <- data.frame(
    MetricID = "Analysis_srs0001",
    Metric = "Risk Score",
    Flag = "0,1,2",
    RiskScoreWeight = "0,1,2"
  )

  dfGroups <- data.frame(
    GroupID = "SiteA",
    Site = "SiteA"
  )

  mock_summary <- data.frame(
    GroupID = "SiteA",
    RiskScore = 0.75
  )

  testthat::local_mocked_bindings(
    SummarizeCrossStudy = function(
        dfResults,
        strGroupLevel,
        dfGroups,
        strRiskScoreMetric) {
      mock_summary
    }
  )

  widget <- Widget_CrossStudyRiskScore(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    strGroupLevel = "Site"
  )

  expect_s3_class(widget, "htmlwidget")
  expect_match(widget$x$strWeightingSummary, "Site Risk Score Overview")
})

testthat::test_that("Widget_CrossStudyRiskScore errors if Analysis_srs0001 is missing (#71)", {
  dfResults <- data.frame(
    MetricID = "OtherMetric",
    Value = 1
  )

  dfMetrics <- data.frame(
    MetricID = "OtherMetric",
    Metric = "Other",
    Flag = "0,1,2",
    RiskScoreWeight = "0,1,2"
  )

  dfGroups <- data.frame(
    GroupID = "SiteA",
    Site = "SiteA"
  )

  expect_error(
    Widget_CrossStudyRiskScore(
      dfResults = dfResults,
      dfMetrics = dfMetrics,
      dfGroups = dfGroups
    ),
    "Analysis_srs0001"
  )
})

testthat::test_that("Widget_CrossStudyRiskScore accepts metadata without weights", {
  dfResults <- data.frame(
    MetricID = "Analysis_srs0001",
    Value = 0.75
  )
  dfMetrics <- data.frame(
    MetricID = "Analysis_srs0001",
    MetricName = "Risk Score"
  )
  dfGroups <- data.frame(
    GroupID = "SiteA",
    Site = "SiteA"
  )

  testthat::local_mocked_bindings(
    SummarizeCrossStudy = function(
        dfResults,
        strGroupLevel,
        dfGroups,
        strRiskScoreMetric) {
      data.frame(GroupID = "SiteA", RiskScore = 0.75)
    }
  )

  widget <- Widget_CrossStudyRiskScore(dfResults, dfMetrics, dfGroups)

  expect_s3_class(widget, "htmlwidget")
  expect_identical(as.character(widget$x$strWeightingSummary), "null")
})

testthat::test_that("Widget_CrossStudyRiskScore supports an explicit SRS metric (#280)", {
  dfResults <- data.frame(
    MetricID = "Analysis_srs0002",
    Value = 0.5
  )
  dfMetrics <- data.frame(
    MetricID = "Analysis_srs0002",
    MetricName = "Action-weighted Risk Score"
  )
  dfGroups <- data.frame(GroupID = "SiteA", Site = "SiteA")
  captured_metric <- NULL

  testthat::local_mocked_bindings(
    SummarizeCrossStudy = function(
        dfResults,
        strGroupLevel,
        dfGroups,
        strRiskScoreMetric) {
      captured_metric <<- strRiskScoreMetric
      data.frame(GroupID = "SiteA", RiskScore = 0.5)
    }
  )
  widget <- Widget_CrossStudyRiskScore(
    dfResults,
    dfMetrics,
    dfGroups,
    strRiskScoreMetric = "Analysis_srs0002"
  )

  expect_equal(captured_metric, "Analysis_srs0002")
  expect_equal(
    jsonlite::fromJSON(widget$x$strSiteRiskMetric),
    "Analysis_srs0002"
  )
})

test_that("Cross-study widget JavaScript uses the configured SRS metric (#280)", {
  js <- readLines(system.file(
    "htmlwidgets",
    "lib",
    "renderCrossStudyRiskScoreTable.js",
    package = "gsm.kri"
  ))

  expect_true(any(grepl("input.strSiteRiskMetric", js, fixed = TRUE)))
  expect_false(any(grepl(
    "MetricID === 'Analysis_srs0001'",
    js,
    fixed = TRUE
  )))
})

testthat::test_that("Widget_CrossStudyRiskScore validates inputs (#71)", {
  dfResults <- data.frame(
    MetricID = "Analysis_srs0001",
    Value = 0.5
  )

  dfMetrics <- data.frame(
    MetricID = "Analysis_srs0001",
    Metric = "Risk Score",
    Flag = "0,1,2",
    RiskScoreWeight = "0,1,2"
  )

  dfGroups <- data.frame(
    GroupID = "SiteA",
    Site = "SiteA"
  )

  expect_error(
    Widget_CrossStudyRiskScore(
      dfResults = "not a data frame",
      dfMetrics = dfMetrics,
      dfGroups = dfGroups
    ),
    class = "simpleError"
  )

  expect_error(
    Widget_CrossStudyRiskScore(
      dfResults = dfResults,
      dfMetrics = "not a data frame",
      dfGroups = dfGroups
    ),
    class = "simpleError"
  )

  expect_error(
    Widget_CrossStudyRiskScore(
      dfResults = dfResults,
      dfMetrics = dfMetrics,
      dfGroups = "not a data frame"
    ),
    class = "simpleError"
  )
})

test_that("Cross-study SRS report widget allows filtering on multiple studies (#171)", {
  skip_if_not_installed("qcthat")
  # gh shows a pagination progress bar while qcthat looks up the issue.
  withr::local_options(
    cli.progress_show_after = Inf,
    cli.progress_handlers = character()
  )
  qcthat::ExpectUserAccepts(
    "Can filter cross-study SRS report on multiple studies.",
    intIssue = 171,
    chrInstructions = paste(
      "1. Navigate to the [Cross-Study SRS Report example](https://gilead-public.github.io/gsm.kri/dev/examples/Example_CrossStudySRS.html).",
      "2. Use the 'Filter by Study' option, following the instructions on the page.",
      sep = "\n"
    ),
    chrChecks = c(
      "The instructions for filtering by multiple studies make sense.",
      "The filters work as expected."
    )
  )
})

local_cross_study_summary <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    SummarizeCrossStudy = function(dfResults, strGroupLevel, dfGroups, strRiskScoreMetric) {
      data.frame(GroupID = "SiteA", AvgRiskScore = 50, MaxRiskScore = 50)
    },
    .env = env
  )
}

make_cross_study_detail <- function() {
  data.frame(
    StudyID = "S1", GroupID = "SiteA", MetricID = "Analysis_kri0001",
    ActionState = "Closed Action", LastActionedDate = as.Date("2025-05-01"),
    DaysSinceAction = 31L, ActionWindowDays = 90L, Weight = 4, EffectiveWeight = 4
  )
}

test_that("Widget_CrossStudyRiskScore forwards the comparison score and action detail (#280)", {
  local_cross_study_summary()
  results <- data.frame(MetricID = c("Analysis_srs0001", "Analysis_srs0002"), Score = c(50, 25))
  widget <- Widget_CrossStudyRiskScore(
    results, data.frame(MetricID = "Analysis_srs0001"), data.frame(GroupID = "SiteA"),
    dfComparisonRiskDetail = make_cross_study_detail()
  )

  expect_equal(jsonlite::fromJSON(widget$x$strComparisonRiskMetric), "Analysis_srs0002")
  expect_equal(jsonlite::fromJSON(widget$x$strComparisonRiskLabel), "Adjusted Risk Score")
  detail <- jsonlite::fromJSON(widget$x$dfComparisonRiskDetail)
  expect_named(detail, c("StudyID", "GroupID", "MetricID", "ActionState",
    "LastActionedDate", "DaysSinceAction", "ActionWindowDays"))
  expect_equal(detail$LastActionedDate, "2025-05-01")
})

test_that("Widget_CrossStudyRiskScore omits an absent or duplicate comparison score (#280)", {
  local_cross_study_summary()
  metrics <- data.frame(MetricID = "Analysis_srs0001")
  groups <- data.frame(GroupID = "SiteA")
  absent <- Widget_CrossStudyRiskScore(
    data.frame(MetricID = "Analysis_srs0001", Score = 50), metrics, groups,
    dfComparisonRiskDetail = make_cross_study_detail()
  )
  expect_null(jsonlite::fromJSON(absent$x$strComparisonRiskMetric))
  expect_null(jsonlite::fromJSON(absent$x$dfComparisonRiskDetail))

  duplicate <- Widget_CrossStudyRiskScore(
    data.frame(MetricID = "Analysis_srs0002", Score = 25), metrics, groups,
    strRiskScoreMetric = "Analysis_srs0002"
  )
  expect_null(jsonlite::fromJSON(duplicate$x$strComparisonRiskMetric))
})

test_that("Widget_CrossStudyRiskScore requires the highlight fields in action detail (#280)", {
  local_cross_study_summary()
  results <- data.frame(MetricID = c("Analysis_srs0001", "Analysis_srs0002"), Score = c(50, 25))
  detail <- make_cross_study_detail()
  detail$DaysSinceAction <- NULL
  expect_error(
    Widget_CrossStudyRiskScore(
      results, data.frame(MetricID = "Analysis_srs0001"), data.frame(GroupID = "SiteA"),
      dfComparisonRiskDetail = detail
    ),
    "missing required columns: DaysSinceAction"
  )
})
