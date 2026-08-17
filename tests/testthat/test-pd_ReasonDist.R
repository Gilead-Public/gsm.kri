dfDeath_full <- tibble::tibble(
  subjid = c("S1", "S2", "S3", "S4"),
  death_dy = c(20, 50, 80, 120),
  deathcls = c(
    "Adverse Event",
    "Adverse Event",
    "Disease Progression",
    "Adverse Event"
  )
)
dfDeath_degraded <- dplyr::select(dfDeath_full, subjid, death_dy)

# The reason chart is now a gsm.viz widget (#264); its reason/n/hover content is
# read back off the serialized widget data instead of a plotly build.
reason_widget_data <- function(w) jsonlite::fromJSON(w$x$data)

test_that("pd_ReasonDist returns a reason-bar htmlwidget {#264}", {
  w <- pd_ReasonDist(dfDeath_full, nWindowDays = 90)
  expect_s3_class(w, c("bars", "htmlwidget"))
})

test_that("pd_ReasonDist counts only premature deaths {#223}", {
  df <- pd_ReasonCounts(dfDeath_full, nWindowDays = 90)
  expect_equal(df$n[df$death_reason == "Adverse Event"], 2) # S1, S2 (S4 day120 excluded)
  expect_equal(df$n[df$death_reason == "Disease Progression"], 1)
})

test_that("pd_ReasonDist degrades to Unknown without deathcls {#223}", {
  df <- pd_ReasonCounts(dfDeath_degraded, nWindowDays = 90)
  expect_equal(df$death_reason, "Unknown")
  expect_equal(df$n, 3) # S1, S2, S3 within window
})

test_that("pd_ReasonDist validates inputs {#223}", {
  expect_error(
    pd_ReasonDist(as.list(dfDeath_full)),
    "dfDeath is not a data.frame"
  )
  expect_error(
    pd_ReasonDist(dfDeath_full, nWindowDays = -5),
    "nWindowDays must be a positive number"
  )
})

test_that("pd_ReasonDist carries the reason hover (with %s) through to the widget {#223}", {
  # premature (<=90): S1, S2 (Adverse Event), S3 (Disease Progression); S4 @120 excluded.
  hover <- reason_widget_data(
    pd_ReasonDist(dfDeath_full, nWindowDays = 90, nEnrolled = 10)
  )$hover
  expect_false(any(grepl("Reason:", hover, fixed = TRUE))) # reason is in the tooltip title, not the body
  expect_true(any(grepl("Subjects: 2", hover))) # Adverse Event = 2
  expect_true(any(grepl("% of enrolled: 20.0%", hover))) # 2 / 10
  expect_true(any(grepl("% of premature deaths: 66.7%", hover))) # 2 / 3
})

test_that("pd_ReasonDist omits enrolled percent when nEnrolled is NULL {#223}", {
  hover <- reason_widget_data(pd_ReasonDist(
    dfDeath_full,
    nWindowDays = 90
  ))$hover
  expect_false(any(grepl("% of enrolled", hover)))
  expect_true(any(grepl("% of premature deaths", hover)))
})

test_that("pd_ReasonByCountry groups reasons per country with an __ALL__ aggregate {#254}", {
  dfDeath <- tibble::tibble(
    subjid = c("S1", "S2", "S3", "S4"),
    death_dy = c(20, 50, 80, 120),
    deathcls = c(
      "Adverse Event",
      "Adverse Event",
      "Disease Progression",
      "Adverse Event"
    )
  )
  dfSubjects <- tibble::tibble(
    subjid = c("S1", "S2", "S3", "S4"),
    country = c("USA", "CAN", "USA", "USA")
  )
  res <- pd_ReasonByCountry(dfDeath, dfSubjects, nWindowDays = 90)
  expect_setequal(names(res), c("USA", "CAN", "__ALL__")) # S4 @120 excluded
  expect_equal(sum(res[["USA"]]$n), 2) # S1 (AE), S3 (DP)
  expect_setequal(
    res[["USA"]]$reason,
    c("Adverse Event", "Disease Progression")
  )
  expect_equal(sum(res[["__ALL__"]]$n), 3) # S1, S2, S3
  expect_equal(res[["__ALL__"]]$reason[1], "Adverse Event") # sorted desc (AE=2)
  expect_match(res[["__ALL__"]]$hover[1], "% of premature deaths")
})

