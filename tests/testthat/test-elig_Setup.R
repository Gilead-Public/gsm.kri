test_that("elig_Setup() defaults are the report's current settings (#390)", {
  s <- elig_Setup()
  expect_named(
    s,
    c(
      "dfSources",
      "strRateMetricID",
      "vCriterionColors",
      "strInvestigatorLevel",
      "vInvestigatorParams"
    )
  )
  expect_equal(
    s$dfSources$flag,
    c(
      "flag_pd",
      "flag_pd_important",
      "flag_pd_nonimportant",
      "flag_ecrf",
      "flag_edc_query",
      "flag_edc_pd"
    )
  )
  expect_equal(
    s$dfSources$label,
    c(
      "Protocol Deviation",
      "Important PD",
      "Non-important PD",
      "EDC eCRF",
      "EDC Query",
      "EDC PD"
    )
  )
  expect_equal(
    s$dfSources$listing_label,
    c(
      "PD",
      "Important PD",
      "Non-important PD",
      "EDC eCRF",
      "EDC Query",
      "EDC PD"
    )
  )
  expect_equal(
    s$dfSources$record_source,
    c(rep("Protocol Deviation", 3), "EDC eCRF", "EDC Query", "EDC PD")
  )
  expect_equal(s$strRateMetricID, "Analysis_qtl0001")
  expect_equal(
    s$vCriterionColors,
    c(
      Inclusion = "#3C587F",
      Exclusion = "#8FB3DE",
      "Not classified" = "#B8C4D6"
    )
  )
  expect_equal(s$strInvestigatorLevel, "Site")
  expect_equal(
    s$vInvestigatorParams,
    c("InvestigatorFirstName", "InvestigatorLastName")
  )
})

test_that("passed source rows override only their flag and columns, in default order (#390)", {
  s <- elig_Setup(
    dfSources = data.frame(
      flag = c("flag_edc_query", "flag_pd"),
      label = c("Open Query", "Deviation")
    )
  )
  expect_equal(s$dfSources$flag, elig_Setup()$dfSources$flag)
  expect_equal(s$dfSources$label[c(1, 5)], c("Deviation", "Open Query"))
  expect_equal(s$dfSources$listing_label[1], "PD")
})

test_that("passing all six source rows sets the display order (#390)", {
  d <- elig_Setup()$dfSources[6:1, ]
  expect_equal(
    elig_Setup(dfSources = d)$dfSources$flag,
    rev(elig_Setup()$dfSources$flag)
  )
})

test_that("elig_Setup() rejects invalid settings (#390)", {
  expect_error(elig_Setup(
    dfSources = data.frame(flag = "flag_new", label = "X")
  ))
  expect_error(elig_Setup(
    dfSources = data.frame(flag = c("flag_pd", "flag_pd"), label = c("A", "B"))
  ))
  expect_error(elig_Setup(
    dfSources = data.frame(flag = "flag_pd", colour = "red")
  ))
  expect_error(elig_Setup(
    dfSources = data.frame(flag = "flag_pd", label = NA_character_)
  ))
  expect_error(elig_Setup(dfSources = data.frame(flag = "flag_pd", label = "")))
  expect_error(elig_Setup(
    dfSources = data.frame(flag = "flag_pd", listing_label = "EDC PD")
  ))
  expect_error(elig_Setup(
    dfSources = data.frame(flag = "flag_ecrf", listing_label = "Site")
  ))
  expect_error(elig_Setup(
    dfSources = data.frame(flag = "flag_pd_important", record_source = "Other")
  ))
  expect_error(elig_Setup(
    dfSources = data.frame(flag = "flag_edc_pd", record_source = "EDC Query")
  ))
  expect_error(elig_Setup(vCriterionColors = c(Other = "#000000")))
  expect_error(elig_Setup(strRateMetricID = c("a", "b")))
  expect_error(elig_Setup(strInvestigatorLevel = NA_character_))
  expect_error(elig_Setup(vInvestigatorParams = character()))
})

test_that("criterion colours override by name and keep stack order (#390)", {
  expect_equal(
    elig_Setup(vCriterionColors = c(Exclusion = "#000000"))$vCriterionColors,
    c(
      Inclusion = "#3C587F",
      Exclusion = "#000000",
      "Not classified" = "#B8C4D6"
    )
  )
})

test_that("record sources take the label of their non-split flag (#390)", {
  s <- elig_Setup(
    dfSources = data.frame(
      flag = c("flag_pd", "flag_pd_important"),
      label = c("Deviation", "Major PD")
    )
  )
  expect_equal(
    elig_RecordLabel(c("Protocol Deviation", "EDC eCRF", "Other"), s),
    c("Deviation", "EDC eCRF", "Other")
  )
  expect_equal(
    elig_FlagLabel(c("flag_pd", "flag_ecrf"), s, "listing_label"),
    c("PD", "EDC eCRF")
  )
})

