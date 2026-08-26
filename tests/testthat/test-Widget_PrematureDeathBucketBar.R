make_bucket_inputs <- function(
  strGroupCol = "invid",
  strOuterCol = "country",
  level = "site"
) {
  dfC <- tibble::tibble(
    subjid = c("A", "B", "C", "D", "E"),
    studyid = "ST01",
    country = c("USA", "USA", "CAN", "CAN", "USA"),
    invid = c("S1", "S1", "S2", "S2", "S1"),
    Category = factor(pd_CategoryLevels(90), levels = pd_CategoryLevels(90)),
    death_dy = c(20, 70, NA, NA, NA)
  )
  list(
    data = pd_BucketRows(dfC, 90, strGroupCol, strOuterCol),
    spec = pd_BucketBarSpec(90, "Site"),
    metadata = list(chartId = "pd-site-buckets", level = level)
  )
}

test_that("Widget_PrematureDeathBucketBar returns a gsm.kri htmlwidget (#264)", {
  i <- make_bucket_inputs()
  w <- Widget_PrematureDeathBucketBar(i$data, i$spec, i$metadata)
  expect_s3_class(w, c("Widget_PrematureDeathBucketBar", "htmlwidget"))
})

test_that("Widget_PrematureDeathBucketBar serializes data/spec/metadata payloads (#264)", {
  i <- make_bucket_inputs()
  w <- Widget_PrematureDeathBucketBar(i$data, i$spec, i$metadata)
  # createWidget wraps each input as a JSON string on w$x
  data_back <- jsonlite::fromJSON(w$x$data)
  spec_back <- jsonlite::fromJSON(w$x$spec, simplifyVector = FALSE)
  meta_back <- jsonlite::fromJSON(w$x$metadata, simplifyVector = FALSE)
  expect_true(all(
    c("GroupID", "Category", "n", "pct", "Level") %in% names(data_back)
  ))
  expect_equal(spec_back$orientation, "vertical")
  expect_equal(spec_back$mapping$y, "n")
  expect_equal(meta_back$chartId, "pd-site-buckets")
})

test_that("Widget_PrematureDeathBucketBar validates inputs (#264)", {
  i <- make_bucket_inputs()
  expect_error(
    Widget_PrematureDeathBucketBar(as.list(i$data), i$spec),
    "data is not a data.frame"
  )
  expect_error(
    Widget_PrematureDeathBucketBar(i$data, i$data),
    "spec must be a list"
  )
  expect_error(
    Widget_PrematureDeathBucketBar(i$data, i$spec, bDebug = 1),
    "bDebug must be logical"
  )
})

test_that("Widget_PrematureDeathBucketBar wires the pinned gsm.viz dependency (#264) (#291)", {
  i <- make_bucket_inputs()
  w <- Widget_PrematureDeathBucketBar(i$data, i$spec, i$metadata)
  gv <- Filter(function(d) identical(d$name, "gsmViz"), w$dependencies)[[1]]
  # Release-mode pin: the dependency version and directory both track gsm.viz
  # 2.4.1. The bundle is served from gsm.vizr, so assert it resolves there -
  # a path back inside gsm.kri would mean the vendored copy had returned.
  expect_equal(as.character(gv$version), "2.4.1")
  expect_match(gv$src$file, "gsm\\.viz-2\\.4\\.1$")
  expect_true(startsWith(gv$src$file, system.file(package = "gsm.vizr")))
})