test_that("pd_ReasonByCountry falls back to Unknown reason and country {#254}", {
  dfDeath <- tibble::tibble(subjid = c("S1", "S2"), death_dy = c(10, 20)) # no deathcls
  dfSubjects <- tibble::tibble(subjid = "S1", country = "USA") # S2 no country
  res <- pd_ReasonByCountry(dfDeath, dfSubjects, nWindowDays = 90)
  expect_true("Unknown" %in% names(res)) # S2 unknown country
  expect_equal(res[["__ALL__"]]$reason, "Unknown") # no deathcls
  expect_equal(sum(res[["__ALL__"]]$n), 2)
})

test_that("pd_ReasonByCountry validates dfDeath {#254}", {
  expect_error(
    pd_ReasonByCountry(
      as.list(dfDeath_full),
      tibble::tibble(subjid = "S1", country = "USA")
    ),
    "dfDeath is not a data.frame"
  )
})

test_that("pd_ReasonByCountry falls back to Unknown country when dfSubjects is NULL {#254}", {
  res <- pd_ReasonByCountry(dfDeath_full, dfSubjects = NULL, nWindowDays = 90)
  expect_setequal(names(res), c("Unknown", "__ALL__"))
  expect_equal(sum(res[["__ALL__"]]$n), 3)
})

# ---------- new {#254} tests for per-country enrolled line + pd_ReasonBar ----------

test_that("pd_ReasonByCountry per-country hover includes enrolled % when nEnrolledByCountry supplied {#254}", {
  # premature (<=90): S1 USA AE, S2 CAN AE, S3 USA DP; S4 @120 excluded
  # USA has 4 enrolled (per nEnrolledByCountry), CAN has 2.
  # USA premature: AE=1 (S1), DP=1 (S3). 1/4 = 25.0%
  # CAN premature: AE=1 (S2).             1/2 = 50.0%
  dfDeath <- tibble::tibble(
    subjid = c("S1", "S2", "S3", "S4"),
    death_dy = c(20, 50, 80, 120),
    deathcls = c(
      "Adverse Event",
      "Adverse Event",
      "Disease Progression",
      "Adverse Event"
    )
  )
  dfSubjects <- tibble::tibble(
    subjid = c("S1", "S2", "S3", "S4"),
    country = c("USA", "CAN", "USA", "USA")
  )
  enrolled_by_country <- c(USA = 4L, CAN = 2L)
  res <- pd_ReasonByCountry(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    nEnrolledByCountry = enrolled_by_country
  )

  # USA: 1 AE of 4 enrolled = 25.0%
  usa_ae_idx <- which(res[["USA"]]$reason == "Adverse Event")
  expect_true(grepl("% of enrolled: 25.0%", res[["USA"]]$hover[usa_ae_idx]))

  # CAN: 1 AE of 2 enrolled = 50.0%
  can_ae_idx <- which(res[["CAN"]]$reason == "Adverse Event")
  expect_true(grepl("% of enrolled: 50.0%", res[["CAN"]]$hover[can_ae_idx]))

  # __ALL__ without nEnrolled should NOT have enrolled line
  expect_false(any(grepl("% of enrolled", res[["__ALL__"]]$hover)))
})

