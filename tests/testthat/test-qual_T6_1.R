## Test Setup
kri_workflows <- workr::MakeWorkflowList(
  c(sprintf("kri%04d", 1:2), sprintf("cou%04d", 1:2)),
  GetDefaultKRIPath()
)
kri_custom <- workr::MakeWorkflowList(
  c(sprintf("kri%04d_custom", 1:2), sprintf("cou%04d_custom", 1:2)),
  GetYamlPathCustomMetrics()
)

outputs <- map(kri_workflows, ~ map_vec(.x$steps, ~ .x$output))

## Test Code
testthat::test_that("Qual: Given appropriate raw participant-level data, an Adverse Event Assessment can be done using the Normal Approximation method (#159)
", {
  TestAtLogLevel("WARN")
  # default
  test <- map(kri_workflows, ~ robust_runworkflow(.x, mapped_data))

  expect_true(
    all(
      imap_lgl(outputs, function(names, kri) {
        all(names %in% names(test[[kri]]))
      })
    )
  )
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
  walk(test, ~ expect_true(is.vector(.x$vThreshold)))
  walk(
    test,
    ~ expect_equal(nrow(.x$Analysis_Flagged), nrow(.x$Analysis_Summary))
  )
  walk(
    test,
    ~ expect_identical(
      sort(.x$Analysis_Flagged$GroupID),
      sort(.x$Analysis_Summary$GroupID)
    )
  )

  # custom
  test_custom <- map(kri_workflows, ~ robust_runworkflow(.x, mapped_data))

  expect_true(
    all(
      imap_lgl(outputs, function(names, kri) {
        all(names %in% names(test_custom[[kri]]))
      })
    )
  )
  expect_true(
    all(
      imap_lgl(test_custom, function(kri, kri_name) {
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
  walk(test_custom, ~ expect_true(is.vector(.x$vThreshold)))
  walk(
    test_custom,
    ~ expect_equal(nrow(.x$Analysis_Flagged), nrow(.x$Analysis_Summary))
  )
  walk(
    test_custom,
    ~ expect_identical(
      sort(.x$Analysis_Flagged$GroupID),
      sort(.x$Analysis_Summary$GroupID)
    )
  )
})
