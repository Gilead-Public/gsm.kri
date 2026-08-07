# AGENTS.md

## Repository overview

**gsm.kri** — Good Statistical Monitoring KRIs

The Good Statistical Monitoring or ‘gsm’ suite of R packages provides a
framework for statistical data monitoring. ‘gsm.kri’ provides workflows
to generate metrics and functionality to visualize and report on these
metrics.

<https://github.com/Gilead-BioStats/gsm.kri>,
<https://gilead-biostats.github.io/gsm.kri>

### Overall structure

The project follows standard R package conventions with these key
directories:

gsm.kri/ ├── R/ \# R source code │ ├── gsm.kri-package.R \#
Auto-generated package docs │ └── \*.R \# Function definitions, 1 file
~= 1 exported function ├── .github/ │ ├── ISSUE_TEMPLATE/ \# GitHub
issue templates │ ├── skills/ \# Agent skill definitions │ └──
workflows/ \# CI/CD configurations ├── tests/testthat/ \# Test suite ├──
man/ \# Generated documentation ├── AGENTS.md \# Main agent setup file
├── DESCRIPTION \# Package metadata ├── NAMESPACE \# Auto-generated
export information ├── NEWS.md \# Changelog └── Various config files \#
.gitignore, codecov.yml, etc.

------------------------------------------------------------------------

## Standard workflow

For any feature, fix, or refactor:

1.  **Update packages**:
    [`pak::pak()`](https://pak.r-lib.org/reference/pak.html)
2.  **Run tests** — confirm passing before changes:
    `devtools::test(reporter = "check")`. If any fail, stop and ask.
3.  **Plan** — identify affected R files; check if new exports are
    needed.
4.  **Test first** — write failing test, then implement:
    `devtools::test(filter = "name", reporter = "check")`.
5.  **Implement** — minimal code to pass tests.
6.  **Refactor** — clean up, keep tests green.
7.  **Document** — document any new or changed exports.
8.  **Verify**: `devtools::check(error_on = "warning")`. Resolve
    warnings, errors, and NOTEs.

------------------------------------------------------------------------

## General

- R console: use `--quiet --vanilla`.
- Comments explain *why*, not *what*.

## Skills

| Triggers              | Path                                           |
|-----------------------|------------------------------------------------|
| tag tests with issues | @.github/skills/tag-tests-with-issues/SKILL.md |
