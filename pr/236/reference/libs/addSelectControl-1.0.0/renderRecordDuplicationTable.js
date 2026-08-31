// Record Duplication Table Widget
function renderRecordDuplicationTable(el, input) {
    if (!input || !input.dfFlagged) {
        el.innerHTML = '<em>No data provided to widget</em>';
        return;
    }

    const data = Array.isArray(input.dfFlagged) ? input.dfFlagged : [];
    if (data.length === 0) {
        el.innerHTML = '<em>No records to display</em>';
        return;
    }

    const groupLevel = input.strGroupLevel || 'Site';
    const prioritized = Array.isArray(input.vPrioritizedMeasures) ? input.vPrioritizedMeasures : [];
    const windowLength = Number(input.nWindowLength) || 3;

    // Repeat window rate = repeat windows / evaluable windows, matching Count_Duplicates().
    // Rows outside an evaluable window (the first W-1 per subject) contribute to neither.
    function windowRate(rows) {
        const den = rows.reduce((acc, d) => acc + (Number(d.IsEvaluableWindow) || 0), 0);
        const num = rows.reduce((acc, d) => acc + (Number(d.IsRepeatWindow) || 0), 0);
        return { num: num, den: den, pct: den > 0 ? (num / den * 100).toFixed(1) : '0.0' };
    }

    // Parse metric inputs
    const reportingResults = Array.isArray(input.dfReportingResults) ? input.dfReportingResults : [];
    const measureMetrics = Array.isArray(input.dfMeasureMetrics) ? input.dfMeasureMetrics : [];

    // Build measure -> MetricID lookup
    const measureToMetricID = {};
    measureMetrics.forEach(mm => { measureToMetricID[mm.measure] = mm.MetricID; });

    // Build metricID+groupID -> {Score, Flag} lookup
    const metricResultLookup = {};
    reportingResults.forEach(r => {
        metricResultLookup[r.MetricID + '|' + r.GroupID] = { Score: r.Score, Flag: r.Flag };
    });

    // ── Flag icon helpers (same SVGs as gsm.kri KRI report) ──────────────────
    const COLOR = { green: '#3DAF06', amber: '#FEAA02', red: '#FF5859', gray: '#828282' };

    function svgSingleArrow(flag, color) {
        const rot = Math.sign(flag) === -1 ? 'transform:rotate(180deg);' : '';
        return `<svg aria-hidden="true" role="img" viewBox="0 0 448 512" style="height:1em;width:0.88em;vertical-align:-0.125em;fill:${color};overflow:visible;position:relative;${rot}"><path d="M201.4 137.4c12.5-12.5 32.8-12.5 45.3 0l160 160c12.5 12.5 12.5 32.8 0 45.3s-32.8 12.5-45.3 0L224 205.3 86.6 342.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3l160-160z"/></svg>`;
    }
    function svgDoubleArrow(flag, color) {
        const rot = Math.sign(flag) === -1 ? 'transform:rotate(180deg);' : '';
        return `<svg aria-hidden="true" role="img" viewBox="0 0 448 512" style="height:1em;width:0.88em;vertical-align:-0.125em;fill:${color};overflow:visible;position:relative;${rot}"><path d="M246.6 41.4c-12.5-12.5-32.8-12.5-45.3 0l-160 160c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L224 109.3 361.4 246.6c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3l-160-160zm160 352l-160-160c-12.5-12.5-32.8-12.5-45.3 0l-160 160c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L224 301.3 361.4 438.6c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3z"/></svg>`;
    }
    function svgCheckMark(color) {
        return `<svg aria-hidden="true" role="img" viewBox="0 0 448 512" style="height:1em;width:0.88em;vertical-align:-0.125em;fill:${color};overflow:visible;position:relative;"><path d="M438.6 105.4c12.5 12.5 12.5 32.8 0 45.3l-256 256c-12.5 12.5-32.8 12.5-45.3 0l-128-128c-12.5-12.5-12.5-32.8 0-45.3s32.8-12.5 45.3 0L160 338.7 393.4 105.4c12.5-12.5 32.8-12.5 45.3 0z"/></svg>`;
    }
    function svgMinus(color) {
        return `<svg aria-hidden="true" role="img" viewBox="0 0 448 512" style="height:1em;width:0.88em;vertical-align:-0.125em;fill:${color};overflow:visible;position:relative;"><path d="M432 256c0 17.7-14.3 32-32 32L48 288c-17.7 0-32-14.3-32-32s14.3-32 32-32l352 0c17.7 0 32 14.3 32 32z"/></svg>`;
    }

    // Returns a colored pill with the appropriate SVG icon for a given flag value
    function flagBadgeHtml(flag, zScore) {
        let icon, bgColor, label;
        const f = (flag === null || flag === undefined) ? null : Number(flag);
        if (f === null || isNaN(f)) {
            icon = svgMinus(COLOR.gray); bgColor = COLOR.gray; label = 'No flag';
        } else if (f === 0) {
            icon = svgCheckMark(COLOR.green); bgColor = COLOR.green; label = 'Flag: 0';
        } else if (Math.abs(f) === 1) {
            icon = svgSingleArrow(f, COLOR.amber); bgColor = COLOR.amber; label = 'Flag: ' + f;
        } else {
            icon = svgDoubleArrow(f, COLOR.red); bgColor = COLOR.red; label = 'Flag: ' + f;
        }
        const zStr = (zScore != null && !isNaN(zScore)) ? ' Z: ' + parseFloat(zScore).toFixed(2) : '';
        return `<span title="${label}${zStr}" style="display:inline-flex;align-items:center;gap:3px;background:${bgColor}22;border:1px solid ${bgColor};color:#333;padding:1px 6px;border-radius:3px;font-size:11px;margin-left:6px;">${icon}<span style="font-size:11px;font-family:monospace;">${zStr}</span></span>`;
    }

    // ── Delta helpers ─────────────────────────────────────────────────────────
    function fmtVal(v) {
        if (v == null || isNaN(v)) return '—';
        // Preserve original precision (no extra decimals)
        return Number.isInteger(v) ? String(v) : parseFloat(v.toPrecision(6)).toString();
    }
    function fmtDelta(d) {
        if (d == null || isNaN(d)) return '—';
        const sign = d > 0 ? '+' : '';
        return sign + (Number.isInteger(d) ? d : parseFloat(d.toPrecision(4)));
    }

    // Group data by measure -> group -> subject
    const allMeasures = [...new Set(data.map(d => d.measure))];

    // Sort: measures with metrics first (prioritized), then alphabetical within each tier
    allMeasures.sort((a, b) => {
        const aPri = prioritized.includes(a) ? 0 : 1;
        const bPri = prioritized.includes(b) ? 0 : 1;
        if (aPri !== bPri) return aPri - bPri;
        return a.localeCompare(b);
    });

    const hasAnyMetric = allMeasures.some(m => !!measureToMetricID[m]);

    let html = '<div class="record-duplication-container" style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 13px;">';

    // ── Controls toolbar ──────────────────────────────────────────────────────
    html += '<div style="margin-bottom:15px; padding:10px; background:#f8f9fa; border:1px solid #dee2e6; border-radius:4px;">';
    html += '<div style="display:flex; gap:15px; align-items:center; flex-wrap:wrap;">';

    // Search
    html += '<div><label style="font-weight:600; margin-right:4px;">Search:</label>';
    html += '<input type="text" id="rd-search" placeholder="Filter by Subject or ' + groupLevel + '..." style="padding:4px 8px; border:1px solid #ced4da; border-radius:3px; width:200px;" /></div>';

    // Display mode dropdown
    html += '<div><label style="font-weight:600; margin-right:4px;">Display:</label>';
    html += '<select id="rd-display-mode" style="padding:4px 8px; border:1px solid #ced4da; border-radius:3px; cursor:pointer;">';
    html += '<option value="raw" selected>Raw Value</option>';
    html += '<option value="baseline">Δ from Baseline</option>';
    html += '<option value="previous">Δ from Previous Visit</option>';
    html += '</select></div>';

    // Measures filter (only show if any measure has a metric)
    if (hasAnyMetric) {
        html += '<div><label style="font-weight:600; margin-right:4px;">Measures:</label>';
        html += '<select id="rd-measure-filter" style="padding:4px 8px; border:1px solid #ced4da; border-radius:3px; cursor:pointer;">';
        html += '<option value="all" selected>All Measures</option>';
        html += '<option value="kri">KRIs Only</option>';
        html += '</select></div>';
    }

    // Expand/Collapse buttons
    html += '<div style="margin-left:auto;"><button id="rd-expand-all" style="padding:4px 10px; background:#e9ecef; border:1px solid #ced4da; border-radius:3px; cursor:pointer;">+ Expand All</button> ';
    html += '<button id="rd-collapse-all" style="padding:4px 10px; background:#e9ecef; border:1px solid #ced4da; border-radius:3px; cursor:pointer;">− Collapse All</button></div>';

    html += '</div></div>';

    // ── Nested measure/group/subject table ────────────────────────────────────
    html += '<div id="rd-content">';

    allMeasures.forEach((measure, mIdx) => {
        const measureData = data.filter(d => d.measure === measure);
        const isPrioritized = prioritized.includes(measure);
        const hasMetric = !!measureToMetricID[measure];
        const measureRate = windowRate(measureData);

        const priLabel = isPrioritized ? ' <span style="background:#ffc107; color:#000; padding:1px 5px; border-radius:3px; font-size:11px; font-weight:600;">KRI</span>' : '';

        // Flag summary for measure header (only when metric exists)
        let measureFlagSummary = '';
        const metricIDForMeasure = measureToMetricID[measure];
        if (metricIDForMeasure) {
            const allGroups = [...new Set(measureData.map(d => d.GroupID))];
            let nRed = 0, nAmber = 0, nGreen = 0;
            allGroups.forEach(g => {
                const r = metricResultLookup[metricIDForMeasure + '|' + g];
                if (!r) return;
                const f = Number(r.Flag);
                if (Math.abs(f) === 2) nRed++;
                else if (Math.abs(f) === 1) nAmber++;
                else nGreen++;
            });
            const parts = [];
            if (nRed > 0)   parts.push(`<span style="display:inline-flex;align-items:center;gap:2px;margin-left:6px;" title="${nRed} flagged (high)">${svgDoubleArrow(1,COLOR.red)}<span style="font-size:11px;color:#fff;">${nRed}</span></span>`);
            if (nAmber > 0) parts.push(`<span style="display:inline-flex;align-items:center;gap:2px;margin-left:6px;" title="${nAmber} flagged (moderate)">${svgSingleArrow(1,COLOR.amber)}<span style="font-size:11px;color:#fff;">${nAmber}</span></span>`);
            if (nGreen > 0) parts.push(`<span style="display:inline-flex;align-items:center;gap:2px;margin-left:6px;" title="${nGreen} no flag">${svgCheckMark(COLOR.green)}<span style="font-size:11px;color:#fff;">${nGreen}</span></span>`);
            measureFlagSummary = parts.join('');
        }

        html += '<div class="rd-measure-section" data-measure="' + measure + '" data-has-metric="' + hasMetric + '">';
        html += '<div class="rd-measure-header" data-idx="m' + mIdx + '" style="background:#343a40; color:#fff; padding:10px 12px; cursor:pointer; border-radius:4px 4px 0 0; margin-top:10px; display:flex; justify-content:space-between; align-items:center;">';
        html += '<span style="font-weight:600;display:flex;align-items:center;gap:4px;">▼ ' + measure + priLabel + measureFlagSummary + '</span>';
        html += '<span style="font-size:12px;">' + measureRate.pct + '% repeat (' + measureRate.num + '/' + measureRate.den + ' windows, W=' + windowLength + ')</span>';
        html += '</div>';
        html += '<div class="rd-measure-body" id="rd-body-m' + mIdx + '" style="display:block; border:1px solid #dee2e6; border-top:none; border-radius:0 0 4px 4px;">';

        // Group by GroupID
        const groups = [...new Set(measureData.map(d => d.GroupID))].sort();

        groups.forEach((group, gIdx) => {
            const groupData = measureData.filter(d => d.GroupID === group);
            const groupRate = windowRate(groupData);

            const metricID = measureToMetricID[measure];
            const metricResult = metricID ? metricResultLookup[metricID + '|' + group] : null;
            const metricBadge = metricResult ? flagBadgeHtml(metricResult.Flag, metricResult.Score) : '';

            html += '<div class="rd-group-section" data-group="' + group + '">';
            html += '<div class="rd-group-header" data-idx="g' + mIdx + '-' + gIdx + '" style="background:#e9ecef; padding:8px 12px 8px 24px; cursor:pointer; border-bottom:1px solid #dee2e6; display:flex; justify-content:space-between; align-items:center;">';
            html += '<span style="font-weight:500;">▼ ' + groupLevel + ': ' + group + '</span>';
            html += '<span style="display:flex;align-items:center;font-size:12px;color:#6c757d;">' + groupRate.pct + '% repeat (' + groupRate.num + '/' + groupRate.den + ')' + metricBadge + '</span>';
            html += '</div>';
            html += '<div class="rd-group-body" id="rd-body-g' + mIdx + '-' + gIdx + '" style="display:block;">';

            // Group by subject
            const subjects = [...new Set(groupData.map(d => d.subjid))].sort();

            subjects.forEach((subj) => {
                const subjData = groupData
                    .filter(d => d.subjid === subj)
                    .sort((a, b) => (a.date || '').localeCompare(b.date || ''));

                const subjRate = windowRate(subjData);
                const dupColor = subjRate.num > 0 ? '#dc3545' : '#6c757d';

                // Pre-compute baseline and previous-visit deltas
                const baseVal = subjData.length > 0 ? subjData[0].value : null;

                html += '<div class="rd-subj-section" data-subj="' + subj + '">';
                html += '<div style="padding:5px 12px 5px 48px; border-bottom:1px solid #f1f3f5; display:flex; align-items:center; gap:12px;">';
                html += '<span style="font-size:12px; min-width:80px; font-weight:500;">' + subj + '</span>';
                html += '<div style="display:flex; gap:3px; flex-wrap:wrap; flex:1;">';

                subjData.forEach((row, rIdx) => {
                    const inRun = Number(row.IsRepeatRun) === 1;
                    const cellBg     = inRun ? '#f8d7da' : '#e8f5e9';
                    const cellBorder = inRun ? '#f5c6cb' : '#c3e6cb';
                    const cellColor  = inRun ? '#721c24' : '#155724';
                    const fontWeight = inRun ? '600' : '400';

                    const rawVal  = row.value;
                    const prevVal = rIdx > 0 ? subjData[rIdx - 1].value : null;
                    const dBase   = (rIdx > 0 && rawVal != null && baseVal != null) ? (rawVal - baseVal) : null;
                    const dPrev   = (rIdx > 0 && rawVal != null && prevVal != null) ? (rawVal - prevVal) : null;

                    const rawStr  = fmtVal(rawVal);
                    const baseStr = rIdx === 0 ? '—' : fmtDelta(dBase);
                    const prevStr = rIdx === 0 ? '—' : fmtDelta(dPrev);

                    const runNote = inRun ? ' | run of ' + row.RunLength + ' identical values' : '';
                    const titleStr = (row.date || '') + ' | ' + rawStr + runNote;

                    html += '<div class="rd-pill"'
                        + ' data-raw="' + rawStr + '"'
                        + ' data-chg-base="' + baseStr + '"'
                        + ' data-chg-prev="' + prevStr + '"'
                        + ' title="' + titleStr + '"'
                        + ' style="'
                        + 'background:' + cellBg + ';'
                        + 'border:1px solid ' + cellBorder + ';'
                        + 'color:' + cellColor + ';'
                        + 'padding:2px 6px;'
                        + 'border-radius:3px;'
                        + 'font-size:12px;'
                        + 'font-weight:' + fontWeight + ';'
                        + 'cursor:default;'
                        + '">' + rawStr + '</div>';
                });

                html += '</div>';
                html += '<span style="font-size:11px; color:' + dupColor + '; white-space:nowrap; min-width:90px; text-align:right;">'
                    + subjRate.pct + '% repeat (' + subjRate.num + '/' + subjRate.den + ')</span>';
                html += '</div></div>';
            });

            html += '</div></div>';
        });

        html += '</div></div>';
    });

    html += '</div></div>';
    el.innerHTML = html;

    // ── Control: display mode ─────────────────────────────────────────────────
    function applyDisplayMode(mode) {
        el.querySelectorAll('.rd-pill').forEach(pill => {
            if (mode === 'raw')      pill.textContent = pill.dataset.raw;
            else if (mode === 'baseline') pill.textContent = pill.dataset.chgBase;
            else                     pill.textContent = pill.dataset.chgPrev;
        });
    }

    const displaySelect = el.querySelector('#rd-display-mode');
    if (displaySelect) {
        displaySelect.addEventListener('change', () => applyDisplayMode(displaySelect.value));
    }

    // ── Control: measure filter ───────────────────────────────────────────────
    function applyMeasureFilter(mode) {
        el.querySelectorAll('.rd-measure-section').forEach(section => {
            const hasMetric = section.dataset.hasMetric === 'true';
            section.style.display = (mode === 'all' || hasMetric) ? '' : 'none';
        });
    }

    const measureFilterSelect = el.querySelector('#rd-measure-filter');
    if (measureFilterSelect) {
        measureFilterSelect.addEventListener('change', () => applyMeasureFilter(measureFilterSelect.value));
    }

    // ── Control: expand / collapse ────────────────────────────────────────────
    function toggleSection(headerEl, bodyId) {
        const body = document.getElementById(bodyId);
        if (!body) return;
        const isHidden = body.style.display === 'none';
        body.style.display = isHidden ? 'block' : 'none';
        const arrow = headerEl.querySelector('span');
        if (arrow) {
            arrow.innerHTML = arrow.innerHTML.replace(isHidden ? '▶' : '▼', isHidden ? '▼' : '▶');
        }
    }

    el.querySelectorAll('.rd-measure-header').forEach(header => {
        header.addEventListener('click', () => toggleSection(header, 'rd-body-' + header.dataset.idx));
    });
    el.querySelectorAll('.rd-group-header').forEach(header => {
        header.addEventListener('click', () => toggleSection(header, 'rd-body-' + header.dataset.idx));
    });

    const expandBtn = el.querySelector('#rd-expand-all');
    const collapseBtn = el.querySelector('#rd-collapse-all');

    if (expandBtn) {
        expandBtn.addEventListener('click', () => {
            el.querySelectorAll('[id^="rd-body-m"], [id^="rd-body-g"]').forEach(b => { b.style.display = 'block'; });
            el.querySelectorAll('.rd-measure-header span:first-child, .rd-group-header span:first-child').forEach(s => {
                s.innerHTML = s.innerHTML.replace('▶', '▼');
            });
        });
    }
    if (collapseBtn) {
        collapseBtn.addEventListener('click', () => {
            el.querySelectorAll('[id^="rd-body-m"], [id^="rd-body-g"]').forEach(b => { b.style.display = 'none'; });
            el.querySelectorAll('.rd-measure-header span:first-child, .rd-group-header span:first-child').forEach(s => {
                s.innerHTML = s.innerHTML.replace('▼', '▶');
            });
        });
    }

    // ── Control: search filter ────────────────────────────────────────────────
    const searchInput = el.querySelector('#rd-search');
    if (searchInput) {
        searchInput.addEventListener('input', () => {
            const query = searchInput.value.toLowerCase();
            el.querySelectorAll('.rd-subj-section').forEach(section => {
                const subj  = (section.dataset.subj || '').toLowerCase();
                const group = (section.closest('.rd-group-section')?.dataset.group || '').toLowerCase();
                section.style.display = (!query || subj.includes(query) || group.includes(query)) ? '' : 'none';
            });
        });
    }
}
