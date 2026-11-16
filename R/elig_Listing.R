# Eligibility report overview cards, listings and logic table (gsm.roadmap#113).

ELIG_DEEP_DIVE_SOURCES <- c("EDC eCRF", "Protocol Deviation", "EDC Query", "EDC PD")

# Listing column names of the flag sources; the single PD source is "PD".
ELIG_LISTING_SOURCES <- c(
  flag_pd = "PD",
  flag_pd_important = "Important PD",
  flag_pd_nonimportant = "Non-important PD",
  flag_ecrf = "EDC eCRF",
  flag_edc_query = "EDC Query",
  flag_edc_pd = "EDC PD"
)

elig_Pct <- function(n, d) ifelse(d > 0, sprintf("%.1f%%", 100 * n / d), "-")

#' Eligibility study overview cards
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Basic mode: Total Enrolled, Ineligible Participants and No Eligibility
#' Risk. Pilot mode: Total Enrolled, Total risk, Ineligible Participants and
#' Potentially Ineligible.
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#' @param bPilot `logical` Pilot mode.
#'
#' @return `htmltools` tag.
#'
#' @keywords internal
#' @export
elig_OverviewCards <- function(dfElig, bPilot = FALSE) {
  colors <- elig_StatusColors()
  n <- nrow(dfElig)
  n_inel <- sum(dfElig$status == ELIG_INELIGIBLE)
  n_pot <- sum(dfElig$status == ELIG_POTENTIAL)
  n_none <- sum(dfElig$status == ELIG_NO_RISK)
  card <- function(label, value, sub, color) {
    htmltools::div(
      class = "elig-card", style = sprintf("border-top: 4px solid %s;", color),
      htmltools::div(class = "elig-card-label", label),
      htmltools::div(class = "elig-card-value", value),
      htmltools::div(class = "elig-card-sub", sub)
    )
  }
  inel <- card(
    "Ineligible Participants", n_inel,
    htmltools::tagList(
      paste0(elig_Pct(n_inel, n), " of enrolled"),
      htmltools::span(class = "elig-badge elig-kri-badge", title = "Key Risk Indicator (qtl0001)", "KRI")
    ),
    colors[[ELIG_INELIGIBLE]]
  )
  cards <- if (isTRUE(bPilot)) {
    list(
      card("Total Enrolled", n, "Denominator", "#5b7193"),
      card("Total risk", n_inel + n_pot, paste0(elig_Pct(n_inel + n_pot, n), " of enrolled (Ineligible + Potentially Ineligible)"), "#1f2d3d"),
      inel,
      card(ELIG_POTENTIAL, n_pot, paste0(elig_Pct(n_pot, n), " of enrolled \u00b7 reporting only"), colors[[ELIG_POTENTIAL]])
    )
  } else {
    list(
      card("Total Enrolled", n, "Denominator", "#5b7193"),
      inel,
      card(ELIG_NO_RISK, n_none, paste0(elig_Pct(n_none, n), " of enrolled"), colors[[ELIG_NO_RISK]])
    )
  }
  htmltools::div(class = "elig-cards", cards)
}

elig_StatusBadge <- function(value) {
  htmltools::span(
    class = "elig-badge",
    style = sprintf("background-color:%s;color:#1f2d3d;", elig_StatusColors()[[value]]),
    value
  )
}

elig_SplitPD <- function(x) {
  if (is.na(x) || !nzchar(x)) character() else trimws(strsplit(x, ";;;", fixed = TRUE)[[1]])
}

