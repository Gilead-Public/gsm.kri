/* gsm.kri Report_KRI_v2 — interactions for the opt-in tabbed KRI report. */
(function () {
  'use strict';

  const root = document.documentElement;
  root.classList.add('v2-js');
  try {
    if (localStorage.getItem('gsm-v2-theme') === 'dark') root.dataset.theme = 'dark';
  } catch (e) { /* storage unavailable (file:// in some browsers) */ }

  const $ = (sel, el = document) => el.querySelector(sel);
  const $$ = (sel, el = document) => [...el.querySelectorAll(sel)];
  const esc = (v) => String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const cssId = (v) => (window.CSS && CSS.escape ? CSS.escape(v) : String(v).replace(/"/g, '\\"'));
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const isTyping = () => /input|select|textarea/i.test((document.activeElement || {}).tagName || '');

  // Charts in hidden tabs or panes render at 0px; a resize lets htmlwidgets and Chart.js re-measure.
  const refreshWidgets = () => requestAnimationFrame(() => window.dispatchEvent(new Event('resize')));

  /* ---------- Site data (Sites tab payload) ---------- */
  let siteData = null;
  const sitesById = {};
  const metricsById = {};
  function loadSiteData() {
    const el = $('#v2-site-data');
    if (!el) return;
    try { siteData = JSON.parse(el.textContent); } catch (e) { siteData = null; return; }
    siteData.sites.forEach((s) => { sitesById[s.id] = s; });
    siteData.metrics.forEach((m) => { metricsById[m.id] = m; });
  }

  /* ---------- Group highlight in gsm.viz charts (mirrors overallGroupDropdown.js) ---------- */
  function highlightCharts(groupID) {
    const value = groupID || 'None';
    $$('.gsm-widget').forEach((el) => {
      const canvas = el.getElementsByTagName('canvas');
      const chart = canvas.length > 0 ? canvas[0].chart : null;
      if (!chart || !chart.helpers) return;
      try {
        if (/timeSeries/.test(el.className)) {
          chart.helpers.updateSelectedGroupIDs(value);
        } else {
          chart.data.config.selectedGroupIDs = value;
          chart.helpers.updateConfig(chart, chart.data.config, chart.data._thresholds_);
        }
      } catch (e) {
        console.warn('gsm.kri v2: could not highlight group in widget', e);
      }
    });
    $$('.gsm-widget-control--group').forEach((el) => {
      el.value = [...el.options].some((o) => o.text === value) ? value : 'None';
    });
    $$('.gsm-widget-control--country').forEach((el) => { el.value = 'None'; });
  }

  /* ---------- Selection ---------- */
  let selected = null;
  let searchIndex = [];

  function setSelected(groupID, opts = {}) {
    selected = groupID || null;
    const input = $('#v2-site-input');
    const entry = searchIndex.find((s) => s.GroupID === selected);
    if (input) input.value = selected ? selected + (entry && entry.label ? ' · ' + entry.label : '') : '';
    const combo = $('#v2-combo');
    combo && combo.classList.toggle('has-value', !!selected);
    $$('[data-site]').forEach((el) => {
      const on = !!selected && el.dataset.site === selected;
      el.classList.toggle('selected', on);
      if (el.classList.contains('v2-site-row')) el.setAttribute('aria-selected', String(on));
    });
    highlightCharts(selected);
    renderSitePanel(selected);
    if (selected && opts.scroll !== false) {
      const row = $(`.v2-site-row[data-site="${cssId(selected)}"]`);
      row && !row.hidden && row.scrollIntoView({ block: 'nearest' });
    }
    if (opts.hash !== false) updateHash();
  }

  /* ---------- Main tabs + hash routing ---------- */
  const TABS = ['overview', 'sites', 'metrics'];
  let currentTab = 'overview';

  function moveInk() {
    const ink = $('.v2-tab-ink');
    const tab = $(`.v2-maintab[data-tab="${currentTab}"]`);
    if (!ink || !tab) return;
    ink.style.setProperty('--x', tab.offsetLeft + 'px');
    ink.style.setProperty('--w', tab.offsetWidth + 'px');
  }

  function activateTab(name, opts = {}) {
    if (!TABS.includes(name) || !$(`.v2-tabpanel[data-tabpanel="${name}"]`)) name = 'overview';
    const changed = name !== currentTab;
    currentTab = name;
    $$('.v2-maintab').forEach((t) => {
      const on = t.dataset.tab === name;
      t.setAttribute('aria-selected', String(on));
      t.tabIndex = on ? 0 : -1;
    });
    $$('.v2-tabpanel').forEach((p) => {
      const on = p.dataset.tabpanel === name;
      p.hidden = !on;
      if (on && changed && !reduceMotion) {
        p.classList.remove('enter');
        void p.offsetWidth;
        p.classList.add('enter');
      }
    });
    document.body.classList.toggle('v2-on-sites', name === 'sites');
    if (name === 'sites') fitSiteColumn();
    moveInk();
    refreshWidgets();
    // Start the new view just below the masthead, with the tab bar stuck under the top bar.
    const masthead = $('.v2-masthead');
    if (changed && masthead && opts.keepScroll !== true) {
      const topbar = parseFloat(getComputedStyle(root).getPropertyValue('--v2-topbar')) || 56;
      const top = Math.max(0, masthead.offsetTop + masthead.offsetHeight - topbar + 6);
      if (window.scrollY > top) window.scrollTo({ top, behavior: 'auto' });
    }
    if (opts.hash !== false) updateHash();
  }

  function updateHash() {
    let hash = '#' + currentTab;
    if (currentTab === 'sites' && selected) hash = '#sites/' + encodeURIComponent(selected);
    if (location.hash !== hash) history.replaceState(null, '', hash);
  }

  function openSite(id) {
    activateTab('sites');
    setSelected(id);
  }

  function openMetric(id, opts = {}) {
    activateTab('metrics', { hash: opts.hash });
    const card = document.getElementById('kri-' + id);
    if (!card) return;
    toggleCard(card, true);
    // Cards above may change height once their charts re-measure, so settle the scroll twice.
    requestAnimationFrame(() => card.scrollIntoView({ block: 'start' }));
    setTimeout(() => card.scrollIntoView({ block: 'start' }), 400);
  }

  function route() {
    const hash = decodeURIComponent((location.hash || '').replace(/^#/, ''));
    if (!hash) return activateTab('overview', { hash: false, keepScroll: true });
    if (hash.startsWith('sites/')) {
      activateTab('sites', { hash: false, keepScroll: true });
      return setSelected(hash.slice(6), { hash: false });
    }
    if (TABS.includes(hash)) return activateTab(hash, { hash: false, keepScroll: true });
    if (hash.startsWith('kri-')) return openMetric(hash.slice(4), { hash: false });
    const target = document.getElementById(hash);
    const panel = target && target.closest('.v2-tabpanel');
    if (panel) {
      activateTab(panel.dataset.tabpanel, { hash: false, keepScroll: true });
      target.scrollIntoView();
    }
  }

  function initTabs() {
    const inner = $('.v2-tabbar-inner');
    if (!inner) return;
    const ink = document.createElement('span');
    ink.className = 'v2-tab-ink';
    ink.setAttribute('aria-hidden', 'true');
    inner.appendChild(ink);
    inner.addEventListener('click', (e) => {
      const tab = e.target.closest('.v2-maintab');
      tab && activateTab(tab.dataset.tab);
    });
    inner.addEventListener('keydown', (e) => {
      if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
      const tabs = $$('.v2-maintab', inner);
      const i = tabs.findIndex((t) => t.dataset.tab === currentTab);
      const next = tabs[(i + (e.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length];
      activateTab(next.dataset.tab);
      next.focus();
    });
    window.addEventListener('resize', moveInk);
    window.addEventListener('hashchange', route);
  }

  /* ---------- Search combobox ---------- */
  function initCombo() {
    const data = $('#v2-sites');
    const input = $('#v2-site-input');
    const list = $('#v2-site-list');
    if (!data || !input || !list) return;
    try { searchIndex = JSON.parse(data.textContent); } catch (e) { searchIndex = []; }

    let active = -1;
    const render = (q) => {
      q = q.trim().toLowerCase();
      const items = searchIndex.filter((s) => !q || s.GroupID.toLowerCase().includes(q) || (s.label || '').toLowerCase().includes(q)).slice(0, 50);
      list.innerHTML = items.map((s, i) => `
        <button type="button" role="option" data-g="${esc(s.GroupID)}" class="${i === active ? 'active' : ''}">
          <span class="v2-mono">${esc(s.GroupID)}</span>
          <span class="v2-muted">${esc(s.label || '')} ${s.red > 0 ? `<span class="v2-badge red">${s.red}</span>` : ''}${s.amber > 0 ? `<span class="v2-badge amber">${s.amber}</span>` : ''}</span>
        </button>`).join('') || '<div class="v2-empty">No matching groups</div>';
      list.classList.add('open');
      input.setAttribute('aria-expanded', 'true');
    };
    const close = () => { list.classList.remove('open'); input.setAttribute('aria-expanded', 'false'); active = -1; };
    const choose = (id) => {
      // On the Overview tab a search jumps to the site; elsewhere it highlights in place.
      if (currentTab === 'overview') openSite(id); else setSelected(id);
      close();
      input.blur();
    };

    input.addEventListener('focus', () => { input.select(); render(''); });
    input.addEventListener('input', () => { active = -1; render(input.value); });
    input.addEventListener('keydown', (e) => {
      const opts = $$('button', list);
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        active = (active + (e.key === 'ArrowDown' ? 1 : -1) + opts.length) % opts.length;
        opts.forEach((o, i) => o.classList.toggle('active', i === active));
        opts[active] && opts[active].scrollIntoView({ block: 'nearest' });
      } else if (e.key === 'Enter' && opts.length) {
        e.preventDefault();
        choose((opts[active] || opts[0]).dataset.g);
      } else if (e.key === 'Escape') {
        close();
        input.blur();
      }
    });
    list.addEventListener('mousedown', (e) => {
      const b = e.target.closest('button');
      if (b) { e.preventDefault(); choose(b.dataset.g); }
    });
    input.addEventListener('blur', () => setTimeout(close, 120));
    $('#v2-site-clear') && $('#v2-site-clear').addEventListener('click', () => setSelected(null));
  }

  /* ---------- Sites tab: heatmap ---------- */
  let fitSiteColumn = () => {};
  function initSites() {
    const table = $('#v2-site-table');
    if (!table) return;
    const rows = $$('.v2-site-row', table);
    const empty = $('.v2-filter-empty');

    // Size the site column to its widest content (the R estimate is a starting point).
    // Hidden tabs measure 0, so this also runs whenever the Sites tab opens.
    fitSiteColumn = () => {
      const widest = Math.max(0, ...$$('.v2-site-id, .v2-site-sub', table).map((el) => el.getBoundingClientRect().width));
      if (widest > 0) table.style.setProperty('--v2-site-w', Math.ceil(widest + 24) + 'px');
    };
    fitSiteColumn();
    document.fonts && document.fonts.ready.then(fitSiteColumn);

    table.addEventListener('click', (e) => {
      const sortBtn = e.target.closest('th[data-sort] .v2-th-btn');
      if (sortBtn) return sortBy(sortBtn.closest('th').dataset.sort);
      const row = e.target.closest('.v2-site-row');
      if (!row) return;
      setSelected(row.dataset.site, { scroll: false });
      // A tile is a site x KRI pair: open that KRI in the site panel.
      const cell = e.target.closest('td.v2-cell');
      cell && focusPanelMetric(cell.dataset.m);
    });

    /* Sorting: a KRI header ranks sites by that KRI's severity (new or worse first within
       a colour); selecting it again, or the Risk header, restores the risk ranking. */
    const tbody = $('tbody', table);
    const riskOrder = new Map(rows.map((r, i) => [r, i]));
    const SEV_RANK = { r: 3, a: 2, g: 1, n: 0 };
    let sortKey = 'risk';
    const severity = (row, m) => {
      const td = row.querySelector(`td[data-m="${cssId(m)}"]`);
      if (!td) return -1;
      const cls = ['r', 'a', 'g', 'n'].find((k) => td.classList.contains(k)) || 'n';
      return SEV_RANK[cls] + (td.classList.contains('worse') ? 0.5 : 0);
    };
    function sortBy(key) {
      sortKey = key === sortKey ? 'risk' : key;
      const ordered = rows.slice().sort((a, b) => (sortKey === 'risk' ? 0 : severity(b, sortKey) - severity(a, sortKey)) || riskOrder.get(a) - riskOrder.get(b));
      tbody.append(...ordered);
      $$('th[data-sort]', table).forEach((th) => th.setAttribute('aria-sort', th.dataset.sort === sortKey ? 'descending' : 'none'));
      $('.v2-table-scroll').scrollTop = 0;
    }

    /* Crosshair + tooltip (mouse only). */
    const tip = document.createElement('div');
    tip.className = 'v2-tip';
    tip.setAttribute('role', 'tooltip');
    document.body.appendChild(tip);
    $$('td.v2-cell[title]', table).forEach((td) => { td.dataset.title = td.title; td.removeAttribute('title'); });
    let hoverRow = null;
    let hoverCol = null;
    const colCells = (m) => (m ? $$(`td[data-m="${cssId(m)}"], th[data-sort="${cssId(m)}"]`, table) : []);
    const setHover = (row, m) => {
      if (row !== hoverRow) {
        hoverRow && hoverRow.classList.remove('hl-row');
        row && row.classList.add('hl-row');
        hoverRow = row;
      }
      if (m !== hoverCol) {
        colCells(hoverCol).forEach((c) => c.classList.remove('hl-col'));
        colCells(m).forEach((c) => c.classList.add('hl-col'));
        hoverCol = m;
      }
      // Fade the rest only when a KRI is in focus (tile or header), not while scanning site names.
      table.classList.toggle('is-hovering', !!m);
    };
    const hideTip = () => tip.classList.remove('show');
    const showTip = (td) => {
      const row = td.closest('.v2-site-row');
      const html = tipHTML(row.dataset.site, td.dataset.m, td.dataset.title);
      if (!html) return hideTip();
      tip.innerHTML = html;
      const rect = td.getBoundingClientRect();
      const tw = tip.offsetWidth;
      const th = tip.offsetHeight;
      const limit = (parseFloat(getComputedStyle(root).getPropertyValue('--v2-topbar')) || 56) + 8;
      let top = rect.top - th - 10;
      if (top < limit) top = rect.bottom + 10;
      const left = Math.min(Math.max(8, rect.left + rect.width / 2 - tw / 2), window.innerWidth - tw - 8);
      tip.style.transform = '';
      tip.style.left = left + 'px';
      tip.style.top = top + 'px';
      tip.classList.add('show');
    };
    if (window.matchMedia('(hover: hover) and (pointer: fine)').matches) {
      table.addEventListener('mouseover', (e) => {
        const row = e.target.closest('.v2-site-row');
        const cell = e.target.closest('td.v2-cell');
        const th = e.target.closest('th.v2-kri-th');
        setHover(row, cell ? cell.dataset.m : th ? th.dataset.sort : null);
        cell ? showTip(cell) : hideTip();
      });
      table.addEventListener('mouseleave', () => { setHover(null, null); hideTip(); });
      $('.v2-table-scroll').addEventListener('scroll', hideTip, { passive: true });
    }
    table.addEventListener('keydown', (e) => {
      const row = e.target.closest('.v2-site-row');
      if (!row) return;
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        setSelected(row.dataset.site, { scroll: false });
      } else if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        const visible = rows.filter((r) => !r.hidden);
        const next = visible[visible.indexOf(row) + (e.key === 'ArrowDown' ? 1 : -1)];
        if (next) {
          next.focus();
          setSelected(next.dataset.site);
        }
      }
    });

    $$('.v2-site-filter button').forEach((b) => b.addEventListener('click', () => {
      $$('.v2-site-filter button').forEach((x) => x.setAttribute('aria-selected', String(x === b)));
      const f = b.dataset.filter;
      let shown = 0;
      rows.forEach((r) => {
        const red = +r.dataset.red;
        const amber = +r.dataset.amber;
        const fresh = +r.dataset.new;
        r.hidden = !(f === 'all' || (f === 'red' && red > 0) || (f === 'flagged' && red + amber > 0) || (f === 'new' && fresh > 0));
        if (!r.hidden) shown += 1;
      });
      if (empty) empty.hidden = shown > 0;
    }));
  }

  /* ---------- Sites tab: site panel ---------- */
  let panelEmptyHTML = '';
  const fmtRate = (v) => {
    if (v == null || !isFinite(v)) return '–';
    if (v === 0) return '0';
    const a = Math.abs(v);
    if (a < 0.001) return v.toExponential(1);
    return a >= 100 ? v.toFixed(0) : Number(v.toPrecision(3)).toString();
  };
  const fmtNum = (v, d = 2) => (v == null || !isFinite(v) ? '–' : Number(v).toFixed(d));
  const sev = (f) => (f == null ? 'n' : Math.abs(f) === 2 ? 'r' : Math.abs(f) === 1 ? 'a' : 'g');
  const SEV_NAME = { r: 'Red', a: 'Amber', g: 'Green', n: 'No flag' };
  const flagTag = (f) => `<span class="v2-flagtag ${sev(f)}">${f > 0 ? '▲ ' : f < 0 ? '▼ ' : ''}${SEV_NAME[sev(f)]}</span>`;

  function bulletSVG(cell, metric) {
    const rate = cell.r;
    const study = metric.studyRate;
    if (rate == null) return '<p class="v2-section-sub">No rate available for this KRI.</p>';
    let mode = 'flags';
    let bands = (cell.b || []).map((b) => ({ lo: b[0], hi: b[1] == null ? Infinity : b[1], f: b[2] }));
    if (!bands.length && metric.q) {
      mode = 'dist';
      const q = metric.q;
      bands = [{ lo: q[0], hi: q[3], cls: 'q1' }, { lo: q[1], hi: q[2], cls: 'q2' }];
    }
    const edges = bands.flatMap((b) => [b.lo, b.hi]).filter((v) => isFinite(v) && v > 0);
    let max = Math.max(rate, study || 0, ...edges);
    if (!(max > 0)) max = 1;
    max *= 1.12;
    const W = 320, P = 2, X = (v) => P + (Math.max(0, Math.min(v, max)) / max) * (W - 2 * P);
    const rect = (lo, hi, cls) => `<rect class="${cls}" x="${X(lo).toFixed(1)}" y="8" width="${Math.max(0, X(hi) - X(lo)).toFixed(1)}" height="22" />`;
    const bandRects = mode === 'flags'
      ? bands.map((b) => rect(b.lo, b.hi, 'bb-' + (b.f === 0 ? 'g' : Math.abs(b.f) === 1 ? 'a' : 'r'))).join('')
      : rect(0, max, 'bb-track') + bands.map((b) => rect(b.lo, b.hi, 'bb-' + b.cls)).join('');
    const marker = study == null ? '' : `<line class="bb-mark" x1="${X(study).toFixed(1)}" x2="${X(study).toFixed(1)}" y1="4" y2="34" />`;
    const label = `Site rate ${fmtRate(rate)} versus study rate ${fmtRate(study)}`;
    const key = mode === 'flags'
      ? 'Bands: green, amber and red flag ranges at this site’s denominator'
      : 'Shaded: middle 50% and 80% of sites (flag ranges unavailable)';
    return `
      <svg class="v2-bullet" viewBox="0 0 ${W} 48" role="img" aria-label="${esc(label)}">
        ${bandRects}
        <rect class="bb-bar" x="${P}" y="15" width="${Math.max(1.5, X(rate) - P).toFixed(1)}" height="8" rx="1.5" />
        ${marker}
        <text x="${P}" y="46">0</text>
        <text x="${W - P}" y="46" text-anchor="end">${esc(fmtRate(max))}</text>
      </svg>
      <div class="v2-bullet-key"><span><i class="k-bar"></i>Site rate</span><span><i class="k-mark"></i>Study rate</span><span>${key}</span></div>`;
  }

  function tipHTML(siteId, metricId, fallback) {
    const site = sitesById[siteId];
    const m = metricsById[metricId];
    if (!site || !m) return '';
    const cell = site.cells.find((c) => c.m === metricId);
    const head = `<div class="v2-tip-head"><b>${esc(m.abbr)} · ${esc(m.name)}</b><span>${esc(siteId)}</span></div>`;
    if (!cell) return `${head}<div class="v2-tip-hint">${esc(fallback || 'No data for this site.')}</div>`;
    const s = sev(cell.f);
    const dir = cell.f > 0 ? ' · above expected' : cell.f < 0 ? ' · below expected' : '';
    const flagged = s === 'r' || s === 'a';
    const change = cell.c === 'new' && flagged ? '<em>New</em>'
      : cell.c === 'worse' && flagged ? `<em>Up from ${SEV_NAME[sev(cell.p)]}</em>`
        : cell.c === 'better' ? `<em class="down">Down from ${SEV_NAME[sev(cell.p)]}</em>` : '';
    const rows = [
      ['Score', fmtNum(cell.s)],
      ['Site rate', `${fmtRate(cell.r)}${cell.n != null && cell.d != null ? ` <span style="color:#94a3b8">(${esc(cell.n)}/${esc(cell.d)})</span>` : ''}`],
      ['Study rate', fmtRate(m.studyRate)],
    ];
    if (cell.w > 0 && !m.inactive) rows.push(['Risk points', '+' + esc(cell.w)]);
    return `${head}
      <div class="v2-tip-flag"><i class="${s}"></i>${SEV_NAME[s]}${dir}${change}</div>
      <dl>${rows.map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`).join('')}</dl>
      <div class="v2-tip-hint">Click to open in the ${esc((siteData.groupLevel || 'site').toLowerCase())} panel</div>`;
  }

  // Open one KRI in the site panel and bring it into view.
  function focusPanelMetric(metricId) {
    const item = metricId && $(`#v2-site-panel .v2-sm[data-m="${cssId(metricId)}"]`);
    if (!item) return;
    item.open = true;
    item.classList.remove('flash');
    void item.offsetWidth;
    item.classList.add('flash');
    item.scrollIntoView({ block: 'center', behavior: reduceMotion ? 'auto' : 'smooth' });
  }

  function metricItem(cell, open) {
    const m = metricsById[cell.m] || { abbr: cell.m, name: cell.m };
    const s = sev(cell.f);
    const flagged = s === 'r' || s === 'a';
    const chip = cell.c === 'new' && flagged ? '<span class="v2-change-chip up" title="Newly flagged since the previous snapshot">New</span>'
      : cell.c === 'worse' && flagged ? `<span class="v2-change-chip up" title="Up from ${SEV_NAME[sev(cell.p)]}">Worse</span>`
        : cell.c === 'better' ? `<span class="v2-change-chip down" title="Down from ${SEV_NAME[sev(cell.p)]}">Improved</span>` : '';
    const weight = cell.w > 0 && !m.inactive ? `<span class="v2-badge neutral" title="Contribution to the site risk score">+${esc(cell.w)}</span>` : '';
    const inactive = m.inactive ? '<span class="v2-badge inactive">Inactive</span>' : '';
    const prev = cell.c && cell.c !== 'same' && cell.p !== undefined ? `<small>was ${SEV_NAME[sev(cell.p)]}</small>` : '';
    return `
      <details class="v2-sm sev-${s}${m.inactive ? ' inactive' : ''}" data-m="${esc(cell.m)}" ${open ? 'open' : ''}>
        <summary>
          <span class="v2-sm-strip" aria-hidden="true"></span>
          <span class="v2-badge neutral v2-mono">${esc(m.abbr)}</span>
          <span class="v2-sm-name" title="${esc(m.name)}">${esc(m.name)}</span>
          <span class="v2-sm-meta">${chip}${weight}${inactive}${flagTag(cell.f)}</span>
        </summary>
        <div class="v2-sm-body">
          ${bulletSVG(cell, m)}
          <dl class="v2-sm-stats">
            <div><dt>Site rate</dt><dd>${fmtRate(cell.r)}<small>${cell.n == null ? '' : esc(cell.n)} / ${cell.d == null ? '' : esc(cell.d)}</small></dd></div>
            <div><dt>Study rate</dt><dd>${fmtRate(m.studyRate)}<small>${esc(m.num || '')}</small></dd></div>
            <div><dt>Score</dt><dd>${fmtNum(cell.s)}${prev}</dd></div>
          </dl>
          <button type="button" class="v2-link" data-open-metric="${esc(cell.m)}">Open ${esc(m.abbr)} in Metrics →</button>
        </div>
      </details>`;
  }

  function renderSitePanel(id) {
    const panel = $('#v2-site-panel');
    if (!panel) return;
    if (!panelEmptyHTML) panelEmptyHTML = panel.innerHTML;
    const site = id && sitesById[id];
    panel.classList.toggle('open', !!site);
    if (!site) {
      panel.innerHTML = panelEmptyHTML;
      return;
    }
    const level = siteData.groupLevel || 'Site';
    const byAbs = (a, b) => Math.abs(b.s || 0) - Math.abs(a.s || 0);
    const cells = site.cells.filter((c) => metricsById[c.m]);
    const active = cells.filter((c) => !metricsById[c.m].inactive);
    // Flagged KRIs rank by their contribution to the risk score, then by score.
    const flagged = active.filter((c) => c.f != null && Math.abs(c.f) >= 1)
      .sort((a, b) => (b.w ?? -1) - (a.w ?? -1) || byAbs(a, b));
    const inRange = active.filter((c) => c.f === 0).sort(byAbs);
    const noData = active.filter((c) => c.f == null);
    const inactive = cells.filter((c) => metricsById[c.m].inactive);
    const group = (title, list, open) => (list.length
      ? `<div class="v2-sp-group"><span>${title}</span><span>${list.length}</span></div>${list.map((c) => metricItem(c, open)).join('')}`
      : '');
    const place = [site.label, [site.city, site.country].filter(Boolean).join(', ')].filter(Boolean).join(' · ');

    panel.innerHTML = `
      <div class="v2-sp-head">
        <div>
          <div class="v2-sp-eyebrow">${esc(level)} · rank ${site.rank} of ${siteData.sites.length}</div>
          <h3>${esc(site.id)}</h3>
          <p>${esc(place)}</p>
        </div>
        <button type="button" class="v2-icon-btn" data-close-panel aria-label="Close ${esc(level.toLowerCase())} details">×</button>
      </div>
      <div class="v2-sp-body">
        <div class="v2-sp-stats">
          <div><span>Risk score</span><b>${site.srs == null ? '–' : fmtNum(site.srs, 1)}</b></div>
          <div><span>Enrolled</span><b>${site.enrolled == null ? '–' : esc(site.enrolled)}</b><small>participants</small></div>
          <div><span>Flags</span><b>${site.red ? `<span class="v2-badge red">${site.red}</span>` : ''}${site.amber ? `<span class="v2-badge amber">${site.amber}</span>` : ''}${!site.red && !site.amber ? '<span class="v2-badge green">✓</span>' : ''}</b><small>red · amber</small></div>
          <div><span>New / worse</span><b>${siteData.hasChanges ? site.new : '–'}</b><small>since last snapshot</small></div>
        </div>
        <div class="v2-sp-list">
          ${group('Flagged', flagged, true)}
          ${group('Within range', inRange, false)}
          ${group('Not enough data', noData, false)}
          ${group('Inactive', inactive, false)}
        </div>
      </div>`;
    if (!reduceMotion) {
      const body = $('.v2-sp-body', panel);
      body && body.classList.add('enter');
    }
    panel.scrollTop = 0;
  }

  function initSitePanel() {
    const panel = $('#v2-site-panel');
    if (!panel) return;
    panel.addEventListener('click', (e) => {
      if (e.target.closest('[data-close-panel]')) return setSelected(null);
      const open = e.target.closest('[data-open-metric]');
      open && openMetric(open.dataset.openMetric);
    });
  }

  /* ---------- Flag changes: perspective + category ---------- */
  function initChanges() {
    const rootEl = $('#v2-changes');
    if (!rootEl) return;
    const views = $$('.v2-change-view', rootEl);
    const more = $('.v2-more', rootEl);
    let view = 'site';
    let cat = 'all';
    let limit = 12;

    const render = () => {
      views.forEach((v) => { v.hidden = v.dataset.viewPanel !== view; });
      const panel = views.find((v) => v.dataset.viewPanel === view);
      if (!panel) return;
      let visible = 0;
      $$('.v2-change-group', panel).forEach((g) => {
        let n = 0;
        $$('.v2-change-row', g).forEach((r) => {
          const on = cat === 'all' || r.dataset.cat === cat;
          r.hidden = !on;
          if (on) n += 1;
        });
        const count = $('.v2-group-count', g);
        if (count) count.textContent = n;
        if (n > 0) visible += 1;
        g.hidden = n === 0 || visible > limit;
      });
      if (!more) return;
      more.innerHTML = '';
      if (visible > limit) {
        const b = document.createElement('button');
        b.type = 'button';
        b.className = 'v2-icon-btn';
        b.textContent = `Show ${Math.min(24, visible - limit)} more of ${visible - limit} groups`;
        b.addEventListener('click', () => { limit += 24; render(); });
        more.appendChild(b);
      }
    };

    $$('.v2-change-persp button', rootEl).forEach((b) => b.addEventListener('click', () => {
      $$('.v2-change-persp button', rootEl).forEach((x) => x.setAttribute('aria-selected', String(x === b)));
      view = b.dataset.view;
      limit = 12;
      render();
    }));
    $$('.v2-change-tabs button', rootEl).forEach((b) => b.addEventListener('click', () => {
      $$('.v2-change-tabs button', rootEl).forEach((x) => x.setAttribute('aria-selected', String(x === b)));
      cat = b.dataset.cat;
      limit = 12;
      render();
    }));
    const follow = (e) => {
      const site = e.target.closest('[data-open-site]');
      if (site) return openSite(site.dataset.openSite);
      const metric = e.target.closest('[data-open-metric]');
      if (metric) return openMetric(metric.dataset.openMetric);
      const row = e.target.closest('.v2-change-row');
      row && openSite(row.dataset.site);
    };
    rootEl.addEventListener('click', follow);
    rootEl.addEventListener('keydown', (e) => { if (e.key === 'Enter' && e.target.closest('.v2-change-row')) follow(e); });
    render();
  }

  /* ---------- Metrics tab: cards, chart tabs, KRI list ---------- */
  function toggleCard(card, open) {
    const isOpen = open === undefined ? card.classList.contains('collapsed') : open;
    card.classList.toggle('collapsed', !isOpen);
    const head = $('.v2-metric-head', card);
    head && head.setAttribute('aria-expanded', String(isOpen));
    if (isOpen) refreshWidgets();
  }

  function initMetrics() {
    $$('.v2-metric').forEach((card) => {
      const head = $('.v2-metric-head', card);
      head.addEventListener('click', () => toggleCard(card));
      head.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleCard(card); }
      });
    });
    document.addEventListener('click', (e) => {
      const tab = e.target.closest('.v2-tab');
      if (!tab) return;
      const scope = tab.closest('.v2-metric') || tab.parentElement.parentElement;
      $$('.v2-tab', tab.parentElement).forEach((t) => t.setAttribute('aria-selected', String(t === tab)));
      $$('.v2-pane', scope).forEach((p) => p.classList.toggle('active', p.dataset.pane === tab.dataset.pane));
      refreshWidgets();
    });
    $$('[data-v2-expand]').forEach((b) => b.addEventListener('click', () => {
      $$('.v2-metric').forEach((c) => toggleCard(c, b.dataset.v2Expand === 'expand'));
    }));

    const links = $$('.v2-metric-nav a[href^="#"]');
    links.forEach((a) => a.addEventListener('click', (e) => {
      const id = a.getAttribute('href').slice(1);
      e.preventDefault();
      if (id.startsWith('kri-')) return openMetric(id.slice(4));
      const target = document.getElementById(id);
      target && target.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth' });
    }));
    if ('IntersectionObserver' in window) {
      const spy = new IntersectionObserver((entries) => entries.forEach((en) => {
        if (!en.isIntersecting) return;
        links.forEach((a) => a.classList.toggle('active', a.getAttribute('href') === '#' + en.target.id));
        const active = links.find((a) => a.classList.contains('active'));
        active && active.scrollIntoView({ block: 'nearest' });
      }), { rootMargin: '-35% 0px -60% 0px' });
      links.forEach((a) => { const t = document.getElementById(a.getAttribute('href').slice(1)); t && spy.observe(t); });
    }
  }

  /* ---------- Chrome: theme, keys, entrance ---------- */
  function initChrome() {
    const themeBtn = $('#v2-theme');
    themeBtn && themeBtn.addEventListener('click', () => {
      root.dataset.theme = root.dataset.theme === 'dark' ? 'light' : 'dark';
      try { localStorage.setItem('gsm-v2-theme', root.dataset.theme); } catch (e) { /* ignore */ }
    });
    $$('details.v2-fot').forEach((d) => d.addEventListener('toggle', refreshWidgets));

    document.addEventListener('keydown', (e) => {
      if (isTyping() || e.metaKey || e.ctrlKey || e.altKey) return;
      const input = $('#v2-site-input');
      if (e.key === '/' && input) { e.preventDefault(); input.focus(); }
      else if (e.key === 'Escape' && selected) setSelected(null);
      else if (['1', '2', '3'].includes(e.key) && !e.target.closest('.v2-site-row')) activateTab(TABS[+e.key - 1]);
    });

    if ('IntersectionObserver' in window) {
      const reveal = new IntersectionObserver((entries) => entries.forEach((en) => {
        if (en.isIntersecting) { en.target.classList.add('in'); reveal.unobserve(en.target); }
      }), { threshold: 0.05 });
      $$('.v2-reveal').forEach((el) => reveal.observe(el));
    } else {
      $$('.v2-reveal').forEach((el) => el.classList.add('in'));
    }

    $$('[data-count]').forEach((el) => {
      const to = Number(el.dataset.count);
      if (reduceMotion || !Number.isFinite(to)) return;
      const t0 = performance.now();
      const tick = (t) => {
        const k = Math.min(1, (t - t0) / 900);
        el.textContent = Math.round(to * (1 - Math.pow(1 - k, 3)));
        if (k < 1) requestAnimationFrame(tick);
      };
      el.textContent = '0';
      requestAnimationFrame(tick);
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    loadSiteData();
    initTabs();
    initCombo();
    initSites();
    initSitePanel();
    initChanges();
    initMetrics();
    initChrome();
    route();
    // The tab bar may still shift while fonts and widgets settle.
    window.addEventListener('load', moveInk);
  });
})();
