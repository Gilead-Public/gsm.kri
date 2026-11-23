test_that("Analyze_PercentileRank scores the spec's 20-site example (#378)", {
  df <- data.frame(GroupID = sprintf("S%02d", 1:20), Numerator = 20:1)
  out <- Analyze_PercentileRank(df)
  out <- out[order(out$GroupID), ]

  expect_equal(out$Score, 100 * (20 - 1:20) / 20)
  expect_equal(out$Score[1:5], c(95, 90, 85, 80, 75))
})

test_that("tied groups share the better rank (#378)", {
  # S02 and S03 tie at rank 2 of 10: both score 80, the next group scores 60.
  df <- data.frame(
    GroupID = sprintf("S%02d", 1:10),
    Numerator = c(50, 40, 40, 30, 20, 10, 9, 8, 7, 6)
  )
  out <- Analyze_PercentileRank(df)
  out <- out[order(out$GroupID), ]

  expect_equal(out$Score[1:4], c(90, 80, 80, 60))
})

test_that("small studies cannot reach the top bands (#378)", {
  five <- Analyze_PercentileRank(data.frame(GroupID = 1:5, Numerator = 5:1))
  expect_equal(max(five$Score), 80)

  four <- Analyze_PercentileRank(data.frame(GroupID = 1:4, Numerator = 4:1))
  expect_equal(max(four$Score), 75)
})

test_that("missing values are not ranked and score NA (#378)", {
  out <- Analyze_PercentileRank(
    data.frame(GroupID = c("A", "B", "C"), Numerator = c(10, NA, 5))
  )
  out <- out[order(out$GroupID), ]
  expect_equal(out$Score, c(50, NA, 0))
})

test_that("Analyze_PercentileRank ranks on strValueCol and handles empty input (#378)", {
  df <- data.frame(GroupID = c("A", "B"), Numerator = c(1, 2), Metric = c(9, 1))
  out <- Analyze_PercentileRank(df, strValueCol = "Metric")
  expect_equal(out$Score[out$GroupID == "A"], 50)

  empty <- Analyze_PercentileRank(df[0, ])
  expect_equal(nrow(empty), 0)
  expect_true("Score" %in% names(empty))

  expect_error(Analyze_PercentileRank(df, "missing"), "strValueCol")
  expect_error(Analyze_PercentileRank(list()), "data.frame")
})
