make_subjects <- function() {
  tibble::tibble(
    subjid = c("A", "B", "C", "D", "E", "F"),
    studyid = "ST01",
    country = c("USA", "USA", "CAN", "CAN", "USA", "CAN"),
    invid = c("S1", "S1", "S2", "S2", "S1", "S2"),
    # snapshot is 2026-05-01; pick rgmn so follow_up is 200,200,200,200,200,40
    rgmn_dt = as.Date(c(
      "2025-10-13",
      "2025-10-13",
      "2025-10-13",
      "2025-10-13",
      "2025-10-13",
      "2026-03-22"
    ))
  )
}

make_death <- function() {
  tibble::tibble(
    subjid = c("A", "B", "G"), # G is not enrolled -> ignored
    death_dt = as.Date(c("2025-11-02", "2025-12-22", "2025-11-02")),
    death_dy = c(20, 70, 20) # A: <=30d, B: 31-90d
  )
}

make_studcomp <- function() {
  tibble::tibble(
    subjid = c("C", "E"),
    compyn = c("N", "N"),
    compreas = c("Withdrawal", "Death"), # E's reason is Death -> NOT dark-grey
    mincreated_dts = as.Date(c("2025-12-01", "2026-04-01")) # C: ~49d -> discont
  )
}

test_that("pd_CategoryLevels labels both death buckets with 'Death within' {#246}", {
  lv <- pd_CategoryLevels(90)
  expect_equal(lv[1], "Death within 30 days")
  expect_equal(lv[2], "Death within 31–90 days")
})

test_that("pd_Classify assigns the five categories by precedence {#246}", {
  out <- pd_Classify(
    dfSubjects = make_subjects(),
    dfDeath = make_death(),
    dfStudComp = make_studcomp(),
    nWindowDays = 90,
    dSnapshotDate = as.Date("2026-05-01")
  )
  lv <- pd_CategoryLevels(90)
  cat_by <- setNames(as.character(out$Category), out$subjid)

  expect_equal(cat_by[["A"]], lv[1]) # death 20d -> Death <=30d
  expect_equal(cat_by[["B"]], lv[2]) # death 70d -> Death 31-90d
  expect_equal(cat_by[["C"]], lv[3]) # studcomp non-death ~49d -> discontinuation
  expect_equal(cat_by[["D"]], lv[4]) # alive, follow_up 200 -> Alive at 90
  expect_equal(cat_by[["E"]], lv[4]) # compreas==Death excluded from grey; alive 200 -> Alive at 90
  expect_equal(cat_by[["F"]], lv[5]) # alive, follow_up 40 -> Alive prior to 90
})

test_that("pd_Classify x_anchor anchors per category {#246}", {
  out <- pd_Classify(
    dfSubjects = make_subjects(),
    dfDeath = make_death(),
    dfStudComp = make_studcomp(),
    nWindowDays = 90,
    dSnapshotDate = as.Date("2026-05-01")
  )
  x_by <- setNames(out$x_anchor, out$subjid)
  expect_equal(x_by[["A"]], 20) # death_dy
  expect_equal(x_by[["B"]], 70) # death_dy
  expect_equal(x_by[["D"]], 90) # Alive at 90 -> window boundary
  expect_equal(x_by[["F"]], 40) # Alive prior -> follow_up
})

test_that("pd_Classify treats a death after the window as Alive at window (E1) {#246}", {
  subj <- tibble::tibble(
    subjid = "Z",
    studyid = "ST01",
    country = "USA",
    invid = "S1",
    rgmn_dt = as.Date("2025-10-13")
  )
  death <- tibble::tibble(
    subjid = "Z",
    death_dt = as.Date("2026-03-01"),
    death_dy = 139
  )
  out <- pd_Classify(
    subj,
    death,
    NULL,
    nWindowDays = 90,
    dSnapshotDate = as.Date("2026-05-01")
  )
  expect_equal(as.character(out$Category), pd_CategoryLevels(90)[4])
  expect_equal(out$x_anchor, 90)
})

test_that("pd_Classify errors without a randomization date {#246}", {
  subj <- tibble::tibble(
    subjid = "A",
    studyid = "ST01",
    country = "USA",
    invid = "S1"
  )
  expect_error(
    pd_Classify(
      subj,
      make_death(),
      NULL,
      dSnapshotDate = as.Date("2026-05-01")
    ),
    "rgmn_dt"
  )
})

test_that("pd_Classify validates its data.frame inputs {#246}", {
  expect_error(
    pd_Classify(as.list(make_subjects()), make_death()),
    "dfSubjects is not a data.frame"
  )
  expect_error(
    pd_Classify(make_subjects(), as.list(make_death())),
    "dfDeath is not a data.frame"
  )
})

test_that("pd_Classify pulls rgmn_dt from dfRand when dfSubjects lacks it {#246}", {
  subj <- make_subjects()
  subj$rgmn_dt <- NULL
  rand <- tibble::tibble(
    subjid = make_subjects()$subjid,
    rgmn_dt = make_subjects()$rgmn_dt
  )
  out <- pd_Classify(
    subj,
    make_death(),
    make_studcomp(),
    dfRand = rand,
    nWindowDays = 90,
    dSnapshotDate = as.Date("2026-05-01")
  )
  cat_by <- setNames(as.character(out$Category), out$subjid)
  expect_equal(cat_by[["A"]], pd_CategoryLevels(90)[1]) # death 20d
  expect_equal(cat_by[["F"]], pd_CategoryLevels(90)[5]) # alive prior
})

test_that("pd_Classify fills missing optional columns with NA {#246}", {
  subj <- tibble::tibble(
    subjid = c("A", "F"),
    rgmn_dt = as.Date(c("2025-10-13", "2026-03-22"))
  )
  out <- pd_Classify(
    subj,
    make_death(),
    NULL,
    nWindowDays = 90,
    dSnapshotDate = as.Date("2026-05-01")
  )
  expect_true(all(is.na(out$studyid)))
  expect_true(all(is.na(out$country)))
  expect_true(all(is.na(out$invid)))
})

test_that("pd_DisplayOrder stacks best-outcome first and is a permutation of the levels {#253}", {
  lv <- pd_CategoryLevels(90)
  ord <- pd_DisplayOrder(90)
  expect_equal(ord, lv[c(4, 5, 3, 2, 1)])
  expect_setequal(ord, lv) # same set, just reordered
  expect_equal(ord[1], lv[4]) # "Alive at 90 days" at the base
  expect_equal(ord[5], lv[1]) # "Death within 30 days" on top
})

test_that("pd_DisplayOrder tracks a non-default window {#253}", {
  expect_setequal(pd_DisplayOrder(60), pd_CategoryLevels(60))
})

test_that("pd_CategoryLevels relabels the alive-prior category to 'not yet ... on study' {#253}", {
  lv <- pd_CategoryLevels(90)
  expect_equal(lv[5], "Alive, not yet 90 days on study")
  expect_equal(lv[4], "Alive at 90 days") # unchanged
})
