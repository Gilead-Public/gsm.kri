test_that("the data block escapes < and round-trips (#320)", {
  tag <- ipc_DataScript(list(
    status = list(study = data.frame(GroupID = "</script><b>"))
  ))
  html <- as.character(tag)
  expect_match(html, 'type="application/json"', fixed = TRUE)
  expect_match(html, 'id="ipc-data"', fixed = TRUE)
  expect_false(grepl("</script><b>", html, fixed = TRUE))
  json <- sub("^<script[^>]*>(.*)</script>$", "\\1", html)
  expect_equal(jsonlite::fromJSON(json)$status$study$GroupID, "</script><b>")
})
