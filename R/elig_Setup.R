# Eligibility report settings: flag sources, rate metric, criterion colours and
# investigator lookup in one validated list.

ELIG_PD_SPLIT <- c("flag_pd_important", "flag_pd_nonimportant")
ELIG_FIXED_LISTING_COLUMNS <- c(
  "Country",
  "Site",
  "Investigator Name",
  "Participant ID",
  "Eligibility Status",
  "Which I/E"
)

elig_DefaultSources <- function() {
  data.frame(
    flag = c(
      "flag_pd",
      "flag_pd_important",
      "flag_pd_nonimportant",
      "flag_ecrf",
      "flag_edc_query",
      "flag_edc_pd"
    ),
    label = c(
      "Protocol Deviation",
      "Important PD",
      "Non-important PD",
      "EDC eCRF",
      "EDC Query",
      "EDC PD"
    ),
    listing_label = c(
      "PD",
      "Important PD",
      "Non-important PD",
      "EDC eCRF",
      "EDC Query",
      "EDC PD"
    ),
    record_source = c(
      rep("Protocol Deviation", 3),
      "EDC eCRF",
      "EDC Query",
      "EDC PD"
    ),
    stringsAsFactors = FALSE
  )
}

elig_IsString <- function(x) {
  is.character(x) && length(x) == 1 && !is.na(x) && nzchar(x)
}

elig_MergeSources <- function(dfSources) {
  def <- elig_DefaultSources()
  if (is.null(dfSources)) {
    return(def)
  }

  if (!is.data.frame(dfSources) || !"flag" %in% names(dfSources)) {
    cli::cli_abort(
      "{.arg dfSources} must be a data frame with a {.field flag} column."
    )
  }
  bad <- setdiff(names(dfSources), names(def))
  if (length(bad) > 0) {
    cli::cli_abort("Unknown {.arg dfSources} column{?s}: {.val {bad}}.")
  }
  flags <- as.character(dfSources$flag)
  if (anyNA(flags) || !all(flags %in% def$flag)) {
    cli::cli_abort(
      "Unknown flag{?s} in {.arg dfSources}: {.val {setdiff(flags, def$flag)}}."
    )
  }
  if (anyDuplicated(flags)) {
    cli::cli_abort("{.arg dfSources} lists a flag more than once.")
  }

  pd_default <- def$record_source[1]
  idx <- match(flags, def$flag)
  for (col in setdiff(names(dfSources), "flag")) {
    val <- as.character(dfSources[[col]])
    if (anyNA(val) || any(!nzchar(val))) {
      cli::cli_abort(
        "{.arg dfSources} column {.field {col}} has missing or empty values."
      )
    }
    def[[col]][idx] <- val
  }
  # The PD split shares flag_pd's records, so it can't have its own source. The
  # default is tolerated so an edited elig_Setup() result still round-trips.
  split <- def$flag %in% ELIG_PD_SPLIT
  passed_split <- dfSources[["record_source"]][flags %in% ELIG_PD_SPLIT]
  if (
    length(passed_split) > 0 &&
      any(!passed_split %in% c(def$record_source[1], pd_default))
  ) {
    cli::cli_abort(
      "Split PD flags must use {.field record_source} of {.val flag_pd}."
    )
  }
  def$record_source[split] <- def$record_source[1]

  for (col in c("label", "listing_label")) {
    if (anyDuplicated(def[[col]])) {
      cli::cli_abort("{.field {col}} values must be unique.")
    }
  }
  if (any(def$listing_label %in% ELIG_FIXED_LISTING_COLUMNS)) {
    cli::cli_abort(
      "{.field listing_label} can't reuse a fixed listing column name."
    )
  }
  if (anyDuplicated(def$record_source[!split])) {
    cli::cli_abort("Two flags can't share a {.field record_source}.")
  }

  if (length(flags) == nrow(def)) {
    def <- def[idx, ]
  }
  rownames(def) <- NULL
  def
}

