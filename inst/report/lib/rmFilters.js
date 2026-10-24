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
    // Listing settings to restore when the participant filter is cleared.
    prev: null,
    // null: vital rows; { subjid, vital }: one participant's records; { all: true }: records in scope.
    drill: null
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

    var records = dtApi('rm-records');
    var drill = state.drill;
    if (records && drill) {
      var subj = drill.subjid || state.subj;
      records.column('country:name').search(subj ? '' : exact(state.country), true, false);
      records.column('invid:name').search(subj ? '' : exact(state.site), true, false);
      records.column('subjid:name').search(exact(subj), true, false);
      records.draw();
      var crumb = byId('rm-crumb');
      if (crumb) {
        crumb.innerHTML = drill.subjid
          ? '<strong>' + esc(drill.subjid) + '</strong>: all records, every vital' +
            (drill.label ? ' (opened from ' + esc(drill.label) + ')' : '')
          : '<strong>All records in scope</strong>: every participant matching the report filters';
      }
    }
    var vView = byId('rm-vitals-view');
    var rView = byId('rm-records-view');
    if (vView) vView.style.display = drill ? 'none' : '';
    if (rView) rView.style.display = drill ? '' : 'none';
    if (drill && records) records.columns.adjust();
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
    if (id && !state.subj) state.prev = { showValues: state.showValues, onlyRepeat: state.onlyRepeat };
    if (!id && state.subj && state.prev) {
      state.showValues = state.prev.showValues;
      state.onlyRepeat = state.prev.onlyRepeat;
      state.prev = null;
    }
    if (id) {
      state.showValues = false;
      state.onlyRepeat = false;
    }
    state.subj = id;
    state.drill = null;
  }

  function rmSync() {
    if (!rmData()) return;
    document.querySelectorAll('[data-rm-group]').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.getAttribute('data-rm-group') === state.group));
    });
    setChip('country', state.country);
    setChip('site', state.site);
    setChip('subj', state.subj);
    if (!allTiles) {
      var c = chart('rm-tiles');
      if (c) allTiles = c.data.slice();
    }
    renderOverview();
    syncBars();
    syncTiles();
    syncListing();
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
    } else if (t.closest('#rm-all-records')) {
      state.drill = { all: true };
      syncListing();
      return;
    } else if (t.closest('#rm-back')) {
      state.drill = null;
      syncListing();
      return;
    } else {
      var tr = t.closest('#rm-vitals tbody tr');
      var api = tr && dtApi('rm-vitals');
      var row = api && api.row(tr).data();
      if (!row) return;
      var cols = api.settings()[0].aoColumns;
      var get = function (name) {
        for (var i = 0; i < cols.length; i++) if (cols[i].name === name) return row[i];
        return null;
      };
      state.drill = { subjid: get('subjid'), label: get('label') };
      syncListing();
      var view = byId('rm-records-view');
      if (view) view.scrollIntoView({ block: 'start' });
      return;
    }
    rmSync();
  });

  document.addEventListener('change', function (e) {
    var id = e.target.id;
    if (id === 'rm-show-values') state.showValues = e.target.checked;
    else if (id === 'rm-only-repeat') state.onlyRepeat = e.target.checked;
    else if (id === 'rm-tiles-sort') {
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

  // gsm.vizr dispatches gsm-viz-select from bars (bar clicks) and tiles (cell
  // and row-header clicks).
  document.addEventListener('gsm-viz-select', function (e) {
    var d = e.detail || {};
    var id = d.chartId || '';
    if (id === 'rm-tiles') {
      if (d.type === 'rowclick') pickParticipant(d.y);
      // Detail cells carry seq; only compact cells select the participant.
      else if (d.type === 'click' && d.datum && d.datum.seq === undefined) pickParticipant(d.datum.subjid);
      return;
    }
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
