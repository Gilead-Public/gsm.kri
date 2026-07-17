# Premature-death category levels

The five categories, in precedence order: death within 30 days, death
31-\`nWindowDays\` days, study discontinuation within the window, alive
at the window (follow-up \>= window), and alive prior to the window
(follow-up \< window). Shared by the bucket bar, the scatter, and the
report so labels and colors stay in lockstep.

## Usage

``` r
pd_CategoryLevels(nWindowDays)
```

## Arguments

- nWindowDays:

  \`numeric\` Premature-death window in days.

## Value

A named length-5 \`character\` vector keyed \`death30\`, \`death3190\`,
\`discont\`, \`alive_at\`, \`alive_prior\` (precedence order). The names
are a stable internal contract; the label strings are what render.
