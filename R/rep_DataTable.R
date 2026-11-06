#' Data table rows for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The Wide data table: one row per `Mapped_VS` record with one column per
#' measure (blank when not measured) and a `<vital>_in_repeat_window` column
#' (`"Y"`, `"N"` or `""`) per measure. `repeat_vitals` lists the
#' participant's measures with at least one repeating window. Participants
#' follow the Participant listing order (worst flag, then most repeating
#' windows, then participant); each participant's records are in measurement
#' order (date, visit, record). The report builds the Long table in the
#' browser from these rows, so the data are embedded once.
#'
#' @param lClass `list` Output of [rep_Classify()].
#'
#' @return A `tibble` with `country`, `invid`, `subjid`, `visit`, `vs_dt`,
#'   `performed` (`"Y"`/`"N"`), one column per measure, one
#'   `<vital>_in_repeat_window` column per measure and the hidden
#'   `repeat_vitals` column.
#' @keywords internal
#' @export
rep_DataTableWide <- function(lClass) {
  vVitals <- lClass$vitals$vital
  dfRecords <- lClass$records
  if (is.null(dfRecords) || nrow(dfRecords) == 0) {
    return(tibble::tibble(
      country = character(), invid = character(), subjid = character(),
      visit = character(), vs_dt = as.Date(character()), performed = character(),
      repeat_vitals = character()
    ))
  }
  vVitals <- intersect(vVitals, names(dfRecords))
  vOrder <- rep_ParticipantOrder(lClass)
  vRecordOrder <- intersect(c("vs_dt", "visit"), names(dfRecords))
  dfRecords <- dfRecords[do.call(order, c(
    list(match(dfRecords$subjid, vOrder)),
    unname(as.list(dfRecords[vRecordOrder])),
    list(dfRecords$record, method = "radix")
  )), ]

  dfM <- lClass$measurements
  lRepeat <- lapply(vVitals, function(strVital) {
    dfV <- dfM[dfM$vital == strVital, ]
    bRW <- dfV$in_repeat_window[match(dfRecords$record, dfV$record)]
    ifelse(is.na(bRW), "", ifelse(bRW, "Y", "N"))
  })
  names(lRepeat) <- sprintf("%s_in_repeat_window", vVitals)

  dfRepeat <- rep_RepeatVitals(lClass)
  vRepeat <- vapply(split(dfRepeat$vital, dfRepeat$subjid), paste, character(1), collapse = " ")

  tibble::as_tibble(c(
    list(
      country = as.character(dfRecords$country),
      invid = as.character(dfRecords$invid),
      subjid = dfRecords$subjid,
      visit = if ("visit" %in% names(dfRecords)) as.character(dfRecords$visit) else NA_character_,
      vs_dt = if ("vs_dt" %in% names(dfRecords)) dfRecords$vs_dt else as.Date(NA),
      performed = rep_Performed(dfRecords$vsperf_std)
    ),
    # Paired BP stays text ("120/80").
    lapply(dfRecords[vVitals], function(x) if (is.character(x)) x else as.numeric(x)),
    lRepeat,
    list(repeat_vitals = dplyr::coalesce(unname(vRepeat[dfRecords$subjid]), ""))
  ))
}

