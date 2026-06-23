test_that("pd_SubjectFatalRelatedAE flags fatal treatment-related AEs {#248}", {
  dfAE <- tibble::tibble(
    subjid = c("A", "A", "B", "C", "D"),
    aetoxgr = c(5L, 3L, 5L, 4L, 5L),
    aerel = c("RELATED", "NOT RELATED", "NOT RELATED", "RELATED", NA)
  )
  out <- pd_SubjectFatalRelatedAE(dfAE)
  flag <- stats::setNames(out$has_fatal_related_ae, out$subjid)
  expect_true(flag[["A"]]) # grade 5 + RELATED (the grade-3 row is irrelevant)
  expect_false(flag[["B"]]) # grade 5 but NOT RELATED
  expect_false(flag[["C"]]) # RELATED but grade 4 (not fatal)
  expect_false(flag[["D"]]) # grade 5 but relatedness missing -> not qualifying
})

test_that("pd_SubjectFatalRelatedAE is case-insensitive and trims {#248}", {
  dfAE <- tibble::tibble(subjid = "A", aetoxgr = 5L, aerel = " related ")
  expect_true(pd_SubjectFatalRelatedAE(dfAE)$has_fatal_related_ae)
})

test_that("pd_SubjectFatalRelatedAE 'NOT RELATED' is never read as related {#248}", {
  dfAE <- tibble::tibble(subjid = "A", aetoxgr = 5L, aerel = "Not Related")
  expect_false(pd_SubjectFatalRelatedAE(dfAE)$has_fatal_related_ae)
})

test_that("pd_SubjectFatalRelatedAE tolerates missing columns {#248}", {
  out <- pd_SubjectFatalRelatedAE(tibble::tibble(subjid = "A"))
  expect_false(out$has_fatal_related_ae)
})

test_that("pd_SubjectFatalRelatedAE validates input {#248}", {
  expect_error(pd_SubjectFatalRelatedAE(as.list(1)), "dfAE is not a data.frame")
})
