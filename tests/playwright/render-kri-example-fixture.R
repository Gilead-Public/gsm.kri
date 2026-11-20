# Renders the Site, Country and Eligibility example pages
# (pkgdown/menus/examples) to fixture/, so kri-example-retired.spec.js and
# eligibility-example.spec.js check the pages the site deploys.
# Run from the gsm.kri package root:
#   R --quiet -e 'devtools::load_all("."); source("tests/playwright/render-kri-example-fixture.R")'
dir.create("tests/playwright/fixture", showWarnings = FALSE, recursive = TRUE)

# Rendered from a copy, so no intermediate files land next to the examples.
strCopy <- tempfile()
dir.create(strCopy)
file.copy("pkgdown/menus/examples", strCopy, recursive = TRUE)

for (strExample in c("Example_SiteReport", "Example_CountryReport", "Example_Eligibility", "Example_Eligibility_Pilot")) {
  out <- rmarkdown::render(
    file.path(strCopy, "examples", paste0(strExample, ".Rmd")),
    output_dir = normalizePath("tests/playwright/fixture"),
    envir = new.env(),
    quiet = TRUE
  )
  cat("Rendered:", out, "\n")
}
