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

    // Group data by measure -> group -> subject
    const measures = [...new Set(data.map(d => d.measure))];

    // Sort: prioritized first, then alphabetical
    measures.sort((a, b) => {
        const aPri = prioritized.includes(a) ? 0 : 1;
        const bPri = prioritized.includes(b) ? 0 : 1;
        if (aPri !== bPri) return aPri - bPri;
        return a.localeCompare(b);
    });

    let html = '<div class="record-duplication-container" style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 13px;">';

    // Controls
    html += '<div style="margin-bottom:15px; padding:10px; background:#f8f9fa; border:1px solid #dee2e6; border-radius:4px;">';
    html += '<div style="display:flex; gap:15px; align-items:center; flex-wrap:wrap;">';
    html += '<div><label style="font-weight:600;">Search: </label>';
    html += '<input type="text" id="rd-search" placeholder="Filter by Subject or ' + groupLevel + '..." style="padding:4px 8px; border:1px solid #ced4da; border-radius:3px; width:200px;" /></div>';
    html += '<div><button id="rd-expand-all" style="padding:4px 10px; background:#e9ecef; border:1px solid #ced4da; border-radius:3px; cursor:pointer;">+ Expand All</button> ';
    html += '<button id="rd-collapse-all" style="padding:4px 10px; background:#e9ecef; border:1px solid #ced4da; border-radius:3px; cursor:pointer;">− Collapse All</button></div>';
    html += '</div></div>';

    // Build nested table
    html += '<div id="rd-content">';

    measures.forEach((measure, mIdx) => {
        const measureData = data.filter(d => d.measure === measure);
        const isPrioritized = prioritized.includes(measure);
        const totalRecords = measureData.length;
        const dupRecords = measureData.filter(d => d.is_duplicate === 1).length;
        const dupPct = totalRecords > 0 ? (dupRecords / totalRecords * 100).toFixed(1) : '0.0';

        const priLabel = isPrioritized ? ' <span style="background:#ffc107; color:#000; padding:1px 5px; border-radius:3px; font-size:11px; font-weight:600;">KRI</span>' : '';

        html += '<div class="rd-measure-section" data-measure="' + measure + '">';
        html += '<div class="rd-measure-header" data-idx="m' + mIdx + '" style="background:#343a40; color:#fff; padding:10px 12px; cursor:pointer; border-radius:4px 4px 0 0; margin-top:10px; display:flex; justify-content:space-between; align-items:center;">';
        html += '<span style="font-weight:600;">▼ ' + measure + priLabel + '</span>';
        html += '<span style="font-size:12px;">' + dupPct + '% duplicate (' + dupRecords + '/' + totalRecords + ' records)</span>';
        html += '</div>';
        html += '<div class="rd-measure-body" id="rd-body-m' + mIdx + '" style="display:block; border:1px solid #dee2e6; border-top:none; border-radius:0 0 4px 4px;">';

        // Group by GroupID (site/country)
        const groups = [...new Set(measureData.map(d => d.GroupID))].sort();

        groups.forEach((group, gIdx) => {
            const groupData = measureData.filter(d => d.GroupID === group);
            const groupDups = groupData.filter(d => d.is_duplicate === 1).length;
            const groupPct = groupData.length > 0 ? (groupDups / groupData.length * 100).toFixed(1) : '0.0';

            html += '<div class="rd-group-section" data-group="' + group + '">';
            html += '<div class="rd-group-header" data-idx="g' + mIdx + '-' + gIdx + '" style="background:#e9ecef; padding:8px 12px 8px 24px; cursor:pointer; border-bottom:1px solid #dee2e6; display:flex; justify-content:space-between;">';
            html += '<span style="font-weight:500;">▼ ' + groupLevel + ': ' + group + '</span>';
            html += '<span style="font-size:12px; color:#6c757d;">' + groupPct + '% dup (' + groupDups + '/' + groupData.length + ')</span>';
            html += '</div>';
            html += '<div class="rd-group-body" id="rd-body-g' + mIdx + '-' + gIdx + '" style="display:block;">';

            // Group by subject
            const subjects = [...new Set(groupData.map(d => d.subjid))].sort();

            subjects.forEach((subj, sIdx) => {
                const subjData = groupData.filter(d => d.subjid === subj);
                const subjDups = subjData.filter(d => d.is_duplicate === 1).length;
                const subjPct = subjData.length > 0 ? (subjDups / subjData.length * 100).toFixed(1) : '0.0';

                // Sort by date
                subjData.sort((a, b) => (a.date || '').localeCompare(b.date || ''));

                const dupColor = subjDups > 0 ? '#dc3545' : '#6c757d';

                html += '<div class="rd-subj-section" data-subj="' + subj + '">';
                html += '<div style="padding:5px 12px 5px 48px; border-bottom:1px solid #f1f3f5; display:flex; align-items:center; gap:12px;">';

                // Subject label
                html += '<span style="font-size:12px; min-width:80px; font-weight:500;">' + subj + '</span>';

                // Single-row value timeline
                html += '<div style="display:flex; gap:3px; flex-wrap:wrap; flex:1;">';
                subjData.forEach(row => {
                    const isDup = row.is_duplicate === 1;
                    const cellBg = isDup ? '#f8d7da' : '#e8f5e9';
                    const cellBorder = isDup ? '#f5c6cb' : '#c3e6cb';
                    const cellColor = isDup ? '#721c24' : '#155724';
                    const val = row.value != null ? row.value : 'NA';
                    const dateStr = row.date || '';
                    html += '<div title="' + dateStr + '" style="'
                        + 'background:' + cellBg + ';'
                        + 'border:1px solid ' + cellBorder + ';'
                        + 'color:' + cellColor + ';'
                        + 'padding:2px 6px;'
                        + 'border-radius:3px;'
                        + 'font-size:12px;'
                        + 'font-weight:' + (isDup ? '600' : '400') + ';'
                        + 'cursor:default;'
                        + '">' + val + '</div>';
                });
                html += '</div>';

                // % dup summary
                html += '<span style="font-size:11px; color:' + dupColor + '; white-space:nowrap; min-width:90px; text-align:right;">'
                    + subjPct + '% dup (' + subjDups + '/' + subjData.length + ')</span>';

                html += '</div></div>';
            });

            html += '</div></div>';
        });

        html += '</div></div>';
    });

    html += '</div></div>';
    el.innerHTML = html;

    // Event handlers for expand/collapse
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

    // Measure headers
    el.querySelectorAll('.rd-measure-header').forEach(header => {
        header.addEventListener('click', () => toggleSection(header, 'rd-body-' + header.dataset.idx));
    });

    // Group headers
    el.querySelectorAll('.rd-group-header').forEach(header => {
        header.addEventListener('click', () => toggleSection(header, 'rd-body-' + header.dataset.idx));
    });

    // Expand/Collapse all (measure + group levels only — participants are always visible)
    const expandBtn = document.getElementById('rd-expand-all');
    const collapseBtn = document.getElementById('rd-collapse-all');

    if (expandBtn) {
        expandBtn.addEventListener('click', () => {
            el.querySelectorAll('[id^="rd-body-m"], [id^="rd-body-g"]').forEach(body => { body.style.display = 'block'; });
            el.querySelectorAll('.rd-measure-header span:first-child, .rd-group-header span:first-child').forEach(span => {
                span.innerHTML = span.innerHTML.replace('▶', '▼');
            });
        });
    }

    if (collapseBtn) {
        collapseBtn.addEventListener('click', () => {
            el.querySelectorAll('[id^="rd-body-m"], [id^="rd-body-g"]').forEach(body => { body.style.display = 'none'; });
            el.querySelectorAll('.rd-measure-header span:first-child, .rd-group-header span:first-child').forEach(span => {
                span.innerHTML = span.innerHTML.replace('▼', '▶');
            });
        });
    }

    // Search filter
    const searchInput = document.getElementById('rd-search');
    if (searchInput) {
        searchInput.addEventListener('input', () => {
            const query = searchInput.value.toLowerCase();
            el.querySelectorAll('.rd-subj-section').forEach(section => {
                const subj = (section.dataset.subj || '').toLowerCase();
                const group = (section.closest('.rd-group-section')?.dataset.group || '').toLowerCase();
                const match = !query || subj.includes(query) || group.includes(query);
                section.style.display = match ? '' : 'none';
            });
        });
    }
}