test_that("pd_ReasonByCountry __ALL__ hover includes enrolled % when nEnrolled supplied {#254}", {
  # premature (<=90): S1 AE, S2 AE, S3 DP; total enrolled = 10
  # AE = 2/10 = 20.0%,  DP = 1/10 = 10.0%
  dfDeath <- tibble::tibble(
    subjid = c("S1", "S2", "S3", "S4"),
    death_dy = c(20, 50, 80, 120),
    deathcls = c(
      "Adverse Event",
      "Adverse Event",
      "Disease Progression",
      "Adverse Event"
    )
  )
  dfSubjects <- tibble::tibble(
    subjid = c("S1", "S2", "S3", "S4"),
    country = c("USA", "CAN", "USA", "USA")
  )
  res <- pd_ReasonByCountry(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    nEnrolled = 10L
  )

  all_ae_idx <- which(res[["__ALL__"]]$reason == "Adverse Event")
  expect_true(grepl("% of enrolled: 20.0%", res[["__ALL__"]]$hover[all_ae_idx]))

  all_dp_idx <- which(res[["__ALL__"]]$reason == "Disease Progression")
  expect_true(grepl("% of enrolled: 10.0%", res[["__ALL__"]]$hover[all_dp_idx]))

  # per-country slices (no nEnrolledByCountry) should NOT have enrolled line
  expect_false(any(grepl("% of enrolled", res[["USA"]]$hover)))
})

test_that("pd_ReasonBar returns a reason-bar htmlwidget carrying the slice rows {#254}", {
  dfDeath <- tibble::tibble(
    subjid = c("S1", "S2", "S3"),
    death_dy = c(20, 50, 80),
    deathcls = c("Adverse Event", "Adverse Event", "Disease Progression")
  )
  dfSubjects <- tibble::tibble(
    subjid = c("S1", "S2", "S3"),
    country = c("USA", "USA", "USA")
  )
  slice <- pd_ReasonByCountry(dfDeath, dfSubjects, nWindowDays = 90)[[
    "__ALL__"
  ]]
  w <- pd_ReasonBar(slice)
  expect_s3_class(w, c("bars", "htmlwidget"))
  data_back <- reason_widget_data(w)
  expect_setequal(data_back$n, slice$n)
  expect_setequal(data_back$hover, slice$hover)
})

test_that("pd_ReasonByCountry __ALL__ hover equals study chart hover (dedup lock) {#254}", {
  # premature (<=90): S1 AE, S2 AE, S3 DP; total enrolled = 10
  dfDeath <- tibble::tibble(
    subjid = c("S1", "S2", "S3", "S4"),
    death_dy = c(20, 50, 80, 120),
    deathcls = c(
      "Adverse Event",
      "Adverse Event",
      "Disease Progression",
      "Adverse Event"
    )
  )
  dfSubjects <- tibble::tibble(
    subjid = c("S1", "S2", "S3", "S4"),
    country = c("USA", "CAN", "USA", "USA")
  )

  # Study chart (pd_ReasonDist path) vs the country aggregate (pd_ReasonByCountry
  # __ALL__). Both flow through pd_ReasonSlice, so their hover must match.
  study_cd <- reason_widget_data(
    pd_ReasonDist(dfDeath, nWindowDays = 90, nEnrolled = 10L)
  )$hover
  res <- pd_ReasonByCountry(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    nEnrolled = 10L
  )
  all_cd <- reason_widget_data(pd_ReasonBar(res[["__ALL__"]]))$hover

  expect_equal(sort(study_cd), sort(all_cd))
})

test_that("pd_ReasonByCountry skips the enrolled line for a country absent from the lookup {#254}", {
  # S2 is absent from dfSubjects -> country NA -> coalesced "Unknown", a key the
  # named-vector lookup does not contain. `[[` would error here before the guard.
  dfDeath <- tibble::tibble(
    subjid = c("S1", "S2"),
    death_dy = c(20, 30),
    deathcls = c("Adverse Event", "Adverse Event")
  )
  dfSubjects <- tibble::tibble(subjid = "S1", country = "USA")

  res <- pd_ReasonByCountry(
    dfDeath,
    dfSubjects,
    nWindowDays = 90,
    nEnrolledByCountry = c(USA = 4L),
    nEnrolled = 8L
  )

  # No crash; present-key USA gets the enrolled line, absent-key Unknown does not,
  # and __ALL__ uses the study total.
  expect_true(any(grepl("% of enrolled", res[["USA"]]$hover)))
  expect_false(any(grepl("% of enrolled", res[["Unknown"]]$hover)))
  expect_true(any(grepl("% of enrolled", res[["__ALL__"]]$hover)))
})
