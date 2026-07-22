TestAtLogLevel <- function(chrLevel = "ERROR", envir = rlang::caller_env()) {
  withr::defer(
    gsm.core::SetLogLevel("DEBUG"),
    envir = envir
  )
  gsm.core::SetLogLevel(toupper(chrLevel))
}
