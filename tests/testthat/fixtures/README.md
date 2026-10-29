# Test fixtures

Small, hand-built datasets with known answers. Use `gsm.core::lSource` for
realistic "normal" data. Use these files when a test needs exact expected values.

Read them with `read_fixture()` (see `helper-fixtures.R`).

## Vital signs repeat-measure fixtures (#306, #307)

| File | Contents |
|---|---|
| `vs_subj.csv` | `Mapped_SUBJ`-shaped subject table (10 subjects, 4 sites, 2 countries). |
| `vs.csv` | `Mapped_VS`-shaped wide vital signs, sorted by `subjid, vs_dt, visit`. |
| `vs_expected_subject.csv` | Hand-derived `Detect_ConsecutiveRepeats()` output (window = 3). |
| `vs_expected_group.csv` | Hand-derived site/country results for `kri0020a`/`b` and `cou0020a`/`b`. |

Expected values are worked out by hand from the rules in #307, not by running
package code. Update them by hand if the rules change.

### Weight scenarios (window = 3)

| Subject | Site | Weight values | Num / Den | Scenario |
|---|---|---|---|---|
| S01 | I1 | 70 70 70 72 73 | 1 / 3 | One run of exactly 3 |
| S02 | I1 | 60 61 62 63 | 0 / 2 | No repeats |
| S03 | I1 | 80 80 | 0 / 0 | Fewer than 3 values; excluded from rate |
| S04 | I2 | 50 50 NA 50 51 51 51 | 2 / 4 | Missing value dropped, so the run spans the gap |
| S05 | I2 | NA NA NA | 0 / 0 | All missing |
| S06 | I2 | 90 90 85 85 85 | 1 / 3 | V2 and V2U share a date; input order (by `visit`) is kept. Swapping them gives 0 |
| S07 | I3 | 100 100 100 | 1 / 1 | Exactly one window |
| S08 | I3 | 101 ... 107 | 0 / 5 | Distinct weights, but pulse is constant (5 / 5) |
| S09 | I2 | 40 ... 44 | 0 / 3 | No repeats |
| S10 | I4 | 5 5 5 | 1 / 1 | Site I4 below the accrual threshold (Denominator < 3) |

### Group results

With thresholds `0.2,0.3` (flags `0,1,2`):

- Weight: I1 = 1/5 = 0.20 (exactly at the amber boundary, so amber). I2 = 3/10 = 0.30 (exactly at the red boundary, so red). I3 = 1/6 (green). I4 is unscored because of accrual.
- Pulse: only S08 repeats, so only I3 / DE are affected. Pulse is never missing, so S05 counts toward pulse denominators even though its weight is all NA. Other vital columns have no repeats.
