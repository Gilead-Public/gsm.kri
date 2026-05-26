#' Premature-death bucket counts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Categorizes every enrolled subject into a premature-death bucket
#' (`<=30d`, `31-Wd`, or `Alive at Wd`, where `W` is `nWindowDays`) grouped by `strGroupCol`.
#'
#' @param dfDeath `data.frame` Mapped death data with `subjid` and `death_dy`.
#' @param dfSubjects `data.frame` Mapped subject data with `subjid` and `strGroupCol`.
#' @param nWindowDays `numeric` Premature-death window in days. Default: 90.
#' @param strGroupCol `character` Column in `dfSubjects` to group by. Default: "studyid".
#'
#' @return A `data.frame` with `GroupID`, `Bucket`, and `n` columns.
#' @export
pd_BucketCounts <- function(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  strGroupCol = "studyid"
) {
  upper_label <- paste0("31-", nWindowDays, "d")
  alive_label <- paste0("Alive at ", nWindowDays, "d")
  bucket_levels <- c("<=30d", upper_label, alive_label)

  death_dy <- dfDeath$death_dy[match(dfSubjects$subjid, dfDeath$subjid)]
  premature <- !is.na(death_dy) & death_dy <= nWindowDays

  bucket <- dplyr::case_when(
    premature & death_dy <= 30 ~ "<=30d",
    premature ~ upper_label,
    TRUE ~ alive_label
  )

  tibble::tibble(
    GroupID = dfSubjects[[strGroupCol]],
    Bucket = factor(bucket, levels = bucket_levels)
  ) %>%
    dplyr::count(.data$GroupID, .data$Bucket, name = "n", .drop = FALSE)
}

#' Premature-death bucket bar chart
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Stacked bar of premature-death bucket counts per group.
#'
#' @inheritParams pd_BucketCounts
#' @param strGroupLabel `character` Axis label for the group dimension. Default: "Group".
#'
#' @return A `plotly` htmlwidget.
#' @export
pd_BucketBar <- function(
  dfDeath,
  dfSubjects,
  nWindowDays = 90,
  strGroupCol = "studyid",
  strGroupLabel = "Group"
) {
  gsm.core::stop_if(
    cnd = !is.data.frame(dfDeath),
    message = "dfDeath is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !is.data.frame(dfSubjects),
    message = "dfSubjects is not a data.frame"
  )
  gsm.core::stop_if(
    cnd = !(is.numeric(nWindowDays) &&
      length(nWindowDays) == 1 &&
      nWindowDays > 0),
    message = "nWindowDays must be a positive number"
  )
  rlang::check_installed("plotly", reason = "to run `pd_BucketBar()`")

  dfCounts <- pd_BucketCounts(dfDeath, dfSubjects, nWindowDays, strGroupCol)

  upper_label <- paste0("31-", nWindowDays, "d")
  alive_label <- paste0("Alive at ", nWindowDays, "d")
  rag_colors <- c(
    colorScheme("red", "dark"),
    colorScheme("amber", "dark"),
    colorScheme("green", "dark")
  )
  names(rag_colors) <- c("<=30d", upper_label, alive_label)

  plotly::plot_ly(
    dfCounts,
    x = ~GroupID,
    y = ~n,
    color = ~Bucket,
    colors = rag_colors,
    type = "bar"
  ) %>%
    plotly::layout(
      barmode = "stack",
      xaxis = list(title = strGroupLabel),
      yaxis = list(title = "Subjects"),
      legend = list(title = list(text = "Bucket"))
    )
}