#' Ineligibility listing data
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Flagged participants only (Ineligible first). Flag columns are Y/N; EDC PD
#' is `"N/A"` when the source is not delivered. PD dates and terms spread into
#' `PD Date 1..n` / `PD Term 1..n`.
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#'
#' @return `data.frame`.
#'
#' @keywords internal
#' @export
elig_ListingData <- function(dfElig) {
  df <- dfElig[dfElig$status != ELIG_NO_RISK, ]
  df <- df[order(match(df$status, c(ELIG_INELIGIBLE, ELIG_POTENTIAL)), df$country, df$invid, df$subjid), ]
  out <- tibble::tibble(
    Country = df$country,
    Site = df$invid,
    `Investigator Name` = df$investigator,
    `Participant ID` = df$subjid,
    `Eligibility Status` = df$status
  )
  for (f in names(elig_Sources(df))) {
    out[[ELIG_LISTING_SOURCES[[f]]]] <- if (all(is.na(df[[f]]))) rep("N/A", nrow(df)) else df[[f]]
  }
  out$`Which I/E` <- gsub(",", ", ", df$criteria, fixed = TRUE)
  dates <- lapply(df$pd_dates, elig_SplitPD)
  terms <- lapply(df$pd_terms, elig_SplitPD)
  for (i in seq_len(max(c(0, lengths(dates), lengths(terms))))) {
    out[[paste("PD Date", i)]] <- vapply(dates, function(x) if (length(x) >= i) x[[i]] else NA_character_, "")
    out[[paste("PD Term", i)]] <- vapply(terms, function(x) if (length(x) >= i) x[[i]] else NA_character_, "")
  }
  as.data.frame(out, check.names = FALSE)
}

elig_ExactFilter <- function() {
  reactable::JS(
    "function (rows, columnId, filterValue) {
      var v = String(filterValue).toLowerCase();
      var exact = rows.filter(function (r) { return String(r.values[columnId]).toLowerCase() === v; });
      return exact.length ? exact : rows.filter(function (r) {
        return String(r.values[columnId]).toLowerCase().indexOf(v) >= 0;
      });
    }"
  )
}

# Long text is cut to one line; the full value shows on hover.
elig_TruncatedCell <- function(value) {
  if (is.na(value) || !nzchar(value)) return("")
  htmltools::div(class = "elig-truncate", title = value, value)
}

elig_RecordText <- function(dfRecords) {
  vKey <- setdiff(names(dfRecords), c("studyid", "subjid", "source", "record_id", "record_date"))
  vapply(seq_len(nrow(dfRecords)), function(i) {
    r <- dfRecords[i, ]
    fields <- vapply(vKey, function(k) {
      v <- as.character(r[[k]])
      if (is.na(v) || !nzchar(v)) NA_character_ else paste0(k, ": ", v)
    }, "")
    head <- sprintf("[%s]%s", r$record_id, if (is.na(r$record_date)) "" else paste0(" ", r$record_date))
    paste(c(head, stats::na.omit(fields)), collapse = "\n")
  }, "")
}

elig_ParticipantDetail <- function(strSubjid, dfElig, dfRecords) {
  if (!is.null(dfRecords)) {
    recs <- dfRecords[dfRecords$subjid == strSubjid, ]
    if (nrow(recs) > 0) {
      vKey <- setdiff(names(recs), c("studyid", "subjid"))
      recs <- recs[vKey]
      recs <- recs[, vapply(recs, function(x) any(!is.na(x) & nzchar(as.character(x))), logical(1)), drop = FALSE]
      return(htmltools::div(
        class = "elig-detail",
        htmltools::tags$strong("Records behind this status"),
        reactable::reactable(as.data.frame(recs), compact = TRUE, bordered = TRUE, fullWidth = TRUE, wrap = TRUE)
      ))
    }
  }
  p <- dfElig[dfElig$subjid == strSubjid, ][1, ]
  dates <- elig_SplitPD(p$pd_dates)
  terms <- elig_SplitPD(p$pd_terms)
  nPD <- max(length(dates), length(terms))
  pd <- data.frame(`PD Date` = dates[seq_len(nPD)], `PD Term` = terms[seq_len(nPD)], check.names = FALSE)
  htmltools::div(
    class = "elig-detail",
    htmltools::tags$p(htmltools::tags$strong("EDC I/E criteria: "), if (is.na(p$criteria)) "none" else gsub(",", ", ", p$criteria)),
    if (nrow(pd) > 0) {
      htmltools::tagList(
        htmltools::tags$strong("Eligibility protocol deviations"),
        reactable::reactable(pd, compact = TRUE, bordered = TRUE, fullWidth = TRUE, wrap = TRUE)
      )
    } else {
      htmltools::tags$p("No eligibility protocol deviation terms.")
    }
  )
}

