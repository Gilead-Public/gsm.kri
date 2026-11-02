read_fixture <- function(strName) {
  df <- utils::read.csv(
    test_path("fixtures", strName),
    na.strings = "",
    stringsAsFactors = FALSE
  )
  if ("vs_dt" %in% names(df)) {
    df$vs_dt <- as.Date(df$vs_dt)
  }
  df
}

vs_fixture <- function() {
  list(
    Mapped_SUBJ = read_fixture("vs_subj.csv"),
    Mapped_VS = read_fixture("vs.csv")
  )
}
