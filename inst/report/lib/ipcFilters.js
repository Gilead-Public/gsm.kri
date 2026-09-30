// IP Compliance report filters. R precomputes every chart slice into the
// #ipc-data JSON block; this script only keeps the reviewer's selection and
// hands each widget the matching slice. Nothing is counted here.
(function () {
  var LEVELS = ['study', 'country', 'site'];
  var state = { dosed: 'all', country: null, site: null };
  // Statuses hidden from the scatters by a legend click, shared by all three.
  var hidden = {};
  // Scatter id -> { el, traces, layout }; traces/layout are the unfiltered originals.
  var scatters = {};
  var data = null;

  function ipcData() {
    if (!data) {
      var node = document.getElementById('ipc-data');
      data = node ? JSON.parse(node.textContent) : { status: {}, reasons: null };
    }
    return data;
  }

  function chart(id) {
    var el = document.getElementById(id);
    return el && el.gsmChart ? el.gsmChart : null;
  }

  function statusRows(level) {
    return (ipcData().status[level] || []).filter(function (r) {
      if (r.Dosed !== state.dosed) return false;
      // The site chart narrows to the selected country; the others keep every bar.
      return level !== 'site' || !state.country || r.OuterGroupID === state.country;
    });
  }

  function reasonRows(level) {
    var r = ipcData().reasons;
    // Not dosed excludes every dosed participant, so every reason is zero.
    if (state.dosed === 'N') return r.zero;
    if (level === 'site' && state.site && state.country) {
      return (r.site[state.country] || {})[state.site] || r.zero;
    }
    if (level !== 'study' && state.country) return r.country[state.country] || r.zero;
    return r.study;
  }

  // cd = [subjid, invid, country, dosed]; the study scatter ignores location.
  function inScope(cd, level) {
    if (state.dosed !== 'all' && cd[3] !== state.dosed) return false;
    if (level === 'study') return true;
    if (state.country && cd[2] !== state.country) return false;
    return level !== 'site' || !state.site || cd[1] === state.site;
  }

  // A one-point trace may arrive with scalars instead of arrays.
  function subset(values, keep, n) {
    var arr = Array.isArray(values) ? values : n === 1 && values !== undefined ? [values] : null;
    return arr ? keep.map(function (i) { return arr[i]; }) : values;
  }

  function redrawScatter(id) {
    var s = scatters[id];
    if (!s) return;
    var level = id.split('-')[1];
    var traces = s.traces.map(function (t) {
      // plotly R's empty base trace carries no customdata.
      if (!Array.isArray(t.customdata)) return t;
      var n = t.customdata.length;
      var keep = [];
      t.customdata.forEach(function (cd, i) {
        if (inScope(cd, level)) keep.push(i);
      });
      return Object.assign({}, t, {
        x: subset(t.x, keep, n),
        y: subset(t.y, keep, n),
        customdata: subset(t.customdata, keep, n),
        marker: Object.assign({}, t.marker, { symbol: subset(t.marker && t.marker.symbol, keep, n) }),
        visible: hidden[t.name] ? 'legendonly' : true
      });
    });
    Plotly.react(s.el, traces, JSON.parse(JSON.stringify(s.layout)));
  }

  function redrawScatters() {
    Object.keys(scatters).forEach(redrawScatter);
  }

  function statusNames() {
    var names = [];
    Object.keys(scatters).forEach(function (id) {
      scatters[id].traces.forEach(function (t) {
        if (t.name && names.indexOf(t.name) < 0) names.push(t.name);
      });
    });
    return names;
  }

  // Plotly's legend toggling is cancelled (return false) and replayed from
  // `hidden`, so every scatter shows the same statuses after any redraw.
  // Returning false also suppresses plotly_legenddoubleclick, so a second
  // click on the same entry inside Plotly's double-click window counts as the
  // double-click. A single click waits out that window, as Plotly does.
  var pendingClick = null;

  function toggleStatus(name) {
    hidden[name] = !hidden[name];
    redrawScatters();
  }

  // Show only this status, or every status if it is already the only one shown.
  function isolateStatus(name) {
    var names = statusNames();
    var isolated = names.every(function (n) {
      return n === name ? !hidden[n] : hidden[n];
    });
    names.forEach(function (n) {
      hidden[n] = isolated ? false : n !== name;
    });
    redrawScatters();
  }

  function onLegendClick(e, el) {
    var name = e.data[e.curveNumber].name;
    var previous = pendingClick;
    pendingClick = null;
    if (previous) {
      clearTimeout(previous.timer);
      if (previous.name === name) {
        isolateStatus(name);
        return false;
      }
      toggleStatus(previous.name);
    }
    pendingClick = {
      name: name,
      timer: setTimeout(function () {
        pendingClick = null;
        toggleStatus(name);
      }, (el._context && el._context.doubleClickDelay) || 300)
    };
    return false;
  }

  // Called by each scatter's htmlwidgets onRender hook.
  window.ipcRegisterScatter = function (el, id) {
    scatters[id] = {
      el: el,
      traces: JSON.parse(JSON.stringify(el.data)),
      layout: JSON.parse(JSON.stringify(el.layout))
    };
    el.on('plotly_legendclick', function (e) {
      return onLegendClick(e, el);
    });
  };

  function syncListing() {
    var table = document.querySelector('#ipc-listing table.dataTable');
    if (!table || !window.jQuery) return;
    var api = jQuery(table).DataTable();
    // Exact, regex-escaped matches: site IDs may contain regex characters.
    function exact(value) {
      return value ? '^' + jQuery.fn.dataTable.util.escapeRegex(value) + '$' : '';
    }
    api.column('dosed:name').search(state.dosed === 'all' ? '' : exact(state.dosed), true, false);
    api.column('country:name').search(exact(state.country), true, false);
    api.column('invid:name').search(exact(state.site), true, false);
    api.draw();
  }

  function setChip(key, value) {
    var chip = document.getElementById('ipc-chip-' + key);
    if (!chip) return;
    chip.style.display = value ? 'inline-flex' : 'none';
    chip.querySelector('.ipc-chip-value').textContent = value || '';
  }

  function ipcSync() {
    ['all', 'Y', 'N'].forEach(function (value) {
      var button = document.getElementById('ipc-dosed-' + value);
      if (button) button.setAttribute('aria-pressed', String(state.dosed === value));
    });
    setChip('country', state.country);
    setChip('site', state.site);
    var hasReasons = !!ipcData().reasons;
    LEVELS.forEach(function (level) {
      var status = chart('ipc-' + level + '-status');
      if (status) {
        status.helpers.updateData(status, statusRows(level), status.data._spec_);
        // updateData clears the selection, so highlight afterwards.
        var selected = level === 'country' ? state.country : level === 'site' ? state.site : null;
        if (selected && status.data.labels.indexOf(selected) >= 0) {
          status.helpers.selectCategory(status, selected);
        } else {
          status.helpers.clearSelection(status);
        }
      }
      var reasons = chart('ipc-' + level + '-reasons');
      if (reasons && hasReasons) {
        reasons.helpers.updateData(reasons, reasonRows(level), reasons.data._spec_);
      }
      var note = document.getElementById('ipc-' + level + '-reasons-note');
      if (note) note.style.display = state.dosed === 'N' ? '' : 'none';
    });
    redrawScatters();
    syncListing();
  }

  document.addEventListener('click', function (e) {
    var dosed = e.target.closest('[data-ipc-dosed]');
    var clear = e.target.closest('[data-ipc-clear]');
    if (dosed) {
      state.dosed = dosed.getAttribute('data-ipc-dosed');
    } else if (clear) {
      // Clearing the country also clears its site.
      if (clear.getAttribute('data-ipc-clear') === 'country') state.country = null;
      state.site = null;
    } else {
      return;
    }
    ipcSync();
  });

  // gsm.vizr's bars() dispatches gsm-viz-select on every bar click; with y
  // mapped, datum is the clicked status row.
  document.addEventListener('gsm-viz-select', function (e) {
    var d = e.detail || {};
    var row = d.datum || {};
    if (d.type !== 'click' || !row.GroupID) return;
    if (d.chartId === 'ipc-country-status') {
      state.country = row.GroupID === state.country ? null : row.GroupID;
      state.site = null;
    } else if (d.chartId === 'ipc-site-status') {
      if (row.GroupID === state.site) {
        state.site = null;
      } else {
        state.site = row.GroupID;
        state.country = row.OuterGroupID;
      }
    } else {
      return;
    }
    ipcSync();
  });
})();
