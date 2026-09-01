# TestAtLogLevel("WARN")
## Test Setup
kri_workflows <- workr::MakeWorkflowList(
  sprintf("kri%04d", 15),
  GetDefaultKRIPath()
)

outputs <- map(kri_workflows, ~ map_vec(.x$steps, ~ .x$output))

## Test Code
testthat::test_that("Qual: Given appropriate raw participant-level data, Deaths in First 90 Days assessment can be done using the Identity method (#193)", {
  TestAtLogLevel("WARN")
  # default ---------------------------------
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

  # verify vThreshold was converted to threshold vector of length 2
  walk(
    test,
    ~ expect_true(is.vector(.x$vThreshold) & length(.x$vThreshold) == 2)
  )

  # verify vRiskScoreWeight was converted to weight vector of length 3
  walk(
    test,
    ~ expect_true(is.vector(.x$vRiskScoreWeight) & length(.x$vRiskScoreWeight) == 3)
  )

  # verify vFlag was converted to flag vector of length 3
  walk(
    test,
    ~ expect_true(is.vector(.x$vFlag) & length(.x$vFlag) == 3)
  )

  # verify Analysis_Flagged contains required flag columns
  walk(
    test,
    ~ expect_true(all(c("Flag", "Weight", "WeightMax") %in% names(.x$Analysis_Flagged)))
  )

})
