test_that("status rows count every enrolled participant by status and level (#371, #180)", {
  df <- elig_ClassifyParticipants(elig_Fixture())
  study <- elig_StatusRows(df, "study")
  expect_equal(sum(study$n), 8)
  expect_equal(study$n[study$Status == ELIG_INELIGIBLE], 4)

  country <- elig_StatusRows(df, "country")
  # US has the highest Ineligible share, so it leads.
  expect_equal(country$GroupID[[1]], "US")
  site <- elig_StatusRows(df, "site")
  expect_equal(unique(site$OuterGroupID[site$GroupID == "0X003"]), "CA")
})

test_that("status bars and Show buttons have 2 statuses in basic and 3 in pilot mode (#371, #180)", {
  expect_equal(names(elig_StatusBarSpec("site")$scales$fill$colors), c(ELIG_INELIGIBLE, ELIG_NO_RISK))
  expect_length(elig_StatusBarSpec("site", bPilot = TRUE)$scales$fill$colors, 3)

  labels <- function(tag) {
    html <- as.character(tag)
    regmatches(html, gregexpr("(?<=>)(All|With any risk|With Ineligible)(?=</button>)", html, perl = TRUE))[[1]]
  }
  expect_equal(labels(elig_StatusFilter("site")), c("All", "With Ineligible"))
  expect_equal(labels(elig_StatusFilter("country", bPilot = TRUE)), c("All", "With any risk", "With Ineligible"))
})

test_that("Flag Sources count a participant under each source, stacked by overall status (#371)", {
  rows <- elig_SourceRows(elig_ClassifyParticipants(elig_Fixture()))
  expect_equal(rows$order, c("Protocol Deviation", "EDC eCRF"))
  n <- function(key) sum(rows$study$n[rows$study$key == key])
  expect_equal(n("Protocol Deviation"), 3)
  expect_equal(n("EDC eCRF"), 2)
  expect_false(ELIG_POTENTIAL %in% rows$study$Status)

  pilot <- elig_SourceRows(elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE)))
  expect_equal(pilot$order, c("Important PD", "Non-important PD", "EDC eCRF", "EDC Query", "EDC PD"))
  q <- pilot$study[pilot$study$key == "EDC Query", ]
  expect_equal(q$n[q$Status == ELIG_INELIGIBLE], 1)
  expect_equal(q$n[q$Status == ELIG_POTENTIAL], 1)
  ca <- pilot$country$CA
  expect_equal(sum(ca$n[ca$key == "EDC PD"]), 1)

  # EDC PD not delivered: no bar, rather than a misleading zero.
  noPD <- elig_SourceRows(elig_ClassifyParticipants(elig_Fixture(bPilot = TRUE, bEdcPd = FALSE)))
  expect_false("EDC PD" %in% noPD$order)
})

test_that("criteria views count EDC I/E criterion cases and keep only groups with cases (#371)", {
  df <- elig_ClassifyParticipants(elig_Fixture())
  a <- elig_CriteriaRows(df)
  expect_equal(a$order, c("incl1", "excl2"))
  expect_equal(sum(a$study$n[a$study$key == "excl2"]), 2)
  expect_equal(sum(a$country$CA$n), 0)

  b <- elig_CriteriaMapRows(df)
  expect_equal(unique(b$country$GroupID), "US")
  expect_setequal(b$site$GroupID, c("0X001", "0X002"))

  c <- elig_ConcentrationRows(df)
  excl <- c$study[c$study$criterion == "excl2", ]
  expect_equal(excl$participants, 2)
  expect_equal(excl$sites, 2)
  expect_equal(excl$top_n, 1)
  expect_equal(nrow(c$country$US), 2)
})

test_that("the data script keeps one-element vectors as JSON arrays (#371)", {
  df <- elig_ClassifyParticipants(elig_Fixture())
  html <- as.character(elig_DataScript(list(map = elig_CriteriaMapRows(df[df$subjid == "P04", ]))))
  expect_match(html, '"order":["excl2"]', fixed = TRUE)
})