#' Ineligibility listing
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Expanding a row shows the participant's level 2 records when delivered,
#' otherwise the PD dates/terms and criterion codes of `Mapped_EXCLUSION`.
#'
#' @param dfListing `data.frame` from [elig_ListingData()].
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#' @param dfRecords `data.frame` Level 2 records, or `NULL`.
#' @param strID `character` Element ID.
#'
#' @return `reactable` widget.
#'
#' @keywords internal
#' @export
elig_Listing <- function(dfListing, dfElig, dfRecords = NULL, strID = "elig-listing") {
  vFlags <- intersect(unname(ELIG_LISTING_SOURCES), names(dfListing))
  vText <- setdiff(names(dfListing), c("Country", "Site", "Participant ID", "Eligibility Status", vFlags))
  columns <- c(
    list(
      Country = reactable::colDef(minWidth = 90, filterMethod = elig_ExactFilter()),
      Site = reactable::colDef(minWidth = 80, filterMethod = elig_ExactFilter()),
      `Participant ID` = reactable::colDef(minWidth = 120),
      `Eligibility Status` = reactable::colDef(
        minWidth = 170, cell = function(value) elig_StatusBadge(value), filterMethod = elig_ExactFilter()
      )
    ),
    stats::setNames(lapply(vFlags, function(f) {
      reactable::colDef(
        align = "center", minWidth = 90, filterMethod = elig_ExactFilter(),
        header = if (identical(f, "EDC PD") && all(dfListing[[f]] == "N/A")) "EDC PD \u2020" else f
      )
    }), vFlags),
    stats::setNames(lapply(vText, function(col) {
      reactable::colDef(minWidth = if (grepl("^PD Date", col)) 100 else 160, cell = elig_TruncatedCell)
    }), vText)
  )
  reactable::reactable(
    dfListing,
    filterable = TRUE, searchable = TRUE, striped = TRUE, highlight = TRUE,
    compact = TRUE, defaultPageSize = 15, showPageSizeOptions = TRUE,
    pageSizeOptions = c(15, 30, 50, 100),
    elementId = strID,
    columns = columns,
    details = function(index) elig_ParticipantDetail(dfListing$`Participant ID`[index], dfElig, dfRecords)
  )
}

#' Deep dive listing data
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One row per flagged participant and one column per source. Each cell lists
#' the participant's records as `[record id] date` followed by the source's
#' key fields; a blank cell means no records.
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#' @param dfRecords `data.frame` Level 2 records: `studyid`, `subjid`,
#'   `source`, `record_id`, `record_date` and key fields.
#'
#' @return `data.frame`.
#'
#' @keywords internal
#' @export
elig_DeepDiveData <- function(dfElig, dfRecords) {
  flagged <- dfElig[dfElig$status != ELIG_NO_RISK, ]
  recs <- dfRecords[dfRecords$subjid %in% flagged$subjid, ]
  recs$text <- elig_RecordText(recs)
  vSources <- c(ELIG_DEEP_DIVE_SOURCES, sort(setdiff(unique(recs$source), ELIG_DEEP_DIVE_SOURCES)))
  out <- data.frame(
    Country = flagged$country,
    Site = flagged$invid,
    `Participant ID` = flagged$subjid,
    `Eligibility Status` = flagged$status,
    check.names = FALSE
  )
  for (s in vSources) {
    r <- recs[recs$source == s, ]
    out[[s]] <- vapply(flagged$subjid, function(id) {
      x <- r$text[r$subjid == id]
      if (length(x)) paste(x, collapse = "\n\n") else NA_character_
    }, "", USE.NAMES = FALSE)
  }
  out[order(match(out$`Eligibility Status`, c(ELIG_INELIGIBLE, ELIG_POTENTIAL)), out$Country, out$Site, out$`Participant ID`), ]
}

