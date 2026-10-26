#' Data table rows for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The two shapes of the Data table (§5). Participants follow the Participant
#' Listing order: worst flag, then most repeating windows, then participant.
#'
#' * `rm_DataTableData()` (Long): one row per participant, vital and
#'   non-missing value, in measurement order. `has_repeat` marks the
#'   participant's vitals with at least one repeat window.
#' * `rm_DataTableWide()` (Wide): one row per `Mapped_VS` record with one
#'   column per vital (blank when not measured) and a
#'   `<vital>_in_repeat_window` column (`"Y"`, `"N"` or `""`) per vital.
#'   `repeat_vitals` lists the participant's vitals with at least one repeat
#'   window.
#'
#' @param lClass `list` Output of [rm_Classify()].
#'
#' @return A `tibble`. Long: `country`, `invid`, `subjid`, `label`, `metric`,
#'   `seq`, `visit`, `vs_dt`, `value`, `in_repeat_window` (`"Yes"`/`"No"`),
#'   and the hidden `vital` and `has_repeat` columns. Wide: `country`,
#'   `invid`, `subjid`, `visit`, `vs_dt`, `performed` (`"Y"`/`"N"`), one
#'   column per vital, one `<vital>_in_repeat_window` column per vital and
#'   the hidden `repeat_vitals` column.
#' @keywords internal
#' @export
rm_DataTableData <- function(lClass) {
  dfVitals <- lClass$vitals
  dfM <- lClass$measurements
  vOrder <- rm_ParticipantOrder(lClass)
  dfRepeat <- rm_RepeatVitals(lClass)
  dfM <- dfM[order(
    match(dfM$subjid, vOrder),
    match(dfM$vital, dfVitals$vital),
    dfM$seq,
    method = "radix"
  ), ]
  tibble::tibble(
    country = as.character(dfM$country),
    invid = as.character(dfM$invid),
    subjid = dfM$subjid,
    label = dfVitals$label[match(dfM$vital, dfVitals$vital)],
    metric = dplyr::coalesce(dfVitals$metric[match(dfM$vital, dfVitals$vital)], ""),
    seq = as.integer(dfM$seq),
    visit = as.character(dfM$visit),
    vs_dt = dfM$vs_dt,
    value = dfM$value_text,
    in_repeat_window = ifelse(dfM$in_repeat_window, "Yes", "No"),
    vital = dfM$vital,
    has_repeat = ifelse(
      paste(dfM$subjid, dfM$vital) %in% paste(dfRepeat$subjid, dfRepeat$vital),
      "Y",
      "N"
    )
  )
}

