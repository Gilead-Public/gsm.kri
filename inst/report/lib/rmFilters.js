// Repeat Measurements report filters and settings. R classifies every
// participant and vital into the widgets and the #rm-data JSON block; this
// script keeps the reviewer's selection and settings, recomputes participant
// flags from N and D when the flag settings change, and hands each widget the
// matching rows.
(function () {
  var FLAG_COLORS = { 0: '#3DAF06', 1: '#FEAA02', 2: '#FF5859' };
  var RAG = ['Red', 'Amber', 'Green'];
  var SEVERITY = { Red: 3, Amber: 2, Green: 1, 'Not evaluable': 0 };
  var state = {
    // Vitals the reviewer unticked; new options start ticked.
    hidden: {},
    country: null,
    site: null,
    subj: null,
    label: 'both',
    sort: 'worst',
    search: '',
    // Values are hidden by default; the compact blocks keep the pattern.
    showValues: false,
    onlyRepeat: true,
    // Data table shape and its "only ... with a repeat window" toggle.
    shape: 'wide',
    // Study overview view: 'counts' table or 'distribution' bars.
    overview: 'distribution',
    // §2: rows by country or site; cells participant or (by country) site flags.
    distLevel: 'country',
    distUnit: 'participants',
    distSort: null,
    distDir: -1,
    distSearch: '',
    // §2 rows: 'all', 'any' (an Amber or Red cell) or 'red' (a Red cell).
    distFlag: 'all',
    dtOnly: true,
    // Listing settings to restore when the participant filter is cleared.
    prev: null
  };
  var data = null;
  var allTiles = null;
  // { rule, thresholds: { count: [amber, red], rate: [amber, red] }, minWindows, bp }
  var settings = null;
  var defaults = null;
  // vital -> { source: 'KRI' | 'report', flags: { invid: 0 | 1 | 2 | null } }
  var siteMap = null;

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

  function clone(x) {
    return JSON.parse(JSON.stringify(x));
  }

  function initSettings() {
    if (settings || !rmData() || !rmData().settings) return;
    defaults = clone(rmData().settings);
    settings = clone(defaults);
  }

  // The BP view swaps systolic and diastolic BP for paired BP, or shows all three.
  function bpShown(vital) {
    var bp = settings ? settings.bp : 'separate';
    if (vital === 'bp') return bp !== 'separate';
    if (vital === 'sysbp' || vital === 'diabp') return bp !== 'combined';
    return true;
  }

  // Vitals the BP view shows, in report order: the Vitals options and the
  // Study overview rows.
  function bpVitals() {
    return rmData().vitals.filter(function (v) {
      return bpShown(v.vital);
    });
  }

  // Vitals the BP view and the Vitals selection show.
  function shownVitals() {
    return bpVitals().filter(function (v) {
      return !state.hidden[v.vital];
    });
  }

  function isShown(vital) {
    return shownVitals().some(function (v) {
      return v.vital === vital;
    });
  }

  function sites() {
    if (!siteMap) {
      siteMap = {};
      (rmData().sites || []).forEach(function (r) {
        var m = siteMap[r.vital] || (siteMap[r.vital] = { source: r.source, flags: {} });
        m.flags[r.invid] = r.flag;
      });
    }
    return siteMap;
  }

  function inScope(row) {
    if (state.subj) return row.subjid === state.subj;
    if (state.site) return row.invid === state.site;
    if (state.country) return row.country === state.country;
    return true;
  }

  // ---- flags ---------------------------------------------------------------
  // Mirrors rm_Classify(): too few windows is Not evaluable; otherwise the
  // count or rate is compared with the Amber and Red thresholds.
  function flagOf(n, d) {
    if (!d || d < settings.minWindows) return 'Not evaluable';
    var x = settings.rule === 'rate' ? n / d : n;
    var th = settings.thresholds[settings.rule];
    if (x >= th[1]) return 'Red';
    if (x >= th[0]) return 'Amber';
    return 'Green';
  }

  // reorder: false on load, where R already sorted the listing worst first.
  function applyFlags(reorder) {
    (allTiles || []).forEach(function (t) {
      t.flag = flagOf(t.Numerator, t.Denominator);
      t.severity = SEVERITY[t.flag];
    });
    var api = dtApi('rm-vitals');
    if (!api) return;
    var ci = colIndex(api);
    api.rows().every(function () {
      var d = this.data();
      d[ci.flag] = flagOf(d[ci.Numerator], d[ci.Denominator]);
    });
    api.rows().invalidate('data');
    if (reorder === false) return;
    // Keep worst first unless the reviewer sorted by another column.
    var order = api.order();
    if (!order.length || order[0][0] === ci.flag) api.order([[ci.flag, 'desc']]);
  }

  // ---- settings ------------------------------------------------------------
  function isRate() {
    return settings.rule === 'rate';
  }

  // Rate thresholds are fractions in #rm-data and percentages in the inputs.
  function syncSettings() {
    document.querySelectorAll('[data-rm-set]').forEach(function (b) {
      var key = b.getAttribute('data-rm-set');
      b.setAttribute('aria-pressed', String(settings[key] === b.value));
    });
    var th = settings.thresholds[settings.rule];
    var scale = isRate() ? 100 : 1;
    var inputs = { 'rm-th-amber': th[0] * scale, 'rm-th-red': th[1] * scale, 'rm-min-windows': settings.minWindows };
    Object.keys(inputs).forEach(function (id) {
      var el = byId(id);
      if (el && document.activeElement !== el) el.value = fmt(inputs[id]);
    });
    document.querySelectorAll('[data-rm-unit]').forEach(function (el) {
      var id = el.getAttribute('data-rm-unit');
      el.textContent = id === 'rm-min-windows' ? '' : isRate() ? '%' : 'windows';
    });
    document.querySelectorAll('.rm-rule-text').forEach(function (el) {
      el.textContent = ruleText();
    });
  }

  function settingsMsg(text) {
    var el = byId('rm-settings-msg');
    if (el) el.textContent = text || '';
  }

  // Applies the inputs when they are valid; otherwise explains and keeps the
  // last valid settings.
  function readThresholds() {
    var amber = parseFloat((byId('rm-th-amber') || {}).value);
    var red = parseFloat((byId('rm-th-red') || {}).value);
    var min = Number((byId('rm-min-windows') || {}).value);
    if (!isFinite(amber) || !isFinite(red) || amber < 0 || red < 0) {
      return settingsMsg('Enter Amber and Red thresholds of 0 or more.');
    }
    if (amber > red) return settingsMsg('Amber must not be above Red.');
    if (!(min >= 1) || Math.floor(min) !== min) return settingsMsg('Minimum windows must be a whole number of 1 or more.');
    var scale = isRate() ? 100 : 1;
    settingsMsg('');
    settings.thresholds[settings.rule] = [amber / scale, red / scale];
    settings.minWindows = min;
    settingsChanged(true);
  }

  function settingsChanged(flags) {
    if (flags) applyFlags();
    syncSettings();
    rmSync();
  }

  // The settings popover opens under its button; the caret points at it.
  function setSettings(open) {
    var panel = byId('rm-settings');
    var btn = byId('rm-settings-toggle');
    if (!panel || !btn || panel.hidden === !open) return;
    panel.hidden = !open;
    btn.setAttribute('aria-expanded', String(open));
    if (!open) return;
    var strip = panel.parentElement.getBoundingClientRect();
    var b = btn.getBoundingClientRect();
    panel.style.setProperty('--rm-caret', Math.max(12, strip.right - b.right + b.width / 2 - 16) + 'px');
  }

  // Hides the floating table of contents so the sections use the full width.
  function setToc(hidden) {
    var toc = byId('TOC');
    var btn = byId('rm-toc-toggle');
    if (!toc || !btn) return;
    var col = toc.parentElement;
    if (col) col.style.display = hidden ? 'none' : '';
    document.body.classList.toggle('rm-toc-hidden', hidden);
    btn.setAttribute('aria-pressed', String(hidden));
    btn.textContent = hidden ? 'Show contents' : 'Hide contents';
    window.dispatchEvent(new Event('resize'));
    ['rm-vitals', 'rm-dt-long', 'rm-dt-wide'].forEach(function (id) {
      var api = dtApi(id);
      if (api) api.columns.adjust();
    });
  }

  function fmt(x) {
    return String(Math.round(x * 1e6) / 1e6);
  }

  function ruleText() {
    var th = settings.thresholds[settings.rule];
    var m = settings.minWindows;
    return (
      (settings.rule === 'rate'
        ? '% of windows that repeat, Amber \u2265 ' + fmt(100 * th[0]) + '%, Red \u2265 ' + fmt(100 * th[1]) + '%'
        : 'repeating windows, Amber \u2265 ' + fmt(th[0]) + ', Red \u2265 ' + fmt(th[1])) +
      '; participants need ' + m + ' window' + (m === 1 ? '' : 's') + ' for a flag'
    );
  }

  // ---- §1 overview --------------------------------------------------------
  // The whole study whatever the filters; it follows only the settings.
  function overviewCounts() {
    var counts = {};
    (allTiles || []).forEach(function (t) {
      var c = counts[t.vital] || (counts[t.vital] = { evaluable: 0, amber: 0, red: 0 });
      if (RAG.indexOf(t.flag) >= 0) c.evaluable++;
      if (t.flag === 'Amber') c.amber++;
      if (t.flag === 'Red') c.red++;
    });
    return counts;
  }

  function siteRuleText() {
    var r = rmData().siteRule || { thresholds: [0.2, 0.3], accrual: 3 };
    return '% of the site\u2019s windows that repeat (summed over its participants), Amber \u2265 ' + fmt(100 * r.thresholds[0]) +
      '%, Red \u2265 ' + fmt(100 * r.thresholds[1]) + '%; sites need ' + r.accrual + ' window' + (r.accrual === 1 ? '' : 's') + ' for a flag';
  }

  // Filled circles are KRI flags; empty circles are flags the report calculates.
  function dots(amber, red, filled, title) {
    var dot = function (color, n) {
      return '<span class="rm-fl"><span class="rm-dot' + (filled ? '' : ' rm-o') + '" style="background:' + color + ';border-color:' + color + '"></span>' + n.toLocaleString() + '</span>';
    };
    return '<span title="' + esc(title) + '">' + dot(FLAG_COLORS[1], amber) + dot(FLAG_COLORS[2], red) + '</span>';
  }

  function info(text) {
    return '<i class="rm-info" tabindex="0" role="img" aria-label="' + esc(text) + '" title="' + esc(text) + '">i</i>';
  }

  // One entry per shown measure: site and participant flag counts for the whole study.
  function overviewRows() {
    var counts = overviewCounts();
    return bpVitals().map(function (v) {
      var r = counts[v.vital] || { evaluable: 0, amber: 0, red: 0 };
      var s = sites()[v.vital] || { source: 'report', flags: {} };
      var site = { evaluated: 0, amber: 0, red: 0 };
      Object.keys(s.flags).forEach(function (id) {
        var f = s.flags[id];
        if (f === null || f === undefined) return;
        site.evaluated++;
        if (f === 1) site.amber++;
        if (f === 2) site.red++;
      });
      return { v: v, kri: s.source === 'KRI', site: site, part: r };
    });
  }

  function measureCell(v) {
    return '<td class="rm-l">' + esc(v.label) +
      (v.metric ? '<span class="rm-kri" title="' + esc(v.metric) + '">KRI</span>' : '') + '</td>';
  }

  // A 100% stacked bar of not flagged / Amber / Red; labels only where they fit.
  function stackBar(n, amber, red, noun, source) {
    if (!n) return '<span class="rm-ne">Not evaluated</span>';
    var parts = [
      ['none', n - amber - red, 'Not flagged'],
      ['amber', amber, 'Amber'],
      ['red', red, 'Red']
    ];
    var title = parts.map(function (x) {
      return x[2] + ': ' + x[1].toLocaleString() + ' (' + pct(x[1], n) + ')';
    }).join(' \u00b7 ') + ' of ' + n.toLocaleString() + ' ' + noun + (source ? ' \u00b7 ' + source : '');
    return '<span class="rm-bar" role="img" aria-label="' + esc(title) + '" title="' + esc(title) + '">' +
      parts.map(function (x) {
        var w = (100 * x[1]) / n;
        return w > 0
          ? '<span class="rm-seg-' + x[0] + '" data-rm-part="' + x[0] + '" style="width:' + w.toFixed(2) + '%">' + (w >= 7.5 ? Math.round(w) + '%' : '') + '</span>'
          : '';
      }).join('') + '</span><span class="rm-bar-n">' + n.toLocaleString() + '</span>';
  }

  function siteInfo() {
    return info(
      'Site flag: ' + siteRuleText() + '. N: sites evaluated / sites with enrolled participants. ' +
      'Filled circles: the KRI site flags (kri0020a\u2013f, latest snapshot). ' +
      'Empty circles: calculated in the report with the same rule, for measures without KRI results.'
    );
  }

  function participantInfo() {
    return info(
      'Participant flag: ' + ruleText() + '. N: evaluable / enrolled participants. ' +
      'Empty circles: calculated in the report; change the rule under Settings.'
    );
  }

  // A row click picks its measure in the Measures select; the selected rows stand out.
  function ovRow(vital) {
    var only = shownVitals();
    var partial = only.length < bpVitals().length;
    var on = partial && isShown(vital);
    var title = on && only.length === 1 ? 'Show all measures' : 'Show only this measure in the report';
    return '<tr data-rm-overview="' + esc(vital) + '" class="' + (on ? 'rm-on' : partial ? 'rm-dim' : '') +
      '" title="' + title + '">';
  }

  function renderOverview() {
    var el = byId('rm-overview');
    if (!el) return;
    document.querySelectorAll('[data-rm-ov]').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.getAttribute('data-rm-ov') === state.overview));
    });
    var participants = rmData().participants || [];
    var enrolled = participants.length;
    var siteIds = {};
    participants.forEach(function (p) {
      siteIds[p.invid] = true;
    });
    var nSites = Object.keys(siteIds).length;
    var rows = overviewRows();
    var h;
    if (state.overview === 'distribution') {
      h = '<table class="table table-condensed rm-ov-dist" data-rm-ov-view="distribution"><thead><tr>' +
        '<th class="rm-l">Measure</th>' +
        '<th class="rm-l rm-sep">Sites' + siteInfo() + ' <span class="b">% of sites evaluated</span></th>' +
        '<th class="rm-l rm-sep">Participants' + participantInfo() + ' <span class="b">% of evaluable participants</span></th>' +
        '</tr></thead><tbody>';
      rows.forEach(function (o) {
        h += ovRow(o.v.vital) + measureCell(o.v) +
          '<td class="rm-l rm-sep" data-rm-col="site-dist" data-rm-source="' + (o.kri ? 'KRI' : 'report') + '">' +
          stackBar(o.site.evaluated, o.site.amber, o.site.red, 'sites evaluated', o.kri ? 'from ' + o.v.metric : 'calculated in the report') + '</td>' +
          '<td class="rm-l rm-sep" data-rm-col="participant-dist">' +
          stackBar(o.part.evaluable, o.part.amber, o.part.red, 'evaluable participants', 'calculated in the report') + '</td></tr>';
      });
      el.innerHTML = h + '</tbody></table>' +
        '<p class="rm-legend">The whole study: the filters do not change this chart. Click a measure to show only it in the report. ' +
        '<span class="rm-dot" style="background:#d0d7de;border-color:#d0d7de"></span>Not flagged \u00b7 ' +
        '<span class="rm-dot" style="background:' + FLAG_COLORS[1] + ';border-color:' + FLAG_COLORS[1] + '"></span>Amber \u00b7 ' +
        '<span class="rm-dot" style="background:' + FLAG_COLORS[2] + ';border-color:' + FLAG_COLORS[2] + '"></span>Red. ' +
        'The number after a bar is the sites evaluated or participants evaluable. Hover a bar for counts.</p>';
      return;
    }
    h =
      '<table class="table table-condensed" data-rm-ov-view="counts"><thead>' +
      '<tr><th rowspan="2" class="rm-l">Measure</th>' +
      '<th colspan="2" class="rm-grp rm-sep">Sites' + siteInfo() + '</th>' +
      '<th colspan="2" class="rm-grp rm-sep">Participants' + participantInfo() + '</th></tr>' +
      '<tr><th class="rm-sep">N</th><th>Flags</th><th class="rm-sep">N</th><th>Flags</th></tr></thead><tbody>';
    rows.forEach(function (o) {
      var v = o.v;
      var r = o.part;
      h +=
        ovRow(v.vital) + measureCell(v) +
        '<td class="rm-sep" data-rm-col="sites" title="' + o.site.evaluated + ' of ' + nSites + ' sites evaluated">' + o.site.evaluated + ' / ' + nSites + '</td>' +
        '<td data-rm-col="site-flags" data-rm-source="' + (o.kri ? 'KRI' : 'report') + '">' + dots(o.site.amber, o.site.red, o.kri, o.kri
          ? 'Amber / Red sites from ' + v.metric
          : 'Amber / Red sites calculated in the report') + '</td>' +
        '<td class="rm-sep" data-rm-col="participants" title="' + r.evaluable + ' of ' + enrolled + ' participants evaluable (' + pct(r.evaluable, enrolled) + ')">' +
        r.evaluable.toLocaleString() + ' / ' + enrolled.toLocaleString() + '</td>' +
        '<td data-rm-col="participant-flags">' + dots(r.amber, r.red, false, 'Amber / Red participants (' + pct(r.amber + r.red, r.evaluable) + ' of evaluable)') + '</td></tr>';
    });
    el.innerHTML = h + '</tbody></table>' +
      '<p class="rm-legend">The whole study: the filters do not change this table. Click a measure to show only it in the report. ' +
      '<span class="rm-dot" style="background:#8c959f;border-color:#8c959f"></span>KRI flag \u00b7 ' +
      '<span class="rm-dot rm-o" style="border-color:#8c959f"></span>calculated in the report. Hover <i class="rm-info" aria-hidden="true">i</i> for the flag rules.</p>';
  }

  function pct(n, d) {
    return d ? Math.round((100 * n) / d) + '%' : '\u2013';
  }

  // ---- §2 distribution ----------------------------------------------------
  // One row per country or site, one column per shown measure. Cells are a
  // 100% bar of evaluable participants (or, by country, sites evaluated) by
  // flag; the hover card has the counts.
  var NE_COLOR = '#CACACA';

  function blank() {
    return { enr: 0, ev: 0, a: 0, r: 0, sites: 0, sev: 0, sa: 0, sr: 0, N: 0, D: 0 };
  }

  // { study, countries, sites } groups with per-measure counts.
  function distGroups() {
    var vitals = bpVitals();
    var siteFlags = sites();
    var study = { label: 'Study', key: null, m: {}, siteIds: {}, np: 0 };
    var countries = {};
    var siteRows = {};
    var get = function (map, key, extra) {
      if (!map[key]) {
        map[key] = Object.assign({ label: key, key: key, m: {}, siteIds: {}, np: 0 }, extra || {});
        vitals.forEach(function (v) {
          map[key].m[v.vital] = blank();
        });
      }
      return map[key];
    };
    vitals.forEach(function (v) {
      study.m[v.vital] = blank();
    });
    (rmData().participants || []).forEach(function (p) {
      var c = get(countries, p.country);
      var st = get(siteRows, p.invid, { country: p.country });
      c.siteIds[p.invid] = true;
      study.siteIds[p.invid] = true;
      study.np++;
      c.np++;
      st.np++;
      vitals.forEach(function (v) {
        study.m[v.vital].enr++;
        c.m[v.vital].enr++;
        st.m[v.vital].enr++;
      });
    });
    (allTiles || []).forEach(function (t) {
      var st = siteRows[t.invid];
      if (!st || !st.m[t.vital]) return;
      st.m[t.vital].N += t.Numerator || 0;
      st.m[t.vital].D += t.Denominator || 0;
      if (RAG.indexOf(t.flag) < 0) return;
      [study, countries[st.country], st].forEach(function (g) {
        var x = g.m[t.vital];
        x.ev++;
        if (t.flag === 'Amber') x.a++;
        if (t.flag === 'Red') x.r++;
      });
    });
    // Site flags: KRI results, or calculated in the report for the other measures.
    Object.keys(siteRows).forEach(function (id) {
      var st = siteRows[id];
      vitals.forEach(function (v) {
        var f = ((siteFlags[v.vital] || {}).flags || {})[id];
        f = f === undefined ? null : f;
        st.m[v.vital].flag = f;
        [study, countries[st.country]].forEach(function (g) {
          var x = g.m[v.vital];
          x.sites++;
          if (f === null) return;
          x.sev++;
          if (f === 1) x.sa++;
          if (f === 2) x.sr++;
        });
      });
    });
    var byName = function (a, b) {
      return a.label < b.label ? -1 : a.label > b.label ? 1 : 0;
    };
    return {
      study: study,
      countries: Object.keys(countries).map(function (k) {
        return countries[k];
      }).sort(byName),
      sites: Object.keys(siteRows).map(function (k) {
        return siteRows[k];
      }).sort(function (a, b) {
        return a.country < b.country ? -1 : a.country > b.country ? 1 : byName(a, b);
      })
    };
  }

  function distSiteUnit() {
    return state.distUnit === 'sites' && state.distLevel === 'country';
  }

  function tipDot(color, hollow) {
    return '<span class="d" style="' + (hollow ? 'border:2px solid ' + color : 'background:' + color) + '"></span>';
  }

  function tipHtml(head, nLab, n, d, a, r, hollow, extra) {
    var row = function (color, lab, v) {
      return '<tr><td>' + tipDot(color, hollow) + lab + '</td><td class="n">' + v.toLocaleString() + '</td><td class="n">' + (n ? pct(v, n) : '') + '</td></tr>';
    };
    return '<div class="h">' + head + '</div>' + (extra || '') +
      '<div>' + nLab + ': <b>' + n.toLocaleString() + ' / ' + d.toLocaleString() + '</b> (' + pct(n, d) + ')</div>' +
      (n
        ? '<table>' + row('#d0d7de', 'Not flagged', n - a - r) + row(FLAG_COLORS[1], 'Amber', a) + row(FLAG_COLORS[2], 'Red', r) + '</table>' +
          '<div class="sub">' + (a + r).toLocaleString() + ' flagged (' + pct(a + r, n) + ')</div>'
        : '<div class="sub">Not evaluated</div>');
  }

  function distBar(n, a, r, label) {
    if (!n) return '<span class="rm-ne">Not evaluated</span>';
    var parts = [['none', n - a - r], ['amber', a], ['red', r]];
    return '<span class="rm-bar" role="img" aria-label="' + esc(label) + '">' +
      parts.map(function (x) {
        var w = (100 * x[1]) / n;
        return w > 0
          ? '<span class="rm-seg-' + x[0] + '" data-rm-part="' + x[0] + '" style="width:' + w.toFixed(2) + '%">' + (w >= 30 ? Math.round(w) + '%' : '') + '</span>'
          : '';
      }).join('') + '</span><span class="rm-bar-n">' + n.toLocaleString() + '</span>';
  }

  function distCell(g, v, isStudy) {
    var x = g.m[v.vital];
    var kri = (sites()[v.vital] || {}).source === 'KRI';
    var head = '<b>' + esc(g.label) + '</b> \u00b7 ' + esc(v.label);
    var n, a, r, tip, summary, sf = '';
    if (distSiteUnit()) {
      n = x.sev;
      a = x.sa;
      r = x.sr;
      tip = tipHtml(head + ' \u00b7 site flags', 'Sites evaluated', n, x.sites, a, r, !kri,
        '<div class="sub" style="margin:0 0 3px">' + (kri ? 'KRI site flags (' + esc(v.metric) + ')' : 'Calculated in the report') + '</div>');
      summary = a + ' Amber, ' + r + ' Red of ' + n + ' sites evaluated';
    } else {
      n = x.ev;
      a = x.a;
      r = x.r;
      var extra = '';
      if (state.distLevel === 'site' && !isStudy) {
        var f = x.flag;
        var color = f === null || f === undefined ? NE_COLOR : FLAG_COLORS[f];
        var name = f === null || f === undefined ? 'Not evaluated' : ['Green', 'Amber', 'Red'][f];
        sf = '<span class="rm-sf rm-dot' + (kri ? '' : ' rm-o') + '" data-rm-site-flag="' + name + '" title="Site flag: ' + name + (kri ? ' (' + esc(v.metric) + ')' : ' (calculated)') + '" style="background:' + color + ';border-color:' + color + '"></span>';
        extra = '<div style="margin-bottom:3px">Site flag: ' + tipDot(color, !kri) + '<b>' + name + '</b>' +
          (x.D ? ' \u00b7 ' + x.N + ' of ' + x.D + ' windows repeat (' + pct(x.N, x.D) + ')' : '') +
          '<span style="color:#c9d1d9"> \u00b7 ' + (kri ? esc(v.metric) : 'calculated') + '</span></div>';
      }
      tip = tipHtml(head + ' \u00b7 participants', 'Evaluable', n, x.enr, a, r, true, extra);
      summary = a + ' Amber, ' + r + ' Red of ' + n + ' evaluable participants';
    }
    return '<td class="rm-sep rm-cell" data-rm-dist-vital="' + esc(v.vital) + '" data-rm-n="' + n + '" data-rm-amber="' + a + '" data-rm-red="' + r +
      '" data-rm-tip="' + esc(tip) + '">' + sf + distBar(n, a, r, summary) + '</td>';
  }

  // Sort keys: a vital (% flagged), or _np / _ns (enrolled participants / sites).
  var COUNT_SORT = { _np: 'participants', _ns: 'sites' };

  function distSortVal(g, vital) {
    if (vital === '_np') return g.np;
    if (vital === '_ns') return Object.keys(g.siteIds).length;
    var x = g.m[vital];
    if (distSiteUnit()) return x.sev ? (x.sa + x.sr) / x.sev : -1;
    return x.ev ? (x.a + x.r) / x.ev : -1;
  }

  var DIST_KEYS = { level: 'distLevel', unit: 'distUnit', flag: 'distFlag' };

  // Whether a row has a flag the Flags control keeps, in the unit the cells show.
  function distFlagged(g, vitals) {
    var red = state.distFlag === 'red';
    var siteUnit = distSiteUnit();
    return vitals.some(function (v) {
      var x = g.m[v.vital];
      var a = siteUnit ? x.sa : x.a;
      var r = siteUnit ? x.sr : x.r;
      return (red ? r : a + r) > 0;
    });
  }

  function renderDist() {
    var el = byId('rm-dist');
    if (!el) return;
    var isSite = state.distLevel === 'site';
    if (isSite) state.distUnit = 'participants';
    document.querySelectorAll('[data-rm-dist]').forEach(function (b) {
      var k = DIST_KEYS[b.getAttribute('data-rm-dist')];
      b.setAttribute('aria-pressed', String(b.value === state[k]));
    });
    var sb = byId('rm-dist-sites');
    if (sb) {
      sb.disabled = isSite;
      sb.title = isSite
        ? 'Country view only. In site view, the dot before the bar is the site\u2019s own flag.'
        : 'Show site flags for each country';
    }
    var search = byId('rm-dist-search');
    if (search) search.hidden = !isSite;
    var unitSites = distSiteUnit();
    var vitals = shownVitals();
    var countSort = state.distSort === '_np' || (state.distSort === '_ns' && !isSite);
    if (state.distSort && !countSort && !vitals.some(function (v) { return v.vital === state.distSort; })) state.distSort = null;
    var groups = distGroups();
    var all = isSite ? groups.sites : groups.countries;
    // Site rows narrow to the selected country, like the other sections.
    var rows = all.filter(function (g) {
      if (state.distFlag !== 'all' && !distFlagged(g, vitals)) return false;
      if (!isSite) return true;
      if (state.country && g.country !== state.country) return false;
      var q = state.distSearch.trim().toLowerCase();
      return !q || (g.label + ' ' + g.country).toLowerCase().indexOf(q) >= 0;
    });
    if (state.distSort) {
      rows.sort(function (a, b) {
        return state.distDir * (distSortVal(a, state.distSort) - distSortVal(b, state.distSort)) ||
          (a.label < b.label ? -1 : a.label > b.label ? 1 : 0);
      });
    }
    var who = unitSites ? 'sites' : 'participants';
    // Enrolled participants (and, by country, sites with enrolled participants) per row.
    var counts = function (g) {
      return '<td class="rm-n" data-rm-dist-np="' + g.np + '">' + g.np.toLocaleString() + '</td>' +
        (isSite ? '' : '<td class="rm-n" data-rm-dist-ns="' + Object.keys(g.siteIds).length + '">' + Object.keys(g.siteIds).length.toLocaleString() + '</td>');
    };
    var sortAttrs = function (key) {
      var on = state.distSort === key;
      return ' data-rm-dist-sort="' + key + '"' + (on ? ' aria-sort="' + (state.distDir < 0 ? 'descending' : 'ascending') + '"' : '');
    };
    var arrow = function (key) {
      return state.distSort === key ? '<span class="rm-arr">' + (state.distDir < 0 ? '\u25bc' : '\u25b2') + '</span>' : '';
    };
    var lead = (isSite
      ? '<th class="rm-l rm-stick">Site</th><th class="rm-l rm-stick2">Country</th>'
      : '<th class="rm-l rm-stick">Country</th>') +
      '<th class="rm-n rm-cnt" title="Enrolled participants. Sort by participants"' + sortAttrs('_np') + '>' + arrow('_np') + 'Participants</th>' +
      (isSite ? '' : '<th class="rm-n rm-cnt" title="Sites with enrolled participants. Sort by sites"' + sortAttrs('_ns') + '>' + arrow('_ns') + 'Sites</th>');
    var h1 = '<tr>' + lead;
    vitals.forEach(function (v) {
      var on = state.distSort === v.vital;
      h1 += '<th class="rm-grp rm-sep" data-rm-dist-sort="' + esc(v.vital) + '" title="' + (unitSites ? 'Site flags' : 'Participant flags') + '. Sort by % ' + who + ' flagged"' +
        (on ? ' aria-sort="' + (state.distDir < 0 ? 'descending' : 'ascending') + '"' : '') + '>' + esc(v.label) +
        (v.metric ? '<span class="rm-kri" title="' + esc(v.metric) + '">KRI</span>' : '') +
        (on ? '<span class="rm-arr">' + (state.distDir < 0 ? '\u25bc' : '\u25b2') + '</span>' : '') + '</th>';
    });
    var body = '<tr class="rm-study" data-rm-dist-study=""><td class="rm-l rm-stick">Study</td>' + (isSite ? '<td class="rm-l rm-stick2"></td>' : '') + counts(groups.study);
    vitals.forEach(function (v) {
      body += distCell(groups.study, v, true);
    });
    body += '</tr>';
    var selected = isSite ? state.site : state.country;
    rows.forEach(function (g) {
      var on = selected === g.key;
      var cls = on ? 'rm-on' : selected ? 'rm-dim' : '';
      body += '<tr data-rm-dist-row="' + state.distLevel + '" data-rm-dist-key="' + esc(g.key) + '"' + (isSite ? ' data-rm-dist-country="' + esc(g.country) + '"' : '') +
        (cls ? ' class="' + cls + '"' : '') + ' aria-selected="' + on + '" title="Click to filter the report to ' + (isSite ? 'site ' : '') + esc(g.label) + '; click again to clear">' +
        '<td class="rm-l rm-stick">' + esc(g.label) + '</td>' + (isSite ? '<td class="rm-l rm-stick2">' + esc(g.country) + '</td>' : '') + counts(g);
      vitals.forEach(function (v) {
        body += distCell(g, v, false);
      });
      body += '</tr>';
    });
    el.innerHTML = vitals.length
      ? '<table class="table table-condensed" data-rm-dist-level="' + state.distLevel + '" data-rm-dist-unit="' + (unitSites ? 'sites' : 'participants') + '"><thead>' +
        h1 + '</tr></thead><tbody>' + body + '</tbody></table>'
      : '<p class="rm-ne">No vitals selected.</p>';
    var first = el.querySelector('thead th.rm-stick');
    if (first) {
      first.insertAdjacentHTML('beforeend', unitSites
        ? info('Site flag: ' + siteRuleText() + '. N: sites evaluated / sites with enrolled participants. ' +
          'Filled circles: the KRI site flags (kri0020a\u2013f, latest snapshot). Empty circles: calculated in the report with the same rule.')
        : info('Participant flag: ' + ruleText() + '. N: evaluable / enrolled participants. Calculated in the report; change the rule under Settings.' +
          (isSite ? ' The dot before a bar is the site\u2019s own flag: ' + siteRuleText() + '.' : '')));
      el.style.setProperty('--rm-c1', first.offsetWidth + 'px');
    }
    var count = byId('rm-dist-count');
    if (count) {
      var sorted = vitals.filter(function (v) { return v.vital === state.distSort; })[0];
      count.textContent = (isSite
        ? rows.length + ' of ' + all.length + ' sites'
        : (rows.length < all.length ? rows.length + ' of ' + all.length : rows.length) + ' countr' + (all.length === 1 ? 'y' : 'ies')) +
        (sorted ? ' \u00b7 sorted by % flagged, ' + sorted.label : COUNT_SORT[state.distSort] ? ' \u00b7 sorted by ' + COUNT_SORT[state.distSort] : '');
    }
    var legend = byId('rm-dist-legend');
    if (legend) {
      legend.innerHTML = '<span class="rm-dot" style="background:#d0d7de;border-color:#d0d7de"></span>Not flagged \u00b7 ' +
        '<span class="rm-dot" style="background:' + FLAG_COLORS[1] + ';border-color:' + FLAG_COLORS[1] + '"></span>Amber \u00b7 ' +
        '<span class="rm-dot" style="background:' + FLAG_COLORS[2] + ';border-color:' + FLAG_COLORS[2] + '"></span>Red. ' +
        'The number after a bar is the ' + (unitSites ? 'sites evaluated' : 'participants evaluable') + '. Hover a cell for counts.' +
        (isSite ? ' The dot before a bar is the site\u2019s own flag for the measure (filled: KRI; empty: calculated; grey: not evaluated).' : '') +
        ' Hover <i class="rm-info" aria-hidden="true">i</i> for the flag rules.';
    }
  }

  function distTip(e) {
    var tip = byId('rm-dist-tip');
    if (!tip) return;
    var td = e.type === 'mouseover' && e.target.closest ? e.target.closest('#rm-dist td[data-rm-tip]') : null;
    if (e.type === 'mouseover') {
      if (!td) {
        tip.hidden = true;
        return;
      }
      tip.innerHTML = td.getAttribute('data-rm-tip');
      tip.hidden = false;
    }
    if (tip.hidden) return;
    var w = tip.offsetWidth;
    var h = tip.offsetHeight;
    var x = e.clientX + 14;
    var y = e.clientY + 16;
    if (x + w > window.innerWidth - 8) x = e.clientX - w - 14;
    if (y + h > window.innerHeight - 8) y = e.clientY - h - 12;
    tip.style.left = x + 'px';
    tip.style.top = y + 'px';
  }

  // ---- §3 participant listing (tiles) -------------------------------------
  function tileRows() {
    var q = state.search.trim().toUpperCase();
    var rows = allTiles.filter(function (t) {
      if (!isShown(t.vital) || !inScope(t)) return false;
      return !q || (t.subjid + ' ' + t.invid + ' ' + t.country).toUpperCase().indexOf(q) >= 0;
    });
    // Rows render in first-appearance order, so sorting participants sorts the grid.
    var key = {};
    var rateVital = state.sort.indexOf('rate:') === 0 ? state.sort.slice(5) : null;
    rows.forEach(function (t, i) {
      var k = key[t.subjid] || (key[t.subjid] = { i: i, rate: -1, worst: -1, most: -1 });
      if (rateVital && t.vital === rateVital && t.rate !== null) k.rate = t.rate;
      // Worst flag over the vitals shown, as the flags may have changed.
      k.worst = Math.max(k.worst, t.severity);
      k.most = Math.max(k.most, t.Numerator);
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
      if (state.sort === 'worst') {
        return key[b.subjid].worst - key[a.subjid].worst || key[b.subjid].most - key[a.subjid].most || (a.subjid < b.subjid ? -1 : 1);
      }
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
      vitals.column('vital:name').search(vitalRegex(), true, false);
      vitals.column('has_repeat:name').search(state.onlyRepeat ? '^Y$' : '', true, false);
      vitals.column('country:name').search(exact(state.country), true, false);
      vitals.column('invid:name').search(exact(state.site), true, false);
      vitals.column('subjid:name').search(exact(state.subj), true, false);
      vitals.draw();
    }
  }

  // ---- §5 data table -------------------------------------------------------
  function vitalKeys() {
    return shownVitals().map(function (v) {
      return jQuery.fn.dataTable.util.escapeRegex(v.vital);
    });
  }

  // Every vital row the Vitals selection and BP view show; matches nothing when none do.
  function vitalRegex() {
    var keys = vitalKeys();
    return keys.length ? '^(' + keys.join('|') + ')$' : '^\\b$';
  }

  function colIndex(api) {
    var ci = {};
    api.settings()[0].aoColumns.forEach(function (c, i) {
      if (c.name) ci[c.name] = i;
    });
    return ci;
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
    var keys = vitalKeys();
    var scope = function (api) {
      api.column('country:name').search(exact(state.country), true, false);
      api.column('invid:name').search(exact(state.site), true, false);
      api.column('subjid:name').search(exact(state.subj), true, false);
    };

    var long = dtApi('rm-dt-long');
    if (long) {
      long.column('vital:name').search(vitalRegex(), true, false);
      long.column('has_repeat:name').search(state.dtOnly ? '^Y$' : '', true, false);
      scope(long);
      long.draw();
    }

    var wide = dtApi('rm-dt-wide');
    if (wide) {
      var shown = {};
      rmData().vitals.forEach(function (v) {
        shown[v.vital] = false;
      });
      shownVitals().forEach(function (v) {
        shown[v.vital] = true;
      });
      wide.columns().every(function () {
        var name = this.settings()[0].aoColumns[this.index()].name;
        if (name in shown && this.visible() !== shown[name]) this.visible(shown[name], false);
      });
      var onlyRe = '';
      if (state.dtOnly) onlyRe = keys.length ? '(^| )(' + keys.join('|') + ')( |$)' : '^\\b$';
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

  // The Vitals menu offers the vitals the BP view shows.
  function syncVitalMenu() {
    var opts = bpVitals();
    var keys = opts.map(function (v) {
      return v.vital;
    });
    document.querySelectorAll('[data-rm-vital-opt]').forEach(function (l) {
      var k = l.getAttribute('data-rm-vital-opt');
      l.style.display = keys.indexOf(k) >= 0 ? '' : 'none';
      l.querySelector('input').checked = !state.hidden[k];
    });
    var shown = shownVitals();
    var all = byId('rm-vital-all');
    if (all) {
      all.checked = shown.length === opts.length;
      all.indeterminate = shown.length > 0 && shown.length < opts.length;
    }
    var summary = byId('rm-vital-summary');
    if (summary) {
      summary.textContent = shown.length === opts.length
        ? 'All'
        : !shown.length
          ? 'None'
          : shown.length <= 3
            ? shown.map(function (v) { return v.short; }).join(', ')
            : shown.length + ' of ' + opts.length;
    }
  }

  function setVitalMenu(open) {
    var menu = byId('rm-vital-menu');
    var btn = byId('rm-vital-btn');
    if (!menu || !btn) return;
    menu.hidden = !open;
    btn.setAttribute('aria-expanded', String(open));
  }

  function rmSync() {
    if (!rmData()) return;
    initSettings();
    syncVitalMenu();
    setChip('country', state.country);
    setChip('site', state.site);
    setChip('subj', state.subj);
    renderCount();
    if (!allTiles) {
      var c = chart('rm-tiles');
      if (c) allTiles = c.data.slice();
    }
    if (settings && !settings._applied) {
      // R used the same settings, so this only keeps the two in step.
      settings._applied = true;
      applyFlags(false);
      syncSettings();
    }
    renderOverview();
    renderDist();
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
    var clear = t.closest('[data-rm-clear]');
    var label = t.closest('[data-rm-label]');
    if (!t.closest('.rm-ms')) setVitalMenu(false);
    if (!t.closest('#rm-settings') && !t.closest('#rm-settings-toggle')) setSettings(false);
    if (t.closest('#rm-vital-btn')) {
      setVitalMenu(byId('rm-vital-menu').hidden);
      return;
    } else if (t.closest('#rm-vital-menu')) {
      return;
    } else if (clear) {
      var key = clear.getAttribute('data-rm-clear');
      // Clearing a level also clears the levels inside it.
      if (key === 'country') state.country = null;
      if (key !== 'subj') state.site = null;
      setSubj(null);
    } else if (label) {
      setLabel(label.getAttribute('data-rm-label'));
      return;
    } else if (t.closest('#rm-reset')) {
      state.hidden = {};
      state.country = null;
      state.site = null;
      setSubj(null);
    } else if (t.closest('#rm-settings-toggle')) {
      setSettings(byId('rm-settings').hidden);
      return;
    } else if (t.closest('#rm-settings-done')) {
      setSettings(false);
      byId('rm-settings-toggle').focus();
      return;
    } else if (t.closest('#rm-how-toggle')) {
      var how = byId('rm-how');
      how.hidden = !how.hidden;
      t.closest('#rm-how-toggle').setAttribute('aria-expanded', String(!how.hidden));
      return;
    } else if (t.closest('#rm-toc-hide')) {
      setToc(true);
      // The sidebar button disappears with the sidebar; the toolbar button restores it.
      var show = byId('rm-toc-toggle');
      if (show) show.focus();
    } else if (t.closest('#rm-toc-toggle')) {
      setToc(!document.body.classList.contains('rm-toc-hidden'));
      return;
    } else if (t.closest('[data-rm-set]')) {
      var set = t.closest('[data-rm-set]');
      var k = set.getAttribute('data-rm-set');
      if (settings[k] === set.value) return;
      settings[k] = set.value;
      settingsMsg('');
      settingsChanged(k === 'rule');
      return;
    } else if (t.closest('#rm-settings-defaults')) {
      var keep = settings._applied;
      settings = clone(defaults);
      settings._applied = keep;
      settingsMsg('');
      settingsChanged(true);
      return;
    } else if (t.closest('#rm-tiles-csv')) {
      downloadTiles();
      return;
    } else if (t.closest('[data-rm-ov]')) {
      state.overview = t.closest('[data-rm-ov]').getAttribute('data-rm-ov');
      renderOverview();
      return;
    } else if (t.closest('#rm-overview tbody tr[data-rm-overview]')) {
      var ov = t.closest('tr').getAttribute('data-rm-overview');
      var only = shownVitals();
      state.hidden = {};
      if (!(only.length === 1 && only[0].vital === ov)) {
        bpVitals().forEach(function (v) {
          if (v.vital !== ov) state.hidden[v.vital] = true;
        });
      }
    } else if (t.closest('[data-rm-dist]')) {
      var db = t.closest('[data-rm-dist]');
      if (db.disabled) return;
      state[DIST_KEYS[db.getAttribute('data-rm-dist')]] = db.value;
      renderDist();
      return;
    } else if (t.closest('#rm-dist th[data-rm-dist-sort]')) {
      var k2 = t.closest('th').getAttribute('data-rm-dist-sort');
      if (state.distSort !== k2) {
        state.distSort = k2;
        state.distDir = -1;
      } else if (state.distDir < 0) {
        state.distDir = 1;
      } else {
        state.distSort = null;
        state.distDir = -1;
      }
      renderDist();
      return;
    } else if (t.closest('#rm-dist tbody tr[data-rm-dist-row]')) {
      var dr = t.closest('tr');
      var key2 = dr.getAttribute('data-rm-dist-key');
      if (dr.getAttribute('data-rm-dist-row') === 'country') {
        state.country = key2 === state.country && !state.site ? null : key2;
        state.site = null;
      } else if (key2 === state.site) {
        state.site = null;
      } else {
        state.site = key2;
        state.country = dr.getAttribute('data-rm-dist-country');
      }
      setSubj(null);
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
    if (id === 'rm-vital-all') {
      state.hidden = {};
      if (!e.target.checked) {
        bpVitals().forEach(function (v) {
          state.hidden[v.vital] = true;
        });
      }
      rmSync();
      return;
    }
    if (e.target.hasAttribute('data-rm-vital-cb')) {
      if (e.target.checked) delete state.hidden[e.target.value];
      else state.hidden[e.target.value] = true;
      rmSync();
      return;
    }
    if (id === 'rm-th-amber' || id === 'rm-th-red' || id === 'rm-min-windows') {
      readThresholds();
      return;
    }
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

  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape') return;
    var menu = byId('rm-vital-menu');
    var panel = byId('rm-settings');
    if (menu && !menu.hidden) {
      setVitalMenu(false);
      byId('rm-vital-btn').focus();
    } else if (panel && !panel.hidden) {
      setSettings(false);
      byId('rm-settings-toggle').focus();
    }
  });

  // Slims the floating table of contents into an "On this page" list.
  function slimToc() {
    var toc = byId('TOC');
    if (!toc || !toc.parentElement || !toc.parentElement.nextElementSibling ||
      !toc.parentElement.nextElementSibling.classList.contains('toc-content')) return;
    toc.classList.add('rm-toc');
    toc.parentElement.classList.add('rm-toc-col');
    if (byId('rm-toc-hide')) return;
    var head = document.createElement('div');
    head.className = 'rm-toc-head';
    head.innerHTML = '<span>On this page</span><button id="rm-toc-hide" type="button" ' +
      'class="rm-toc-hide" aria-label="Hide contents" title="Hide contents">&laquo;</button>';
    toc.insertBefore(head, toc.firstChild);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', slimToc);
  else slimToc();

  document.addEventListener('input', function (e) {
    if (e.target.id === 'rm-dist-search') {
      state.distSearch = e.target.value;
      renderDist();
      return;
    }
    if (e.target.id !== 'rm-tiles-search') return;
    state.search = e.target.value;
    syncTiles();
  });

  // The Participant Listing widget dispatches rm-tiles-select on a label or
  // tile click (or Enter / Space).
  document.addEventListener('rm-tiles-select', function (e) {
    pickParticipant((e.detail || {}).subjid);
  });

  ['mouseover', 'mousemove'].forEach(function (type) {
    document.addEventListener(type, function (e) {
      if (type === 'mousemove' && !(e.target.closest && e.target.closest('#rm-dist'))) {
        var tip = byId('rm-dist-tip');
        if (tip) tip.hidden = true;
        return;
      }
      distTip(e);
    });
  });
  // The card follows the pointer; scrolling the table moves the cell away from it.
  document.addEventListener('scroll', function (e) {
    var tip = byId('rm-dist-tip');
    if (tip && e.target && e.target.id === 'rm-dist') tip.hidden = true;
  }, true);

  window.addEventListener('load', function () {
    var toc = byId('rm-toc-toggle');
    if (toc && byId('TOC')) toc.style.display = '';
    rmSync();
  });
})();
