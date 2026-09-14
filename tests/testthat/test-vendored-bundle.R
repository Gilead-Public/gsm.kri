test_that("gsm.kri ships no vendored gsm.viz bundle (#263, #291)", {
  # #263 pinned the vendored bundle to a single directory so a widget could
  # never load a stale second copy. #291 retired vendoring entirely -- the
  # bundle comes from gsm.vizr::html_dependency_gsm_viz() now -- so the guard
  # inverts: re-vendoring one here would shadow gsm.vizr's copy and resurrect
  # the exact bug #263 fixed.
  lib <- system.file("htmlwidgets", "lib", package = "gsm.kri")
  skip_if(!nzchar(lib), "htmlwidgets/lib not installed")
  bundles <- grep(
    "^gsm\\.viz-",
    list.dirs(lib, full.names = FALSE, recursive = FALSE),
    value = TRUE
  )
  expect_identical(bundles, character(0))
})