#' @rdname rm_DataTableData
#' @keywords internal
#' @export
rm_DataTableWide <- function(lClass) {
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
  vOrder <- rm_ParticipantOrder(lClass)
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

  dfRepeat <- rm_RepeatVitals(lClass)
  vRepeat <- vapply(split(dfRepeat$vital, dfRepeat$subjid), paste, character(1), collapse = " ")

  tibble::as_tibble(c(
    list(
      country = as.character(dfRecords$country),
      invid = as.character(dfRecords$invid),
      subjid = dfRecords$subjid,
      visit = if ("visit" %in% names(dfRecords)) as.character(dfRecords$visit) else NA_character_,
      vs_dt = if ("vs_dt" %in% names(dfRecords)) dfRecords$vs_dt else as.Date(NA),
      performed = rm_Performed(dfRecords$vsperf_std)
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
#' The two `DT` tables of the Data table (§5): `rm-dt-long` and `rm-dt-wide`.
#' Values in a repeat window are red. To fit without horizontal scrolling,
#' Long shows the metric as a KRI badge on the vital (metric ID on hover);
#' Wide abbreviates the vital headers (name and metric on hover), shows the
#' country on hover over the site and greys the records not performed. The
#' CSVs keep the full headers and the country, metric and performed columns.
#' The report's filter script switches
#' between them, filters the named `vital`, `country`, `invid`, `subjid`,
#' `has_repeat` and `repeat_vitals` columns, hides the Wide vital columns
#' outside the selected group, and turns a row click into the participant
#' filter. Each CSV holds the rows the filters show: Long with every column,
#' Wide with the shown vitals and their `<vital>_in_repeat_window` columns.
#'
#' @param dfLong `data.frame` Output of [rm_DataTableData()].
#' @param dfWide `data.frame` Output of [rm_DataTableWide()].
#' @param dfVitals `data.frame` `vitals` from [rm_Classify()].
#' @param bExport `logical` Show the CSV buttons.
#'
#' @return A named `list` of two `DT` htmlwidgets, `long` and `wide`.
#' @keywords internal
#' @export
rm_DataTable <- function(dfLong, dfWide, dfVitals, bExport = TRUE) {
  idx <- function(df, col) match(col, names(df)) - 1L
  dom <- if (isTRUE(bExport)) "Bfrtip" else "frtip"
  rowTitle <- DT::JS(
    "function (row) { row.title = 'Click to filter the report to this participant; click again to clear'; }"
  )
  named <- function(df, cols, ...) {
    lapply(cols, function(col) list(targets = idx(df, col), name = col, ...))
  }

  vLong <- c(
    country = "Country", invid = "Site", subjid = "Participant", label = "Vital",
    metric = "Metric", seq = "#", visit = "Visit", vs_dt = "Date", value = "Value",
    in_repeat_window = "Repeat", vital = "vital", has_repeat = "has_repeat"
  )
  # Every column but the hidden filter columns.
  vLongExport <- idx(dfLong, setdiff(names(dfLong), c("vital", "has_repeat")))
  long <- DT::datatable(
    dfLong,
    elementId = "rm-dt-long",
    rownames = FALSE,
    colnames = unname(vLong[names(dfLong)]),
    extensions = "Buttons",
    selection = "none",
    class = "compact hover nowrap",
    options = list(
      dom = dom,
      pageLength = 25,
      deferRender = TRUE,
      order = list(),
      buttons = rm_CsvButton(
        bExport,
        "repeat-measurements-data-long",
        vLongExport,
        stats::setNames(list("In repeat window"), idx(dfLong, "in_repeat_window"))
      ),
      createdRow = rowTitle,
      columnDefs = c(
        named(dfLong, c("country", "invid", "subjid")),
        list(list(
          targets = idx(dfLong, "label"),
          render = DT::JS(sprintf(
            "function (data, type, row) {
              var m = row[%d];
              if (type !== 'display' || !m) return data;
              return data + '<span class=\"rm-kri\" title=\"' + m + '\">KRI</span>';
            }",
            idx(dfLong, "metric")
          ))
        )),
        list(list(targets = idx(dfLong, "metric"), visible = FALSE)),
        list(list(targets = idx(dfLong, "in_repeat_window"), title = "<span title=\"In a repeat window\">Repeat</span>")),
        list(list(
          targets = idx(dfLong, "value"),
          render = DT::JS(sprintf(
            "function (data, type, row) {
              if (type !== 'display' || row[%d] !== 'Yes') return data;
              return '<b class=\"rm-rw\" title=\"In a repeat window\">' + data + '</b>';
            }",
            idx(dfLong, "in_repeat_window")
          ))
        )),
        named(dfLong, c("vital", "has_repeat"), visible = FALSE)
      )
    )
  )

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
  # A <vital>_in_repeat_window column exports only while its vital is shown;
  # the country and performed columns always export.
  lPairs <- stats::setNames(as.list(idx(dfWide, vVitals)), idx(dfWide, vRW))
  vAlways <- idx(dfWide, c("country", "performed"))
  wide <- DT::datatable(
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
      buttons = rm_CsvButton(
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
              return '<span title=\"' + (row[%d] || '') + '\">' + data + '</span>';
            }",
            idx(dfWide, "country")
          ))
        )),
        named(dfWide, "subjid"),
        lapply(vVitals, function(strVital) {
          list(
            targets = idx(dfWide, strVital),
            name = strVital,
            className = "dt-right",
            createdCell = DT::JS(sprintf(
              "function (td, cellData, rowData) {
                if (rowData[%d] === 'Y') { td.classList.add('rm-rw'); td.title = 'In a repeat window'; }
              }",
              idx(dfWide, sprintf("%s_in_repeat_window", strVital))
            ))
          )
        }),
        list(list(targets = idx(dfWide, vRW), visible = FALSE)),
        named(dfWide, "repeat_vitals", visible = FALSE)
      )
    )
  )
  list(long = long, wide = wide)
}

# Participants in Participant Listing order: worst flag, then most repeating
# windows, then participant.
rm_ParticipantOrder <- function(lClass) {
  vSeverity <- c(Red = 3, Amber = 2, Green = 1, `Not evaluable` = 0)
  df <- lClass$participants %>%
    dplyr::mutate(severity = unname(vSeverity[as.character(.data$flag)])) %>%
    dplyr::group_by(.data$subjid) %>%
    dplyr::summarise(
      worst = max(.data$severity),
      most = max(.data$Numerator),
      .groups = "drop"
    ) %>%
    dplyr::arrange(-.data$worst, -.data$most, .data$subjid)
  df$subjid
}

# Participant x vital pairs with at least one repeat window.
rm_RepeatVitals <- function(lClass) {
  vVitals <- lClass$vitals$vital
  df <- lClass$participants[lClass$participants$Numerator > 0, c("subjid", "vital")]
  df[order(df$subjid, match(df$vital, vVitals)), ]
}

rm_Performed <- function(x) {
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
