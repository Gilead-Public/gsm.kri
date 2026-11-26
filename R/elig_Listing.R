# Eligibility report overview cards, listings and logic table.

# Order of the expanded row's tables and the CSV details columns.
ELIG_RECORD_SOURCES <- c("Protocol Deviation", "EDC eCRF", "EDC Query", "EDC PD")

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
#' Flagged participants only (Ineligible first). Flag columns are Y/N; EDC
#' Query and EDC PD are `"N/A"` when the source is not delivered.
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
  as.data.frame(out, check.names = FALSE)
}

elig_ExactFilter <- function() {
  reactable::JS(
    "function (rows, columnId, filterValue) {
      var v = String(filterValue).toLowerCase();
      var exact = rows.filter(function (r) { return String(r.values[columnId]).toLowerCase() === v; });
      var picked = (window.eligChartFilter || {})[columnId];
      return exact.length || filterValue === picked ? exact : rows.filter(function (r) {
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

#' Records behind each flagged participant's status
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One row per record: the level 2 records when delivered. A participant's PD
#' or EDC eCRF source without level 2 records falls back to `Mapped_EXCLUSION`:
#' one Protocol Deviation row per PD date/term pair and one EDC eCRF row per
#' criterion code.
#'
#' @param dfElig `data.frame` from [elig_ClassifyParticipants()].
#' @param dfRecords `data.frame` Level 2 records, or `NULL`.
#'
#' @return `data.frame` with `subjid`, `source`, `ID`, `Date` and the key
#'   fields.
#'
#' @keywords internal
#' @export
elig_ParticipantRecords <- function(dfElig, dfRecords = NULL) {
  flagged <- dfElig[dfElig$status != ELIG_NO_RISK, ]
  vHead <- c("subjid", "source", "ID", "Date")
  # Mapped_EXCLUSION carries no PD record IDs.
  pd <- lapply(seq_len(nrow(flagged)), function(i) {
    dates <- elig_SplitPD(flagged$pd_dates[[i]])
    terms <- elig_SplitPD(flagged$pd_terms[[i]])
    n <- max(length(dates), length(terms))
    if (n == 0) return(NULL)
    data.frame(
      subjid = flagged$subjid[[i]], source = "Protocol Deviation", ID = NA_character_,
      Date = substr(dates[seq_len(n)], 1, 10), Description = terms[seq_len(n)]
    )
  })
  ecrf <- flagged[!is.na(flagged$criteria) & nzchar(flagged$criteria), c("subjid", "criteria")] %>%
    tidyr::separate_longer_delim("criteria", delim = ",") %>%
    dplyr::transmute(
      subjid = .data$subjid, source = "EDC eCRF", ID = NA_character_, Date = NA_character_,
      Criterion = trimws(.data$criteria)
    )
  empty <- data.frame(subjid = character(), source = character(), ID = character(), Date = character())
  derived <- dplyr::bind_rows(empty, pd, ecrf)
  if (is.null(dfRecords)) return(as.data.frame(derived))
  recs <- dfRecords[dfRecords$subjid %in% flagged$subjid, setdiff(names(dfRecords), "studyid")]
  names(recs)[match(c("record_id", "record_date"), names(recs))] <- c("ID", "Date")
  # Character throughout, so Date or numeric key fields bind with the fallback rows.
  recs <- dplyr::mutate(recs, dplyr::across(dplyr::everything(), as.character))
  # Incomplete level 2 data must not leave a flagged participant with nothing behind the flag.
  derived <- dplyr::anti_join(derived, recs, by = c("subjid", "source"))
  out <- as.data.frame(dplyr::bind_rows(recs, derived))
  out[c(vHead, setdiff(names(out), vHead))]
}

elig_RecordSourceOrder <- function(vSources) {
  c(intersect(ELIG_RECORD_SOURCES, vSources), sort(setdiff(vSources, ELIG_RECORD_SOURCES)))
}

elig_HasValue <- function(x) !is.na(x) & nzchar(as.character(x))

elig_ParticipantDetail <- function(strSubjid, dfPartRecords) {
  recs <- dfPartRecords[dfPartRecords$subjid == strSubjid, , drop = FALSE]
  if (nrow(recs) == 0) {
    return(htmltools::div(class = "elig-detail", htmltools::tags$p("No records.")))
  }
  htmltools::div(
    class = "elig-detail",
    lapply(elig_RecordSourceOrder(unique(recs$source)), function(s) {
      r <- recs[recs$source == s, setdiff(names(recs), c("subjid", "source")), drop = FALSE]
      r <- r[, vapply(r, function(x) any(elig_HasValue(x)), logical(1)), drop = FALSE]
      htmltools::tagList(
        htmltools::tags$strong(sprintf("%s (%d)", s, nrow(r))),
        reactable::reactable(r, compact = TRUE, bordered = TRUE, fullWidth = TRUE, wrap = TRUE)
      )
    })
  )
}

#' Ineligibility listing
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Expanding a row shows the records behind the participant's status, one
#' table per source.
#'
#' @param dfListing `data.frame` from [elig_ListingData()].
#' @param dfPartRecords `data.frame` from [elig_ParticipantRecords()].
#' @param strID `character` Element ID.
#'
#' @return `reactable` widget.
#'
#' @keywords internal
#' @export
elig_Listing <- function(dfListing, dfPartRecords, strID = "elig-listing") {
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
      reactable::colDef(align = "center", minWidth = 90, filterMethod = elig_ExactFilter())
    }), vFlags),
    stats::setNames(lapply(vText, function(col) {
      reactable::colDef(minWidth = 160, cell = elig_TruncatedCell)
    }), vText)
  )
  reactable::reactable(
    dfListing,
    filterable = TRUE, searchable = TRUE, striped = TRUE, highlight = TRUE,
    compact = TRUE, defaultPageSize = 15, showPageSizeOptions = TRUE,
    pageSizeOptions = c(15, 30, 50, 100),
    elementId = strID,
    columns = columns,
    details = function(index) elig_ParticipantDetail(dfListing$`Participant ID`[index], dfPartRecords)
  )
}