#' Eligibility report settings
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Settings of the Eligibility report. `NULL` `dfSources` and `vCriterionColors`
#' take the defaults. The result is accepted back by this function unchanged.
#'
#' @param dfSources `data.frame` Flag sources with columns `flag`, `label`
#'   (chart name), `listing_label` (listing column) and `record_source` (record
#'   table in the expanded row). Only `flag` is required; each passed row
#'   overrides the defaults of that flag for the passed columns. Passing all six
#'   flags sets their display order. Both PD split flags use the
#'   `record_source` of `flag_pd`. Defaults:
#'   \tabular{llll}{
#'     `flag` \tab `label` \tab `listing_label` \tab `record_source` \cr
#'     `flag_pd` \tab Protocol Deviation \tab PD \tab Protocol Deviation \cr
#'     `flag_pd_important` \tab Important PD \tab Important PD \tab Protocol Deviation \cr
#'     `flag_pd_nonimportant` \tab Non-important PD \tab Non-important PD \tab Protocol Deviation \cr
#'     `flag_ecrf` \tab EDC eCRF \tab EDC eCRF \tab EDC eCRF \cr
#'     `flag_edc_query` \tab EDC Query \tab EDC Query \tab EDC Query \cr
#'     `flag_edc_pd` \tab EDC PD \tab EDC PD \tab EDC PD
#'   }
#' @param strRateMetricID `character` Analysis metric charted as the
#'   eligibility rate. `workflow/4_modules/report_eligibility.yaml` queries only
#'   `Analysis_qtl0001`, so the setting matters for direct callers. Default:
#'   `"Analysis_qtl0001"`.
#' @param vCriterionColors Named `character` Colours by criterion type; passed
#'   names replace the defaults, stack order stays `Inclusion`, `Exclusion`,
#'   `Not classified`. Defaults: `"#3C587F"`, `"#8FB3DE"`, `"#B8C4D6"`.
#' @param strInvestigatorLevel `character` Group level of the investigator
#'   parameters. Default: `"Site"`.
#' @param vInvestigatorParams `character` Parameters joined into the
#'   investigator name. Default: `c("InvestigatorFirstName",
#'   "InvestigatorLastName")`.
#'
#' @return `list` with `dfSources`, `strRateMetricID`, `vCriterionColors`,
#'   `strInvestigatorLevel` and `vInvestigatorParams`.
#'
#' @export
elig_Setup <- function(
  dfSources = NULL,
  strRateMetricID = "Analysis_qtl0001",
  vCriterionColors = NULL,
  strInvestigatorLevel = "Site",
  vInvestigatorParams = c("InvestigatorFirstName", "InvestigatorLastName")
) {
  for (arg in c("strRateMetricID", "strInvestigatorLevel")) {
    if (!elig_IsString(get(arg))) {
      cli::cli_abort("{.arg {arg}} must be a single non-empty string.")
    }
  }
  if (
    !is.character(vInvestigatorParams) ||
      length(vInvestigatorParams) == 0 ||
      anyNA(vInvestigatorParams)
  ) {
    cli::cli_abort(
      "{.arg vInvestigatorParams} must be a non-empty character vector without {.val NA}."
    )
  }

  colors <- c(
    Inclusion = "#3C587F",
    Exclusion = "#8FB3DE",
    "Not classified" = "#B8C4D6"
  )
  if (!is.null(vCriterionColors)) {
    bad <- setdiff(names(vCriterionColors), names(colors))
    if (is.null(names(vCriterionColors)) || length(bad) > 0) {
      cli::cli_abort(
        "{.arg vCriterionColors} names must be among {.val {names(colors)}}."
      )
    }
    if (
      !is.character(vCriterionColors) ||
        anyNA(vCriterionColors) ||
        !all(nzchar(vCriterionColors))
    ) {
      cli::cli_abort(
        "{.arg vCriterionColors} must be non-empty strings without {.val NA}."
      )
    }
    colors[names(vCriterionColors)] <- vCriterionColors
  }

  list(
    dfSources = elig_MergeSources(dfSources),
    strRateMetricID = strRateMetricID,
    vCriterionColors = colors,
    strInvestigatorLevel = strInvestigatorLevel,
    vInvestigatorParams = vInvestigatorParams
  )
}

#' Eligibility flag names
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Looks up a `dfSources` column for flags.
#'
#' @param vFlags `character` Flag column names.
#' @param lSetup `list` Result of [elig_Setup()].
#' @param strColumn `character` `dfSources` column to return. Default: `"label"`.
#'
#' @return Unnamed `character`, one value per flag.
#'
#' @keywords internal
#' @export
elig_FlagLabel <- function(vFlags, lSetup = elig_Setup(), strColumn = "label") {
  df <- lSetup$dfSources
  unname(df[[strColumn]][match(vFlags, df$flag)])
}

# Record sources are labelled after their non-split flag; the PD split shares
# flag_pd's records.
elig_RecordLabel <- function(vRecordSources, lSetup = elig_Setup()) {
  df <- lSetup$dfSources[!lSetup$dfSources$flag %in% ELIG_PD_SPLIT, ]
  out <- df$label[match(vRecordSources, df$record_source)]
  out[is.na(out)] <- vRecordSources[is.na(out)]
  unname(out)
}
