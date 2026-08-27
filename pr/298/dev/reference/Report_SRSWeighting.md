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
#> <style>.srs-weighting-summary{color:#333}.srs-weighting-summary p{max-width:80rem} .srs-weighting-table-wrap{overflow-x:auto;margin:1rem 0} .srs-weighting-table{border-collapse:collapse;width:100%;font-size:0.95em} .srs-weighting-table caption{text-align:left;font-weight:bold;margin-bottom:.5rem} .srs-weighting-table th,.srs-weighting-table td{border:1px solid #d8d8d8;padding:.55rem .7rem;text-align:center} .srs-weighting-table thead th{background:#3c587f;color:white;vertical-align:bottom} .srs-weighting-table tbody th{text-align:left;background:#f5f5f5} .srs-weighting-table tbody tr:nth-child(even) td{background:#fafafa} .srs-weighting-maximum,.srs-weighting-share{font-weight:bold} .srs-weighting-not-configured{color:#666;font-style:italic} .srs-weighting-total-row th{background:#e8eef5!important;color:#243b5a!important;font-size:1.1em;text-align:left!important} .srs-weighting-total-score{font-size:1.25em} .srs-weighting-flag-select{min-width:10rem;padding:.35rem} .srs-weighting-metric-score{font-weight:bold;white-space:nowrap}</style>
#> <section class="srs-weighting-summary" data-total-possible="202">
#>   <h3>Site Risk Score Overview</h3>
#>   <p>Each metric assigns points according to the site's flag. The points for all metrics are added together, then divided by the total possible points and multiplied by 100 to produce the normalized SRS.</p>
#>   <p>Each metric's maximum contribution is the highest number of points that the metric can add to the SRS, based on its largest configured weight. The contribution percentage shows how much of the total possible SRS can come from that metric.</p>
#>   <p>Choose a flag for each metric to see its point contribution and calculate an example SRS.</p>
#>   <div class="srs-weighting-table-wrap">
#>     <table class="srs-weighting-table">
#>       <caption>Metric weights used in the Site Risk Score</caption>
#>       <thead>
#>         <tr class="srs-weighting-total-row">
#>           <th colspan="10">
#>             Example SRS: 
#>             <output class="srs-weighting-total-score" aria-live="polite">0.0</output>
#>              = 
#>             <span class="srs-weighting-selected-points">0</span>
#>              selected points / 
#>             202
#>              total possible points x 100
#>           </th>
#>         </tr>
#>         <tr>
#>           <th scope="col">Metric</th>
#>           <th scope="col">Low red (-2)</th>
#>           <th scope="col">Low amber (-1)</th>
#>           <th scope="col">Not flagged (0)</th>
#>           <th scope="col">High amber (+1)</th>
#>           <th scope="col">High red (+2)</th>
#>           <th scope="col">Maximum contribution</th>
#>           <th scope="col">Share of total possible SRS</th>
#>           <th scope="col">Selected flag</th>
#>           <th scope="col">Metric score</th>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Adverse Event Rate">
#>               <option value="-2" data-weight="32">Low red (-2)</option>
#>               <option value="-1" data-weight="16">Low amber (-1)</option>
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="1">High amber (+1)</option>
#>               <option value="2" data-weight="2">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Serious Adverse Event Rate">
#>               <option value="-2" data-weight="8">Low red (-2)</option>
#>               <option value="-1" data-weight="0">Low amber (-1)</option>
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="4">High amber (+1)</option>
#>               <option value="2" data-weight="8">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Non-Important Protocol Deviation Rate">
#>               <option value="-2" data-weight="8">Low red (-2)</option>
#>               <option value="-1" data-weight="4">Low amber (-1)</option>
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="8">High amber (+1)</option>
#>               <option value="2" data-weight="16">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Important Protocol Deviation Rate">
#>               <option value="-2" data-weight="0">Low red (-2)</option>
#>               <option value="-1" data-weight="0">Low amber (-1)</option>
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="16">High amber (+1)</option>
#>               <option value="2" data-weight="32">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Grade 3+ Lab Abnormality Rate">
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="1">High amber (+1)</option>
#>               <option value="2" data-weight="2">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Study Discontinuation Rate">
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="16">High amber (+1)</option>
#>               <option value="2" data-weight="32">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Treatment Discontinuation Rate">
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="16">High amber (+1)</option>
#>               <option value="2" data-weight="32">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Query Rate">
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="1">High amber (+1)</option>
#>               <option value="2" data-weight="2">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Delayed Query Resolution Rate">
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="1">High amber (+1)</option>
#>               <option value="2" data-weight="2">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Delayed Data Entry Rate">
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="1">High amber (+1)</option>
#>               <option value="2" data-weight="2">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Data Change Rate">
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="1">High amber (+1)</option>
#>               <option value="2" data-weight="2">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Screen Failure Rate">
#>               <option value="-2" data-weight="0">Low red (-2)</option>
#>               <option value="-1" data-weight="0">Low amber (-1)</option>
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="8">High amber (+1)</option>
#>               <option value="2" data-weight="16">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Ineligibility">
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="8">High amber (+1)</option>
#>               <option value="2" data-weight="16">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
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
#>           <td>
#>             <select class="srs-weighting-flag-select" aria-label="Select flag for Premature Death Rate">
#>               <option value="0" data-weight="0" selected="">Not flagged (0)</option>
#>               <option value="1" data-weight="4">High amber (+1)</option>
#>               <option value="2" data-weight="8">High red (+2)</option>
#>             </select>
#>           </td>
#>           <td>
#>             <output class="srs-weighting-metric-score" aria-live="polite">0 points</output>
#>           </td>
#>         </tr>
#>       </tbody>
#>     </table>
#>   </div>
#> </section>
```