#' Ineligibility listing CSV data
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The listing plus one `"<source> details"` column per source: each record's
#' `Field: value` pairs joined by `"; "`, records joined by `" | "`. One line
#' per cell, because Excel's text import splits rows at line breaks even
#' inside quotes.
#'
#' @param dfListing `data.frame` from [elig_ListingData()].
#' @param dfPartRecords `data.frame` from [elig_ParticipantRecords()].
#' @param bRecords `logical` Level 2 records delivered. Without them only
#'   Protocol Deviation gets a details column: eCRF details would only repeat
#'   Which I/E.
#'
#' @return `data.frame`.
#'
#' @keywords internal
#' @export
elig_ExportData <- function(dfListing, dfPartRecords, bRecords = TRUE) {
  # Any extra source shown in the expanded row also reaches the CSV.
  vSources <- if (isTRUE(bRecords)) {
    elig_RecordSourceOrder(c(ELIG_RECORD_SOURCES, unique(dfPartRecords$source)))
  } else {
    "Protocol Deviation"
  }
  vFields <- setdiff(names(dfPartRecords), c("subjid", "source"))
  text <- vapply(seq_len(nrow(dfPartRecords)), function(i) {
    v <- vapply(vFields, function(f) as.character(dfPartRecords[[f]][[i]]), "")
    keep <- elig_HasValue(v)
    paste0(vFields[keep], ": ", gsub("[\r\n]+", " ", v[keep]), collapse = "; ")
  }, "")
  for (s in vSources) {
    bSource <- dfPartRecords$source == s
    dfListing[[paste(s, "details")]] <- vapply(dfListing$`Participant ID`, function(id) {
      paste(text[bSource & dfPartRecords$subjid == id], collapse = " | ")
    }, "", USE.NAMES = FALSE)
  }
  dfListing
}

#' CSV download of a listing's on-screen rows
#'
#' Exports the rows left by the listing's filters and search, with the
#' details columns of the report's precomputed export data.
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
      onclick = sprintf("eligDownloadCsv('%s', '%s')", strID, strFile),
      "\u2b07\ufe0f Download CSV"
    )
  )
}

#' Eligibility logic table
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Basic mode shows the two Ineligible rules; pilot mode adds the two
#' Potentially Ineligible rules. The pilot flags are derived by the study's
#' own mapping, so the table describes what each flag means, not how a study
#' derives it.
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
      "1", ELIG_INELIGIBLE, "EDC eCRF", "The I/E eCRF has Inclusion = \"No\" or Exclusion = \"Yes\".",
      "2", ELIG_INELIGIBLE, "Protocol Deviation", "At least one PD in one of the study's eligibility categories. Important and Non-important both count.",
      "3", ELIG_POTENTIAL, "EDC Query", "At least one open eligibility-related EDC query (edc_query = \"Y\"), as defined by the study.",
      "4", ELIG_POTENTIAL, "EDC PD", "At least one active eligibility-related EDC protocol deviation (edc_pd = \"Y\"), as defined by the study."
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
