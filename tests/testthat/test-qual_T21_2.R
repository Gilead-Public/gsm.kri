## Test Setup
kri_workflows <- workr::MakeWorkflowList(
  c("kri0016", "kri0017"),
  GetDefaultKRIPath()
)

# Runs each metric's own threshold-parsing and flagging steps against a
# hand-built Analysis_Analyzed, so scores can be placed exactly on the
# configured thresholds.
run_flag_steps <- function(lWorkflow, dfAnalyzed) {
  lData <- list(Analysis_Analyzed = dfAnalyzed)
  for (step in lWorkflow$steps) {
    if (step$name == "gsm.core::ParseThreshold") {
      lData[[step$output]] <- workr::RunStep(step, lData, lWorkflow$meta)
    }
  }
  flag_step <- Find(function(s) s$output == "Analysis_Flagged", lWorkflow$steps)
  workr::RunStep(flag_step, lData, lWorkflow$meta)
}

dfBoundary <- tibble::tribble(
  ~GroupID, ~Denominator, ~Score, ~ExpectedFlag, ~ExpectedWeight,
  "below_-3", 20, -3.5, -2, 8,
  "at_-3", 20, -3.0, -2, 8,
  "between_-3_-2", 20, -2.5, -1, 4,
  "at_-2", 20, -2.0, -1, 4,
  "inside_-2", 20, -1.99, 0, 0,
  "zero", 20, 0, 0, 0,
  "inside_2", 20, 1.99, 0, 0,
  "at_2", 20, 2.0, 1, 4,
  "between_2_3", 20, 2.5, 1, 4,
  "at_3", 20, 3.0, 2, 8,
  "above_3", 20, 3.5, 2, 8,
  # Accrual threshold is on the denominator: 19 graded AEs is not evaluable
  # however extreme the score, 20 is.
  "accrual_19_high", 19, 5, NA, NA,
  "accrual_19_low", 19, -5, NA, NA,
  "accrual_20_high", 20, 5, 2, 8
) %>%
  mutate(
    GroupLevel = "Site",
    Numerator = 1,
    Metric = Numerator / Denominator,
    OverallMetric = 0.2,
    Factor = 1
  )

## Test Code
testthat::test_that("Qual: kri0016/kri0017 flag two-sided at the -3,-2,2,3 adjusted z-score thresholds and suppress sites below 20 graded AEs (#317)", {
  TestAtLogLevel("WARN")

  iwalk(kri_workflows, function(wf, kri_name) {
    expect_equal(wf$meta$Model, "Normal Approximation")
    expect_equal(wf$meta$Score, "Adjusted Z-Score")
    expect_equal(wf$meta$AnalysisType, "binary")
    expect_equal(wf$meta$AccrualThreshold, 20)
    expect_equal(wf$meta$AccrualMetric, "Denominator")

    dfFlagged <- run_flag_steps(
      wf,
      dfBoundary %>% select(-ExpectedFlag, -ExpectedWeight)
    ) %>%
      left_join(
        dfBoundary %>% select(GroupID, ExpectedFlag, ExpectedWeight),
        by = "GroupID"
      )

    expect_equal(nrow(dfFlagged), nrow(dfBoundary))
    expect_identical(as.numeric(dfFlagged$Flag), dfFlagged$ExpectedFlag)
    expect_identical(as.numeric(dfFlagged$Weight), dfFlagged$ExpectedWeight)
    # Suppressed sites lose their score as well as their flag.
    expect_true(all(is.na(dfFlagged$Score[is.na(dfFlagged$ExpectedFlag)])))
  })
})
