test_that("repo guidance references the gsm.viz bundle update skill (#282)", {
  agents <- readLines("AGENTS.md", warn = FALSE)

  expect_true(any(grepl("update-gsm-viz-bundle/SKILL.md", agents, fixed = TRUE)))
  expect_true(any(grepl("update gsm.viz bundles", agents, fixed = TRUE)))
})