#' Deep dive listing
#'
#' @param dfDeepDive `data.frame` from [elig_DeepDiveData()].
#' @param strID `character` Element ID.
#'
#' @return `reactable` widget.
#'
#' @keywords internal
#' @export
elig_DeepDive <- function(dfDeepDive, strID = "elig-deep-dive") {
  vSources <- setdiff(names(dfDeepDive), c("Country", "Site", "Participant ID", "Eligibility Status"))
  reactable::reactable(
    dfDeepDive,
    filterable = TRUE, searchable = TRUE, striped = TRUE, highlight = TRUE,
    compact = TRUE, defaultPageSize = 10, showPageSizeOptions = TRUE,
    pageSizeOptions = c(10, 25, 50, 100),
    elementId = strID, wrap = TRUE,
    columns = c(
      list(
        Country = reactable::colDef(minWidth = 90, filterMethod = elig_ExactFilter()),
        Site = reactable::colDef(minWidth = 80, filterMethod = elig_ExactFilter()),
        `Participant ID` = reactable::colDef(minWidth = 120),
        `Eligibility Status` = reactable::colDef(
          minWidth = 170, cell = function(value) elig_StatusBadge(value), filterMethod = elig_ExactFilter()
        )
      ),
      stats::setNames(lapply(vSources, function(s) {
        reactable::colDef(minWidth = 260, cell = function(value) {
          if (is.na(value)) return("")
          htmltools::div(class = "elig-records", value)
        })
      }), vSources)
    )
  )
}

#' CSV download of a listing's on-screen rows
#'
#' Exports the rows left by the listing's filters and search.
#'
#' @param strID `character` reactable element ID.
#' @param strFile `character` Download file name.
#'
#' @return `htmltools` tag.
#'
#' @keywords internal
#' @export
elig_CsvButton <- function(strID, strFile) {
  htmltools::tags$p(
    htmltools::tags$button(
      type = "button", class = "btn btn-primary btn-sm",
      onclick = sprintf("Reactable.downloadDataCSV('%s', '%s')", strID, strFile),
      "\u2b07\ufe0f Download CSV"
    )
  )
}

#' Eligibility logic table
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Basic mode shows today's two rules; pilot mode shows rules 2.4-2.7 of the
#' #113 business requirement.
#'
#' @param bPilot `logical` Pilot mode.
#'
#' @return `gt_tbl`.
#'
#' @keywords internal
#' @export
elig_LogicTable <- function(bPilot = FALSE) {
  rules <- if (isTRUE(bPilot)) {
    tibble::tribble(
      ~Rule, ~Status, ~Source, ~Criteria,
      "2.4", ELIG_INELIGIBLE, "EDC eCRF", "The I/E eCRF has Inclusion = \"No\" or Exclusion = \"Yes\".",
      "2.5", ELIG_INELIGIBLE, "Protocol Deviation", "At least one PD in an eligibility category (Inclusion Criteria, Exclusion Criteria, Inclusion / Exclusion, Eligibility Criteria, Eligibility Criteria with different code), in the Gilead or the CRO category. Important and Non-important both count.",
      "2.6", ELIG_POTENTIAL, "EDC Query", "At least one Open or Answered query from System Query or CDA to Site Manual Query, in the Enrollment folder on an Inclusion/Exclusion Criteria form, or in the Screening folder with \"Potential Protocol Deviation\" / \"Potential PD\" in the query text, opened more than 3 days before the snapshot date.",
      "2.7", ELIG_POTENTIAL, "EDC PD", "At least one active EDC PD (marking_active = 1) in the Enrollment folder on an Inclusion/Exclusion Criteria form, or in the Screening folder."
    )
  } else {
    tibble::tribble(
      ~Rule, ~Status, ~Source, ~Criteria,
      "1", ELIG_INELIGIBLE, "EDC eCRF", "The I/E eCRF has Inclusion = \"No\" or Exclusion = \"Yes\".",
      "2", ELIG_INELIGIBLE, "Protocol Deviation", "At least one PD in one of the study's eligibility categories."
    )
  }
  footnote <- paste(
    "Only enrolled participants are included, each with exactly one status.",
    if (isTRUE(bPilot)) {
      "A participant meeting both an Ineligible and a Potentially Ineligible rule is Ineligible. Potentially Ineligible is reporting only: it does not enter the qtl0001 metric or raise risk signals."
    } else {
      "A participant meeting no rule has No Eligibility Risk."
    },
    "Rules are applied upstream by the mapping layer; the report receives the result per participant."
  )
  rules %>%
    gt::gt() %>%
    gt::tab_header(title = "Eligibility rules") %>%
    gt::tab_footnote(footnote) %>%
    gt::cols_width(Rule ~ gt::px(60), Status ~ gt::px(180), Source ~ gt::px(160)) %>%
    gt::tab_options(table.width = gt::pct(100), table.font.size = "13px")
}
