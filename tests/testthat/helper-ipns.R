# Six subjects over two sites and two countries, one per status plus two extra
# numerator subjects at site I1 so it clears the accrual gate and I2 does not.
ipns_fixture <- function() {
  data.frame(
    studyid = "S",
    subjid = paste0("S", 1:6),
    invid = c("I1", "I1", "I1", "I1", "I2", "I2"),
    country = c("US", "US", "US", "US", "DE", "DE"),
    drv_days_lapsed_since_enrl = c(NA, 10L, 60L, 60L, 60L, NA),
    drv_ip_nonstarter_status = c(
      "Dosed",
      "Potential Non-Starter within window",
      "Potential Non-Starter outside window",
      "Confirmed Non-Starter",
      "Confirmed Non-Starter",
      "Dosed"
    ),
    ipns_status_ord = c(0L, 1L, 2L, 3L, 3L, 0L),
    stringsAsFactors = FALSE
  )
}

# Reads the SOURCE workflow YAML: under load_all, system.file() resolves to the
# source root, so the directory is passed explicitly rather than by strPackage.
kri_workflow <- function(id) {
  workr::MakeWorkflowList(
    strNames = id,
    strPath = file.path(
      system.file(package = "gsm.kri"),
      "workflow",
      "2_metrics"
    )
  )
}

# Task 9's qualification test maps lSource through SUBJ + IPNS before comparing.
ipns_mapping_workflows <- function() {
  workr::MakeWorkflowList(
    strNames = c("SUBJ", "IPNS"),
    strPath = file.path(
      system.file(package = "gsm.mapping"),
      "workflow",
      "1_mappings"
    )
  )
}
