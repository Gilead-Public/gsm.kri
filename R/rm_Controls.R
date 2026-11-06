#' Header card of the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The card at the top of the report: an optional context line, the title, the
#' study, snapshot, window length and participant flag rule, and the
#' collapsible "How to read" notes. `rmFilters.js` rewrites the rule text
#' (`.rm-rule-text`) when the reviewer changes the settings.
#'
#' @param lClass `list` Output of [rm_Classify()].
#' @param strStudy `character` Study ID(s) shown in the header.
#' @param dSnapshotDate `Date` Snapshot date. Optional; omitted when `NULL`.
#' @param strContext `character` HTML for a line above the title, such as a
#'   link back to the page that embeds the report. Omitted when empty.
#'
#' @return An `htmltools` tag.
#' @keywords internal
#' @export
rm_Header <- function(lClass, strStudy, dSnapshotDate = NULL, strContext = "") {
  nW <- lClass$meta$window_length
  rule_text <- rm_RuleText(lClass$meta)
  # The H1 is HTML rather than markdown and .toc-ignore, so the contents list
  # starts at the first section.
  htmltools::tags$header(
    id = "rm-header",
    class = "rm-header",
    if (nzchar(strContext)) htmltools::tags$div(class = "rm-ctx", htmltools::HTML(strContext)),
    htmltools::tags$div(
      class = "rm-title",
      htmltools::tags$h1(class = "toc-ignore", "Repeat Measurements"),
      htmltools::tags$button(id = "rm-how-toggle", type = "button", class = "rm-btn", `aria-expanded` = "false", `aria-controls` = "rm-how", "How to read")
    ),
    htmltools::tags$div(
      class = "rm-meta",
      rm_Pill("Study", strStudy),
      if (!is.null(dSnapshotDate)) rm_Pill("Snapshot", format(dSnapshotDate)),
      rm_Pill("Window", paste(nW, "measurements")),
      rm_Pill("Participant flag", htmltools::HTML(rule_text), class = "rm-pill-rule")
    ),
    htmltools::tags$div(
      id = "rm-how",
      class = "rm-how",
      hidden = NA,
      htmltools::HTML(sprintf('<ul>
<li>A <strong>window</strong> is %1$s consecutive measurements of one measure for one participant, in date order (visit breaks ties; missing values skipped). A window <strong>repeats</strong> when all %1$s values are identical. Each participant and measure has <strong>N</strong> repeating windows of <strong>D</strong> windows; the KRIs <code>kri0020a</code>&ndash;<code>f</code> sum N and D by site.</li>
<li>Participants are <strong>evaluable</strong> for a measure once they have enough windows. Flag rule: %2$s. Change the rule, thresholds and minimum windows under <strong>Settings</strong> in the bar below; participant flags in every section follow, while site flags keep the KRI rule.</li>
<li><strong>Blood pressure</strong> (Settings): <em>Separate</em> shows systolic and diastolic BP (the KRIs); <em>Combined</em> shows paired BP, where a window repeats only when both readings repeat over the same visits (no KRI); <em>Both</em> shows all three.</li>
<li>Pick measures under <strong>Measures</strong> in the bar below, or click a measure in the Study overview, to focus every section except the Study overview, which always covers the whole study. Click a country or site to filter; remove a filter with its &times; or all of them with <strong>Reset filters</strong>.</li>
<li>The last three sections drill down from one row per participant (Participant listing) to one per participant and measure (Measure listing) to one per visit record or value (Data table). Click a participant, tile or row in any of them to filter the whole report to that participant; click it again to clear.</li>
</ul>', nW, rule_text))
    )
  )
}

#' Segmented control for the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A group of toggle buttons, one per value, with `aria-pressed` on the
#' selected one. `rmFilters.js` finds the buttons by their data attribute.
#'
#' @param strLabel `character` Accessible label of the group.
#' @param vValues `character` Button labels, named by value.
#' @param strSelected `character` The value pressed initially.
#' @param strAttr `character` Data attribute the script reads, such as
#'   `"data-rm-ov"`.
#' @param strGroup `character` Optional. When given, every button sets
#'   `strAttr` to `strGroup` and carries its value in `value`; otherwise
#'   `strAttr` holds the value.
#' @param strIdPrefix `character` Optional prefix of each button's `id`,
#'   followed by its value.
#'
#' @return An `htmltools` tag.
#' @keywords internal
#' @export
rm_Seg <- function(strLabel, vValues, strSelected, strAttr, strGroup = NULL, strIdPrefix = NULL) {
  htmltools::tags$span(
    class = "rm-seg",
    role = "group",
    `aria-label` = strLabel,
    lapply(names(vValues), function(v) {
      lAttrs <- list()
      if (!is.null(strIdPrefix)) lAttrs$id <- paste0(strIdPrefix, v)
      lAttrs$type <- "button"
      lAttrs[[strAttr]] <- if (is.null(strGroup)) v else strGroup
      if (!is.null(strGroup)) lAttrs$value <- v
      lAttrs[["aria-pressed"]] <- if (identical(v, strSelected)) "true" else "false"
      do.call(htmltools::tags$button, c(lAttrs, list(vValues[[v]])))
    })
  )
}

#' Filter strip of the Repeat Measurements report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The sticky bar under the header: the measure picker, the country, site and
#' participant filter chips, Reset filters, and the Settings popover, which
#' `rmFilters.js` fills from the settings in `#rm-data`.
#'
#' @param dfVitals `data.frame` The measures, `vitals` of [rm_Classify()].
#' @param lSettings `list` The initial settings: `rule`, `thresholds`,
#'   `minWindows` and `bp`.
#'
#' @return An `htmltools` tag.
#' @keywords internal
#' @export
rm_Toolbar <- function(dfVitals, lSettings) {
  # htmltools, not raw HTML, so pandoc does not wrap the controls in a <p>.
  htmltools::tags$div(
    id = "rm-filter-strip",
    class = "rm-filter-strip",
    htmltools::tags$span(class = "rm-eyebrow", "Measures"),
    rm_MeasureSelect(dfVitals),
    htmltools::tags$span(
      class = "rm-chips",
      rm_Chip("country", "Country"),
      rm_Chip("site", "Site"),
      rm_Chip("subj", "Participant")
    ),
    htmltools::tags$span(id = "rm-count", class = "rm-count", title = "Filters apply to every section except the Study overview."),
    htmltools::tags$button(id = "rm-reset", type = "button", class = "rm-ghost", title = "Clear the measure, country, site and participant filters", "Reset filters"),
    htmltools::tags$span(class = "rm-vr"),
    htmltools::tags$button(id = "rm-settings-toggle", type = "button", class = "rm-btn", `aria-expanded` = "false", `aria-controls` = "rm-settings", "Settings"),
    htmltools::tags$button(id = "rm-toc-toggle", type = "button", class = "rm-ghost", `aria-pressed` = "false", style = "display:none;", "Hide contents"),
    rm_SettingsPanel(lSettings)
  )
}

rm_RuleText <- function(lMeta) {
  th <- lMeta$thresholds
  sprintf(
    "<span class=\"rm-rule-text\">%s; participants need %s window%s for a flag</span>",
    if (lMeta$rule == "rate") {
      sprintf("%% of windows that repeat, Amber \u2265 %s%%, Red \u2265 %s%%", format(100 * th[1]), format(100 * th[2]))
    } else {
      sprintf("repeating windows, Amber \u2265 %s, Red \u2265 %s", format(th[1]), format(th[2]))
    },
    lMeta$min_windows,
    if (lMeta$min_windows == 1) "" else "s"
  )
}

rm_Pill <- function(label, ..., class = NULL) {
  htmltools::tags$span(class = paste(c("rm-pill", class), collapse = " "), htmltools::tags$b(label), ...)
}

# A popover under the Settings button.
rm_SettingsPanel <- function(lSettings) {
  num <- function(id, label, min, step) {
    htmltools::tags$label(
      label,
      htmltools::tags$input(id = id, type = "number", min = min, step = step),
      htmltools::tags$span(class = "rm-unit", `data-rm-unit` = id)
    )
  }
  dot <- function(color) {
    htmltools::tags$span(class = "rm-dot", style = sprintf("background:%1$s;border-color:%1$s", color))
  }
  set_row <- function(label, control, help = NULL, `for` = NULL) {
    htmltools::tags$div(
      class = "rm-set-row",
      htmltools::tags$label(class = "rm-set-l", `for` = `for`, label),
      htmltools::tags$div(class = "rm-set-c", control),
      if (!is.null(help)) htmltools::tags$div(class = "rm-set-h", help)
    )
  }
  htmltools::tags$div(
    id = "rm-settings",
    class = "rm-settings",
    role = "dialog",
    `aria-label` = "Report settings",
    hidden = NA,
    htmltools::tags$div(
      class = "rm-set-head",
      htmltools::tags$b("Report settings"),
      htmltools::tags$span(class = "rm-set-hint", "Participant flags follow; site flags keep the KRI rule \u00b7 Esc to close")
    ),
    set_row(
      "Blood pressure",
      rm_Seg("Blood pressure", c(separate = "Separate", combined = "Combined", both = "Both"), lSettings$bp, "data-rm-set", strGroup = "bp"),
      "Separate: systolic and diastolic BP (the KRIs). Combined: paired BP, where a window repeats only when both readings repeat. Both: all three."
    ),
    set_row(
      "Participant flag",
      rm_Seg("Flag rule", c(count = "# repeating", rate = "% repeating"), lSettings$rule, "data-rm-set", strGroup = "rule"),
      "Count repeating windows, or their share of the participant\u2019s windows."
    ),
    set_row(
      "Thresholds",
      htmltools::tagList(
        num("rm-th-amber", htmltools::tagList(dot("#FEAA02"), "Amber \u2265"), 0, "any"),
        num("rm-th-red", htmltools::tagList(dot("#FF5859"), "Red \u2265"), 0, "any")
      )
    ),
    set_row(
      "Minimum windows",
      htmltools::tagList(
        htmltools::tags$input(id = "rm-min-windows", type = "number", min = 1, step = 1),
        htmltools::tags$span(class = "rm-unit", `data-rm-unit` = "rm-min-windows"),
        htmltools::tags$span(class = "rm-unit", "per participant and measure")
      ),
      "Participants with fewer windows are not evaluable.",
      `for` = "rm-min-windows"
    ),
    htmltools::tags$div(
      class = "rm-set-foot",
      htmltools::tags$button(id = "rm-settings-defaults", type = "button", class = "rm-ghost", "Restore defaults"),
      htmltools::tags$span(id = "rm-settings-msg", class = "rm-settings-msg", role = "status"),
      htmltools::tags$button(id = "rm-settings-done", type = "button", class = "rm-btn rm-pri", "Done")
    )
  )
}

rm_Chip <- function(key, label) {
  htmltools::tags$span(
    id = paste0("rm-chip-", key),
    class = "rm-chip",
    style = "display:none;",
    htmltools::tags$span(label, ": ", htmltools::tags$span(class = "rm-chip-value")),
    htmltools::tags$button(
      type = "button",
      `data-rm-clear` = key,
      `aria-label` = paste("Clear", tolower(label), "filter"),
      htmltools::HTML("&times;")
    )
  )
}

# rmFilters.js hides the BP options the Blood pressure setting does not show.
rm_MeasureSelect <- function(dfVitals) {
  kri_badge <- function(strMetric) {
    if (!is.na(strMetric)) htmltools::tags$span(class = "rm-kri", title = strMetric, "KRI")
  }
  htmltools::tags$span(
    class = "rm-ms",
    htmltools::tags$button(
      id = "rm-vital-btn",
      type = "button",
      class = "rm-ms-btn",
      `aria-haspopup` = "true",
      `aria-expanded` = "false",
      `aria-controls` = "rm-vital-menu",
      htmltools::tags$span(id = "rm-vital-summary", "All"),
      htmltools::HTML(" &#9662;")
    ),
    htmltools::tags$div(
      id = "rm-vital-menu",
      class = "rm-ms-menu",
      role = "group",
      `aria-label` = "Measures",
      hidden = NA,
      htmltools::tags$label(
        class = "rm-ms-all",
        htmltools::tags$input(id = "rm-vital-all", type = "checkbox", checked = NA),
        " All measures"
      ),
      lapply(seq_len(nrow(dfVitals)), function(i) {
        htmltools::tags$label(
          `data-rm-vital-opt` = dfVitals$vital[i],
          htmltools::tags$input(type = "checkbox", value = dfVitals$vital[i], `data-rm-vital-cb` = NA, checked = NA),
          " ", dfVitals$label[i], " ",
          kri_badge(dfVitals$metric[i])
        )
      })
    )
  )
}
