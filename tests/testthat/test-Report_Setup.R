test_that("Test with valid input and one group", {
  result <- Report_Setup(
    dfGroups = gsm.core::reportingGroups,
    dfMetrics = gsm.core::reportingMetrics,
    dfResults = gsm.core::reportingResults
  )

  expect_equal(result$GroupLevel, "Site")
  expect_equal(result$SnapshotDate, as.Date("2025-04-01"))
  expect_equal(result$StudyID, "AA-AA-000-0000")
  expect_true(is.numeric(result$red_kris))
  expect_true(is.numeric(result$amber_kris))
})

test_that("Test with missing SnapshotDate and protocol number/title", {
  reportingResults_alt <- gsm.core::reportingResults %>%
    select(-SnapshotDate)
  reportingGroups_alt <- gsm.core::reportingGroups %>%
    filter(!Param %in% c("protocol_title", "protocol_number"))

  expect_message(
    {
      today <- Sys.Date()
      result <- Report_Setup(
        reportingGroups_alt,
        gsm.core::reportingMetrics,
        reportingResults_alt
      )
    },
    "No `SnapshotDate`"
  )

  expect_equal(result$GroupLevel, "Site")
  expect_equal(result$SnapshotDate, Sys.Date())
  expect_true(is.numeric(result$red_kris))
  expect_true(is.numeric(result$amber_kris))
})

test_that("Test StudyID output with missing protocol number", {
  reportingGroups_alt <- gsm.core::reportingGroups %>%
    filter(Param != "protocol_number")

  result <- Report_Setup(
    reportingGroups_alt,
    gsm.core::reportingMetrics,
    gsm.core::reportingResults
  )

  expect_equal(result$GroupLevel, "Site")
  expect_equal(result$SnapshotDate, as.Date("2025-04-01"))
  expect_equal(result$StudyID, "AA-AA-000-0000")
  expect_true(is.numeric(result$red_kris))
  expect_true(is.numeric(result$amber_kris))
})

test_that("dfSummary empty data frame", {
  dfSummary <- tibble(Flag = integer(0))

  expect_message(
    {
      today <- Sys.Date()
      result <- Report_Setup(
        gsm.core::reportingGroups,
        gsm.core::reportingMetrics,
        dfSummary
      )
    },
    "No `SnapshotDate`"
  )

  expect_equal(result$SnapshotDate, today)
  expect_equal(result$red_kris, 0)
  expect_equal(result$amber_kris, 0)
})

test_that("Makes StudyLabel properly", {
  result <- Report_Setup(
    gsm.core::reportingGroups,
    gsm.core::reportingMetrics,
    gsm.core::reportingResults
  )
  expect_equal(
    result$StudyLabel,
    glue::glue("{result$StudyID} ({result$lStudy$nickname})")
  )

  reportingGroups_alt1 <- gsm.core::reportingGroups %>%
    filter(Param != "nickname")

  result1 <- Report_Setup(
    reportingGroups_alt1,
    gsm.core::reportingMetrics,
    gsm.core::reportingResults
  )
  expect_equal(result1$StudyLabel, result1$StudyID)

  reportingGroups_alt2 <- gsm.core::reportingGroups
  reportingGroups_alt2[reportingGroups_alt2$Param == "nickname", ]$Value <- NA

  result2 <- Report_Setup(
    reportingGroups_alt2,
    gsm.core::reportingMetrics,
    gsm.core::reportingResults
  )
  expect_equal(result2$StudyLabel, result2$StudyID)
})
