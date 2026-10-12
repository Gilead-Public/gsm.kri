TestAtLogLevel <- function(chrLevel = "FATAL", envir = rlang::caller_env()) {
  lvlStart <- gsm.core::GetLogLevel()
  withr::defer(gsm.core::SetLogLevel(lvlStart), envir = envir)
  gsm.core::SetLogLevel(toupper(chrLevel))
  local_quiet_workr(envir = envir)
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
