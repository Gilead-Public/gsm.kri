#### Helper Function: Sim_Studies ####

#' Simulate Multi-Study KRI Data
#'
#' Generates simulated cross-study KRI data for testing and demonstration purposes.
#' Creates realistic multi-study datasets including KRI metrics, flags, risk score weights,
#' and study/site metadata.
#'
#' @param dfMetrics Data frame with metrics metadata containing MetricID, Flag, and RiskScoreWeight columns
#' @param n_studies Number of studies to simulate (default: 5)
#' @param n_sites Total number of unique sites to simulate (default: 30)
#' @param n_sites_per_study Range of sites per study as c(min, max) (default: c(8, 15))
#' @param snapshot_date Single snapshot date for all simulated data (default: "2025-06-01")
#' @param seed Random seed for reproducibility (default: 123)
#'
#' @return A named list with two elements:
#'   - dfResults: Data frame of simulated KRI results
#'   - dfGroups: Data frame of groups metadata (site-level + study-level)
Sim_Studies <- function(dfMetrics=gsm.core::reportingMetrics, 
                        n_studies = 5,
                        n_sites = 30,
                        n_sites_per_study = c(8, 15),
                        snapshot_date = as.Date("2025-06-01"),
                        seed = 123) {
  ########## 0. set up key parameters for sampling ############
  # Set seed for reproducibility
  set.seed(seed)
  
  # Generate study IDs
  study_ids <- sprintf("STUDY%03d", 1:n_studies)
  
  # Get metric IDs from dfMetrics (exclude risk score metrics)
  metric_ids <- unique(dfMetrics$MetricID)
  metric_ids <- metric_ids[grepl("kri", metric_ids, ignore.case = TRUE)]
  
  # Generate simulated site IDs
  site_ids <- sprintf("SITE%04d", 1:n_sites)
  
  # Generate simulated investigator names
  first_names <- c("James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
                   "William", "Elizabeth", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
                   "Thomas", "Sarah", "Charles", "Karen", "Christopher", "Nancy", "Daniel", "Lisa",
                   "Matthew", "Betty", "Anthony", "Margaret", "Mark", "Sandra")
  last_names <- c("Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
                  "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas",
                  "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White", "Harris",
                  "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson")
  
  investigator_names <- sample(last_names, n_sites, replace = TRUE)
  
  ########## 1. simulate reporting results ############
  sim_reportingResults <- lapply(study_ids, function(study) {
    n_sites_in_study <- sample(n_sites_per_study[1]:n_sites_per_study[2], 1)
    study_sites <- sample(site_ids, n_sites_in_study, replace = FALSE)
    
    expand.grid(
      StudyID = study,
      SnapshotDate = snapshot_date,
      GroupLevel = "Site",
      GroupID = study_sites,
      MetricID = metric_ids,
      stringsAsFactors = FALSE
    )
  }) %>%
    dplyr::bind_rows() %>%
    dplyr::mutate(
      Numerator = sample(1:100, dplyr::n(), replace = TRUE),
      Denominator = sample(100:200, dplyr::n(), replace = TRUE),
      Metric = Numerator / Denominator,
      Score = round(runif(dplyr::n(), -3, 3), 2),  # Z-scores
      Flag = dplyr::case_when(
        Score <= -2 ~ -2,
        Score <= -1 ~ -1,
        Score >= 2 ~ 2,
        Score >= 1 ~ 1,
        TRUE ~ 0
      )
    )
  
  # Create weight table from dfMetrics
  weight_table <- MakeWeights(dfMetrics)

  # Calculate Risk Scores separately for each study and combine with original data
  risk_scores_by_study <- sim_reportingResults %>%
    split(.$StudyID) %>%
    purrr::map_dfr(~ {
      study_id <- .x$StudyID[1]
      result <- CalculateRiskScore(.x, weight_table)
      result$StudyID <- study_id
      result
    })
  
  # Combine original KRI results with risk scores
  dfResults <- dplyr::bind_rows(
    sim_reportingResults,
    risk_scores_by_study
  )
 ####### Simulate Group Metadata #######
 # Create site-level groups metadata based on study-site combinations in results
  # Get unique study-site combinations from the simulated results
  study_site_combos <- dfResults %>%
    dplyr::select(StudyID, GroupID) %>%
    dplyr::distinct()
  
  # Create dfGroups_sites with one row per study-site combination
  dfGroups_sites <- lapply(1:nrow(study_site_combos), function(i) {
    site_id <- study_site_combos$GroupID[i]
    study_id <- study_site_combos$StudyID[i]
    site_index <- which(site_ids == site_id)
    
    data.frame(
      Index = 1:3,
      StudyID = study_id,
      GroupID = site_id,
      Param = c("siteid", "InvestigatorLastName", "ParticipantCount"),
      Value = c(site_id, investigator_names[site_index], as.character(sample(20:100, 1))),
      GroupLevel = "Site",
      stringsAsFactors = FALSE
    )
  }) %>%
    dplyr::bind_rows()

  # Create dfGroups data for simulated studies
  dfGroups_studies <- lapply(study_ids, function(study_id) {
    study_number <- as.numeric(gsub("STUDY", "", study_id))
    
    data.frame(
      Index = 1:22,
      GroupID = study_id,
      StudyID = study_id,
      Param = c("studyid", "nickname", "protocol_title", "status", "num_plan_site", 
                "num_plan_subj", "act_fpfv", "est_fpfv", "est_lplv", "est_lpfv",
                "therapeutic_area", "protocol_indication", "phase", "product",
                "SiteTarget", "ParticipantTarget", "ParticipantCount", "SiteCount",
                "PercentSitesActivated", "SiteActivation", "PercentParticipantsEnrolled", 
                "ParticipantEnrollment"),
      Value = c(
        study_id,
        paste0("Protocol-", study_number),
        paste("Protocol Title for Study", study_number),
        sample(c("Active", "Completed", "Enrolling"), 1),
        as.character(sample(100:200, 1)),
        as.character(sample(800:1200, 1)),
        as.character(as.Date("2024-01-01") + sample(0:365, 1)),
        as.character(as.Date("2024-01-01") + sample(0:30, 1)),
        as.character(as.Date("2024-12-31") + sample(0:365, 1)),
        as.character(as.Date("2024-06-01") + sample(0:180, 1)),
        sample(c("Oncology", "Virology", "Cardiology", "Neurology", "Immunology"), 1),
        sample(c("Hematology", "Solid Tumors", "Respiratory", "Dermatology"), 1),
        sample(c("P1", "P2", "P3"), 1),
        paste("Product", LETTERS[study_number]),
        as.character(sample(100:200, 1)),
        as.character(sample(800:1200, 1)),
        as.character(sample(600:1000, 1)),
        as.character(sample(80:150, 1)),
        as.character(round(runif(1, 85, 98), 1)),
        paste0(sample(80:150, 1), " / ", sample(100:200, 1), " (", round(runif(1, 85, 98), 1), "%)"),
        as.character(round(runif(1, 70, 90), 1)),
        paste0(sample(600:1000, 1), " / ", sample(800:1200, 1), " (", round(runif(1, 70, 90), 1), "%)")
      ),
      GroupLevel = "Study",
      stringsAsFactors = FALSE
    )
  }) %>%
    dplyr::bind_rows()
  
  # Combine site and study groups data
  dfGroups <- dplyr::bind_rows(
    dfGroups_sites,     # Simulated site-level groups
    dfGroups_studies    # Simulated study-level groups
  )
  
  # Return results as a named list
  return(list(
    dfResults = dfResults,
    dfGroups = dfGroups
  ))
}
