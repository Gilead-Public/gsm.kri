test_that("repo guidance references the gsm.viz bundle update skill (#282)", {
  agents_path <- testthat::test_path("..", "..", "AGENTS.md")
  skip_if_not(file.exists(agents_path), "AGENTS.md not found (likely in installed package)")
  agents <- readLines(agents_path, warn = FALSE)

  expect_true(any(grepl("update-gsm-viz-bundle/SKILL.md", agents, fixed = TRUE)))
  expect_true(any(grepl("update gsm.viz bundles", agents, fixed = TRUE)))
})
