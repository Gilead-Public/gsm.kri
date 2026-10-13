/* gsm.kri Report_KRI_v2 — interactions for the opt-in modern KRI report. */
(function () {
  'use strict';

  document.documentElement.classList.add('v2-js');
  try {
    if (localStorage.getItem('gsm-v2-theme') === 'dark') document.documentElement.dataset.theme = 'dark';
  } catch (e) { /* storage unavailable (file:// in some browsers) */ }

  const $ = (sel, el = document) => el.querySelector(sel);
  const $$ = (sel, el = document) => [...el.querySelectorAll(sel)];
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Hidden Chart.js canvases render at 0px; a resize lets htmlwidgets and Chart.js re-measure.
  const refreshWidgets = () => requestAnimationFrame(() => window.dispatchEvent(new Event('resize')));

  /* ---------- Group highlight (mirrors overallGroupDropdown.js) ---------- */
  let selected = null;

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

  function setSelected(groupID) {
    selected = groupID || null;
    const input = $('#v2-site-input');
    const site = siteIndex.find((s) => s.GroupID === selected);
    if (input) input.value = selected ? selected + (site && site.label ? ' · ' + site.label : '') : '';
    $('#v2-combo') && $('#v2-combo').classList.toggle('has-value', !!selected);
    $$('[data-site]').forEach((el) => {
      const on = selected && el.dataset.site === selected;
      el.classList.toggle('selected', !!on);
      if (el.classList.contains('v2-change')) el.classList.toggle('dim', !!selected && !on);
    });
    highlightCharts(selected);
  }

  /* ---------- Combobox ---------- */
  let siteIndex = [];
  function initCombo() {
    const data = $('#v2-sites');
    const input = $('#v2-site-input');
    const list = $('#v2-site-list');
    if (!data || !input || !list) return;
    try { siteIndex = JSON.parse(data.textContent); } catch (e) { siteIndex = []; }

    let active = -1;
    const render = (q) => {
      q = q.trim().toLowerCase();
      const items = siteIndex.filter((s) => !q || s.GroupID.toLowerCase().includes(q) || (s.label || '').toLowerCase().includes(q)).slice(0, 50);
      list.innerHTML = '';
      items.forEach((s, i) => {
        const b = document.createElement('button');
        b.type = 'button';
        b.setAttribute('role', 'option');
        b.dataset.g = s.GroupID;
        const left = document.createElement('span');
        left.className = 'v2-mono';
        left.textContent = s.GroupID;
        const right = document.createElement('span');
        right.className = 'v2-muted';
        right.textContent = (s.label ? s.label + ' ' : '');
        [['red', s.red], ['amber', s.amber]].forEach(([cls, n]) => {
          if (n > 0) {
            const badge = document.createElement('span');
            badge.className = 'v2-badge ' + cls;
            badge.textContent = n;
            right.appendChild(badge);
          }
        });
        b.append(left, right);
        if (i === active) b.classList.add('active');
        list.appendChild(b);
      });
      if (!items.length) {
        const empty = document.createElement('div');
        empty.className = 'v2-empty';
        empty.textContent = 'No matching groups';
        list.appendChild(empty);
      }
      list.classList.add('open');
      input.setAttribute('aria-expanded', 'true');
    };
    const close = () => { list.classList.remove('open'); input.setAttribute('aria-expanded', 'false'); active = -1; };

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
        setSelected((opts[active] || opts[0]).dataset.g);
        close();
        input.blur();
      } else if (e.key === 'Escape') {
        close();
        input.blur();
      }
    });
    list.addEventListener('mousedown', (e) => {
      const b = e.target.closest('button');
      if (b) { e.preventDefault(); setSelected(b.dataset.g); close(); input.blur(); }
    });
    input.addEventListener('blur', () => setTimeout(close, 120));
    $('#v2-site-clear') && $('#v2-site-clear').addEventListener('click', () => setSelected(null));
    document.addEventListener('keydown', (e) => {
      const typing = /input|select|textarea/i.test((document.activeElement || {}).tagName || '');
      if (e.key === '/' && !typing) { e.preventDefault(); input.focus(); }
      if (e.key === 'Escape' && !typing && selected) setSelected(null);
    });
  }

  /* ---------- Tabs, metric cards, flag changes ---------- */
  function initTabs() {
    document.addEventListener('click', (e) => {
      const tab = e.target.closest('.v2-tab');
      if (!tab) return;
      const scope = tab.closest('[data-tabs-scope]') || tab.closest('.v2-metric') || tab.parentElement.parentElement;
      $$('.v2-tab', tab.parentElement).forEach((t) => t.setAttribute('aria-selected', String(t === tab)));
      $$('.v2-pane', scope).forEach((p) => p.classList.toggle('active', p.dataset.pane === tab.dataset.pane));
      refreshWidgets();
    });
  }

  function initMetricCards() {
    const toggle = (card, open) => {
      const isOpen = open === undefined ? card.classList.contains('collapsed') : open;
      card.classList.toggle('collapsed', !isOpen);
      $('.v2-metric-head', card).setAttribute('aria-expanded', String(isOpen));
      if (isOpen) refreshWidgets();
    };
    $$('.v2-metric').forEach((card) => {
      const head = $('.v2-metric-head', card);
      head.addEventListener('click', () => toggle(card));
      head.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggle(card); }
      });
    });
    $$('[data-v2-expand]').forEach((b) => b.addEventListener('click', () => {
      $$('.v2-metric').forEach((c) => toggle(c, b.dataset.v2Expand === 'expand'));
    }));
    // Opening a KRI from the sidebar should never land on a collapsed card.
    $$('.v2-sidebar a[href^="#kri-"]').forEach((a) => a.addEventListener('click', () => {
      const card = document.getElementById(a.getAttribute('href').slice(1));
      if (card && card.classList.contains('collapsed')) toggle(card, true);
      document.body.classList.remove('v2-nav-open');
    }));
  }

  function initChanges() {
    const root = $('#v2-changes');
    if (!root) return;
    const tabs = $$('.v2-change-tabs button', root);
    const cards = $$('.v2-change', root);
    const more = $('.v2-more', root);
    const step = 12;
    let cat = tabs.length ? tabs[0].dataset.cat : null;
    let limit = step;

    const render = () => {
      const inCat = cards.filter((c) => c.dataset.cat === cat);
      cards.forEach((c) => c.classList.add('v2-hidden'));
      inCat.slice(0, limit).forEach((c) => c.classList.remove('v2-hidden'));
      if (!more) return;
      more.innerHTML = '';
      if (inCat.length > limit) {
        const b = document.createElement('button');
        b.type = 'button';
        b.className = 'v2-icon-btn';
        b.textContent = `Show ${Math.min(24, inCat.length - limit)} more of ${inCat.length - limit}`;
        b.addEventListener('click', () => { limit += 24; render(); });
        more.appendChild(b);
      }
    };
    tabs.forEach((t) => t.addEventListener('click', () => {
      tabs.forEach((x) => x.setAttribute('aria-selected', String(x === t)));
      cat = t.dataset.cat;
      limit = step;
      render();
    }));
    cards.forEach((c) => {
      c.addEventListener('click', () => c.classList.toggle('open'));
      c.addEventListener('keydown', (e) => { if (e.key === 'Enter') c.classList.toggle('open'); });
    });
    render();
  }

  /* ---------- Chrome: theme, nav, scrollspy, hide-on-scroll, entrance ---------- */
  function initChrome() {
    const themeBtn = $('#v2-theme');
    themeBtn && themeBtn.addEventListener('click', () => {
      const root = document.documentElement;
      root.dataset.theme = root.dataset.theme === 'dark' ? 'light' : 'dark';
      try { localStorage.setItem('gsm-v2-theme', root.dataset.theme); } catch (e) { /* ignore */ }
    });
    const navToggle = $('#v2-nav-toggle');
    navToggle && navToggle.addEventListener('click', () => document.body.classList.toggle('v2-nav-open'));

    document.addEventListener('click', (e) => {
      const hot = e.target.closest('.v2-hot');
      if (hot) setSelected(hot.dataset.site === selected ? null : hot.dataset.site);
    });

    const links = $$('.v2-sidebar a[href^="#"]');
    if ('IntersectionObserver' in window) {
      const spy = new IntersectionObserver((entries) => entries.forEach((en) => {
        if (en.isIntersecting) links.forEach((a) => a.classList.toggle('active', a.getAttribute('href') === '#' + en.target.id));
      }), { rootMargin: '-30% 0px -65% 0px' });
      links.forEach((a) => { const t = document.getElementById(a.getAttribute('href').slice(1)); t && spy.observe(t); });

      const reveal = new IntersectionObserver((entries) => entries.forEach((en) => {
        if (en.isIntersecting) { en.target.classList.add('in'); reveal.unobserve(en.target); }
      }), { threshold: 0.05 });
      $$('.v2-reveal').forEach((el) => reveal.observe(el));
    } else {
      $$('.v2-reveal').forEach((el) => el.classList.add('in'));
    }

    const bar = $('#v2-topbar');
    let lastY = window.scrollY;
    window.addEventListener('scroll', () => {
      const y = window.scrollY;
      const focused = document.activeElement && document.activeElement.id === 'v2-site-input';
      bar && bar.classList.toggle('hidden', y > lastY && y > 240 && !focused);
      lastY = y;
    }, { passive: true });

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
    initCombo();
    initTabs();
    initMetricCards();
    initChanges();
    initChrome();
  });
})();
