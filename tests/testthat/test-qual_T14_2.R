## Test Setup
kri_workflows <- workr::MakeWorkflowList(
  c(sprintf("kri%04d", 13), sprintf("cou%04d", 13)),
  GetDefaultKRIPath()
)
kri_custom <- workr::MakeWorkflowList(
  c(sprintf("kri%04d_custom", 13), sprintf("cou%04d_custom", 13)),
  GetYamlPathCustomMetrics()
)

## Test Code
testthat::test_that("Qual: PK Compliance Assessments can be done correctly using a grouping variable, such as Site, Country, or Study, when applicable (#159)", {
  TestAtLogLevel("WARN")
  ## regular -----------------------------------------
  expect_warning(
    test <- map(
      kri_workflows,
      ~ robust_runworkflow(.x, mapped_data, steps = 1:7)
    ),
    "value of 0 removed."
  )
  # grouping col in yaml file is interpreted correctly in dfInput GroupID
  iwalk(
    test,
    ~ expect_identical(
      sort(unique(.x$Analysis_Input$GroupID)),
      sort(unique(test$cou0013$Mapped_SUBJ[[
        kri_workflows[[.y]]$steps[[which(
          map_chr(kri_workflows[[.y]]$steps, ~ .x$name) ==
            "gsm.core::Input_Rate"
        )]]$params$strGroupCol
      ]])) # No guarantee the Input_Rate mapping is done step 2, need better index
    )
  )

  # data is properly transformed by correct group in dfTransformed
  iwalk(
    test,
    ~ expect_true(
      all(
        .x$Analysis_Transformed$GroupID %in%
          unique(.x$Mapped_SUBJ[[
            kri_workflows[[.y]]$steps[[which(
              map_chr(kri_workflows[[.y]]$steps, ~ .x$name) ==
                "gsm.core::Input_Rate"
            )]]$params$strGroupCol
          ]])
      )
    )
  )

  ## custom -------------------------------------------
  test_custom <- map(
    kri_custom,
    ~ robust_runworkflow(.x, mapped_data, steps = 1:5)
  )

  # grouping col in custom yaml file is interpreted correctly in dfInput GroupID
  iwalk(
    test_custom,
    ~ expect_identical(
      sort(unique(.x$Analysis_Input$GroupID)),
      sort(unique(.x$Mapped_SUBJ[[tolower(kri_custom[[.y]]$meta$GroupLevel)]]))
    )
  )

  # data is properly transformed by correct group in dfTransformed
  iwalk(
    test_custom,
    ~ expect_equal(
      n_distinct(.x$Mapped_SUBJ[[tolower(kri_custom[[.y]]$meta$GroupLevel)]]),
      nrow(.x$Analysis_Transformed)
    )
  )
})
