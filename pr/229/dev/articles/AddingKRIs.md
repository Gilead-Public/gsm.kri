# Step-by-Step Guide to add a new KRI

## Overview

This vignette outlines the necessary analytics tasks required before a
new Key Risk Indicator (KRI), Quality Tolerance Limit (QTL), or similar
metric can be put into production. Once a subject-level data listing is
received from the source system and incorporated into our monthly
snapshots, a structured workflow ensures seamless integration of the new
metric. This process includes updates to the GSM data model, creation of
a KRI workflow, qualification testing, and incorporation into reporting
outputs. By following these steps, we maintain data integrity, ensure
metric accuracy, and support risk signal generation and reporting
functionalities.

## Adding a new KRI Step-by-Step

Once a subject level data listing is provided from a source system and
those tables have been added to our monthly snapshots, we have the
following analytics tasks to complete before a new metric (KRI/QTL, etc)
can be put in to production.

1.  Make needed updates to gsm data model
2.  Create a KRI workflow
3.  Add qualification test(s) ensuring that the metric is behaving as
    expected for test data.  
4.  Steps to incorporate metric into optional reporting outputs
    - Add new metrics to apps/reports
    - Generate Risk signals for `{grail}`
    - Update existing Study scripts to add the metrics

Below we get into more detail for each of these steps

### Make updates to the gsm data model

