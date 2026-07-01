# Qualification test for gsm.kri#238.
#
# The workflow-runtime functions were re-pointed from {gsm.core} to {workr}.
# Staying functions (Input_*, Transform_*, Flag_*, Summarize, ParseThreshold)
# intentionally remain on gsm.core::, so this test only checks the extracted
# runtime surface.

test_that("workflow specs route extracted runtime functions through workr (#238)", {
  skip_if_not_installed("yaml")

  wf_dir <- system.file("workflow", package = "gsm.kri")
  skip_if(identical(wf_dir, ""), "gsm.kri not installed")

  yaml_files <- list.files(
    wf_dir,
    pattern = "\\.ya?ml$",
    recursive = TRUE,
    full.names = TRUE
  )
  skip_if(length(yaml_files) == 0, "no workflow specs found")

  step_names <- unlist(lapply(yaml_files, function(f) {
    steps <- tryCatch(yaml::read_yaml(f)$steps, error = function(e) NULL)
    if (is.null(steps)) {
      return(character(0))
    }
    vapply(
      steps,
      function(s) if (is.null(s$name)) NA_character_ else s$name,
      character(1)
    )
  }))
  step_names <- step_names[!is.na(step_names)]

  # Extracted runtime functions must resolve from {workr}, not {gsm.core}.
  extracted <- c(
    "RunQuery", "RunStep", "RunWorkflow", "RunWorkflows", "MakeWorkflowList"
  )
  pattern <- paste0("gsm\\.core::(", paste(extracted, collapse = "|"), ")")
  expect_equal(grep(pattern, step_names, value = TRUE), character(0))

  # ...and the re-point actually happened (RunQuery is the SQL/dplyr primitive).
  expect_true(any(grepl("workr::RunQuery", step_names)))
})
