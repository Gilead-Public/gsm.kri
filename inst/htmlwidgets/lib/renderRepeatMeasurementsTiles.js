// Participant Listing for the Repeat Measurements report: one row per
// participant, one tile per KRI vital, filled by the participant's flag.
// The widget only draws and reports clicks; the report's filter script owns
// the participant filter and calls back through chart.helpers.
function renderRepeatMeasurementsTiles(el, input) {
  var MODES = { both: 'N/D \u00b7 rate', rate: 'Rate', nd: 'N/D' };
  var chart = {
    data: (input.tiles || []).slice(),
    columns: input.columns || [],
    colors: input.colors || {},
    label: MODES[input.label] ? input.label : 'both',
    pageSize: input.pageSize || 50,
    page: 0,
    selected: null,
    focus: null,
    helpers: {}
  };

  el.classList.add('rm-tiles');
  el.innerHTML = '<div class="rm-tiles-scroll"></div><div class="rm-tiles-pager"></div>';
  var scroll = el.querySelector('.rm-tiles-scroll');
  var pagerEl = el.querySelector('.rm-tiles-pager');

  function esc(s) {
    return String(s === null || s === undefined ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  // Participants in first-appearance order, so the caller's row order is the
  // grid's row order.
  function participants() {
    var order = [];
    var byId = {};
    chart.data.forEach(function (t) {
      var p = byId[t.subjid];
      if (!p) {
        p = byId[t.subjid] = { subjid: t.subjid, invid: t.invid, country: t.country, tiles: {} };
        order.push(p);
      }
      p.tiles[t.vital] = t;
    });
    return order;
  }

  // Columns follow the vitals in the current rows (the report's vital group).
  function visibleColumns() {
    var present = {};
    chart.data.forEach(function (t) {
      present[t.vital] = true;
    });
    return chart.columns.filter(function (c) {
      return present[c.vital];
    });
  }

  // Green is tinted so that the flagged tiles stand out.
  function fill(flag) {
    var c = chart.colors[flag];
    if (!c || flag === 'Not evaluable') return '';
    return c + (flag === 'Green' ? '33' : 'cc');
  }

  function evaluable(t) {
    return t.Denominator > 0;
  }

  function cellLabel(t) {
    if (!evaluable(t)) return 'NE';
    if (chart.label === 'rate') return esc(t.label_rate);
    if (chart.label === 'nd') return esc(t.label_nd);
    return esc(t.label_nd) + '<span class="rm-tiles-rt">' + esc(t.label_rate) + '</span>';
  }

  function action(id) {
    return chart.selected === id
      ? 'Click to clear the participant filter'
      : 'Click to filter the report to ' + id;
  }

  function tileTitle(p, c, t) {
    var detail = evaluable(t)
      ? t.Numerator + ' of ' + t.Denominator + ' windows repeat (' + Math.round((100 * t.Numerator) / t.Denominator) + '%)'
      : 'not evaluable';
    return p.subjid + ' \u00b7 ' + c.label + ': ' + t.flag + ' \u00b7 ' + detail + '. ' + action(p.subjid);
  }

  function render() {
    var ps = participants();
    var cols = visibleColumns();
    var size = chart.pageSize;
    var pages = Math.max(1, Math.ceil(ps.length / size));
    chart.page = Math.max(0, Math.min(chart.page, pages - 1));
    if (!ps.length) {
      scroll.innerHTML = '<div class="rm-tiles-empty">No participants match the current filters.</div>';
      pagerEl.innerHTML = '';
      return;
    }
    var h =
      '<table><thead><tr><th class="rm-tiles-lab" scope="col">Participant</th>' +
      cols
        .map(function (c) {
          return (
            '<th scope="col" title="' + esc(c.label + (c.metric ? ' (' + c.metric + ')' : '')) + '">' +
            esc(c.column) + '<span class="rm-tiles-mode">' + MODES[chart.label] + '</span></th>'
          );
        })
        .join('') +
      '</tr></thead><tbody>';
    ps.slice(chart.page * size, chart.page * size + size).forEach(function (p) {
      var sel = chart.selected === p.subjid;
      var id = esc(p.subjid);
      h +=
        '<tr data-subjid="' + id + '"' + (sel ? ' class="rm-tiles-sel"' : '') + '>' +
        '<th scope="row" class="rm-tiles-lab" role="button" tabindex="0" aria-pressed="' + sel + '" data-subjid="' + id + '"' +
        ' title="' + esc('Site ' + p.invid + ' \u00b7 ' + p.country + '. ' + action(p.subjid)) + '">' +
        id + ' <span class="rm-tiles-site">' + esc(p.invid) + '</span></th>';
      cols.forEach(function (c) {
        var t = p.tiles[c.vital];
        if (!t) {
          h += '<td class="rm-tiles-none"></td>';
          return;
        }
        var bg = fill(t.flag);
        h +=
          '<td class="rm-tiles-c" role="button" tabindex="0" data-subjid="' + id + '" data-vital="' + esc(c.vital) + '"' +
          ' data-flag="' + esc(t.flag) + '"' + (bg ? ' style="background-color:' + bg + '"' : '') +
          ' title="' + esc(tileTitle(p, c, t)) + '">' + cellLabel(t) + '</td>';
      });
      h += '</tr>';
    });
    scroll.innerHTML = h + '</tbody></table>';
    renderPager(ps.length, pages);
    restoreFocus();
  }

  function renderPager(n, pages) {
    var from = chart.page * chart.pageSize + 1;
    var to = Math.min(n, (chart.page + 1) * chart.pageSize);
    var h = '<span>Participants ' + from + '\u2013' + to + ' of ' + n + '</span>';
    if (pages > 1) {
      h +=
        '<button type="button" data-rm-page="-1"' + (chart.page === 0 ? ' disabled' : '') + '>Previous</button>' +
        '<span>Page ' + (chart.page + 1) + ' of ' + pages + '</span>' +
        '<button type="button" data-rm-page="1"' + (chart.page === pages - 1 ? ' disabled' : '') + '>Next</button>';
    }
    pagerEl.innerHTML = h;
  }

  // Selecting re-renders the grid, so keyboard focus returns to the same
  // participant label or tile when it is still shown.
  function restoreFocus() {
    if (!chart.focus) return;
    var sel = '[role="button"][data-subjid="' + cssEsc(chart.focus.subjid) + '"]' +
      (chart.focus.vital ? '[data-vital="' + cssEsc(chart.focus.vital) + '"]' : ':not([data-vital])');
    var target = scroll.querySelector(sel);
    if (target) target.focus();
  }

  function cssEsc(s) {
    return window.CSS && CSS.escape ? CSS.escape(s) : String(s).replace(/["\\]/g, '\\$&');
  }

  function select(target, fromKey) {
    var id = target.getAttribute('data-subjid');
    chart.focus = fromKey ? { subjid: id, vital: target.getAttribute('data-vital') } : null;
    el.dispatchEvent(new CustomEvent('rm-tiles-select', {
      bubbles: true,
      detail: { chartId: el.id, subjid: id }
    }));
    chart.focus = null;
  }

  el.addEventListener('click', function (e) {
    var pg = e.target.closest('[data-rm-page]');
    if (pg) {
      chart.page += Number(pg.getAttribute('data-rm-page'));
      render();
      return;
    }
    var hit = e.target.closest('[role="button"][data-subjid]');
    if (hit && el.contains(hit)) select(hit, false);
  });

  el.addEventListener('keydown', function (e) {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    var hit = e.target.closest('[role="button"][data-subjid]');
    if (!hit || !el.contains(hit)) return;
    e.preventDefault();
    select(hit, true);
  });

  chart.helpers = {
    updateData: function (c, rows) {
      c.data = (rows || []).slice();
      c.page = 0;
      render();
    },
    selectRow: function (c, id) {
      c.selected = id;
      render();
    },
    clearSelection: function (c) {
      c.selected = null;
      render();
    },
    // Only the label mode is configurable: { mapping: { label: 'label_rate' } }.
    updateSpec: function (c, spec) {
      var l = spec && spec.mapping && spec.mapping.label;
      l = l ? String(l).replace(/^label_/, '') : null;
      if (l && MODES[l]) c.label = l;
      render();
    }
  };

  render();
  return chart;
}
