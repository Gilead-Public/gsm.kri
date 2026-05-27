#' Premature-death bucket labels
#'
#' @description
#' The three bucket labels (`<=30d`, `31-Wd`, `Alive at Wd`, where `W` is
#' `nWindowDays`), in RAG order. Shared by the bucket bar and the
#' randomization-to-death scatter so labels and colors stay in lockstep.
#'
#' @param nWindowDays `numeric` Premature-death window in days.
#'
#' @return A length-3 `character` vector of bucket labels.
#' @noRd
pd_BucketLabels <- function(nWindowDays) {
  c(
    "<=30d",
    paste0("31-", nWindowDays, "d"),
    paste0("Alive at ", nWindowDays, "d")
  )
}

#' Premature-death bucket RAG colors
#'
#' @description
#' Named (red / amber / green) color vector keyed by [pd_BucketLabels()].
#'
#' @param nWindowDays `numeric` Premature-death window in days.
#'
#' @return A length-3 named `character` vector of hex colors.
#' @noRd
pd_RagColors <- function(nWindowDays) {
  rag_colors <- c(
    colorScheme("red", "dark"),
    colorScheme("amber", "dark"),
    colorScheme("green", "dark")
  )
  names(rag_colors) <- pd_BucketLabels(nWindowDays)
  rag_colors
}

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
  bucket_levels <- pd_BucketLabels(nWindowDays)

  death_dy <- dfDeath$death_dy[match(dfSubjects$subjid, dfDeath$subjid)]
  premature <- !is.na(death_dy) & death_dy <= nWindowDays

  bucket <- dplyr::case_when(
    premature & death_dy <= 30 ~ bucket_levels[1],
    premature ~ bucket_levels[2],
    TRUE ~ bucket_levels[3]
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

  rag_colors <- pd_RagColors(nWindowDays)

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
