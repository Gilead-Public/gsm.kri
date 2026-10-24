test_that("the data block escapes < and round-trips (#320)", {
  tag <- ipm_DataScript(list(
    status = list(study = data.frame(GroupID = "</script><b>"))
  ))
  html <- as.character(tag)
  expect_match(html, 'type="application/json"', fixed = TRUE)
  expect_match(html, 'id="ipc-data"', fixed = TRUE)
  expect_false(grepl("</script><b>", html, fixed = TRUE))
  json <- sub("^<script[^>]*>(.*)</script>$", "\\1", html)
  expect_equal(jsonlite::fromJSON(json)$status$study$GroupID, "</script><b>")
})

test_that("the data block id can be set so other reports reuse it (#344)", {
  html <- as.character(ipm_DataScript(list(a = 1), strId = "rm-data"))
  expect_match(html, 'id="rm-data"', fixed = TRUE)
  expect_false(grepl("ipc-data", html, fixed = TRUE))
})
