ptd_fixture <- function() {
  subj <- data.frame(
    studyid = "S",
    subjid = sprintf("S%02d", 1:62),
    invid = c(rep(paste0("I", 1:6), each = 10), "I1", "I1"),
    country = c(rep(c("US", "DE"), each = 30), "US", "US"),
    drv_ip_dosed = c(rep("Y", 60), "N", NA_character_),
    drv_treatment_discontinuation_dt = as.Date(NA),
    drv_premature_discontinuation_reason = NA_character_,
    stringsAsFactors = FALSE
  )
  subj$drv_treatment_discontinuation_dt[c(
    1:8,
    11,
    12,
    21,
    22,
    31,
    32,
    41,
    51,
    61,
    62
  )] <- as.Date("2025-02-01")
  subj$drv_drg_completion <- NA_character_
  subj$drv_drg_completion[c(1:7, 9, 11, 21, 31, 41, 51, 61, 62)] <- "N"
  subj$drv_drg_completion[c(8, 12, 32)] <- c("Potential No", "Y", "")
  subj$drv_premature_discontinuation_reason[c(
    2:9,
    11,
    21,
    31,
    41,
    51
  )] <- "Adverse Event"
  subj$drv_premature_discontinuation_reason[
    2
  ] <- "Adverse Event, Physician Decision"

  list(
    Mapped_SUBJ = subj,
    Mapped_STUDCOMP = data.frame(
      studyid = "S",
      invid = "I1",
      subjid = "S03",
      compyn = "Y",
      compreas = "",
      stringsAsFactors = FALSE
    )
  )
}

# I() selects the file by exact name rather than by pattern, and
# bActiveOnly = FALSE also returns the inactive kri0007/cou0007.
ptd_workflow <- function(id) {
  workr::MakeWorkflowList(
    strNames = I(id),
    strPath = file.path(
      system.file(package = "gsm.kri"),
      "workflow",
      "2_metrics"
    ),
    bActiveOnly = FALSE
  )
}