test_that("the PD split follows flag_pd's record source and label in any order (#390)", {
  s <- elig_Setup(
    dfSources = data.frame(flag = "flag_pd", record_source = "PD")
  )
  expect_equal(s$dfSources$record_source[1:3], rep("PD", 3))
  expect_equal(
    elig_RecordLabel(
      "Protocol Deviation",
      elig_Setup(dfSources = elig_Setup()$dfSources[6:1, ])
    ),
    "Protocol Deviation"
  )
})

test_that("elig_Setup() accepts its own result unchanged (#390)", {
  s <- elig_Setup(
    dfSources = data.frame(flag = "flag_edc_query", label = "Open Query")
  )
  expect_identical(do.call(elig_Setup, s), s)
  expect_identical(do.call(elig_Setup, elig_Setup()), elig_Setup())
})

s390 <- elig_Setup(
  dfSources = data.frame(
    flag = c("flag_pd", "flag_edc_query"),
    label = c("Deviation", "Open Query"),
    listing_label = c("Dev", "Open Query")
  )
)

test_that("a relabelled source reaches charts, listing, records and CSV (#390)", {
  el <- elig_ClassifyParticipants(
    elig_Fixture(bPilot = TRUE, bPDSplit = FALSE),
    elig_FixtureGroups(),
    "pilot",
    s390
  )
  expect_equal(
    unname(elig_Sources(el, s390)[c("flag_pd", "flag_edc_query")]),
    c("Deviation", "Open Query")
  )
  expect_true(all(
    c("Deviation", "Open Query") %in% elig_SourceRows(el, s390)$order
  ))
  lst <- elig_ListingData(el, s390)
  expect_true(all(c("Dev", "Open Query") %in% names(lst)))
  expect_false("PD" %in% names(lst))
  recs <- elig_ParticipantRecords(el, NULL, s390)
  expect_true("Protocol Deviation" %in% recs$source)
  expect_true(
    "Deviation details" %in% names(elig_ExportData(lst, recs, FALSE, s390))
  )
  html <- as.character(elig_ParticipantDetail("P02", recs, s390))
  expect_match(html, "Deviation \\(2\\)")
  expect_true("Deviation" %in% elig_LogicTable(TRUE, s390)$`_data`$Source)
})

test_that("the PD record table keeps flag_pd's label when only a split flag is relabelled (#390)", {
  s <- elig_Setup(
    dfSources = data.frame(flag = "flag_pd_important", label = "Major PD")
  )
  expect_equal(elig_RecordLabel("Protocol Deviation", s), "Protocol Deviation")
  el <- elig_ClassifyParticipants(
    elig_Fixture(bPilot = TRUE),
    elig_FixtureGroups(),
    "pilot",
    s
  )
  expect_true(
    "Protocol Deviation details" %in%
      names(elig_ExportData(
        elig_ListingData(el, s),
        elig_ParticipantRecords(el, NULL, s),
        FALSE,
        s
      ))
  )
})

test_that("record sources outside the table still show, after the table's (#390)", {
  expect_equal(
    elig_RecordSourceOrder(c("Zeta", "EDC PD", "Alpha", "Protocol Deviation")),
    c("Protocol Deviation", "EDC PD", "Alpha", "Zeta")
  )
})

test_that("a full source table reorders the listing columns (#390)", {
  s <- elig_Setup(dfSources = elig_Setup()$dfSources[6:1, ])
  el <- elig_ClassifyParticipants(
    elig_Fixture(bPilot = TRUE, bPDSplit = FALSE),
    elig_FixtureGroups(),
    "pilot",
    s
  )
  expect_equal(
    intersect(
      names(elig_ListingData(el, s)),
      c("PD", "EDC eCRF", "EDC Query", "EDC PD")
    ),
    c("EDC PD", "EDC Query", "EDC eCRF", "PD")
  )
})

test_that("elig_RecordLabel always returns character (#390)", {
  expect_identical(elig_RecordLabel(character()), character())
})

test_that("the rate metric comes from the setup (#390)", {
  df <- data.frame(MetricID = c("Analysis_qtl0001", "Analysis_qtl0002"))
  expect_equal(elig_RateMetricID(df, elig_Setup(strRateMetricID = "Analysis_qtl0002")), "Analysis_qtl0002")
  expect_equal(elig_RateMetricID(df, elig_Setup(strRateMetricID = "Analysis_other")), "Analysis_qtl0001")
})

test_that("criterion colours come from the setup (#390)", {
  expect_equal(elig_CriterionColors(elig_Setup(vCriterionColors = c(Inclusion = "#000000")))[["Inclusion"]], "#000000")
})

test_that("the investigator name uses the setup's group level and params (#390)", {
  g <- elig_FixtureGroups()
  s <- elig_Setup(vInvestigatorParams = c("InvestigatorLastName", "InvestigatorFirstName"))
  expect_equal(elig_Investigator("0X001", g, s), "Lovelace Ada")
  g$GroupLevel[g$GroupLevel == "Site"] <- "Investigator"
  expect_equal(elig_Investigator("0X001", g, elig_Setup(strInvestigatorLevel = "Investigator")), "Ada Lovelace")
  el <- elig_ClassifyParticipants(elig_Fixture(), elig_FixtureGroups(), "basic", s)
  expect_equal(el$investigator[el$subjid == "P01"], "Lovelace Ada")
})