#' Data table for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The Wide `DT` table of the Data table, `rm-dt-wide`. Values in a repeating
#' window are dark red. To fit without horizontal scrolling, it abbreviates
#' the measure headers (name and metric on hover), shows the country on hover
#' over the site and greys the records not performed; the CSV keeps the full
#' headers and the country and performed columns. Every column is named so
#' the report's filter script can find it: the script filters `country`,
#' `invid`, `subjid` and `repeat_vitals`, hides the measure columns that are
#' not selected, turns a row click into the participant filter and builds the
#' Long table from these rows. The CSV holds the rows the filters show, with
#' the shown measures and their `<vital>_in_repeat_window` columns.
#'
#' @param dfWide `data.frame` Output of [rep_DataTableWide()].
#' @param dfVitals `data.frame` `vitals` from [rep_Classify()].
#' @param bExport `logical` Show the CSV button.
#'
#' @return A `DT` htmlwidget.
#' @keywords internal
#' @export
rep_DataTable <- function(dfWide, dfVitals, bExport = TRUE) {
  idx <- function(df, col) match(col, names(df)) - 1L
  dom <- if (isTRUE(bExport)) "Bfrtip" else "frtip"
  named <- function(df, cols, ...) {
    lapply(cols, function(col) list(targets = idx(df, col), name = col, ...))
  }

  vVitals <- intersect(dfVitals$vital, names(dfWide))
  vRW <- sprintf("%s_in_repeat_window", vVitals)
  vLabel <- stats::setNames(dfVitals$label, dfVitals$vital)[vVitals]
  vShort <- stats::setNames(dplyr::coalesce(dfVitals$short, dfVitals$vital), dfVitals$vital)[vVitals]
  vMetric <- stats::setNames(dfVitals$metric, dfVitals$vital)[vVitals]
  vWide <- c(
    country = "Country", invid = "Site", subjid = "Participant", visit = "Visit",
    vs_dt = "Date", performed = "Performed",
    vShort,
    stats::setNames(vRW, vRW),
    repeat_vitals = "repeat_vitals"
  )
  vTitle <- stats::setNames(
    paste0(vLabel, ifelse(is.na(vMetric), " (no KRI)", paste0(" (", vMetric, ")"))),
    vVitals
  )
  wide_header <- htmltools::tags$table(
    class = "display",
    htmltools::tags$thead(htmltools::tags$tr(lapply(names(dfWide), function(col) {
      htmltools::tags$th(title = if (col %in% vVitals) vTitle[[col]], vWide[[col]])
    })))
  )
  # A <vital>_in_repeat_window column exports only while its measure is shown;
  # the country and performed columns always export.
  lPairs <- stats::setNames(as.list(idx(dfWide, vVitals)), idx(dfWide, vRW))
  vAlways <- idx(dfWide, c("country", "performed"))
  DT::datatable(
    dfWide,
    elementId = "rm-dt-wide",
    rownames = FALSE,
    container = wide_header,
    extensions = "Buttons",
    selection = "none",
    class = "compact hover nowrap",
    options = list(
      dom = dom,
      pageLength = 25,
      deferRender = TRUE,
      order = list(),
      buttons = rep_CsvButton(
        bExport,
        "repeat-measurements-data-wide",
        DT::JS(sprintf(
          "function (idx) {
            var t = jQuery('#rm-dt-wide table.dataTable').DataTable();
            var pairs = %s, always = %s, hidden = %d;
            if (idx === hidden) return false;
            if (always.indexOf(idx) >= 0) return true;
            if (pairs[idx] !== undefined) return t.column(pairs[idx]).visible();
            return t.column(idx).visible();
          }",
          jsonlite::toJSON(lPairs, auto_unbox = TRUE),
          jsonlite::toJSON(vAlways),
          idx(dfWide, "repeat_vitals")
        )),
        stats::setNames(as.list(unname(vLabel)), idx(dfWide, vVitals))
      ),
      createdRow = DT::JS(sprintf(
        "function (row, data) {
          row.title = 'Click to filter the report to this participant; click again to clear';
          if (data[%d] === 'N') { row.classList.add('rm-np'); row.title = 'Not performed. ' + row.title; }
        }",
        idx(dfWide, "performed")
      )),
      columnDefs = c(
        named(dfWide, "country", visible = FALSE),
        named(dfWide, "performed", visible = FALSE),
        list(list(
          targets = idx(dfWide, "invid"),
          name = "invid",
          render = DT::JS(sprintf(
            "function (data, type, row) {
              if (type !== 'display') return data;
              return '<span title=\"' + String(row[%d] || '').replace(/\"/g, '&quot;') + '\">' + data + '</span>';
            }",
            idx(dfWide, "country")
          ))
        )),
        named(dfWide, c("subjid", "visit", "vs_dt")),
        lapply(vVitals, function(strVital) {
          list(
            targets = idx(dfWide, strVital),
            name = strVital,
            className = "dt-right",
            createdCell = DT::JS(sprintf(
              "function (td, cellData, rowData) {
                if (rowData[%d] === 'Y') { td.classList.add('rm-rw'); td.title = 'In a repeating window'; }
              }",
              idx(dfWide, sprintf("%s_in_repeat_window", strVital))
            ))
          )
        }),
        named(dfWide, vRW, visible = FALSE),
        named(dfWide, "repeat_vitals", visible = FALSE)
      )
    )
  )
}

# Participants in Participant Listing order: worst flag, then most repeating
# windows, then participant.
rep_ParticipantOrder <- function(lClass) {
  df <- lClass$participants %>%
    dplyr::mutate(severity = rep_FlagSeverity(.data$flag)) %>%
    dplyr::group_by(.data$subjid) %>%
    dplyr::summarise(
      worst = max(.data$severity),
      most = max(.data$Numerator),
      .groups = "drop"
    ) %>%
    dplyr::arrange(-.data$worst, -.data$most, .data$subjid)
  df$subjid
}

# Participant x vital pairs with at least one repeating window.
rep_RepeatVitals <- function(lClass) {
  vVitals <- lClass$vitals$vital
  df <- lClass$participants[lClass$participants$Numerator > 0, c("subjid", "vital")]
  df[order(df$subjid, match(df$vital, vVitals)), ]
}

rep_Performed <- function(x) {
  if (is.null(x)) {
    return(NA_character_)
  }
  x <- toupper(as.character(x))
  dplyr::case_when(
    x %in% c("1", "Y", "YES") ~ "Y",
    x %in% c("0", "N", "NO") ~ "N",
    TRUE ~ x
  )
}
