## Test Setup
kri_workflows <- workr::MakeWorkflowList(
  c("kri0016", "kri0017"),
  GetDefaultKRIPath()
)

outputs <- map(kri_workflows, ~ map_vec(.x$steps, ~ .x$output))

# Grades counted in each metric's numerator, per the metric specification.
numerator_grades <- list(kri0016 = 3:5, kri0017 = 1L)

## Test Code
testthat::test_that("Qual: Given appropriate raw participant-level data, AE Severity Grading Assessments can be done using the Normal Approximation method (#317)", {
  TestAtLogLevel("WARN")
  test <- map(kri_workflows, ~ robust_runworkflow(.x, mapped_data)) %>%
    suppressWarnings()

  # verify outputs names exported
  iwalk(test, ~ expect_true(all(outputs[[.y]] %in% names(.x))))

  # verify output data expected as data.frames are in fact data.frames
  expect_true(
    all(
      imap_lgl(test, function(kri, kri_name) {
        all(map_lgl(
          kri[outputs[[kri_name]][str_detect(
            outputs[[kri_name]],
            pattern = "Analysis_"
          )]],
          is.data.frame
        ))
      })
    )
  )

  # verify two-sided thresholds and matching flag/weight vectors were parsed
  walk(test, function(kri) {
    expect_equal(kri$vThreshold, c(-3, -2, 2, 3))
    expect_equal(kri$vFlag, c(-2, -1, 0, 1, 2))
    expect_equal(kri$vRiskScoreWeight, c(8, 4, 0, 4, 8))
  })
})

# Double programming: numerator, denominator, adjusted z-score and flag are all
# re-derived from the mapped AE and subject data without using the workflow.
testthat::test_that("Qual: kri0016/kri0017 site results match an independent derivation from mapped AE data (#317)", {
  TestAtLogLevel("WARN")
  test <- map(kri_workflows, ~ robust_runworkflow(.x, mapped_data)) %>%
    suppressWarnings()

  dfGraded <- mapped_data$Mapped_AE %>%
    mutate(Grade = suppressWarnings(as.integer(as.character(aetoxgr)))) %>%
    filter(Grade %in% 1:5) %>%
    inner_join(
      mapped_data$Mapped_SUBJ %>% select(subjid, GroupID = invid),
      by = "subjid"
    )

  iwalk(test, function(kri, kri_name) {
    # From the specification, not the workflow meta, so a changed threshold fails.
    nAccrual <- 20

    expected <- dfGraded %>%
      group_by(GroupID) %>%
      summarise(
        Numerator = sum(Grade %in% numerator_grades[[kri_name]]),
        Denominator = n(),
        .groups = "drop"
      ) %>%
      mutate(Metric = Numerator / Denominator) %>%
      qualification_analyze_normalapprox(strType = "binary") %>%
      mutate(
        # |z| at or beyond a threshold flags, in both directions; sites below
        # the accrual threshold are scored for the dispersion factor but not
        # flagged.
        ExpectedFlag = case_when(
          Denominator < nAccrual ~ NA_real_,
          Score <= -3 ~ -2,
          Score <= -2 ~ -1,
          Score >= 3 ~ 2,
          Score >= 2 ~ 1,
          TRUE ~ 0
        ),
        ExpectedScore = ifelse(Denominator < nAccrual, NA_real_, Score)
      )

    actual <- kri$Analysis_Flagged %>%
      select(GroupID, Numerator, Denominator, Score, Flag)
    compare <- inner_join(expected, actual, by = "GroupID", suffix = c("", "_wf"))

    expect_setequal(actual$GroupID, expected$GroupID)
    expect_equal(compare$Numerator_wf, compare$Numerator)
    expect_equal(compare$Denominator_wf, compare$Denominator)
    expect_equal(compare$Score_wf, compare$ExpectedScore, tolerance = 1e-8)
    expect_identical(as.numeric(compare$Flag), compare$ExpectedFlag)

    # A comparison with no flagged or no accrual-suppressed sites would not
    # exercise the thresholds.
    expect_true(any(compare$ExpectedFlag != 0, na.rm = TRUE))
    expect_true(any(is.na(compare$ExpectedFlag)))
  })
})
