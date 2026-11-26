// Eligibility report filters, adapted from the IP Monitoring
// report (ipmFilters.js) and gsm.stratification (stratFilters.js). R
// precomputes every slice into the #elig-data JSON block; this script only
// keeps the reviewer's selection, hands each widget the matching slice and
// draws the criteria map from the precomputed rows.
// No participant is classified or counted here.
(function () {
  var LEVELS = ['study', 'country', 'site'];
  var KINDS = ['sources', 'criteria'];
  var LISTINGS = ['elig-listing'];
  var state = { country: null, site: null, statuses: { country: [], site: [] } };
  var data = null;

  function eligData() {
    if (!data) {
      var node = document.getElementById('elig-data');
      data = node ? JSON.parse(node.textContent) : { status: {} };
    }
    return data;
  }

  function chart(id) {
    var el = document.getElementById(id);
    return el && el.gsmChart ? el.gsmChart : null;
  }

  function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  // Breakdown totals sit past the bar end, so the chart keeps room on the right.
  // A scope with few categories keeps its bars at the study chart's thickness
  // instead of stretching them over the fixed chart height.
  var PAD = 80;
  var MAX_BAR = 24;
  function padBreakdowns() {
    LEVELS.forEach(function (level) {
      KINDS.forEach(function (kind) {
        var c = chart('elig-' + level + '-' + kind);
        if (!c) return;
        var opts = c.config.options;
        if (opts.layout && opts.layout.padding && opts.layout.padding.right === PAD) return;
        opts.layout = { padding: { right: PAD } };
        opts.datasets = { bar: { maxBarThickness: MAX_BAR } };
        c.update('none');
      });
    });
  }
  window.addEventListener('load', padBreakdowns);

  // Groups with at least one participant in one of the statuses, with every
  // status row of those groups so their bars stay whole.
  function keepGroupsWithStatus(rows, statuses) {
    if (!statuses || !statuses.length) return rows;
    var keep = Object.create(null);
    rows.forEach(function (r) {
      if (r.n > 0 && statuses.indexOf(r.Status) >= 0) keep[r.GroupID] = true;
    });
    return rows.filter(function (r) { return keep[r.GroupID] === true; });
  }

  function countGroups(rows) {
    var groups = Object.create(null);
    rows.forEach(function (r) { groups[r.GroupID] = true; });
    return Object.keys(groups).length;
  }

  // gsm.viz updateData shows every series again (Gilead-Public/gsm.viz#616);
  // replay the legend click for each series the reviewer had hidden.
  function updateKeepingLegend(c, rows, spec) {
    var present = c.data.datasets.map(function (d) { return d.label; });
    var hidden = (c._eligHidden_ || [])
      .filter(function (label) { return present.indexOf(label) < 0; })
      .concat(c.data.datasets
        .filter(function (d, i) { return !c.isDatasetVisible(i); })
        .map(function (d) { return d.label; }));
    c.helpers.updateData(c, rows, spec);
    c._eligHidden_ = hidden;
    if (!hidden.length || !c.legend) return;
    var onClick = c.legend.options.onClick;
    (c.legend.legendItems || []).forEach(function (item) {
      var ds = c.data.datasets[item.datasetIndex];
      if (ds && hidden.indexOf(ds.label) >= 0 && c.isDatasetVisible(item.datasetIndex)) {
        onClick.call(c.legend, { native: null }, item, c.legend);
      }
    });
  }

  // Criteria map rows in scope, most affected group first, and the criteria
  // with at least one case among them (empty columns are not drawn).
  function mapView(level) {
    var m = eligData().map;
    if (!m) return { groups: [], criteria: [], cells: {} };
    var rows = (m[level] || []).filter(function (r) {
      if (!state.country) return true;
      return level === 'country' ? r.GroupID === state.country : r.OuterGroupID === state.country;
    });
    var totals = Object.create(null);
    var cells = Object.create(null);
    var used = Object.create(null);
    rows.forEach(function (r) {
      totals[r.GroupID] = (totals[r.GroupID] || 0) + r.n;
      cells[r.GroupID + '\u0000' + r.criterion] = r.n;
      if (r.n > 0) used[r.criterion] = true;
    });
    var groups = Object.keys(totals).sort(function (a, b) {
      return totals[b] - totals[a] || a.localeCompare(b, undefined, { numeric: true });
    });
    var criteria = (m.order || []).filter(function (k) { return used[k]; });
    return { groups: groups, criteria: criteria, cells: cells, totals: totals };
  }

  function renderMap(level) {
    var host = document.getElementById('elig-' + level + '-map');
    if (!host) return;
    var v = mapView(level);
    if (!v.groups.length) {
      host.innerHTML = '<p class="elig-empty">No criterion cases in scope.</p>';
      return;
    }
    var max = 1;
    Object.keys(v.cells).forEach(function (k) { max = Math.max(max, v.cells[k]); });
    var html = '<table class="elig-map"><thead><tr><th>' + (level === 'country' ? 'Country' : 'Site') + '</th>' +
      v.criteria.map(function (k) { return '<th>' + escapeHtml(k) + '</th>'; }).join('') +
      '<th>Total</th></tr></thead><tbody>';
    v.groups.forEach(function (g) {
      html += '<tr><th scope="row">' + escapeHtml(g) + '</th>';
      v.criteria.forEach(function (k) {
        var n = v.cells[g + '\u0000' + k] || 0;
        var dark = n && n / max > 0.5;
        html += '<td style="background-color: ' + (n ? mapShade(n, max) : 'transparent') + ';' + (dark ? 'color:#ffffff;' : '') + '">' + (n || '') + '</td>';
      });
      html += '<td class="elig-map-total">' + v.totals[g] + '</td></tr>';
    });
    host.innerHTML = html + '</tbody></table>';
  }

  function mapShade(n, max) {
    return 'rgba(60, 88, 127, ' + (0.15 + 0.75 * n / max).toFixed(2) + ')';
  }

  function csvCell(v) {
    var s = v == null ? '' : String(v);
    return /[",\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  }

  // Not Reactable.downloadDataCSV: the details columns are not on screen, so
  // R precomputes the export rows and this keeps the listing's filtered order.
  function downloadCsv(listingId, file) {
    var exp = eligData().export || { columns: [], rows: [] };
    var byId = {};
    exp.rows.forEach(function (r) { byId[r['Participant ID']] = r; });
    var lines = [exp.columns.map(csvCell).join(',')];
    Reactable.getState(listingId).sortedData.forEach(function (shown) {
      var r = byId[shown['Participant ID']];
      if (r) lines.push(exp.columns.map(function (c) { return csvCell(r[c]); }).join(','));
    });
    var a = document.createElement('a');
    // The BOM tells Excel the file is UTF-8, so accented names import intact.
    a.href = URL.createObjectURL(new Blob(['\ufeff' + lines.join('\r\n') + '\r\n'], { type: 'text/csv;charset=utf-8' }));
    a.download = file;
    document.body.appendChild(a);
    a.click();
    setTimeout(function () {
      URL.revokeObjectURL(a.href);
      a.remove();
    }, 0);
  }
  window.eligDownloadCsv = downloadCsv;

  // Pure helpers, exposed for tests.
  window.eligFilters = {
    keepGroupsWithStatus: keepGroupsWithStatus,
    countGroups: countGroups,
    mapView: mapView,
    state: state
  };

  function scopedStatusRows(level) {
    return ((eligData().status || {})[level] || []).filter(function (r) {
      return level !== 'site' || !state.country || r.OuterGroupID === state.country;
    });
  }

  function breakdownRows(kind, level) {
    var b = eligData()[kind];
    if (level === 'site' && state.site && state.country) {
      return (b.site[state.country] || {})[state.site] || [];
    }
    if (level !== 'study' && state.country) return b.country[state.country] || [];
    return b.study;
  }

  function syncListings() {
    if (!window.Reactable) return;
    // elig_ExactFilter() matches these values exactly, so a pick never shows
    // another group whose ID contains it.
    window.eligChartFilter = { Country: state.country, Site: state.site };
    LISTINGS.forEach(function (id) {
      if (!document.getElementById(id)) return;
      try {
        Reactable.setFilter(id, 'Country', state.country || undefined);
        Reactable.setFilter(id, 'Site', state.site || undefined);
      } catch (e) {
        // A listing that has not rendered yet picks the filters up on the next sync.
      }
    });
  }

  function setChip(key, value) {
    var chip = document.getElementById('elig-chip-' + key);
    if (!chip) return;
    chip.style.display = value ? 'inline-flex' : 'none';
    chip.querySelector('.elig-chip-value').textContent = value || '';
  }

  // "Showing X of Y" replaces the old "groups with no flagged participant are
  // hidden" caption; it shows whenever groups are left out.
  function setStatusCount(level, shown, total) {
    var bar = document.querySelector('[data-elig-status-filter="' + level + '"]');
    if (!bar) return;
    var active = state.statuses[level].length > 0;
    var noun = bar.getAttribute(total === 1 ? 'data-elig-noun' : 'data-elig-nouns');
    bar.classList.toggle('elig-status-filter-active', active);
    bar.querySelector('.elig-status-count').textContent = 'Showing ' + shown + ' of ' + total + ' ' + noun;
    bar.querySelector('.elig-status-empty').style.display = active && shown === 0 ? '' : 'none';
  }

  function syncStatus(level) {
    var status = chart('elig-' + level + '-status');
    if (!status) return;
    var scoped = scopedStatusRows(level);
    var rows = keepGroupsWithStatus(scoped, state.statuses[level]);
    updateKeepingLegend(status, rows, status.data._spec_);
    var selected = level === 'country' ? state.country : level === 'site' ? state.site : null;
    if (selected && status.data.labels.indexOf(selected) >= 0) {
      status.helpers.selectCategory(status, selected);
    } else {
      status.helpers.clearSelection(status);
    }
    if (level !== 'study') setStatusCount(level, countGroups(rows), countGroups(scoped));
  }

  function eligSync() {
    padBreakdowns();
    setChip('country', state.country);
    setChip('site', state.site);
    var hint = document.getElementById('elig-filter-hint');
    if (hint) hint.style.display = state.country || state.site ? 'none' : '';
    LEVELS.forEach(function (level) {
      syncStatus(level);
      KINDS.forEach(function (kind) {
        var c = chart('elig-' + level + '-' + kind);
        if (c && eligData()[kind]) updateKeepingLegend(c, breakdownRows(kind, level), c.data._spec_);
      });
    });
    renderMap('country');
    renderMap('site');
    syncListings();
  }

  document.addEventListener('click', function (e) {
    var button = e.target.closest('[data-elig-statuses]');
    if (!button) return;
    var bar = button.closest('[data-elig-status-filter]');
    var level = bar.getAttribute('data-elig-status-filter');
    state.statuses[level] = JSON.parse(button.getAttribute('data-elig-statuses'));
    bar.querySelectorAll('[data-elig-statuses]').forEach(function (b) {
      var on = b === button;
      b.classList.toggle('active', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    syncStatus(level);
  });

  document.addEventListener('click', function (e) {
    var clear = e.target.closest('[data-elig-clear]');
    if (!clear) return;
    if (clear.getAttribute('data-elig-clear') === 'country') state.country = null;
    state.site = null;
    eligSync();
  });

  // gsm.vizr's bars() dispatches gsm-viz-select on every bar click.
  document.addEventListener('gsm-viz-select', function (e) {
    var d = e.detail || {};
    var row = d.datum || {};
    if (d.type !== 'click' || !row.GroupID) return;
    if (d.chartId === 'elig-country-status') {
      state.country = row.GroupID === state.country ? null : row.GroupID;
      state.site = null;
    } else if (d.chartId === 'elig-site-status') {
      if (row.GroupID === state.site) {
        state.site = null;
      } else {
        state.site = row.GroupID;
        state.country = row.OuterGroupID;
      }
    } else {
      return;
    }
    eligSync();
  });

  function init() {
    renderMap('country');
    renderMap('site');
    ['country', 'site'].forEach(function (level) {
      var scoped = scopedStatusRows(level);
      setStatusCount(level, countGroups(scoped), countGroups(scoped));
    });
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
