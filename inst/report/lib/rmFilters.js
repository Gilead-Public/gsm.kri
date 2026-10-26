// Repeat Measurements report filters. R precomputes the overview, chart slices
// and listing rows into the #rm-data JSON block and the widgets; this script
// keeps the reviewer's selection and hands each widget the matching rows.
(function () {
  var LEVELS = ['study', 'country', 'site'];
  var FLAG_COLORS = { 0: '#3DAF06', 1: '#FEAA02', 2: '#FF5859' };
  var state = {
    group: 'All',
    country: null,
    site: null,
    subj: null,
    label: 'both',
    sort: 'worst',
    search: '',
    showValues: true,
    onlyRepeat: true,
    // Data table shape and its "only ... with a repeat window" toggle.
    shape: 'wide',
    dtOnly: true,
    // Listing settings to restore when the participant filter is cleared.
    prev: null
  };
  var data = null;
  var allTiles = null;

  function rmData() {
    if (!data) {
      var node = document.getElementById('rm-data');
      data = node ? JSON.parse(node.textContent) : null;
    }
    return data;
  }

  function byId(id) {
    return document.getElementById(id);
  }

  function chart(id) {
    var el = byId(id);
    return el && el.gsmChart ? el.gsmChart : null;
  }

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  // KRI vitals in the selected group, in report order.
  function groupVitals() {
    return rmData().vitals.filter(function (v) {
      return v.metric && (state.group === 'All' || v.group === state.group);
    });
  }

  function inGroup(vital) {
    return groupVitals().some(function (v) {
      return v.vital === vital;
    });
  }

  function inScope(row) {
    if (state.subj) return row.subjid === state.subj;
    if (state.site) return row.invid === state.site;
    if (state.country) return row.country === state.country;
    return true;
  }

  // ---- §1 overview --------------------------------------------------------
  function overviewRows() {
    var d = rmData();
    if (state.subj) {
      // One participant: counts come straight from their tiles.
      return (allTiles || [])
        .filter(function (t) {
          return t.subjid === state.subj;
        })
        .map(function (t) {
          return {
            vital: t.vital,
            enrolled: 1,
            evaluable: t.Denominator > 0 ? 1 : 0,
            amber: t.flag === 'Amber' ? 1 : 0,
            red: t.flag === 'Red' ? 1 : 0
          };
        });
    }
    var level = state.site ? 'site' : state.country ? 'country' : 'study';
    var id = state.site || state.country;
    return d.overview.filter(function (r) {
      return r.Level === level && (level === 'study' || r.GroupID === id);
    });
  }

  function pct(n, d) {
    return d ? Math.round((100 * n) / d) + '%' : '\u2013';
  }

  // One row per vital keeps the table narrow enough for every vital group.
  function renderOverview() {
    var el = byId('rm-overview');
    if (!el) return;
    var rows = overviewRows();
    var scope = state.subj
      ? 'Participant ' + state.subj
      : state.site
        ? 'Site ' + state.site
        : state.country
          ? state.country
          : 'Study';
    var enrolled = rows.length ? rows[0].enrolled : 0;
    var h =
      '<p><strong>' + esc(scope) + ':</strong> ' + enrolled + ' enrolled participant' + (enrolled === 1 ? '' : 's') + '</p>' +
      '<table class="table table-condensed"><thead><tr><th style="text-align:left">Vital</th><th style="text-align:left">KRI</th>' +
      '<th>Evaluable</th><th>% of enrolled</th><th>Flagged</th><th>% of evaluable</th><th>Amber</th><th>Red</th></tr></thead><tbody>';
    groupVitals().forEach(function (v) {
      var r = rows.filter(function (x) {
        return x.vital === v.vital;
      })[0] || { evaluable: 0, amber: 0, red: 0 };
      var fl = r.amber + r.red;
      h +=
        '<tr data-rm-overview="' + esc(v.vital) + '"><td style="text-align:left">' + esc(v.label) + '</td>' +
        '<td style="text-align:left"><code>' + esc(v.metric) + '</code></td>' +
        '<td class="v">' + r.evaluable + '</td><td class="b">' + pct(r.evaluable, enrolled) + '</td>' +
        '<td class="v">' + fl + '</td><td class="b">' + pct(fl, r.evaluable) + '</td>' +
        '<td><span class="rm-dot" style="background:#FEAA02"></span>' + r.amber + '</td>' +
        '<td><span class="rm-dot" style="background:#FF5859"></span>' + r.red + '</td></tr>';
    });
    el.innerHTML = h + '</tbody></table>';
  }

  // ---- §2 distribution ----------------------------------------------------
  function distRows(level, vital) {
    return (rmData().distribution[level] || []).filter(function (r) {
      if (vital ? r.vital !== vital : !inGroup(r.vital)) return false;
      // The site charts narrow to the selected country; the others keep every bar.
      return level !== 'site' || !state.country || r.OuterGroupID === state.country;
    });
  }

  // Site tick labels take the colour of the site's KRI flag for that vital.
  function colorSiteTicks(c, vital) {
    var flags = (rmData().siteFlags || {})[vital];
    if (!flags) return;
    var opts = c.config.options;
    var axis = opts.indexAxis === 'y' ? 'y' : 'x';
    if (!opts.scales || !opts.scales[axis]) return;
    var ticks = (opts.scales[axis].ticks = opts.scales[axis].ticks || {});
    if (ticks._rmFlags) return;
    ticks._rmFlags = true;
    ticks.color = function (ctx) {
      var label = c.data.labels[ctx.index];
      var f = flags[label];
      return f === undefined || f === null ? '#666666' : FLAG_COLORS[Math.abs(f)] || '#666666';
    };
    c.update('none');
  }

  function syncBars() {
    var study = chart('rm-study');
    if (study) study.helpers.updateData(study, distRows('study'), study.data._spec_);
    rmData().vitals.forEach(function (v) {
      if (!v.metric) return;
      ['country', 'site'].forEach(function (level) {
        var c = chart('rm-' + level + '-' + v.vital);
        if (!c) return;
        c.helpers.updateData(c, distRows(level, v.vital), c.data._spec_);
        var selected = level === 'country' ? state.country : state.site;
        if (selected && c.data.labels.indexOf(selected) >= 0) {
          c.helpers.selectCategory(c, selected);
        } else {
          c.helpers.clearSelection(c);
        }
        if (level === 'site') colorSiteTicks(c, v.vital);
      });
    });
    document.querySelectorAll('[data-rm-vital]').forEach(function (div) {
      div.style.display = inGroup(div.getAttribute('data-rm-vital')) ? '' : 'none';
    });
  }

  // ---- §3 participant listing (tiles) -------------------------------------
  function tileRows() {
    var q = state.search.trim().toUpperCase();
    var rows = allTiles.filter(function (t) {
      if (!inGroup(t.vital) || !inScope(t)) return false;
      return !q || (t.subjid + ' ' + t.invid + ' ' + t.country).toUpperCase().indexOf(q) >= 0;
    });
    if (state.sort === 'worst') return rows;
    // Rows render in first-appearance order, so sorting participants sorts the grid.
    var key = {};
    var rateVital = state.sort.indexOf('rate:') === 0 ? state.sort.slice(5) : null;
    rows.forEach(function (t, i) {
      if (!(t.subjid in key)) key[t.subjid] = { i: i, rate: -1 };
      if (rateVital && t.vital === rateVital && t.rate !== null) key[t.subjid].rate = t.rate;
    });
    var first = {};
    rows.forEach(function (t) {
      if (!(t.subjid in first)) first[t.subjid] = t;
    });
    function cmp(a, b) {
      var x = first[a.subjid];
      var y = first[b.subjid];
      if (a.subjid === b.subjid) return key[a.subjid].i - key[b.subjid].i;
      if (rateVital) return key[b.subjid].rate - key[a.subjid].rate || key[a.subjid].i - key[b.subjid].i;
      if (state.sort === 'invid' && x.invid !== y.invid) return x.invid < y.invid ? -1 : 1;
      return a.subjid < b.subjid ? -1 : 1;
    }
    // Stable within a participant: keep their vitals in report order.
    return rows
      .map(function (t, i) {
        return { t: t, i: i };
      })
      .sort(function (a, b) {
        return cmp(a.t, b.t) || a.i - b.i;
      })
      .map(function (x) {
        return x.t;
      });
  }

  function syncTiles() {
    var c = chart('rm-tiles');
    if (!c) return;
    if (!allTiles) allTiles = c.data.slice();
    c.helpers.updateData(c, tileRows());
    if (state.subj) c.helpers.selectRow(c, state.subj);
    else c.helpers.clearSelection(c);
  }

  function setLabel(mode) {
    state.label = mode;
    document.querySelectorAll('[data-rm-label]').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.getAttribute('data-rm-label') === mode));
    });
    var c = chart('rm-tiles');
    if (c) c.helpers.updateSpec(c, { mapping: { label: 'label_' + mode } });
  }

  function csvCell(x) {
    if (x === null || x === undefined) return '';
    var s = String(x);
    return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  }

  function downloadTiles() {
    var cols = ['country', 'invid', 'subjid', 'vital', 'flag', 'Numerator', 'Denominator', 'rate'];
    var lines = [cols.join(',')].concat(
      tileRows().map(function (t) {
        return cols.map(function (k) {
          return csvCell(t[k]);
        }).join(',');
      })
    );
    var a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([lines.join('\n') + '\n'], { type: 'text/csv' }));
    a.download = 'repeat-measurements-participants.csv';
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () {
      URL.revokeObjectURL(a.href);
    }, 1000);
  }

  // ---- §4 vitals listing --------------------------------------------------
  function exact(value) {
    return value ? '^' + jQuery.fn.dataTable.util.escapeRegex(value) + '$' : '';
  }

  function dtApi(id) {
    var table = document.querySelector('#' + id + ' table.dataTable');
    return table && window.jQuery ? jQuery(table).DataTable() : null;
  }

  function syncListing() {
    var wrap = byId('rm-vitals-wrap');
    if (wrap) wrap.classList.toggle('rm-compact', !state.showValues);
    var showValues = byId('rm-show-values');
    var onlyRepeat = byId('rm-only-repeat');
    if (showValues) showValues.checked = state.showValues;
    if (onlyRepeat) onlyRepeat.checked = state.onlyRepeat;

    var vitals = dtApi('rm-vitals');
    if (vitals) {
      // Height and BSA have no group, so they show only under All.
      var keys = state.group === 'All' ? [] : groupVitals().map(function (v) {
        return jQuery.fn.dataTable.util.escapeRegex(v.vital);
      });
      vitals.column('vital:name').search(keys.length ? '^(' + keys.join('|') + ')$' : '', true, false);
      vitals.column('has_repeat:name').search(state.onlyRepeat ? '^Y$' : '', true, false);
      vitals.column('country:name').search(exact(state.country), true, false);
      vitals.column('invid:name').search(exact(state.site), true, false);
      vitals.column('subjid:name').search(exact(state.subj), true, false);
      vitals.draw();
    }
  }

  // ---- §5 data table -------------------------------------------------------
  function vitalKeys() {
    return groupVitals().map(function (v) {
      return jQuery.fn.dataTable.util.escapeRegex(v.vital);
    });
  }

  function syncDataTable() {
    document.querySelectorAll('[data-rm-shape]').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.getAttribute('data-rm-shape') === state.shape));
    });
    document.querySelectorAll('[data-rm-shape-view]').forEach(function (div) {
      div.style.display = div.getAttribute('data-rm-shape-view') === state.shape ? '' : 'none';
    });
    var only = byId('rm-dt-only');
    if (only) only.checked = state.dtOnly;
    var onlyLabel = byId('rm-dt-only-label');
    if (onlyLabel) {
      onlyLabel.textContent = state.shape === 'wide'
        ? 'Only participants with a repeat window'
        : 'Only vitals with a repeat window';
    }
    // Height and BSA have no group, so they show only under All.
    var keys = state.group === 'All' ? [] : vitalKeys();
    var scope = function (api) {
      api.column('country:name').search(exact(state.country), true, false);
      api.column('invid:name').search(exact(state.site), true, false);
      api.column('subjid:name').search(exact(state.subj), true, false);
    };

    var long = dtApi('rm-dt-long');
    if (long) {
      long.column('vital:name').search(keys.length ? '^(' + keys.join('|') + ')$' : '', true, false);
      long.column('has_repeat:name').search(state.dtOnly ? '^Y$' : '', true, false);
      scope(long);
      long.draw();
    }

    var wide = dtApi('rm-dt-wide');
    if (wide) {
      var shown = {};
      rmData().vitals.forEach(function (v) {
        shown[v.vital] = state.group === 'All' || (v.metric && v.group === state.group);
      });
      wide.columns().every(function () {
        var name = this.settings()[0].aoColumns[this.index()].name;
        if (name in shown && this.visible() !== shown[name]) this.visible(shown[name], false);
      });
      var onlyRe = '';
      if (state.dtOnly) onlyRe = keys.length ? '(^| )(' + keys.join('|') + ')( |$)' : '\\S';
      wide.column('repeat_vitals:name').search(onlyRe, true, false);
      scope(wide);
      wide.columns.adjust().draw();
    }
    var shownApi = state.shape === 'wide' ? wide : long;
    if (shownApi) shownApi.columns.adjust();
  }

  // ---- shared --------------------------------------------------------------
  function setChip(key, value) {
    var chip = byId('rm-chip-' + key);
    if (!chip) return;
    chip.style.display = value ? 'inline-flex' : 'none';
    chip.querySelector('.rm-chip-value').textContent = value || '';
  }

  // Selecting a participant shows all of their vital rows in the compact
  // view; clearing it restores the reviewer's previous listing settings.
  function setSubj(id) {
    if (id && !state.subj) {
      state.prev = { showValues: state.showValues, onlyRepeat: state.onlyRepeat, dtOnly: state.dtOnly };
    }
    if (!id && state.subj && state.prev) {
      state.showValues = state.prev.showValues;
      state.onlyRepeat = state.prev.onlyRepeat;
      state.dtOnly = state.prev.dtOnly;
      state.prev = null;
    }
    if (id) {
      state.showValues = false;
      state.onlyRepeat = false;
      state.dtOnly = false;
    }
    state.subj = id;
  }

  function renderCount() {
    var el = byId('rm-count');
    var all = rmData().participants || [];
    if (!el) return;
    var n = all.filter(inScope).length;
    el.innerHTML = '<b>' + n.toLocaleString() + '</b> / ' + all.length.toLocaleString() + ' participants selected';
  }

  function rmSync() {
    if (!rmData()) return;
    document.querySelectorAll('[data-rm-group]').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.getAttribute('data-rm-group') === state.group));
    });
    setChip('country', state.country);
    setChip('site', state.site);
    setChip('subj', state.subj);
    renderCount();
    if (!allTiles) {
      var c = chart('rm-tiles');
      if (c) allTiles = c.data.slice();
    }
    renderOverview();
    syncBars();
    syncTiles();
    syncListing();
    syncDataTable();
  }

  function pickParticipant(subjid) {
    if (!subjid || subjid === state.subj) {
      setSubj(null);
    } else {
      setSubj(subjid);
    }
    rmSync();
  }

  document.addEventListener('click', function (e) {
    var t = e.target;
    var group = t.closest('[data-rm-group]');
    var clear = t.closest('[data-rm-clear]');
    var label = t.closest('[data-rm-label]');
    if (group) {
      state.group = group.getAttribute('data-rm-group');
    } else if (clear) {
      var key = clear.getAttribute('data-rm-clear');
      // Clearing a level also clears the levels inside it.
      if (key === 'country') state.country = null;
      if (key !== 'subj') state.site = null;
      setSubj(null);
    } else if (label) {
      setLabel(label.getAttribute('data-rm-label'));
      return;
    } else if (t.closest('#rm-tiles-csv')) {
      downloadTiles();
      return;
    } else if (t.closest('[data-rm-shape]')) {
      state.shape = t.closest('[data-rm-shape]').getAttribute('data-rm-shape');
      syncDataTable();
      return;
    } else {
      // A §4 or §5 row click toggles the participant filter.
      var tr = t.closest('#rm-vitals tbody tr, #rm-dt-long tbody tr, #rm-dt-wide tbody tr');
      var host = tr && tr.closest('.datatables');
      var api = host && dtApi(host.id);
      var row = api && api.row(tr).data();
      if (!row) return;
      var cols = api.settings()[0].aoColumns;
      for (var i = 0; i < cols.length; i++) {
        if (cols[i].name === 'subjid') {
          pickParticipant(row[i]);
          return;
        }
      }
      return;
    }
    rmSync();
  });

  document.addEventListener('change', function (e) {
    var id = e.target.id;
    if (id === 'rm-show-values') state.showValues = e.target.checked;
    else if (id === 'rm-only-repeat') state.onlyRepeat = e.target.checked;
    else if (id === 'rm-dt-only') {
      state.dtOnly = e.target.checked;
      syncDataTable();
      return;
    } else if (id === 'rm-tiles-sort') {
      state.sort = e.target.value;
      syncTiles();
      return;
    } else return;
    syncListing();
  });

  document.addEventListener('input', function (e) {
    if (e.target.id !== 'rm-tiles-search') return;
    state.search = e.target.value;
    syncTiles();
  });

  // The Participant Listing widget dispatches rm-tiles-select on a label or
  // tile click (or Enter / Space).
  document.addEventListener('rm-tiles-select', function (e) {
    pickParticipant((e.detail || {}).subjid);
  });

  // gsm.vizr dispatches gsm-viz-select from the bar charts.
  document.addEventListener('gsm-viz-select', function (e) {
    var d = e.detail || {};
    var id = d.chartId || '';
    var row = d.datum || {};
    if (d.type !== 'click' || !row.GroupID) return;
    if (id.indexOf('rm-country-') === 0) {
      state.country = row.GroupID === state.country && !state.site ? null : row.GroupID;
      state.site = null;
    } else if (id.indexOf('rm-site-') === 0) {
      if (row.GroupID === state.site) {
        state.site = null;
      } else {
        state.site = row.GroupID;
        state.country = row.OuterGroupID;
      }
    } else {
      return;
    }
    setSubj(null);
    rmSync();
  });

  window.addEventListener('load', rmSync);
})();
