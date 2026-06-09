# pkgdown ignores the css: YAML parameter in menu articles, so report styles
# must be duplicated in pkgdown/extra.css (#240).

test_that("pkgdown/extra.css exists", {
  extra_css <- system.file("../pkgdown/extra.css", package = "gsm.kri")
  # system.file returns "" when the path is outside inst/; use file path instead
  extra_css_path <- file.path(
    system.file(package = "gsm.kri"),
    "..", "pkgdown", "extra.css"
  )

  skip_if_not(file.exists(extra_css_path), "pkgdown/extra.css not found (likely in installed package)")

  extra_css_content <- readLines(extra_css_path)
  extra_css_text <- paste(extra_css_content, collapse = "\n")

  expect_match(
    extra_css_text,
    "Widget_GroupOverview",
    fixed = TRUE,
    label = "extra.css must style Widget_GroupOverview"
  )

  expect_match(
    extra_css_text,
    "height:\\s*auto\\s*!important",
    label = "extra.css must override widget height to auto"
  )
})

test_that("pkgdown/extra.css contains critical selectors", {
  extra_css_path <- file.path(
    system.file(package = "gsm.kri"),
    "..", "pkgdown", "extra.css"
  )

  skip_if_not(file.exists(extra_css_path), "pkgdown/extra.css not found (likely in installed package)")

  extra_css_text <- paste(readLines(extra_css_path), collapse = "\n")

  # These selectors are critical for correct report rendering on the pkgdown site.
  critical_selectors <- c(
    ".Widget_GroupOverview",
    ".gsm-overview-table",
    ".overall-group-select",
    ".flag-container",
    ".flag-amber",
    ".flag-red"
  )

  for (selector in critical_selectors) {
    expect_match(
      extra_css_text,
      selector,
      fixed = TRUE,
      label = paste("extra.css must contain selector:", selector)
    )
  }
})
