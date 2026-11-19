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
  expect_equal(
    names(elig_StatusBarSpec("site")$scales$fill$colors),
    c(ELIG_INELIGIBLE, ELIG_NO_RISK)
  )
  expect_length(elig_StatusBarSpec("site", bPilot = TRUE)$scales$fill$colors, 3)

  labels <- function(tag) {
    html <- as.character(tag)
    regmatches(
      html,
      gregexpr(
        "(?<=>)(All|With any risk|With Ineligible)(?=</button>)",
        html,
        perl = TRUE
      )
    )[[1]]
  }
  expect_equal(labels(elig_StatusFilter("site")), c("All", "With Ineligible"))
  expect_equal(
    labels(elig_StatusFilter("country", bPilot = TRUE)),
    c("All", "With any risk", "With Ineligible")
  )
})

test_that("Flag Sources count a participant under each source, stacked by overall status (#371)", {
  rows <- elig_SourceRows(elig_ClassifyParticipants(elig_Fixture()))
  expect_equal(rows$order, c("Protocol Deviation", "EDC eCRF"))
  n <- function(key) sum(rows$study$n[rows$study$key == key])
  expect_equal(n("Protocol Deviation"), 3)
  expect_equal(n("EDC eCRF"), 2)
  expect_false(ELIG_POTENTIAL %in% rows$study$Status)

  pilot <- elig_SourceRows(elig_ClassifyParticipants(elig_Fixture(
    bPilot = TRUE
  ), strMode = "pilot"))
  expect_equal(
    pilot$order,
    c("Important PD", "Non-important PD", "EDC eCRF", "EDC Query", "EDC PD")
  )
  q <- pilot$study[pilot$study$key == "EDC Query", ]
  expect_equal(q$n[q$Status == ELIG_INELIGIBLE], 1)
  expect_equal(q$n[q$Status == ELIG_POTENTIAL], 1)
  ca <- pilot$country$CA
  expect_equal(sum(ca$n[ca$key == "EDC PD"]), 1)

  # EDC PD not delivered: no bar, rather than a misleading zero.
  noPD <- elig_SourceRows(elig_ClassifyParticipants(elig_Fixture(
    bPilot = TRUE,
    bEdcPd = FALSE
  ), strMode = "pilot"))
  expect_false("EDC PD" %in% noPD$order)

  # EDC Query not delivered: no bar, and EDC PD still yields Potentially Ineligible.
  dfNoQuery <- elig_Fixture(bPilot = TRUE)
  dfNoQuery$edc_query <- NA_character_
  noQuery <- elig_SourceRows(elig_ClassifyParticipants(dfNoQuery, strMode = "pilot"))
  expect_false("EDC Query" %in% noQuery$order)
  expect_true(ELIG_POTENTIAL %in% noQuery$study$Status)
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
})

test_that("criteria slices hold only the criteria with cases in each scope (#371)", {
  a <- elig_CriteriaRows(elig_ClassifyParticipants(elig_Fixture()))
  slices <- c(list(a$study), a$country, unlist(a$site, recursive = FALSE))
  for (s in slices) {
    expect_true(all(s$n > 0))
  }
  expect_equal(a$site$US$`0X002`$key, "excl2")
  expect_equal(nrow(a$country$CA), 0)
  # 1 of 3 enrolled at 0X001.
  expect_equal(a$site$US$`0X001`$pct, c(33.3, 33.3))
})

test_that("breakdown slices drop zero counts, so no chart shows an empty category (#371)", {
  src <- elig_SourceRows(elig_ClassifyParticipants(elig_Fixture()))
  # 0X003 has a PD but no EDC eCRF case.
  expect_equal(src$site$CA$`0X003`$key, "Protocol Deviation")
  slices <- c(list(src$study), src$country, unlist(src$site, recursive = FALSE))
  for (s in slices) {
    expect_true(all(s$n > 0))
  }
  expect_false("zero" %in% names(src))
})

test_that("every eligibility bar chart hides categories a legend click leaves empty (#371)", {
  specs <- c(
    lapply(c("study", "country", "site"), elig_StatusBarSpec),
    list(elig_TrendBarSpec(), elig_BreakdownBarSpec("incl1", "I/E criterion", ELIG_CRITERION_COLORS))
  )
  for (s in specs) {
    expect_true(isTRUE(s$theme$dynamicCategoryAxis))
  }
})

test_that("the data script keeps one-element vectors as JSON arrays (#371)", {
  df <- elig_ClassifyParticipants(elig_Fixture())
  html <- as.character(elig_DataScript(list(
    map = elig_CriteriaMapRows(df[df$subjid == "P04", ])
  )))
  expect_match(html, '"order":["excl2"]', fixed = TRUE)
})
