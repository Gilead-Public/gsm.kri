---
name: update-gsm-viz-bundle
description: Replace the gsm.viz bundle vendored by gsm.vizr from an official release tag or an explicit development commit, and update every package reference and regression pin. Run from the gsm.vizr repository only.
---
# Update the gsm.viz bundle

The bundle is consumed by downstream applications at runtime through
`gsm.vizr::html_dependency_gsm_viz()` and vendors no copy of its own.

Use this skill when upgrading the gsm.viz assets vendored by `gsm.vizr`, including temporary development bundles from an immutable upstream commit. All repository-relative paths below refer to the **gsm.vizr** working tree.

## Inputs
- Required: target version as `X.Y.Z` (without `v`).
- Optional: upstream repository; default to `Gilead-Public/gsm.viz`.
- Optional: upstream commit SHA, abbreviated to at least 7 characters or full-length. Supplying it selects development mode; omitting it selects release mode.
- Development mode only: a numeric manifest version accepted by R's `package_version()`, such as `2.4.1-550`.
Set `VERSION` and `UPSTREAM`. In release mode, set `TAG="v${VERSION}"`. In development mode, set `COMMIT_REF` and `MANIFEST_VERSION`; verification below derives the canonical `SOURCE_SHA` and `SHORT_SHA`. Do not infer an input from a branch, PR, package manifest, or directory name.
## Safety gates
1. Read `AGENTS.md`, inspect `git status`, and do not overwrite unrelated changes.
2. Run the repository's required pre-change setup and baseline:
   ```sh
   R --quiet --vanilla -e 'pak::pak()'
   R --quiet --vanilla -e 'devtools::test(reporter = "check")'
   ```
   Stop and ask if the baseline fails.
3. Select and verify exactly one source mode:
   - **Release mode:** verify the exact release with GitHub CLI:
     ```sh
     gh release view "$TAG" --repo "$UPSTREAM" \
       --json tagName,isDraft,isPrerelease,publishedAt,url
     SOURCE_SHA="$(gh api "repos/$UPSTREAM/commits/$TAG" --jq .sha)"
     ```
     Continue only when `tagName` equals `TAG`, `isDraft` and `isPrerelease` are both false, and the release is published.
   - **Development mode:** require `COMMIT_REF` to match `^[0-9a-fA-F]{7,40}$`, then resolve it to one canonical commit:
     ```sh
     SOURCE_SHA="$(gh api "repos/$UPSTREAM/commits/$COMMIT_REF" --jq .sha)"
     test "$(printf '%s' "$SOURCE_SHA" | cut -c1-${#COMMIT_REF})" = \
       "$(printf '%s' "$COMMIT_REF" | tr '[:upper:]' '[:lower:]')"
     SHORT_SHA="$(printf '%s' "$SOURCE_SHA" | cut -c1-7)"
     R --quiet --vanilla -e "package_version('$MANIFEST_VERSION')"
     ```
     Stop if GitHub cannot resolve the abbreviation uniquely or the resolved SHA does not have the requested prefix. A branch name, PR number/head, non-hex reference, or workflow artifact is not an acceptable substitute. Development mode is provisional and must not be presented as a released upgrade.
4. Record the source mode, `VERSION`, `SOURCE_SHA`, upstream repository, and asset checksums in the change description. In release mode also record `TAG` and release URL. Stop if the selected source cannot be resolved exactly; in release mode also stop for an absent, draft, or prerelease release.

## Inspect before editing
Discover the current state; do not assume a fixed widget list:
```sh
find inst/htmlwidgets/lib -maxdepth 1 -type d -name 'gsm.viz-*' -print
rg -n 'name:\s*gsmViz|gsm\.viz-|gsmViz' inst tests .github
git log --oneline --all -- inst/htmlwidgets/lib 'inst/htmlwidgets/*.yaml'
```
Identify every YAML dependency with `name: gsmViz`, every exact bundle/version pin, provisional note, and bundle safeguard. Inspect at least:
- gsm.vizr's single-bundle safeguard test (the `vendored-bundle` testthat file) and its bundle-export assertions
- `R/dependency.R` — defines `html_dependency_gsm_viz()`, the exported dependency other packages consume; its `version` must track the bundle directory
- widget dependency assertions found by the search

