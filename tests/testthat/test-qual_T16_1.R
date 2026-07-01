TestAtLogLevel("WARN")
## Test Setup
kri_workflows <- workr::MakeWorkflowList(
  strNames = c(paste0("kri000", 1:9), paste0("kri00", 10:12), "srs"),
  strPath = GetDefaultKRIPath()
)
analyzed <- workr::RunWorkflows(
  kri_workflows,
  lData = c(mapped_data, list(lWorkflows = kri_workflows))
) %>%
  suppressWarnings()
# Exclude pk/pd and exclusion since thats not counting to SRS

## Test Code
testthat::test_that("Qual: Given summarized analytics data, all appropriate aspects of site risk score are available to calculate it correctly (#159)", {
  # Check all kri workflows have 1:1 mapped flags and respective weights, exclude PK-PD and SRS
  expect_equal(
    map(kri_workflows[-13], function(x) {
      length(strsplit(x$meta$Flag, ",")[[1]])
    }),
    map(kri_workflows[-13], function(x) {
      length(strsplit(x$meta$RiskScoreWeight, ",")[[1]])
    })
  )

  # Check that all Analysis_Flagged data frames contain columns for Weight and WeightMax
  expect_true(all(unlist(map(analyzed[-13], function(x) {
    all(c("Weight", "WeightMax") %in% names(x$Analysis_Flagged))
  }))))

  # Check Site Risk Score matches by hand vs using gsm.kri functions
  global_weight <- map2(
    analyzed[-13],
    names(analyzed)[-13],
    function(x, y) {
      x$Analysis_Flagged %>%
        mutate(MetricID = y)
    }
  ) %>%
    bind_rows() %>%
    filter(!is.na(.data$Weight) & !is.na(.data$WeightMax)) %>%
    summarize(
      GlobalDenominator = sum(max(WeightMax), na.rm = TRUE),
      .by = MetricID
    ) %>%
    pull(GlobalDenominator) %>%
    sum()

  SRS_by_hand <- map2(
    analyzed[-13],
    names(analyzed)[-13],
    function(x, y) {
      x$Analysis_Flagged %>%
        mutate(MetricID = y)
    }
  ) %>%
    bind_rows() %>%
    filter(!is.na(.data$Weight) & !is.na(.data$WeightMax)) %>%
    group_by(GroupID) %>%
    summarize(
      Numerator = sum(Weight, na.rm = TRUE),
      Denominator = global_weight,
      Metric = Numerator / Denominator * 100,
      Score = Metric
    ) %>%
    ungroup() %>%
    mutate(GroupLevel = "Site", MetricID = "Analysis_srs0001", Flag = NA) %>%
    select(
      GroupLevel,
      GroupID,
      MetricID,
      Numerator,
      Denominator,
      Metric,
      Score,
      Flag
    ) %>%
    arrange(GroupID)

  SRS_auto <- analyzed[[13]]$Analysis_Summary %>%
    arrange(GroupID)

  # Diagnostic output for debugging CI failures
  if(any(unique(SRS_by_hand$Denominator) != unique(SRS_auto$Denominator))) {
    cat("DIAGNOSTIC: Denominator mismatch detected\n")
    cat("SRS_by_hand denominators:", paste(unique(SRS_by_hand$Denominator), collapse=", "), "\n")
    cat("SRS_auto denominators:", paste(unique(SRS_auto$Denominator), collapse=", "), "\n")
  }

  # Use tolerance for numerical comparisons and check structure first
  expect_equal(dim(SRS_by_hand), dim(SRS_auto))
  expect_equal(names(SRS_by_hand), names(SRS_auto))
  expect_equal(SRS_by_hand, SRS_auto, tolerance = 1e-12)
})