For each KRI, there will be data requirements that need to be specified
as the first step to incorporating the KRI into a final report. The
first step in this process is to ensure that the data is
programmatically available to be pulled down from a centralized data
store. Once this is confirmed, an issue is to be filed in
[gsm.mapping](https://github.com/Gilead-BioStats/gsm.mapping) repo using
the `Add New Domain` issue template and filling in the relevant
information.

With the issue filed, and the requirements laid out, a specification
mapping file is created that indicates the name of each data source, and
all required fields from each respective data source along with their
data types. An example of this specification yaml file is below. More
details about the construction of these files can be found in
[gsm.mapping](https://github.com/Gilead-BioStats/gsm.mapping) package
documentation.

    meta:
      Type: Mapped
      ID: PD
      Description: Protocol Deviation Data Mapping 
      Priority: 1
    spec: 
      Raw_PD:
        subjid:
          type: character
          source_col: subjectenrollmentnumber
        deemedimportant:
          type: character
    steps:
      - output: Mapped_PD
        name: =
        params:
          lhs: Mapped_PD
          rhs: Raw_PD

It is possible that some of the domains that are needed for a given KRI
may already be mapped in
[gsm.mapping](https://github.com/Gilead-BioStats/gsm.mapping). In this
case, check the existing spec for that domain for all relevant fields,
and if any are missing, create an issue to
`Request New Domain or Variable`, and fill in all fields. Once the edits
have been made following the [Contributor
Guidelines](https://gilead-biostats.github.io/gsm.core/articles/ContributorGuidelines.html),
submit a Pull Request to merge in the edits required for adding this new
KRI.

Add support for new tables in `gsm.datasim` for use in the gismo test
environment.

### Creating a KRI Workflow

To implement a new Key Risk Indicator (KRI) within the system, we must
establish workflows and update several existing analytical functions to
align with the new requirements. This process ensures that the new KRI
is accurately integrated into our analytics framework and reporting
structure. A more in depth discussion of the Analytics pipeline is
outlined in this
[vignette](https://gilead-biostats.github.io/gsm.core/articles/DataAnalysis.html)

#### Creating and Customizing YAML Workflow Files

The first step is to create or modify YAML workflow files that define
the new KRI. These files include:

- **Metric Metadata:** Define key details such as the metric’s
  description, numerator, denominator, and other relevant
  specifications. Each KRI must have a unique identifier that follows
  the existing naming convention (e.g., `kri0013` for
  [gsm.kri](https://github.com/Gilead-BioStats/gsm.kri) or `kri0002ep`
  for `{gsm.endpoints}`).
- **Metric Data Specification:** Ensure the data specifications align
  with updates made to the data model. This step guarantees consistency
  in data interpretation and calculation.
- **Metric Workflow Definition:** Specify the functions and parameters
  required to calculate the metric. This typically follows the standard
  [gsm.core](https://gilead-biostats.github.io/gsm.core) [analysis
  workflow](https://gilead-biostats.github.io/gsm.core/articles/DataAnalysis.html),
  ensuring consistency with existing metrics.

#### Creating Country-Level Workflows (If Applicable)

If country-level metrics are needed, parallel workflows must be created
within the [gsm.kri](https://github.com/Gilead-BioStats/gsm.kri)
package. These workflows allow for localized risk assessment and
reporting, providing granularity in data analysis.

#### Updating Core Analytical Functions

The next step involves updating
[gsm.core](https://gilead-biostats.github.io/gsm.core) analytics
functions to ensure they can accurately compute the new KRI. This may
include modifying existing logic, incorporating additional parameters,
or adjusting calculations to reflect the new metric’s requirements. This
step may not be necessary for every new metric.

#### Enhancing Visualization and Reporting Functionality

Finally, any necessary updates should be made to the
[gsm.kri](https://github.com/Gilead-BioStats/gsm.kri) and `{rbm-viz}`
packages to support visualization and widget functionality. This ensures
that the new KRI is correctly represented in dashboards and reports,
providing clear and actionable insights for stakeholders. This step may
not be necessary for every new metric.

By following these steps, we ensure that the new metric is seamlessly
integrated into our analytics framework, maintaining consistency,
accuracy, and usability across the system.

#### Add qualification test(s)

To ensure that the metric is behaving as expected for test data, a new
test or multiple tests must be written and documented in the `{gsm.qc}`
package. `{gsm.qc}` uses the
[qcthat](https://gilead-biostats.github.io/qcthat/) framework, which is
detailed in the package documentation
[here](https://gilead-biostats.github.io/qcthat/).

### Steps to Incorporate a Metric into Reporting Outputs

Once the new Key Risk Indicator (KRI) has been integrated into the
analytics framework, it must be incorporated into reporting outputs to
ensure visibility and usability. This process involves updating existing
reports or creating new ones and integrating the metric into the
application specified in `{gsm.app}`.

#### Adding New Metric(s) to Reports

- **Integrate into Existing Reports:** If the new metric aligns with the
  structure of current KRI reports, add it to the appropriate reports to
  maintain consistency in analysis and visualization.
- **Create a New Report (If Needed):** If the new metric requires unique
  data representation or analysis, develop a standalone report tailored
  to its specifications. This ensures that the metric is properly
  contextualized for stakeholders.

#### Updating the Application for Metric Integration

- **Add the Metric to {gsm.app}:** If the metric follows standard KRI
  functionality, integrate it into the existing application as a
  standard KRI. This ensures that it is accessible and consistent with
  other KRIs.
- **Develop a New Module (If Required):** If the metric requires
  specialized functionality beyond the existing KRI framework, create a
  new module within {gsm.app} to support its unique requirements. This
  may involve custom visualizations, interactions, or calculations
  specific to the new metric.

#### Generate Risk signals for ADO

In order to incorporate this metric into the ticketing system used by
the risk advisers to address flagged sites or participants, `{grail}`
must be updated to add default actions for risk signals produced by this
metric.

#### Update Study scripts to add the metrics

To ensure that the new Key Risk Indicator (KRI) is correctly integrated
into ongoing studies, we must update existing study scripts. These
scripts are responsible for processing study-level data, generating risk
signals, and ensuring that the new metric is included in all relevant
analyses.

Review the current study scripts to determine which ones require
modifications to accommodate the new metric. Identify any dependencies
or interactions between the new metric and existing KRIs, ensuring that
all calculations remain consistent, and the Priority tag in the `meta`
yamls are appropriately assigned.

By following these steps, we ensure that the new KRI is effectively
incorporated into reporting modules and applications, enabling the study
team to monitor and evaluate the metric for a given study.