Downstream consumers do not vendor the bundle and must not be edited to do so. gsm.kri holds a browser regression (`tests/playwright/bundle-regression.spec.js`) that renders reports against whatever bundle gsm.vizr serves; after a bump, re-run it from the gsm.kri repository to confirm the new bundle did not change report structure.
## Source the assets
Work in a temporary checkout of the verified immutable source. Resolve its `HEAD` and require it to equal `SOURCE_SHA`.
```sh
TMP="$(mktemp -d)"
git init "$TMP/gsm.viz"
git -C "$TMP/gsm.viz" remote add origin "https://github.com/$UPSTREAM.git"
git -C "$TMP/gsm.viz" fetch --depth 1 origin "$SOURCE_SHA"
git -C "$TMP/gsm.viz" checkout --detach FETCH_HEAD
test "$(git -C "$TMP/gsm.viz" rev-parse HEAD)" = "$SOURCE_SHA"
```
Obtain `index.js` and `index.js.map` only from that checkout:
- Prefer the files committed at the verified source.
- If either is not committed, run `npm ci` and the upstream bundle command from that checkout (normally `npm run bundle`). Use the lockfile and build scripts from the same verified source; do not substitute newer dependencies or tooling.
- Stop if the build is not lockfile-based, fails, omits the source map, or cannot be reproduced from the verified source.
Create a fresh staging directory named `gsm.viz-${VERSION}` in release mode or `gsm.viz-${VERSION}-dev.${SHORT_SHA}` in development mode and copy those two files into it. Copy the required `main.css` unchanged from the current vendored bundle because gsm.viz does not publish that package integration stylesheet; compare its SHA-256 before and after copying. Do not rename an old/provisional directory or reuse its JavaScript artifacts.
Verify all three staged files are non-empty, `index.js.map` parses as JSON, and the bundle/source map identify no unexpected local paths. Capture SHA-256 checksums. Remove the temporary checkout when finished.
## Replace and repoint
1. Replace the existing bundle directory with the staged directory in one change. Do not add alongside it.
2. Update every discovered `gsmViz` YAML dependency:
   - release mode: `version: ${VERSION}` and `src: htmlwidgets/lib/gsm.viz-${VERSION}`
   - development mode: `version: ${MANIFEST_VERSION}` and `src: htmlwidgets/lib/gsm.viz-${VERSION}-dev.${SHORT_SHA}`
   - retain `script: index.js` and each widget's existing `stylesheet: main.css` declaration
3. Update all exact test pins and widget dependency assertions to the selected manifest version and directory.
4. Remove obsolete bundle directories, version strings, and source references. In release mode, remove all PR-head SHAs and provisional comments. In development mode, replace stale provisional references and add a concise `PROVISIONAL` comment to the exact bundle pin stating `SOURCE_SHA` and that a release-tag rebuild is required before merge/release. Search again rather than relying on today's filenames:
   ```sh
   find inst/htmlwidgets/lib -maxdepth 1 -type d -name 'gsm.viz-*' -print
   rg -n 'gsm\.viz-|pr[0-9]+|PROVISIONAL|name:\s*gsmViz' inst tests .github
   ```
Exactly one `gsm.viz-*` directory must remain, and every manifest and exact pin must reference it. A development directory must contain its verified short SHA and must never be renamed into a release directory.
## Validate
In the **gsm.vizr** repository, run the focused safeguards and the package gate:
```sh
R --quiet --vanilla -e 'devtools::test(filter = "vendored-bundle", reporter = "check")'
R --quiet --vanilla -e 'devtools::test(reporter = "check")'
R --quiet --vanilla -e 'devtools::check(error_on = "warning")'
```
Then run gsm.vizr's own browser specs and any fixture generators affected by upstream API or rendering changes.

Because gsm.kri renders production reports against this bundle, install the updated gsm.vizr and re-run the downstream browser regression **from the gsm.kri repository**:
```sh
R CMD INSTALL <path-to-gsm.vizr>
R --quiet -e 'devtools::load_all("."); source("tests/playwright/render-kri-fixture.R")'
npm --prefix tests/playwright ci
npm --prefix tests/playwright test -- bundle-regression.spec.js
```

Do not refresh structural baselines merely to make failures pass; inspect and explain intentional rendering changes first.
Review `git diff --check`, `git status --short`, the complete diff, the single-directory invariant, and all remaining `gsm.viz` references. Stop instead of completing the upgrade if provenance is uncertain, required exports disappear, a widget throws, fingerprints drift without an understood cause, R checks warn/error, or stale provisional references remain. Never approve a development-mode bundle as the final released upgrade; repeat the workflow in release mode from the official tag before merge/release.
