## Test Setup
kri_workflows <- workr::MakeWorkflowList(
  c(sprintf("kri%04d", 8:9), sprintf("cou%04d", 8:9)),
  GetDefaultKRIPath()
)
kri_custom <- workr::MakeWorkflowList(
  c(sprintf("kri%04d_custom", 8:9), sprintf("cou%04d_custom", 8:9)),
  GetYamlPathCustomMetrics()
)

## Test Code
testthat::test_that("Qual: Query Rate Assessments can be done correctly using a grouping variable, such as Site, Country, or Study, when applicable (#159)", {
  TestAtLogLevel("WARN")
  ## regular -----------------------------------------
  test <- map(
    kri_workflows,
    ~ robust_runworkflow(.x, mapped_data, steps = 1:8)
  ) %>%
    suppressWarnings()
  a <- map(
    kri_workflows,
    ~ robust_runworkflow(.x, mapped_data, steps = 1:8)
  ) %>%
    capture_warnings()
  removed <- ifelse(
    length(a) == 0,
    0,
    a[1] %>%
      strsplit(., " ") %>%
      unlist() %>%
      dplyr::first() %>%
      str_extract(., "\\d+$") %>%
      as.numeric()
  )

  # grouping col in yaml file is interpreted correctly in dfInput GroupID
  iwalk(
    test,
    ~ expect_identical(
      sort(unique(.x$Analysis_Input$GroupID)),
      sort(unique(.x$Mapped_SUBJ[[
        kri_workflows[[.y]]$steps[[which(
          map_chr(kri_workflows[[.y]]$steps, ~ .x$name) ==
            "gsm.core::Input_Rate"
        )]]$params$strGroupCol
      ]])) # No guarantee the Input_Rate mapping is done step 2, need better index
    )
  )

  test_new <- test[-3]

  # data is properly transformed by correct group in dfTransformed
  expect_equal(
    n_distinct(test$cou0008$Mapped_SUBJ[[
      kri_workflows[[1]]$steps[[which(
        map_chr(kri_workflows[[1]]$steps, ~ .x$name) == "gsm.core::Input_Rate"
      )]]$params$strGroupCol
    ]]),
    nrow(test$cou0008$Analysis_Transformed)
  )
  expect_equal(
    n_distinct(test$cou0009$Mapped_SUBJ[[
      kri_workflows[[2]]$steps[[which(
        map_chr(kri_workflows[[2]]$steps, ~ .x$name) == "gsm.core::Input_Rate"
      )]]$params$strGroupCol
    ]]),
    nrow(test$cou0009$Analysis_Transformed)
  )
  expect_equal(
    n_distinct(test$kri0008$Mapped_SUBJ[[
      kri_workflows[[3]]$steps[[which(
        map_chr(kri_workflows[[3]]$steps, ~ .x$name) == "gsm.core::Input_Rate"
      )]]$params$strGroupCol
    ]]) -
      removed,
    nrow(test$kri0008$Analysis_Transformed)
  )
  expect_equal(
    n_distinct(test$kri0009$Mapped_SUBJ[[
      kri_workflows[[4]]$steps[[which(
        map_chr(kri_workflows[[4]]$steps, ~ .x$name) == "gsm.core::Input_Rate"
      )]]$params$strGroupCol
    ]]) -
      removed,
    nrow(test$kri0009$Analysis_Transformed)
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
