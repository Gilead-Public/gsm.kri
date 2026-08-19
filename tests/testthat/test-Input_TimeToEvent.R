make_ttae_subjects <- function() {
  tibble::tibble(
    subjid = c("A", "B", "C", "D"),
    invid = c("S1", "S1", "S2", "S2"),
    country = c("USA", "USA", "CAN", "CAN"),
    firstparticipantdate = as.Date("2024-01-01"),
    timeonstudy = c(100L, 100L, 100L, 100L)
  )
}

test_that("Input_TimeToEvent times the first event and censors the rest", {
  dfEvents <- tibble::tibble(
    subjid = c("A", "A", "C"),
    aest_dt = as.Date(c("2024-01-11", "2024-02-01", "2024-01-21"))
  )

  out <- Input_TimeToEvent(make_ttae_subjects(), dfEvents)

  expect_equal(
    names(out),
    c(
      "SubjectID",
      "GroupID",
      "GroupLevel",
      "Numerator",
      "Denominator",
      "Metric"
    )
  )
  expect_equal(nrow(out), 4) # every enrolled subject contributes a row
  expect_equal(out$Numerator, c(1, 0, 1, 0))
  # A's earliest event wins (day 10, not day 31); B and D are censored at 100
  expect_equal(out$Denominator, c(10, 100, 20, 100))
})

test_that("Input_TimeToEvent drops pre-reference events but keeps the subject at risk", {
  dfEvents <- tibble::tibble(
    subjid = c("A", "A", "B"),
    aest_dt = as.Date(c("2023-12-01", "2024-01-21", "2023-11-01"))
  )

  out <- Input_TimeToEvent(make_ttae_subjects(), dfEvents)

  # A's pre-enrollment AE is ignored, so its day-20 AE is the event
  expect_equal(out$Numerator[out$SubjectID == "A"], 1)
  expect_equal(out$Denominator[out$SubjectID == "A"], 20)
  # B's only AE precedes enrollment, so B is censored rather than dropped
  expect_equal(out$Numerator[out$SubjectID == "B"], 0)
  expect_equal(out$Denominator[out$SubjectID == "B"], 100)
})

test_that("bIncludePreReferenceEvents clamps pre-reference events to day 0", {
  dfEvents <- tibble::tibble(subjid = "B", aest_dt = as.Date("2023-11-01"))

  out <- Input_TimeToEvent(
    make_ttae_subjects(),
    dfEvents,
    bIncludePreReferenceEvents = TRUE
  )

  expect_equal(out$Numerator[out$SubjectID == "B"], 1)
  expect_equal(out$Denominator[out$SubjectID == "B"], 0)
})

test_that("Input_TimeToEvent ignores events with a missing date", {
  dfEvents <- tibble::tibble(
    subjid = c("A", "B"),
    aest_dt = as.Date(c(NA, "2024-01-11"))
  )

  out <- Input_TimeToEvent(make_ttae_subjects(), dfEvents)

  expect_equal(out$Numerator[out$SubjectID == "A"], 0)
  expect_equal(out$Denominator[out$SubjectID == "A"], 100)
  expect_equal(out$Numerator[out$SubjectID == "B"], 1)
})

test_that("Input_TimeToEvent drops subjects with no reference date", {
  dfSubjects <- make_ttae_subjects()
  dfSubjects$firstparticipantdate[[2]] <- NA

  expect_warning(
    out <- Input_TimeToEvent(dfSubjects, tibble::tibble(
      subjid = character(0),
      aest_dt = as.Date(character(0))
    )),
    "missing"
  )

  expect_equal(nrow(out), 3)
  expect_false("B" %in% out$SubjectID)
})

test_that("Input_TimeToEvent treats missing or negative follow-up as zero exposure", {
  dfSubjects <- make_ttae_subjects()
  dfSubjects$timeonstudy <- c(NA, -5L, 0L, 100L)

  out <- Input_TimeToEvent(dfSubjects, tibble::tibble(
    subjid = character(0),
    aest_dt = as.Date(character(0))
  ))

  expect_equal(out$Denominator, c(0, 0, 0, 100))
  expect_false(anyNA(out$Denominator)) # Transform_Rate rejects NA denominators
})

test_that("Input_TimeToEvent caps exposure at the follow-up duration", {
  dfSubjects <- make_ttae_subjects()
  dfSubjects$timeonstudy <- c(5L, 100L, 100L, 100L)
  # A's AE is dated day 10, past its 5 documented follow-up days
  dfEvents <- tibble::tibble(subjid = "A", aest_dt = as.Date("2024-01-11"))

  expect_warning(
    out <- Input_TimeToEvent(dfSubjects, dfEvents),
    "exposure capped"
  )

  expect_equal(out$Numerator[out$SubjectID == "A"], 1)
  expect_equal(out$Denominator[out$SubjectID == "A"], 5)
})

test_that("Input_TimeToEvent collapses same-day events into one", {
  dfEvents <- tibble::tibble(
    subjid = c("A", "A"),
    aest_dt = as.Date(c("2024-01-11", "2024-01-11"))
  )

  out <- Input_TimeToEvent(make_ttae_subjects(), dfEvents)

  expect_equal(out$Numerator[out$SubjectID == "A"], 1)
  expect_equal(nrow(out), 4)
})

test_that("Input_TimeToEvent removes subjects with a missing GroupID", {
  dfSubjects <- make_ttae_subjects()
  dfSubjects$invid[[1]] <- NA

  expect_warning(
    out <- Input_TimeToEvent(dfSubjects, tibble::tibble(
      subjid = character(0),
      aest_dt = as.Date(character(0))
    )),
    "GroupID"
  )

  expect_equal(nrow(out), 3)
  expect_false(anyNA(out$GroupID))
})

test_that("Input_TimeToEvent honours strGroupCol and strGroupLevel", {
  out <- Input_TimeToEvent(
    make_ttae_subjects(),
    tibble::tibble(subjid = "A", aest_dt = as.Date("2024-01-11")),
    strGroupCol = "country",
    strGroupLevel = "Country"
  )

  expect_setequal(out$GroupID, c("USA", "CAN"))
  expect_equal(unique(out$GroupLevel), "Country")
})

test_that("Input_TimeToEvent rejects missing columns", {
  expect_error(
    Input_TimeToEvent(
      make_ttae_subjects() %>% dplyr::select(-"timeonstudy"),
      tibble::tibble(subjid = "A", aest_dt = as.Date("2024-01-11"))
    ),
    "timeonstudy"
  )
  expect_error(
    Input_TimeToEvent(
      make_ttae_subjects(),
      tibble::tibble(subjid = "A")
    ),
    "aest_dt"
  )
})

test_that("Input_TimeToEvent output feeds Transform_Rate and Analyze_Poisson", {
  dfEvents <- tibble::tibble(
    subjid = c("A", "C"),
    aest_dt = as.Date(c("2024-01-11", "2024-01-21"))
  )

  dfTransformed <- Input_TimeToEvent(make_ttae_subjects(), dfEvents) %>%
    gsm.core::Transform_Rate()

  expect_setequal(dfTransformed$GroupID, c("S1", "S2"))
  expect_equal(dfTransformed$Numerator, c(1, 1))
  expect_equal(dfTransformed$Denominator, c(110, 120))

  dfAnalyzed <- gsm.core::Analyze_Poisson(dfTransformed)
  expect_true(all(c("Score", "PredictedCount") %in% names(dfAnalyzed)))
  expect_false(anyNA(dfAnalyzed$Score))
})
