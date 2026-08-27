# Summarize Site Risk Score Weighting

\`r lifecycle::badge("experimental")\`

Creates a user-facing explanation and table showing how each metric's
flag weights contribute to the normalized Site Risk Score (SRS).

## Usage

``` r
Report_SRSWeighting(dfMetrics, dfResults = NULL)
```

## Arguments

- dfMetrics:

  \`data.frame\` Metrics metadata containing \`MetricID\`, \`Flag\`, and
  \`RiskScoreWeight\`. When available, \`Metric\` supplies the display
  label and inactive metrics are excluded.

- dfResults:

  Optional \`data.frame\` of results used to calculate the SRS. When
  supplied, the summary includes only metrics present in these results.

## Value

An \[htmltools::tagList()\] containing explanatory text and a formatted
weighting table.

## Examples

``` r
Report_SRSWeighting(gsm.core::reportingMetrics)
#> <style>.srs-weighting-summary{color:#333}.srs-weighting-summary p{max-width:80rem} .srs-weighting-table-wrap{overflow-x:auto;margin:1rem 0} .srs-weighting-table{border-collapse:collapse;width:100%;font-size:0.95em} .srs-weighting-table caption{text-align:left;font-weight:bold;margin-bottom:.5rem} .srs-weighting-table th,.srs-weighting-table td{border:1px solid #d8d8d8;padding:.55rem .7rem;text-align:center} .srs-weighting-table thead th{background:#3c587f;color:white;vertical-align:bottom} .srs-weighting-table tbody th{text-align:left;background:#f5f5f5} .srs-weighting-table tbody tr:nth-child(even) td{background:#fafafa} .srs-weighting-maximum,.srs-weighting-share{font-weight:bold} .srs-weighting-not-configured{color:#666;font-style:italic}</style>
#> <section class="srs-weighting-summary">
#>   <h3>How metric weighting contributes to the Site Risk Score</h3>
#>   <p>Each metric assigns points according to the site's flag. The points for all metrics are added together, then divided by the total possible points and multiplied by 100 to produce the normalized SRS.</p>
#>   <p>
#>     The maximum contribution is the largest configured weight for a metric. 
#>     Its share shows how much that metric can contribute to the total possible SRS. 
#>     <strong>Total possible points: 202</strong>
#>   </p>
#>   <div class="srs-weighting-table-wrap">
#>     <table class="srs-weighting-table">
#>       <caption>Metric weights used in the Site Risk Score</caption>
#>       <thead>
#>         <tr>
#>           <th scope="col">Metric</th>
#>           <th scope="col">Low red (-2)</th>
#>           <th scope="col">Low amber (-1)</th>
#>           <th scope="col">Not flagged (0)</th>
#>           <th scope="col">High amber (+1)</th>
#>           <th scope="col">High red (+2)</th>
#>           <th scope="col">Maximum contribution</th>
#>           <th scope="col">Share of total possible SRS</th>
#>         </tr>
#>       </thead>
#>       <tbody>
#>         <tr>
#>           <th scope="row">Adverse Event Rate</th>
#>           <td>32</td>
#>           <td>16</td>
#>           <td>0</td>
#>           <td>1</td>
#>           <td>2</td>
#>           <td class="srs-weighting-maximum">32 points</td>
#>           <td class="srs-weighting-share">15.8%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Serious Adverse Event Rate</th>
#>           <td>8</td>
#>           <td>0</td>
#>           <td>0</td>
#>           <td>4</td>
#>           <td>8</td>
#>           <td class="srs-weighting-maximum">8 points</td>
#>           <td class="srs-weighting-share">4.0%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Non-Important Protocol Deviation Rate</th>
#>           <td>8</td>
#>           <td>4</td>
#>           <td>0</td>
#>           <td>8</td>
#>           <td>16</td>
#>           <td class="srs-weighting-maximum">16 points</td>
#>           <td class="srs-weighting-share">7.9%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Important Protocol Deviation Rate</th>
#>           <td>0</td>
#>           <td>0</td>
#>           <td>0</td>
#>           <td>16</td>
#>           <td>32</td>
#>           <td class="srs-weighting-maximum">32 points</td>
#>           <td class="srs-weighting-share">15.8%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Grade 3+ Lab Abnormality Rate</th>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td>0</td>
#>           <td>1</td>
#>           <td>2</td>
#>           <td class="srs-weighting-maximum">2 points</td>
#>           <td class="srs-weighting-share">1.0%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Study Discontinuation Rate</th>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td>0</td>
#>           <td>16</td>
#>           <td>32</td>
#>           <td class="srs-weighting-maximum">32 points</td>
#>           <td class="srs-weighting-share">15.8%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Treatment Discontinuation Rate</th>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td>0</td>
#>           <td>16</td>
#>           <td>32</td>
#>           <td class="srs-weighting-maximum">32 points</td>
#>           <td class="srs-weighting-share">15.8%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Query Rate</th>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td>0</td>
#>           <td>1</td>
#>           <td>2</td>
#>           <td class="srs-weighting-maximum">2 points</td>
#>           <td class="srs-weighting-share">1.0%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Delayed Query Resolution Rate</th>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td>0</td>
#>           <td>1</td>
#>           <td>2</td>
#>           <td class="srs-weighting-maximum">2 points</td>
#>           <td class="srs-weighting-share">1.0%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Delayed Data Entry Rate</th>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td>0</td>
#>           <td>1</td>
#>           <td>2</td>
#>           <td class="srs-weighting-maximum">2 points</td>
#>           <td class="srs-weighting-share">1.0%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Data Change Rate</th>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td>0</td>
#>           <td>1</td>
#>           <td>2</td>
#>           <td class="srs-weighting-maximum">2 points</td>
#>           <td class="srs-weighting-share">1.0%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Screen Failure Rate</th>
#>           <td>0</td>
#>           <td>0</td>
#>           <td>0</td>
#>           <td>8</td>
#>           <td>16</td>
#>           <td class="srs-weighting-maximum">16 points</td>
#>           <td class="srs-weighting-share">7.9%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Ineligibility</th>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td>0</td>
#>           <td>8</td>
#>           <td>16</td>
#>           <td class="srs-weighting-maximum">16 points</td>
#>           <td class="srs-weighting-share">7.9%</td>
#>         </tr>
#>         <tr>
#>           <th scope="row">Premature Death Rate</th>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td class="srs-weighting-not-configured">Not configured</td>
#>           <td>0</td>
#>           <td>4</td>
#>           <td>8</td>
#>           <td class="srs-weighting-maximum">8 points</td>
#>           <td class="srs-weighting-share">4.0%</td>
#>         </tr>
#>       </tbody>
#>     </table>
#>   </div>
#> </section>
```
