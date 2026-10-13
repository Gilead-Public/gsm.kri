# Report_FlagOverTime returns the expected object

    Code
      x$`_data`
    Output
      # A tibble: 423 x 8
         GroupLevel GroupID MetricID Abbreviation FlagChange `2024-12-31` `2025-01-31`
         <chr>      <chr>   <chr>    <chr>        <lgl>             <int>        <int>
       1 Site       0X002   Analysi~ AE           FALSE                NA           NA
       2 Site       0X002   Analysi~ SAE          FALSE                NA           NA
       3 Site       0X002   Analysi~ PD           FALSE                NA           NA
       4 Site       0X012   Analysi~ AE           FALSE                NA           NA
       5 Site       0X012   Analysi~ SAE          FALSE                NA           NA
       6 Site       0X012   Analysi~ PD           FALSE                NA           NA
       7 Site       0X094   Analysi~ AE           FALSE                NA           NA
       8 Site       0X094   Analysi~ SAE          FALSE                NA           NA
       9 Site       0X094   Analysi~ PD           FALSE                NA           NA
      10 Site       0X1010  Analysi~ AE           FALSE                NA            0
      # i 413 more rows
      # i 1 more variable: `2025-02-28` <int>

