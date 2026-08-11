test_that("exactly one vendored gsm.viz bundle ships and it is the pinned one (#264)", {
  # A gsm.viz upgrade must REPLACE the vendored bundle, not add a second copy:
  # a stray second gsm.viz-* dir would let a widget load a stale bundle. Pinning
  # the exact name also fails loudly if a future bump lands without updating the
  # vendored assets. Mirrors the JS bundle-exports Playwright check.
  #
  lib <- system.file("htmlwidgets", "lib", package = "gsm.kri")
  skip_if(!nzchar(lib), "htmlwidgets/lib not installed")
  bundles <- grep(
    "^gsm\\.viz-",
    list.dirs(lib, full.names = FALSE, recursive = FALSE),
    value = TRUE
  )
  expect_identical(bundles, "gsm.viz-2.4.1")
})
