# Report_FlagOverTime returns the expected object

    Code
      x$`_data`
    Output
      # A tibble: 9 x 7
        GroupLevel GroupID MetricID  Abbreviation FlagChange `2025-01-31` `2025-02-28`
        <chr>      <chr>   <chr>     <chr>        <lgl>             <int>        <int>
      1 Site       0X2516  Analysis~ AE           FALSE                 0            0
      2 Site       0X2516  Analysis~ SAE          FALSE                -1           -1
      3 Site       0X2516  Analysis~ PD           TRUE                  1            0
      4 Site       0X2675  Analysis~ AE           TRUE                  1            0
      5 Site       0X2675  Analysis~ SAE          TRUE                  2            0
      6 Site       0X2675  Analysis~ PD           FALSE                 0            0
      7 Site       0X999   Analysis~ AE           TRUE                  1            0
      8 Site       0X999   Analysis~ SAE          TRUE                  2            1
      9 Site       0X999   Analysis~ PD           FALSE                 0            0

