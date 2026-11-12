test_that("metric workflows with a Threshold attribute also have a Flag attribute (#369)", {
  strPaths <- list.files(
    system.file("workflow", "2_metrics", package = "gsm.kri"),
    pattern = "\\.ya?ml$",
    full.names = TRUE
  )
  lMeta <- purrr::map(strPaths, ~ yaml::read_yaml(.x)$meta)
  names(lMeta) <- basename(strPaths)
  lThresholded <- purrr::keep(lMeta, ~ !is.null(.x$Threshold))

  # Guards against the check passing vacuously if no workflows are found.
  expect_gt(length(lThresholded), 0)

  strMissingFlag <- names(purrr::keep(lThresholded, ~ is.null(.x$Flag)))
  expect_equal(strMissingFlag, character())
})
