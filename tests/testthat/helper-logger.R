TestAtLogLevel <- function(chrLevel = "FATAL", envir = rlang::caller_env()) {
  lvlStart <- gsm.core::GetLogLevel()
  withr::defer(gsm.core::SetLogLevel(lvlStart), envir = envir)
  gsm.core::SetLogLevel(toupper(chrLevel))
  local_quiet_workr(envir = envir)
  local_quiet_duckdb(envir = envir)
}

# duckdb prints a storage-location notice on each new connection unless the
# home is chosen explicitly. Choosing duckdb's own default (~/.duckdb) keeps
# behavior identical while silencing the notice.
local_quiet_duckdb <- function(envir = rlang::caller_env()) {
  strHomeVar <- if (.Platform$OS.type == "windows") "USERPROFILE" else "HOME"
  withr::local_options(
    duckdb.home = file.path(Sys.getenv(strHomeVar), ".duckdb"),
    .local_envir = envir
  )
}

# WORKAROUND: workr::LogMessage() emits unconditionally, ignoring the gsm.core
# log level. Until workr respects it, swap in a level-aware version for the
# duration of the calling test. Remove once fixed upstream.
local_quiet_workr <- function(envir = rlang::caller_env()) {
  vRank <- c(FATAL = 1, ERROR = 2, WARN = 3, INFO = 4, DEBUG = 5, TRACE = 6)
  testthat::local_mocked_bindings(
    LogMessage = function(level = "info", message, cli_detail = NULL) {
      nMsg <- vRank[[toupper(level)]]
      nMax <- vRank[[toupper(gsm.core::GetLogLevel())]]
      if (nMsg > nMax) {
        return(invisible(NULL))
      }
      msg <- glue::glue(message, .envir = parent.frame())
      message("[", toupper(level), "] ", msg)
    },
    .package = "workr",
    .env = envir
  )
}

# Report renders stream knitr progress, pandoc output, and log lines (which
# may go to stdout or stderr depending on the logger) to the console.
quiet_render <- function(expr) {
  TestAtLogLevel()
  out <- NULL
  # capture.output() prints visible values, so keep the inner result invisible.
  utils::capture.output(
    invisible(utils::capture.output(
      out <- suppressMessages(expr),
      type = "output"
    )),
    type = "message"
  )
  out
}
