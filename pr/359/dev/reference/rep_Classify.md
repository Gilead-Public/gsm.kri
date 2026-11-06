# Classify participants and measures for the Repeat Measurements report

\`r lifecycle::badge("experimental")\`

Windows every measure of every enrolled participant once with the engine
behind \[Detect_ConsecutiveRepeats()\], the \`kri0020\` / \`cou0020\`
metric function, so every section of the report reads one frame. Summing
\`Numerator\` and \`Denominator\` by site or country reproduces the
metrics.

A participant's flag for a measure comes from \[gsm.core::Flag()\] with
one of two rules: \* \`"count"\` (default): repeating windows
\`Numerator\` against \`vFlagThresholds\` (default Amber at 2, Red at 3
or more). \* \`"rate"\`: \`Numerator / Denominator\` against
\`vFlagThresholds\` (default the site-level \`kri0020\` / \`cou0020\`
\`Threshold\` in \`dfMetrics\`, else 20% / 30%; see
\[rep_FlagThresholds()\]).

Amber is at or above the first threshold, Red at or above the second.
Participants with fewer than \`nMinWindows\` windows are \`Not
evaluable\`. Height, BSA and any other numeric \`Mapped_VS\` column are
windowed and flagged the same way, although they have no KRI. With
\`sysbp\` and \`diabp\`, paired blood pressure (\`bp\`, see
\[rep_Vitals()\]) is added.

## Usage

``` r
rep_Classify(
  lListings,
  dfMetrics = NULL,
  nWindowLength = NULL,
  strFlagRule = c("count", "rate"),
  vFlagThresholds = NULL,
  nMinWindows = 1
)
```

## Arguments

- lListings:

  \`list\` with \`Mapped_SUBJ\` (enrolled participants with \`subjid\`,
  \`invid\` and \`country\`; a missing \`invid\` or \`country\` is shown
  as \`"(missing)"\`) and \`Mapped_VS\`.

- dfMetrics:

  \`data.frame\` Reporting metrics; the \`kri0020\*\` rows supply the
  window length and the rate thresholds. Optional.

- nWindowLength:

  \`numeric\` Window length when \`dfMetrics\` has none. Default
  \`NULL\`, meaning 3. When \`dfMetrics\` has a window length, it wins
  and a different \`nWindowLength\` raises a warning.

- strFlagRule:

  \`character\` \`"count"\` or \`"rate"\`.

- vFlagThresholds:

  \`numeric\` Amber and Red thresholds: repeating windows for
  \`"count"\`, a proportion of windows for \`"rate"\`. Default \`NULL\`:
  see Details.

- nMinWindows:

  \`numeric\` Windows a participant needs for a flag. Default 1.

## Value

A \`list\`: \* \`participants\`: one row per participant and vital with
\`studyid\`, \`country\`, \`invid\`, \`subjid\`, \`vital\`, \`metric\`,
\`n_records\` (non-missing measurements), \`Numerator\`,
\`Denominator\`, \`rate\` and \`flag\` (a factor with levels \`Red\`,
\`Amber\`, \`Green\` and \`Not evaluable\`). \* \`measurements\`: one
row per non-missing measurement with \`studyid\`, \`country\`,
\`invid\`, \`subjid\`, \`record\`, \`visit\`, \`vs_dt\`, \`vital\`,
\`value\` (\`NA\` for paired BP), \`value_text\` (the displayed value),
\`seq\`, \`in_repeat_window\` and \`window_start\` (the repeat-window
marks used by \[Detect_ConsecutiveRepeats()\]). \* \`records\`: the
enrolled participants' \`Mapped_VS\` rows, with \`country\` and
\`invid\` from \`Mapped_SUBJ\` and a \`record\` key that
\`measurements\` refers to. \* \`vitals\`: the rows of \[rep_Vitals()\]
in the report, plus any other numeric \`Mapped_VS\` column. \* \`meta\`:
\`window_length\`, \`window_source\` (\`"metrics"\`, \`"argument"\` or
\`"default"\`), \`rule\`, \`thresholds\` (Amber, Red), \`min_windows\`
and \`split_sites\` (sites whose participants have more than one
country; a warning lists them).
