# Report_FlagOverTime returns the expected object

    Code
      x$`_data`
    Output
      # A tibble: 9 x 7
        GroupLevel GroupID MetricID  Abbreviation FlagChange `2025-01-31` `2025-02-28`
        <chr>      <chr>   <chr>     <chr>        <lgl>             <int>        <int>
      1 Site       0X126   Analysis~ AE           TRUE                  0           -1
      2 Site       0X126   Analysis~ SAE          FALSE                 0            0
      3 Site       0X126   Analysis~ PD           FALSE                 0            0
      4 Site       0X1755  Analysis~ AE           FALSE                -1           -1
      5 Site       0X1755  Analysis~ SAE          FALSE                 0            0
      6 Site       0X1755  Analysis~ PD           FALSE                 0            0
      7 Site       0X239   Analysis~ AE           TRUE                  0           -1
      8 Site       0X239   Analysis~ SAE          FALSE                 0            0
      9 Site       0X239   Analysis~ PD           FALSE                 0            0

