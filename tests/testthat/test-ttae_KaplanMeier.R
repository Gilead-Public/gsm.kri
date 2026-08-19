test_that("ttae_KaplanMeier reproduces the product-limit estimate", {
  dfInput <- data.frame(
    Numerator = c(1, 1, 0, 1, 0),
    Denominator = c(5, 10, 12, 20, 30)
  )

  out <- ttae_KaplanMeier(dfInput)

  expect_equal(out$Time[1], 0)
  expect_equal(out$Survival[1], 1)
  # 4/5, then 3/4 of that, then 1/2 of that
  expect_equal(out$Survival[2:4], c(0.8, 0.6, 0.3))
  # subject censored at 12 is still at risk at 10 but not at 20
  expect_equal(out$NRisk[2:4], c(5, 4, 2))
})

test_that("ttae_KaplanMeier agrees with survival::survfit", {
  skip_if_not_installed("survival")

  dfInput <- data.frame(
    Numerator = c(1, 0, 1, 1, 0, 1, 1, 0),
    Denominator = c(3, 3, 7, 7, 9, 14, 22, 30)
  )

  ours <- ttae_KaplanMeier(dfInput)
  fit <- survival::survfit(
    survival::Surv(Denominator, Numerator) ~ 1,
    data = dfInput
  )

  # survfit reports a row at every observed time; compare on the event times
  dfRef <- data.frame(Time = fit$time, Survival = fit$surv) %>%
    dplyr::filter(.data$Time %in% ours$Time)

  expect_equal(
    ours$Survival[match(dfRef$Time, ours$Time)],
    dfRef$Survival,
    tolerance = 1e-9
  )
})

test_that("ttae_KaplanMeier carries a zero-event cohort out to last follow-up", {
  out <- ttae_KaplanMeier(data.frame(
    Numerator = c(0, 0),
    Denominator = c(3, 40)
  ))

  # two points, so the curve actually draws instead of collapsing to a dot
  expect_equal(nrow(out), 2)
  expect_equal(out$Time, c(0, 40))
  expect_equal(out$Survival, c(1, 1))
})

test_that("ttae_KaplanMeier extends past the last event to last follow-up", {
  out <- ttae_KaplanMeier(data.frame(
    Numerator = c(1, 0),
    Denominator = c(5, 50)
  ))

  expect_equal(out$Time, c(0, 5, 50))
  expect_equal(out$Survival, c(1, 0.5, 0.5))
})

test_that("ttae_KaplanMeier handles an empty cohort", {
  out <- ttae_KaplanMeier(data.frame(
    Numerator = numeric(0),
    Denominator = numeric(0)
  ))

  expect_equal(nrow(out), 1)
  expect_equal(out$Survival, 1)
})

test_that("ttae_KaplanMeier rejects malformed input", {
  expect_error(ttae_KaplanMeier("not a data frame"), "data.frame")
  expect_error(
    ttae_KaplanMeier(data.frame(Numerator = 1)),
    "Numerator and Denominator"
  )
})

test_that("ttae_MedianTime returns the first time survival reaches 0.5", {
  dfInput <- data.frame(
    Numerator = c(1, 1, 0, 1, 0),
    Denominator = c(5, 10, 12, 20, 30)
  )

  expect_equal(ttae_MedianTime(ttae_KaplanMeier(dfInput)), 20)
})

test_that("ttae_MedianTime is NA when the median is not reached", {
  # only 1 of 4 subjects has an event, so survival never drops to 0.5
  dfInput <- data.frame(
    Numerator = c(1, 0, 0, 0),
    Denominator = c(5, 30, 30, 30)
  )

  expect_true(is.na(ttae_MedianTime(ttae_KaplanMeier(dfInput))))
})

test_that("ttae_MedianTime rejects malformed input", {
  expect_error(ttae_MedianTime(data.frame(Time = 1)), "Survival")
})
