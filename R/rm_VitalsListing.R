#' Vitals listing rows for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Level 1 of the vitals listing: one row per participant and vital, for
#' every vital in `Mapped_VS`, with the measurements in order. `values` and
#' `in_repeat_window` are space-separated and aligned: `"72 72 72 80"` and
#' `"1 1 1 0"`.
#'
#' @param lClass `list` Output of [rm_Classify()].
#'
#' @return A `tibble` in display order (worst flag, then most repeat
#'   windows) with `country`, `invid`, `subjid`, `label`, `metric`, `flag`,
#'   `measured`, `Numerator`, `Denominator`, `rate`, `values`,
#'   `in_repeat_window`, and the hidden `vital` and `has_repeat` columns.
#' @keywords internal
#' @export
rm_VitalRows <- function(lClass) {
  dfVitals <- lClass$vitals
  vSeverity <- c(Red = 4, Amber = 3, Green = 2, `No KRI` = 1, `Not evaluable` = 0)
  dfValues <- lClass$measurements %>%
    dplyr::arrange(.data$subjid, .data$vital, .data$seq) %>%
    dplyr::group_by(.data$subjid, .data$vital) %>%
    dplyr::summarise(
      values = paste(format_value(.data$value), collapse = " "),
      in_repeat_window = paste(as.integer(.data$in_repeat_window), collapse = " "),
      .groups = "drop"
    )
  df <- lClass$participants %>%
    dplyr::left_join(dfValues, by = c("subjid", "vital"))
  tibble::tibble(
    country = as.character(df$country),
    invid = as.character(df$invid),
    subjid = df$subjid,
    label = dfVitals$label[match(df$vital, dfVitals$vital)],
    metric = dplyr::coalesce(df$metric, ""),
    flag = as.character(df$flag),
    measured = as.integer(df$n_records),
    Numerator = df$Numerator,
    Denominator = df$Denominator,
    rate = ifelse(df$Denominator > 0, round(df$rate, 4), NA_real_),
    values = dplyr::coalesce(df$values, ""),
    in_repeat_window = dplyr::coalesce(df$in_repeat_window, ""),
    vital = df$vital,
    has_repeat = ifelse(grepl("1", df$in_repeat_window), "Y", "N"),
    severity = unname(vSeverity[as.character(df$flag)])
  ) %>%
    dplyr::arrange(
      -.data$severity,
      -.data$Numerator,
      .data$subjid,
      match(.data$vital, dfVitals$vital)
    ) %>%
    dplyr::select(-"severity")
}

#' Record rows for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Level 2 of the vitals listing: the enrolled participants' `Mapped_VS`
#' records with every vital. `repeat_vitals` lists the vitals whose value is
#' in a repeat window on that record.
#'
#' @param lClass `list` Output of [rm_Classify()].
#'
#' @return A `tibble` with `country`, `invid`, `subjid`, `visit`, `vs_dt`, `vsperf_std`,
#'   one column per vital, and the hidden `repeat_vitals` column, ordered by
#'   participant and measurement order.
#' @keywords internal
#' @export
rm_RecordRows <- function(lClass) {
  dfRecords <- lClass$records
  vVitals <- lClass$vitals$vital
  if (is.null(dfRecords) || nrow(dfRecords) == 0) {
    return(tibble::tibble(
      country = character(), invid = character(), subjid = character(),
      visit = character(), vs_dt = as.Date(character()), repeat_vitals = character()
    ))
  }
  dfRepeat <- lClass$measurements[lClass$measurements$in_repeat_window, ] %>%
    dplyr::arrange(match(.data$vital, vVitals)) %>%
    dplyr::group_by(.data$record) %>%
    dplyr::summarise(repeat_vitals = paste(.data$vital, collapse = " "), .groups = "drop")
  dfRecords$repeat_vitals <- dplyr::coalesce(
    dfRepeat$repeat_vitals[match(dfRecords$record, dfRepeat$record)],
    ""
  )
  vOrder <- intersect(c("vs_dt", "visit"), names(dfRecords))
  dfRecords <- dfRecords[do.call(order, c(
    list(dfRecords$subjid),
    unname(as.list(dfRecords[vOrder])),
    list(method = "radix")
  )), ]
  vCols <- c(
    intersect(c("country", "invid", "subjid", "visit", "vs_dt", "vsperf_std"), names(dfRecords)),
    intersect(vVitals, names(dfRecords)),
    "repeat_vitals"
  )
  dfRecords <- dfRecords[vCols]
  dfRecords$country <- as.character(dfRecords$country)
  dfRecords$invid <- as.character(dfRecords$invid)
  tibble::as_tibble(dfRecords)
}

