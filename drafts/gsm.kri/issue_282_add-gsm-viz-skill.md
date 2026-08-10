<!-- STATUS: Posted to https://github.com/Gilead-BioStats/gsm.kri/issues/282 -->
<!-- GITHUB_PROPERTIES: Labels: user request, Assignee: @me -->
This Issue was drafted by GitHub Copilot using GPT-5.4 mini and reviewed by @michkam89

# Add the gsm.viz bundle update skill to gsm.kri

## Task Summary
Create a repo-local `update-gsm-viz-bundle` skill in `gsm.kri` so future `gsm.viz` bundle upgrades can be handled with a repeatable, repo-specific workflow.

## Problem / Rationale
Recent work on [gsm.roadmap #120](https://github.com/Gilead-BioStats/gsm.roadmap/issues/120) moves premature-death charting toward `gsm.viz`. That increases the likelihood of additional vendored bundle updates in `gsm.kri`, and the current upgrade path is easy to drift or misapply.

This package needs a dedicated skill that documents the expected vendoring workflow so maintainers have a clear, repeatable process for future `gsm.viz` upgrades.

## Scope
- Add a new `update-gsm-viz-bundle` skill under the repository's `.github/skills` area.
- Make the skill discoverable from the repo's agent guidance where appropriate.
- Document the correct vendoring workflow for `gsm.viz` bundle updates.
- Keep the change focused on the upgrade process rather than the chart migration itself.

## Proposed Approach (Optional)
- Review existing agent guidance and repository docs for the best insertion point.
- Add or reference the skill in the package's workflow documentation.
- Verify the resulting guidance is consistent with the `gsm.viz` vendoring process used in the package.

## QC Approach
In addition to standard QC (e.g. code reviews, automated checks) the following QC measures will be implemented:

[ ] Qualification Test via Double Programming
[ ] Unit Tests
[ ] User Tests (e.g. visual comparison)
