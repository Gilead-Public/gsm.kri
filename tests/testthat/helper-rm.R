# Builders for the Repeat Measurements tests (rm_* helpers and the report).
rm_listings <- function(dfVS, dfSubj = NULL) {
  if (is.null(dfSubj)) {
    dfSubj <- data.frame(
      studyid = "S1",
      subjid = unique(dfVS$subjid),
      invid = "I1",
      country = "US"
    )
  }
  list(Mapped_VS = dfVS, Mapped_SUBJ = dfSubj)
}

rm_vs <- function(lValues, strCol = "weight") {
  do.call(rbind, lapply(names(lValues), function(id) {
    x <- lValues[[id]]
    df <- data.frame(
      subjid = id,
      vs_dt = as.Date("2024-01-01") + seq_along(x) - 1,
      visit = paste0("V", seq_along(x))
    )
    df[[strCol]] <- x
    df
  }))
}

rm_metrics <- function(nWindow = 3, strThreshold = "0.2,0.3") {
  data.frame(
    ID = c("kri0020a", "cou0020a"),
    MetricID = c("Analysis_kri0020a", "Analysis_cou0020a"),
    WindowLength = nWindow,
    Threshold = strThreshold
  )
}

flag_of <- function(lClass, id, strVital = "weight") {
  df <- lClass$participants
  as.character(df$flag[df$subjid == id & df$vital == strVital])
}

# Five participants over two countries and three sites, at W = 3, with flags
# under the rate rule (under the default count rule only A's weight is flagged,
# Amber):
# weight: A 2/2 Red, B 0/2 Green, C 0/0 Not evaluable, D 1/4 Amber, E no VS.
# pulse: A 0/1 Green, B 1/2 Red. height (no KRI): D 1/1.
rm_Fixture <- function() {
  vs <- function(id, weight = NULL, pulse = NULL, height = NULL) {
    n <- max(length(weight), length(pulse), length(height))
    pad <- function(x) c(x, rep(NA_real_, n - length(x)))
    data.frame(
      subjid = id,
      visit = paste0("V", seq_len(n)),
      vs_dt = as.Date("2024-01-01") + seq_len(n) - 1,
      vsperf_std = "Y",
      weight = pad(weight),
      pulse = pad(pulse),
      height = pad(height)
    )
  }
  dfVS <- rbind(
    vs("A", weight = c(70, 70, 70, 70), pulse = c(60, 61, 62)),
    vs("B", weight = c(80, 81, 82, 83), pulse = c(60, 60, 60, 61)),
    vs("C", weight = c(55, 55)),
    vs("D", weight = c(90, 90, 90, 91, 92, 93), height = c(170, 170, 170))
  )
  dfSubj <- data.frame(
    studyid = "STUDY1",
    subjid = c("A", "B", "C", "D", "E"),
    invid = c("S1", "S1", "S2", "S3", "S3"),
    country = c("US", "US", "US", "JP", "JP")
  )
  list(Mapped_VS = dfVS, Mapped_SUBJ = dfSubj)
}

# Site results for kri0020a/b that reconcile with rm_Fixture(), plus an older
# snapshot that does not.
rm_FixtureResults <- function() {
  latest <- data.frame(
    MetricID = rep(c("Analysis_kri0020a", "Analysis_kri0020b"), each = 3),
    GroupLevel = "Site",
    GroupID = rep(c("S1", "S2", "S3"), 2),
    Numerator = c(2, 0, 1, 1, 0, 0),
    Denominator = c(4, 0, 4, 3, 0, 0),
    Flag = c(-2, 0, 1, 2, 0, 0),
    SnapshotDate = as.Date("2024-03-01")
  )
  older <- transform(latest, Numerator = 0, Flag = 0, SnapshotDate = as.Date("2024-02-01"))
  rbind(older, latest)
}

# kri0020a-f and cou0020a-f metrics at W = 3 with the default thresholds.
rm_FixtureMetrics <- function(nWindow = 3) {
  vIDs <- c(paste0("kri0020", letters[1:6]), paste0("cou0020", letters[1:6]))
  data.frame(
    ID = vIDs,
    MetricID = paste0("Analysis_", vIDs),
    WindowLength = nWindow,
    Threshold = "0.2,0.3"
  )
}

render_rm <- function(lListings = rm_Fixture(), ...) {
  testthat::skip_if_not_installed("DT")
  out <- quiet_render(suppressWarnings(Report_RepeatMeasurements(
    lListings = lListings,
    strOutputDir = tempdir(),
    strOutputFile = paste0(basename(tempfile("rm")), ".html"),
    ...
  )))
  paste(readLines(out, warn = FALSE), collapse = "\n")
}

rm_DataBlock <- function(html) {
  jsonlite::fromJSON(sub(
    '.*<script type="application/json" id="rm-data">(.*?)</script>.*',
    "\\1",
    html
  ))
}

# htmlwidgets serializes each widget into a JSON <script data-for=...> block;
# the payloads are named by element id.
rm_WidgetPayloads <- function(html) {
  m <- stringr::str_match_all(
    html,
    '<script type="application/json" data-for="([^"]*)">(.*?)</script>'
  )[[1]]
  stats::setNames(
    lapply(m[, 3], function(p) jsonlite::fromJSON(p, simplifyVector = FALSE)$x),
    m[, 2]
  )
}