#' Vitals listing tables for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Two `DT` tables. `rm-vitals` (level 1) draws the measurements in order
#' with repeat-window values highlighted; the report's filter script toggles
#' the numbers and filters the named `vital`, `country`, `invid`, `subjid`
#' and `has_repeat` columns. `rm-records` (level 2) highlights each record's
#' repeat-window cells. The CSV of each holds the rows the filters show.
#'
#' @param dfVitalRows `data.frame` Output of [rm_VitalRows()].
#' @param dfRecordRows `data.frame` Output of [rm_RecordRows()].
#' @param dfVitals `data.frame` `vitals` from [rm_Classify()].
#' @param bExport `logical` Show the CSV buttons.
#'
#' @return A named `list` of two `DT` htmlwidgets, `vitals` and `records`.
#' @keywords internal
#' @export
rm_VitalsListing <- function(dfVitalRows, dfRecordRows, dfVitals, bExport = TRUE) {
  idx <- function(df, col) which(names(df) == col) - 1L
  csv <- function(strFile) {
    if (!isTRUE(bExport)) {
      return(list())
    }
    list(list(
      extend = "csv",
      text = "Download CSV",
      filename = strFile,
      exportOptions = list(
        columns = ":visible, .rm-export",
        orthogonal = "export",
        modifier = list(search = "applied")
      )
    ))
  }
  dom <- if (isTRUE(bExport)) "Bfrtip" else "frtip"
  named <- function(df, cols, ...) {
    lapply(cols, function(col) list(targets = idx(df, col), name = col, ...))
  }

  vLabels1 <- c(
    country = "Country", invid = "Site", subjid = "Participant", label = "Vital",
    metric = "Metric", flag = "Flag", measured = "Measured", Numerator = "N",
    Denominator = "D", rate = "Rate",
    values = "Measurements in order", in_repeat_window = "In repeat window",
    vital = "vital", has_repeat = "has_repeat"
  )
  vitals <- DT::datatable(
    dfVitalRows,
    elementId = "rm-vitals",
    rownames = FALSE,
    colnames = unname(vLabels1[names(dfVitalRows)]),
    extensions = "Buttons",
    selection = "none",
    class = "compact hover rm-show-values",
    options = list(
      dom = dom,
      pageLength = 25,
      order = list(),
      buttons = csv("repeat-measurements-vitals"),
      columnDefs = c(
        named(dfVitalRows, c("country", "invid", "subjid", "label")),
        list(
          list(
            targets = idx(dfVitalRows, "flag"),
            render = DT::JS(sprintf(
              "function (data, type) {
                if (type !== 'display' || !data) return data;
                var c = %s[data] || '#FFFFFF';
                return '<span style=\"white-space:nowrap\"><span class=\"rm-dot\" style=\"background:' + c + '\"></span>' + data + '</span>';
              }",
              jsonlite::toJSON(as.list(rm_FlagColors()), auto_unbox = TRUE)
            ))
          ),
          list(
            targets = idx(dfVitalRows, "rate"),
            render = DT::JS(
              "function (data, type) {
                if (type !== 'display' || data === null) return data;
                return (100 * data).toFixed(0) + '%';
              }"
            )
          ),
          list(
            targets = idx(dfVitalRows, "values"),
            orderable = FALSE,
            render = DT::JS(sprintf(
              "function (data, type, row) {
                if (type !== 'display' || !data) return data;
                var mask = String(row[%d]).split(' ');
                return '<span class=\"rm-vals\">' + String(data).split(' ').map(function (v, i) {
                  return '<b' + (mask[i] === '1' ? ' class=\"rw\" title=\"In a repeat window\"' : '') + '>' + v + '</b>';
                }).join('') + '</span>';
              }",
              idx(dfVitalRows, "in_repeat_window")
            ))
          ),
          list(
            targets = idx(dfVitalRows, "in_repeat_window"),
            visible = FALSE,
            className = "rm-export"
          )
        ),
        named(dfVitalRows, c("vital", "has_repeat"), visible = FALSE)
      )
    )
  )

  vVitalCols <- intersect(dfVitals$vital, names(dfRecordRows))
  vLabels2 <- c(
    country = "Country", invid = "Site", subjid = "Participant", visit = "Visit",
    vs_dt = "Date", vsperf_std = "Performed",
    stats::setNames(dfVitals$label, dfVitals$vital),
    repeat_vitals = "Vitals in repeat window"
  )
  records <- DT::datatable(
    dfRecordRows,
    elementId = "rm-records",
    rownames = FALSE,
    colnames = unname(vLabels2[names(dfRecordRows)]),
    extensions = "Buttons",
    selection = "none",
    class = "compact nowrap",
    options = list(
      dom = dom,
      pageLength = 25,
      order = list(),
      buttons = csv("repeat-measurements-records"),
      createdRow = DT::JS(sprintf(
        "function (row, data) {
          var cols = %s, rw = String(data[%d] || '').split(' ');
          rw.forEach(function (k) {
            if (cols[k] !== undefined) row.cells[cols[k]].classList.add('rw');
          });
        }",
        jsonlite::toJSON(
          as.list(stats::setNames(vapply(vVitalCols, idx, integer(1), df = dfRecordRows), vVitalCols)),
          auto_unbox = TRUE
        ),
        idx(dfRecordRows, "repeat_vitals")
      )),
      columnDefs = c(
        named(dfRecordRows, intersect(c("country", "invid", "subjid"), names(dfRecordRows))),
        list(list(
          targets = idx(dfRecordRows, "repeat_vitals"),
          name = "repeat_vitals",
          visible = FALSE,
          className = "rm-export"
        ))
      )
    )
  )
  list(vitals = vitals, records = records)
}

format_value <- function(x) {
  format(x, trim = TRUE, drop0trailing = TRUE, scientific = FALSE, digits = 10)
}
