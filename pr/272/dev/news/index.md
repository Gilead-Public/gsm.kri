# Changelog

## gsm.kri (development version)

## gsm.kri v1.6.0

This minor release introduces the Premature Deaths reporting module and
adds cross-study sorting and filtering capabilities.

**New Features:**

- Add Premature Deaths report module with interactive charts and patient
  listing
  ([\#221](https://github.com/Gilead-BioStats/gsm.kri/issues/221),
  [\#223](https://github.com/Gilead-BioStats/gsm.kri/issues/223))
  - Five-category classification of death timing via
    [`pd_Classify()`](https://gilead-biostats.github.io/gsm.kri/dev/reference/pd_Classify.md)
    ([\#246](https://github.com/Gilead-BioStats/gsm.kri/issues/246))
  - Bucket bar charts with count/percent toggle, on-bar labels, and
    range slider
    ([\#223](https://github.com/Gilead-BioStats/gsm.kri/issues/223),
    [\#246](https://github.com/Gilead-BioStats/gsm.kri/issues/246),
    [\#253](https://github.com/Gilead-BioStats/gsm.kri/issues/253))
  - Randomization-to-death scatter plot with fixed shared range across
    study/country/site views
    ([\#247](https://github.com/Gilead-BioStats/gsm.kri/issues/247))
  - Death-reason distribution chart with country-reactive filtering
    ([\#254](https://github.com/Gilead-BioStats/gsm.kri/issues/254))
  - Patient listing with site/country filter, eligibility status, and
    download button
    ([\#249](https://github.com/Gilead-BioStats/gsm.kri/issues/249))
  - Overview preamble with death-breakdown sub-line and ≤30 / 31–90 day
    split
    ([\#250](https://github.com/Gilead-BioStats/gsm.kri/issues/250),
    [\#252](https://github.com/Gilead-BioStats/gsm.kri/issues/252))
  - Sticky bucket-bar count/percent toggle and chip-strip filter UI
    ([\#253](https://github.com/Gilead-BioStats/gsm.kri/issues/253))
- Add patient-level premature-death workflow `pat0015` with configurable
  window
  ([\#221](https://github.com/Gilead-BioStats/gsm.kri/issues/221))
- Derive Treatment Related status from `deathcls` + fatal related AE
  ([\#248](https://github.com/Gilead-BioStats/gsm.kri/issues/248))
- Add eligibility status derivation via
  [`pd_EligibilityStatus()`](https://gilead-biostats.github.io/gsm.kri/dev/reference/pd_EligibilityStatus.md)
  ([\#249](https://github.com/Gilead-BioStats/gsm.kri/issues/249),
  [\#250](https://github.com/Gilead-BioStats/gsm.kri/issues/250))
- Add sort-by-enrollment option to Cross-Study Site Risk Score widget
- Recalculate site metrics from the cross-study study filter selection

**Bug Fixes:**

- Fix country cross-filter and absent country key guard in
  premature-death charts
  ([\#222](https://github.com/Gilead-BioStats/gsm.kri/issues/222))
- Fix `cou0015` to exclude subjects without a randomization date from
  the cohort
  ([\#247](https://github.com/Gilead-BioStats/gsm.kri/issues/247))
- Fix plotly scalar-text bug by using `customdata` for hover tooltips
- Remove risk score weight from `cou0015` workflow
- Fix overlapping sticky bucket toggle placement in report
  ([\#253](https://github.com/Gilead-BioStats/gsm.kri/issues/253))
- Ignore inactive workflows
  ([\#237](https://github.com/Gilead-BioStats/gsm.kri/issues/237))

## gsm.kri v1.5.2

This patch release fixes report display issues on the pkgdown site and
renders missing examples.

**Bug Fixes:** - Fix overlapping summary table and text in Site/Country
Report examples on the pkgdown site
([\#240](https://github.com/Gilead-BioStats/gsm.kri/issues/240)) -
Render missing pkgdown examples
([\#228](https://github.com/Gilead-BioStats/gsm.kri/issues/228))

## gsm.kri v1.5.1

This patch release updates the GitHub action workflows to align with the
new federated action framework in `gsm.utils`

## gsm.kri v1.5.0

This minor release includes new workflows/tests and CI automation, plus
performance-focused improvements to the qcthat testing infrastructure.

**Changes:** - Add test-data caching helpers and new tests (cache, pipe
export, gt utilities), and refactor qual test data setup to use cached
mapped data. - Introduce new “Deaths in First 90 Days / Premature Death”
KRI workflows (site + country) and expand Cross-Study SRS widget study
filtering to multi-select. - Migrate/replace qcthat GitHub Actions
workflows.

## gsm.kri v1.4.1

This patch release addresses the following issues:

- Updates bug in cou0014 metric to use Identity method instead of Normal
  Approximation
- Converts example R scripts to Rmd format with proper indexing for
  documentation using new gsm.utils implementation
- Streamlines GitHub Actions workflow for releases

## gsm.kri v1.4.0

This minor release updates the comprehensive site risk score (SRS)
functionality in gsm.kri v1.4.0, including calculation methods,
cross-study visualization capabilities, and extensive test coverage.
Additionally, this release does the following: - Introduces new
visualization widgets for time series, bar charts, and cross-study risk
score display - Expands vignette documentation with detailed SRS
methodology and implementation examples - Adds comprehensive test suite
covering all KRI types with updated YAML workflow configurations - Adds
new Inclusion/Exclusion Violation Rate KRI (0014)

## gsm.kri 1.3.2

This patch release addresses a bug that was impacting the country-level
KRI report.

## gsm.kri 1.3.1

This patch release addresses a bug related to the `gsm.viz`
implementation of site risk score.

## gsm.kri 1.3.0

This release adds a new Site Risk Score metric that calculates weighted
site-level risk across multiple KRIs. In short, the new default workflow
has the following steps:

- KRI Flags are given weights using the new `RiskScoreWeight` parameter
  in the `yaml` workflows for each KRI.
- Site-level risk scores are calculated using the new
  [`CalculateRiskScore()`](https://gilead-biostats.github.io/gsm.kri/dev/reference/CalculateRiskScore.md)
  function.
- Site Risk Scores are saved in a new Metric `srs0001` via a new
  standard workflow
- A column showing site risk scores has been added to the KRI report via
  update in `gsm.viz`

See the new Site Risk Score vignette for full implementation details.
Other minor updates are described below.

Minor Updates: - Update Issue Templates and Contributor Guidelines - Add
GitHub Actions for tarball creation upon release

## gsm.kri 1.2.2

This patch release fixes a bug in `Report_KRI.Rmd` that produced an
error in LaTeX compilation of the report output.

## gsm.kri 1.2.1

This patch release addresses changes to an `.rda` object updated in
`gsm.core` v1.1.3.

## gsm.kri 1.2.0

This minor release introduces new chart configuration functionality,
refactors widget generation to support additional settings and unified
output labels, and adds a new flag‐change report. Key changes:

- Add MakeChartConfig() helper and propagate … into widgets and
  Visualize_Metric()
- Refactor widgets to return a labeled lWidget with output_label
  attribute
- Introduce Report_FlagChange() using updates from gsm.reporting v1.1.0

## gsm.kri 1.1.2

This patch release updates the following yaml files in `/2_metrics` to
update default accrual thresholds

- kri0005.yaml
- kri0006.yaml
- kri0007.yaml
- kri0008.yaml
- kri0009.yaml
- kri0010.yaml
- kri0011.yaml
- cou0005.yaml
- cou0006.yaml
- cou0007.yaml
- cou0008.yaml
- cou0009.yaml
- cou0010.yaml
- cou0011.yaml

## gsm.kri 1.1.1

This patch release updates the description file to incorporate min
version for [gsm.core](https://gilead-biostats.github.io/gsm.core).

## gsm.kri v1.1.0

This minor release adds a new KRI along with a few other small fixes.

- PK Compliance Rate KRI workflows have been added as workflow 0013.
- Remove unnecessary lower bound thresholds for the Data Quality KRIs.
- All workflows now use the new FlagAccrual() functionality, so
  AccrualMetric and AccrualThreshold have been added to the `meta` of
  each yaml.

## gsm.kri v1.0.0

We are happy to announce the first major release of the `gsm.kri`
package, which houses the metric and module workflows, as well as all
visualization functions and widgets for the GSM pipeline.

#### Key Enhancements:

- **Updated KRI Descriptions and Templates:**  
  The descriptions of Key Risk Indicators (KRIs) have been updated to
  improve clarity and understanding based on Risk Advisor feedback.
  [PR](https://github.com/Gilead-BioStats/gsm.kri/pull/27)
  [\#27](https://github.com/Gilead-BioStats/gsm.kri/issues/27)

- **Qualification Report GitHub Actions (GHA):**  
  A new GitHub Actions workflow for generating qualification reports has
  been added, automating the process and ensuring better integration
  with the overall pipeline.  
  [PR](https://github.com/Gilead-BioStats/gsm.kri/pull/33)
  [\#33](https://github.com/Gilead-BioStats/gsm.kri/issues/33)

- **Update to gsm.viz 2.2:**  
  The package has been updated to use `gsm.viz` version 2.2, bringing
  new visualization capabilities and updates.  
  [PR](https://github.com/Gilead-BioStats/gsm.kri/pull/36)
  [\#36](https://github.com/Gilead-BioStats/gsm.kri/issues/36)

- **Replacement of clindata with gsm.datasim:**  
  In line with updates across other GSM packages, `clindata` has been
  replaced with the `gsm.datasim` package.  
  [PR](https://github.com/Gilead-BioStats/gsm.kri/pull/34)
  [\#34](https://github.com/Gilead-BioStats/gsm.kri/issues/34)

- **“How to Add a New KRI” Vignette:**  
  A new vignette has been added that provides a step-by-step guide on
  how to add a new KRI to the package, making it easier for users to
  extend and customize the package for their needs.  
  [PR](https://github.com/Gilead-BioStats/gsm.kri/pull/29)
  [\#29](https://github.com/Gilead-BioStats/gsm.kri/issues/29)

#### Other Updates:

- Several bug fixes have been applied to improve stability and
  functionality.

For more detailed information, please refer to the pull requests linked
above.

## gsm.kri v0.0.1

This initial release migrates the KRI-specific functions, workflows,
widgets and documentation from `{gsm}` to
[gsm.kri](https://github.com/Gilead-BioStats/gsm.kri).
