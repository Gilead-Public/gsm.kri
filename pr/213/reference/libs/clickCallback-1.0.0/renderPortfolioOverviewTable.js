// Portfolio Overview Table Widget
// D1: portfolio rollup table. One column per metric (sorted by MetricID).
// One row for the portfolio total plus drill-down rows grouped by
// study-level params (therapeutic_area, protocol_indication, phase, status,
// product). Each cell shows numerator / denominator / rate.
// D2: client-side filter bar layered above the table. Filtering a study set
// recomputes the total + drill-down buckets in place from the per-study
// contribution table.
// D4: expandable rows. Click a drill-down row to reveal per-study
// numerator / denominator / rate values that rolled up into that bucket.
function renderPortfolioOverviewTable(el, input) {
  if (!input) {
    el.innerHTML = '<em>No input provided to widget</em>';
    return;
  }

  if (!Array.isArray(input.dfSummary) || input.dfSummary.length === 0) {
    el.innerHTML = '<em>No summary data found in widget input</em>';
    return;
  }

  var perStudy = Array.isArray(input.dfPerStudy) ? input.dfPerStudy : [];
  var studyAttrs = Array.isArray(input.dfStudyAttrs) ? input.dfStudyAttrs : [];
  var groupParams = Array.isArray(input.vGroupParams) && input.vGroupParams.length > 0
    ? input.vGroupParams
    : ['therapeutic_area', 'protocol_indication', 'phase', 'status', 'product'];
  var filterParams = Array.isArray(input.vFilterParams) && input.vFilterParams.length > 0
    ? input.vFilterParams
    : ['therapeutic_area', 'phase', 'status'];
  var metricOrder = Array.isArray(input.vMetricOrder) && input.vMetricOrder.length > 0
    ? input.vMetricOrder.slice().sort()
    : Array.from(new Set(input.dfSummary.map(function(r) { return r.MetricID; }))).sort();

  // Header label = Abbreviation; tooltip = full metric metadata.
  var metricLabels = {};
  var metricTooltips = {};
  var metricsMeta = Array.isArray(input.dfMetrics) ? input.dfMetrics : [];
  var tooltipFields = [
    'MetricID', 'Metric', 'Abbreviation', 'Type', 'GroupLevel',
    'Numerator', 'Denominator', 'Model', 'AnalysisType', 'Score',
    'Threshold', 'AccrualThreshold', 'AccrualMetric'
  ];
  metricsMeta.forEach(function(m) {
    if (!m || !m.MetricID) return;
    metricLabels[m.MetricID] = m.Abbreviation || m.Metric || m.MetricID;
    var lines = [];
    tooltipFields.forEach(function(f) {
      var v = m[f];
      if (v != null && v !== '' && v !== 'NA') lines.push(f + ': ' + v);
    });
    metricTooltips[m.MetricID] = lines.join('\n');
  });
  function metricLabel(mid) { return metricLabels[mid] || mid; }
  function metricTooltip(mid) { return metricTooltips[mid] || mid; }
  function escAttr(s) {
    return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  // Study attribute lookup: { StudyID: { Param: Value } }.
  var studyAttrLookup = {};
  studyAttrs.forEach(function(row) {
    if (!studyAttrLookup[row.StudyID]) studyAttrLookup[row.StudyID] = {};
    studyAttrLookup[row.StudyID][row.Param] = row.Value;
  });

  var allStudies = Array.from(new Set(perStudy.map(function(r) { return r.StudyID; }))).sort();
  var filterOptions = {};
  filterParams.forEach(function(p) {
    var values = new Set();
    Object.keys(studyAttrLookup).forEach(function(sid) {
      if (studyAttrLookup[sid][p] != null) values.add(studyAttrLookup[sid][p]);
    });
    filterOptions[p] = Array.from(values).sort();
  });

  var filterState = {};
  filterParams.forEach(function(p) { filterState[p] = []; });
  filterState.StudyID = [];

  // Tracks which (category|value) bucket rows are currently expanded so a
  // re-render after a filter change preserves user state where possible.
  var expandedBuckets = {};
  var heatmapMode = 'none';
  // Symmetric severity palette for flags -2, -1, 0, 1, 2.
  var FLAG_COLORS = [
    'rgba(229,57,53,0.55)',    // -2: red
    'rgba(255,179,0,0.55)',    // -1: amber
    'rgba(76,175,80,0.45)',    //  0: green
    'rgba(255,179,0,0.55)',    //  1: amber
    'rgba(229,57,53,0.55)'     //  2: red
  ];
  var cellMetric = 'rate';
  var gradientRange = { min: 0, max: 1 };

  function bucketKey(category, value) {
    return category + '||' + value;
  }

  function fmtRate(rate) {
    if (rate === null || rate === undefined || isNaN(rate)) return '-';
    return (rate * 100).toFixed(1) + '%';
  }

  function flagCounts(cell) {
    return {
      n2: cell.FlagN2 || 0,
      n1: cell.FlagN1 || 0,
      z: cell.Flag0 || 0,
      p1: cell.FlagP1 || 0,
      p2: cell.FlagP2 || 0
    };
  }
  function flagTotals(cell) {
    var f = flagCounts(cell);
    var red = f.n2 + f.p2;
    var amber = f.n1 + f.p1;
    var green = f.z;
    return { red: red, amber: amber, green: green, total: red + amber + green, parts: f };
  }

  function cellValue(cell) {
    if (!cell || cell.Denominator === 0) return null;
    var t = flagTotals(cell);
    if (cellMetric === 'count') return cell.Numerator;
    if (cellMetric === 'flagged-red') return t.total > 0 ? t.red / t.total : null;
    if (cellMetric === 'flagged-any') return t.total > 0 ? (t.red + t.amber) / t.total : null;
    return cell.Rate;
  }

  function fmtValue(v) {
    if (v === null || v === undefined || isNaN(v)) return '-';
    if (cellMetric === 'count') return String(v);
    return (v * 100).toFixed(1) + '%';
  }

  function cellDisplay(cell) {
    return fmtValue(cellValue(cell));
  }

  function computeGradientRange(buckets) {
    var min = Infinity, max = -Infinity;
    buckets.forEach(function(b) {
      Object.keys(b.cells).forEach(function(mid) {
        var v = cellValue(b.cells[mid]);
        if (v === null || v === undefined || isNaN(v)) return;
        if (v < min) min = v;
        if (v > max) max = v;
      });
    });
    if (!isFinite(min) || !isFinite(max)) { min = 0; max = 1; }
    if (min === max) max = min + 1e-9;
    gradientRange = { min: min, max: max };
  }

  function cellMetricLabel() {
    if (cellMetric === 'count') return 'Count';
    if (cellMetric === 'flagged-red') return '% flagged (red)';
    if (cellMetric === 'flagged-any') return '% flagged (any)';
    return 'Rate';
  }

  function renderHeatmapLegend() {
    var legendEl = el.querySelector('#po-heatmap-legend');
    if (!legendEl) return;
    if (heatmapMode === 'flags') {
      var labels = ['-2', '-1', '0', '1', '2'];
      var swatches = labels.map(function(lab, i) {
        return '<span><span style="display:inline-block; width:14px; height:10px; background:' +
          FLAG_COLORS[i] + '; margin-right:4px; vertical-align:middle;"></span>' + lab + '</span>';
      }).join('');
      legendEl.innerHTML =
        '<div style="display:flex; gap:12px; align-items:center; font-size:12px; color:#444;">' +
        '<span style="color:#666;">Heatmap (flag distribution):</span>' + swatches +
        '</div>';
      return;
    }
    if (heatmapMode === 'gradient') {
      var lo = gradientRange.min;
      var hi = gradientRange.max;
      var mid = (lo + hi) / 2;
      legendEl.innerHTML =
        '<div style="display:flex; gap:8px; align-items:center; font-size:12px; color:#444;">' +
        '<span style="color:#666;">Heatmap (' + escAttr(cellMetricLabel()) + '):</span>' +
        '<span>' + fmtValue(lo) + '</span>' +
        '<span style="display:inline-block; width:200px; height:10px; background: linear-gradient(to right, ' +
        gradientColor(lo) + ', ' + gradientColor(mid) + ', ' + gradientColor(hi) + '); border:1px solid #ddd;"></span>' +
        '<span>' + fmtValue(hi) + '</span>' +
        '</div>';
      return;
    }
    legendEl.innerHTML = '';
  }

  function gradientColor(v) {
    var lo = gradientRange.min;
    var hi = gradientRange.max;
    var t = hi > lo ? (v - lo) / (hi - lo) : 0;
    if (t < 0) t = 0; else if (t > 1) t = 1;
    // Diverging blue (33,150,243) -> white (255,255,255) -> orange (255,152,0).
    var r, g, b;
    if (t < 0.5) {
      var s = t / 0.5;
      r = Math.round(33 + (255 - 33) * s);
      g = Math.round(150 + (255 - 150) * s);
      b = Math.round(243 + (255 - 243) * s);
    } else {
      var s2 = (t - 0.5) / 0.5;
      r = Math.round(255 + (255 - 255) * s2);
      g = Math.round(255 + (152 - 255) * s2);
      b = Math.round(255 + (0 - 255) * s2);
    }
    return 'rgba(' + r + ',' + g + ',' + b + ',0.5)';
  }

  function fmtCell(cell) {
    if (!cell || cell.Denominator === 0) return '<div class="po-heat-cell"><span class="po-empty">-</span></div>';
    var t = flagTotals(cell);
    var tip = 'Numerator: ' + cell.Numerator +
      '\nDenominator: ' + cell.Denominator +
      '\nRate: ' + fmtRate(cell.Rate);
    if (t.total > 0) {
      tip += '\nFlags: -2:' + t.parts.n2 + ', -1:' + t.parts.n1 +
        ', 0:' + t.parts.z + ', 1:' + t.parts.p1 + ', 2:' + t.parts.p2 +
        ' (n=' + t.total + ')';
    }

    var style = '';
    if (heatmapMode === 'flags' && t.total > 0) {
      var pct = [
        t.parts.n2 / t.total * 100,
        t.parts.n1 / t.total * 100,
        t.parts.z / t.total * 100,
        t.parts.p1 / t.total * 100,
        t.parts.p2 / t.total * 100
      ];
      var c = FLAG_COLORS;
      var cum = 0;
      var stops = [];
      for (var i = 0; i < 5; i += 1) {
        var start = cum;
        cum += pct[i];
        stops.push(c[i] + ' ' + start + '% ' + cum + '%');
      }
      style = ' style="background: linear-gradient(to right, ' + stops.join(', ') + ');"';
    } else if (heatmapMode === 'gradient') {
      var v = cellValue(cell);
      if (v !== null && !isNaN(v)) {
        style = ' style="background:' + gradientColor(v) + ';"';
      }
    }
    return '<div class="po-heat-cell"' + style + ' title="' + escAttr(tip) + '">' +
      '<span class="po-rate">' + cellDisplay(cell) + '</span></div>';
  }

  function filteredPerStudy() {
    return perStudy.filter(function(row) {
      if (filterState.StudyID.length > 0 && filterState.StudyID.indexOf(row.StudyID) === -1) {
        return false;
      }
      var attrs = studyAttrLookup[row.StudyID] || {};
      for (var i = 0; i < filterParams.length; i += 1) {
        var p = filterParams[i];
        if (filterState[p].length > 0 && filterState[p].indexOf(attrs[p]) === -1) {
          return false;
        }
      }
      return true;
    });
  }

  // Collect studies belonging to a (category, value) bucket from the filtered
  // per-study set. The "Total" bucket is the union of all surviving studies.
  function studiesInBucket(rows, category, value) {
    if (category === 'Total') {
      return Array.from(new Set(rows.map(function(r) { return r.StudyID; }))).sort();
    }
    var out = new Set();
    rows.forEach(function(r) {
      var attrs = studyAttrLookup[r.StudyID] || {};
      if (attrs[category] === value) out.add(r.StudyID);
    });
    return Array.from(out).sort();
  }

  // Build per-study rows for an expanded bucket: one tr per study with
  // numerator / denominator / rate per metric.
  function buildPerStudyRows(rows, studyIds) {
    var byStudy = {};
    rows.forEach(function(r) {
      if (studyIds.indexOf(r.StudyID) === -1) return;
      if (!byStudy[r.StudyID]) byStudy[r.StudyID] = {};
      byStudy[r.StudyID][r.MetricID] = r;
    });

    var html = '';
    studyIds.forEach(function(sid) {
      var attrs = studyAttrLookup[sid] || {};
      var attrLines = Object.keys(attrs)
        .filter(function(k) { return attrs[k] != null && attrs[k] !== ''; })
        .sort()
        .map(function(k) { return k + ': ' + attrs[k]; });
      var studyTip = sid + (attrLines.length ? '\n' + attrLines.join('\n') : '');
      html += '<tr class="po-study-row" style="background:#fcfcfc;">';
      html += '<td class="po-bucket-label" style="padding-left:24px;" title="' + escAttr(studyTip) + '">↳ ' + sid + '</td>';
      html += '<td>1</td>';
      metricOrder.forEach(function(mid) {
        var cell = byStudy[sid] && byStudy[sid][mid];
        var formatted = cell
          ? {
              Numerator: cell.Numerator,
              Denominator: cell.Denominator,
              Rate: cell.Rate,
              FlagN2: cell.FlagN2,
              FlagN1: cell.FlagN1,
              Flag0: cell.Flag0,
              FlagP1: cell.FlagP1,
              FlagP2: cell.FlagP2
            }
          : null;
        html += '<td class="po-cell-wrap">' + fmtCell(formatted) + '</td>';
      });
      html += '</tr>';
    });
    return html;
  }

  function computeBuckets(rows) {
    var totalIdx = {};
    var byCategory = {};

    function newAcc() { return { num: 0, den: 0, n2: 0, n1: 0, z: 0, p1: 0, p2: 0, studies: new Set() }; }
    function addRow(acc, r) {
      acc.num += (r.Numerator || 0);
      acc.den += (r.Denominator || 0);
      acc.n2 += (r.FlagN2 || 0);
      acc.n1 += (r.FlagN1 || 0);
      acc.z += (r.Flag0 || 0);
      acc.p1 += (r.FlagP1 || 0);
      acc.p2 += (r.FlagP2 || 0);
      acc.studies.add(r.StudyID);
    }
    function finalize(c) {
      return {
        Numerator: c.num,
        Denominator: c.den,
        Rate: c.den > 0 ? c.num / c.den : null,
        FlagN2: c.n2,
        FlagN1: c.n1,
        Flag0: c.z,
        FlagP1: c.p1,
        FlagP2: c.p2
      };
    }

    rows.forEach(function(r) {
      if (!totalIdx[r.MetricID]) totalIdx[r.MetricID] = newAcc();
      addRow(totalIdx[r.MetricID], r);

      var attrs = studyAttrLookup[r.StudyID] || {};
      groupParams.forEach(function(cat) {
        var val = attrs[cat];
        if (val == null) return;
        if (!byCategory[cat]) byCategory[cat] = {};
        if (!byCategory[cat][val]) byCategory[cat][val] = {};
        if (!byCategory[cat][val][r.MetricID]) byCategory[cat][val][r.MetricID] = newAcc();
        addRow(byCategory[cat][val][r.MetricID], r);
      });
    });

    var buckets = [];
    var allStudiesInScope = new Set();
    rows.forEach(function(r) { allStudiesInScope.add(r.StudyID); });
    var totalRow = { category: 'Total', value: 'Total', numStudies: allStudiesInScope.size, cells: {} };
    Object.keys(totalIdx).forEach(function(mid) {
      totalRow.cells[mid] = finalize(totalIdx[mid]);
    });
    buckets.push(totalRow);

    groupParams.forEach(function(cat) {
      if (!byCategory[cat]) return;
      Object.keys(byCategory[cat]).sort().forEach(function(val) {
        var cells = {};
        var studies = new Set();
        Object.keys(byCategory[cat][val]).forEach(function(mid) {
          var c = byCategory[cat][val][mid];
          cells[mid] = finalize(c);
          c.studies.forEach(function(s) { studies.add(s); });
        });
        buckets.push({ category: cat, value: val, numStudies: studies.size, cells: cells });
      });
    });

    return buckets;
  }

  function buildTable(rows, buckets) {
    var html = '<table class="po-table"><thead><tr>';
    html += '<th style="text-align:left;">Group</th>';
    html += '<th style="text-align:right;">Studies</th>';
    metricOrder.forEach(function(mid) {
      html += '<th title="' + escAttr(metricTooltip(mid)) + '">' + metricLabel(mid) + '</th>';
    });
    html += '</tr></thead><tbody>';

    var lastCategory = null;
    buckets.forEach(function(b) {
      if (b.category !== lastCategory && b.category !== 'Total') {
        html += '<tr class="po-category-header"><td colspan="' + (metricOrder.length + 2) + '">' +
          b.category + '</td></tr>';
      }
      lastCategory = b.category;

      var key = bucketKey(b.category, b.value);
      var isExpanded = !!expandedBuckets[key];
      var rowClass = b.category === 'Total' ? 'po-total-row' : 'po-bucket-row';
      var caret = isExpanded ? '▾' : '▸';

      html += '<tr class="' + rowClass + '" data-bucket-key="' + key + '" style="cursor:pointer;">';
      html += '<td class="po-bucket-label"><span class="po-caret">' + caret + '</span> ' + b.value + '</td>';
      html += '<td>' + (b.numStudies != null ? b.numStudies : '-') + '</td>';
      metricOrder.forEach(function(mid) {
        html += '<td class="po-cell-wrap">' + fmtCell(b.cells[mid]) + '</td>';
      });
      html += '</tr>';

      if (isExpanded) {
        var studyIds = studiesInBucket(rows, b.category, b.value);
        html += buildPerStudyRows(rows, studyIds);
      }
    });

    html += '</tbody></table>';
    return html;
  }

  function buildFilterBar() {
    var btnStyle = 'padding:2px 8px; font-size:12px; border-radius:3px; cursor:pointer;';
    var html = '<div class="po-filter-bar" style="background:#f5f5f5; padding:8px 12px; margin-bottom:10px; border:1px solid #ddd; border-radius:4px;">';
    html += '<div style="display:flex; gap:6px; align-items:center;">';
    html += '<button id="po-toggle-filters" style="' + btnStyle + ' background:#f5f5f5; color:#333; border:1px solid #ccc;">▸ Filters</button>';
    html += '<label for="po-cell-metric" style="font-size:12px; color:#333;">Show:</label>';
    html += '<select id="po-cell-metric" style="font-size:12px; padding:2px 4px;">' +
      '<option value="rate">Rate</option>' +
      '<option value="count">Count</option>' +
      '<option value="flagged-red">% flagged (red)</option>' +
      '<option value="flagged-any">% flagged (any)</option>' +
      '</select>';
    html += '<label for="po-heatmap-mode" style="font-size:12px; color:#333;">Heatmap:</label>';
    html += '<select id="po-heatmap-mode" style="font-size:12px; padding:2px 4px;">' +
      '<option value="none">None</option>' +
      '<option value="flags">Flags</option>' +
      '<option value="gradient">Gradient</option>' +
      '</select>';
    html += '<div style="flex:1;"></div>';
    html += '<button id="po-reset-filters" style="' + btnStyle + ' background:#2196f3; color:white; border:none;">Reset</button>';
    html += '<button id="po-expand-all" style="' + btnStyle + ' background:#f5f5f5; color:#333; border:1px solid #ccc;">+ Expand</button>';
    html += '<button id="po-collapse-all" style="' + btnStyle + ' background:#f5f5f5; color:#333; border:1px solid #ccc;">− Collapse</button>';
    html += '</div>';
    html += '<div id="po-filter-controls" style="display:none; margin-top:10px;">';
    html += '<div style="display:flex; gap:16px; flex-wrap:wrap; align-items:flex-start;">';
    filterParams.forEach(function(p) {
      html += '<div style="flex:1; min-width:160px;">';
      html += '<label style="display:block; font-weight:bold; margin-bottom:4px;">' + p + '</label>';
      html += '<select multiple data-filter-param="' + p + '" style="width:100%; min-height:90px;">';
      filterOptions[p].forEach(function(v) {
        html += '<option value="' + v + '">' + v + '</option>';
      });
      html += '</select></div>';
    });
    html += '<div style="flex:1; min-width:160px;">';
    html += '<label style="display:block; font-weight:bold; margin-bottom:4px;">Study</label>';
    html += '<select multiple data-filter-param="StudyID" style="width:100%; min-height:90px;">';
    allStudies.forEach(function(s) {
      html += '<option value="' + s + '">' + s + '</option>';
    });
    html += '</select></div>';
    html += '</div></div></div>';
    return html;
  }

  var styleHtml = '<style>' +
    '.po-container { font-family: sans-serif; }' +
    '.po-table { width: 100%; border-collapse: collapse; margin-top: 10px; }' +
    '.po-heat-cell { padding: 6px 8px; text-align: right; min-height: 20px; }' +
    '.po-table th, .po-table td { border: 1px solid #ddd; padding: 6px 8px; vertical-align: top; text-align: right; font-size: 13px; }' +
    '.po-table td.po-cell-wrap { padding: 0; }' +
    '.po-table th { background: #f5f5f5; text-align: center; }' +
    '.po-table tr.po-total-row { background: #e8eef7; font-weight: bold; }' +
    '.po-table tr.po-category-header td { background: #fafafa; text-align: left; font-weight: bold; color: #555; }' +
    '.po-table td.po-bucket-label { text-align: left; white-space: nowrap; }' +
    '.po-table tr.po-bucket-row:hover { background: #f9f9f9; }' +
    '.po-rate { color: #2c3e50; }' +
    '.po-empty { color: #aaa; }' +
    '.po-caret { display: inline-block; width: 14px; color: #888; }' +
    '</style>';

  el.innerHTML = styleHtml +
    '<div class="po-container"><h3>Portfolio Overview</h3>' +
    buildFilterBar() +
    '<div id="po-filter-info" style="margin-bottom:6px; font-size:12px; color:#666;"></div>' +
    '<div id="po-heatmap-legend" style="margin-bottom:6px;"></div>' +
    '<div id="po-table-container"></div>' +
    '</div>';

  function rerender() {
    var rows = filteredPerStudy();
    var infoEl = el.querySelector('#po-filter-info');
    if (infoEl) {
      var nStudies = new Set(rows.map(function(r) { return r.StudyID; })).size;
      infoEl.textContent = 'Showing ' + nStudies + ' / ' + allStudies.length + ' studies';
    }
    var container = el.querySelector('#po-table-container');
    if (container) {
      var buckets = computeBuckets(rows);
      computeGradientRange(buckets);
      renderHeatmapLegend();
      container.innerHTML = buildTable(rows, buckets);
      // Wire expand/collapse for the current pass.
      container.querySelectorAll('tr[data-bucket-key]').forEach(function(tr) {
        tr.addEventListener('click', function() {
          var key = tr.getAttribute('data-bucket-key');
          if (expandedBuckets[key]) {
            delete expandedBuckets[key];
          } else {
            expandedBuckets[key] = true;
          }
          rerender();
        });
      });
    }
  }

  el.querySelectorAll('select[data-filter-param]').forEach(function(sel) {
    sel.addEventListener('change', function() {
      var p = sel.getAttribute('data-filter-param');
      filterState[p] = Array.from(sel.selectedOptions).map(function(o) { return o.value; });
      rerender();
    });
  });
  var toggleBtn = el.querySelector('#po-toggle-filters');
  var filterControls = el.querySelector('#po-filter-controls');
  if (toggleBtn && filterControls) {
    toggleBtn.addEventListener('click', function() {
      var open = filterControls.style.display !== 'none';
      filterControls.style.display = open ? 'none' : 'block';
      toggleBtn.innerHTML = (open ? '▸' : '▾') + ' Filters';
    });
  }
  var cellMetricSel = el.querySelector('#po-cell-metric');
  if (cellMetricSel) {
    cellMetricSel.addEventListener('change', function(evt) {
      cellMetric = evt.target.value;
      rerender();
    });
  }
  var heatSel = el.querySelector('#po-heatmap-mode');
  if (heatSel) {
    heatSel.addEventListener('change', function(evt) {
      heatmapMode = evt.target.value;
      rerender();
    });
  }
  var resetBtn = el.querySelector('#po-reset-filters');
  if (resetBtn) {
    resetBtn.addEventListener('click', function() {
      Object.keys(filterState).forEach(function(k) { filterState[k] = []; });
      el.querySelectorAll('select[data-filter-param]').forEach(function(sel) { sel.selectedIndex = -1; });
      rerender();
    });
  }
  var expandAllBtn = el.querySelector('#po-expand-all');
  if (expandAllBtn) {
    expandAllBtn.addEventListener('click', function() {
      var rows = filteredPerStudy();
      computeBuckets(rows).forEach(function(b) {
        if (b.category !== 'Total') expandedBuckets[bucketKey(b.category, b.value)] = true;
      });
      rerender();
    });
  }
  var collapseAllBtn = el.querySelector('#po-collapse-all');
  if (collapseAllBtn) {
    collapseAllBtn.addEventListener('click', function() {
      expandedBuckets = {};
      rerender();
    });
  }
  rerender();
}
