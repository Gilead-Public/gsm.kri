# Report_FlagOverTime returns the expected object

    Code
      x$`_data`
    Output
      # A tibble: 435 x 8
         GroupLevel GroupID MetricID Abbreviation FlagChange `2024-12-31` `2025-01-31`
         <chr>      <chr>   <chr>    <chr>        <lgl>             <int>        <int>
       1 Site       0X031   Analysi~ AE           FALSE                NA           NA
       2 Site       0X031   Analysi~ SAE          FALSE                NA           NA
       3 Site       0X031   Analysi~ PD           FALSE                NA           NA
       4 Site       0X103   Analysi~ AE           FALSE                NA           NA
       5 Site       0X103   Analysi~ SAE          FALSE                NA           NA
       6 Site       0X103   Analysi~ PD           FALSE                NA           NA
       7 Site       0X1091  Analysi~ AE           FALSE                NA           NA
       8 Site       0X1091  Analysi~ SAE          FALSE                NA           NA
       9 Site       0X1091  Analysi~ PD           FALSE                NA           NA
      10 Site       0X126   Analysi~ AE           FALSE                NA            0
      # i 425 more rows
      # i 1 more variable: `2025-02-28` <int>

