## Test Setup
kri_workflows <- workr::MakeWorkflowList(
  c(sprintf("kri%04d", 14), sprintf("cou%04d", 14)),
  GetDefaultKRIPath()
)

outputs <- map(kri_workflows, ~ map_vec(.x$steps, ~ .x$output))

## Test Code
testthat::test_that("Qual: Given appropriate raw participant-level data, an Ineligibility Assessment can be done using the Identity method (#183)", {
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

  # verify vThreshold was converted to threshold vector of length 4
  walk(
    test,
    ~ expect_true(is.vector(.x$vThreshold) & length(.x$vThreshold) == 2)
  )
})
