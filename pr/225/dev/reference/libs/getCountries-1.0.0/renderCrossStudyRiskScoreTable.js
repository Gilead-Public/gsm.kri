// Cross-Study Risk Score Table Widget
function renderCrossStudyRiskScoreTable(el, input) {
    if (!input) {
        el.innerHTML = '<em>No input provided to widget</em>';
        return;
    }
    
    if (!input.dfSummary) {
        el.innerHTML = '<em>No summary data found in widget input</em>';
        return;
    }
    
    // Check that dfSummary is properly formatted as an array
    if (!Array.isArray(input.dfSummary)) {
        el.innerHTML = '<div style="padding: 20px; background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 5px; color: #856404;"><h4>⚠️ Data Format Warning</h4><p><strong>Summary data must be provided as an array.</strong></p><p>Expected: Array of objects with GroupID, NumStudies, AvgRiskScore, etc.</p><p>Received: ' + typeof input.dfSummary + '</p></div>';
        return;
    }
    
    if (input.dfSummary.length === 0) {
        el.innerHTML = '<em>Summary data array is empty</em>';
        return;
    }

    // Check that dfResults is properly formatted as an array
    if (!Array.isArray(input.dfResults)) {
        el.innerHTML = '<div style="padding: 20px; background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 5px; color: #856404;"><h4>⚠️ Data Format Error</h4><p><strong>Results data must be provided as an array.</strong></p><p>Expected: Array of objects with StudyID, GroupID, MetricID, etc.</p><p>Received: ' + typeof input.dfResults + '</p></div>';
        return;
    }
    
    const resultsArray = input.dfResults;

    // Get unique study IDs for the study filter
    const uniqueStudies = [...new Set(resultsArray.map(d => d.StudyID))].sort();
    
    // Calculate SRS range for slider
    const srsValues = input.dfSummary.map(s => s.AvgRiskScore);
    const minSRS = Math.floor(Math.min(...srsValues));
    const maxSRS = Math.ceil(Math.max(...srsValues));

    // Create controls and table
    let html = '<div class="cross-study-container">';
    html += '<h3>Cross-Study Site Risk Score Summary</h3>';
    
    // Add filter controls
    html += '<div class="filter-controls" style="background:#f5f5f5; padding:15px; margin-bottom:15px; border-radius:5px; border:1px solid #ddd;">';
    
    // First row: Search box
    html += '<div style="margin-bottom:15px;">';
    html += '<label style="display:block; font-weight:bold; margin-bottom:5px;">🔍 Search Sites:</label>';
    html += '<input type="text" id="site-search" placeholder="Search by Site ID or Investigator Name..." style="width:100%; padding:8px; border:1px solid #ccc; border-radius:3px; font-size:14px;" />';
    html += '</div>';
    
    // Second row: Other filters
    html += '<div style="display:flex; gap:20px; flex-wrap:wrap; align-items:center;">';
    
    // SRS Filter
    html += '<div style="flex:1; min-width:200px;">';
    html += '<label style="display:block; font-weight:bold; margin-bottom:5px;">Average SRS Range:</label>';
    html += `<input type="range" id="srs-min-slider" min="${minSRS}" max="${maxSRS}" value="${minSRS}" style="width:45%;" />`;
    html += '<span id="srs-min-value" style="margin:0 5px;">' + minSRS + '</span>';
    html += '<span style="margin:0 5px;">to</span>';
    html += `<input type="range" id="srs-max-slider" min="${minSRS}" max="${maxSRS}" value="${maxSRS}" style="width:45%;" />`;
    html += '<span id="srs-max-value" style="margin:0 5px;">' + maxSRS + '</span>';
    html += '</div>';
    
    // Study Count Filter
    html += '<div style="flex:1; min-width:150px;">';
    html += '<label style="display:block; font-weight:bold; margin-bottom:5px;">Min Study Count:</label>';
    html += '<input type="number" id="study-count-filter" min="1" value="1" style="width:80px; padding:4px;" />';
    html += '</div>';
    
    // Study Filter
    html += '<div style="flex:1; min-width:200px;">';
    html += '<label style="display:block; font-weight:bold; margin-bottom:5px;">Filter by Study:</label>';
    html += '<div style="font-size:12px; color:#555; margin-bottom:5px;">Hold Cmd (Mac) or Ctrl (Windows) to select multiple studies</div>';
    html += '<select id="study-filter" multiple style="width:100%; padding:4px; min-height:120px;">';
    uniqueStudies.forEach(study => {
        html += `<option value="${study}">${study}</option>`;
    });
    html += '</select>';
    html += '</div>';
    
    // Sort dropdown
    html += '<div style="flex:1; min-width:200px;">';
    html += '<label style="display:block; font-weight:bold; margin-bottom:5px;">Sort by:</label>';
    html += '<select id="sort-by" style="width:100%; padding:4px;">';
    html += '<option value="srs-desc">Avg SRS (High to Low)</option>';
    html += '<option value="srs-asc">Avg SRS (Low to High)</option>';
    html += '<option value="max-srs-desc">Max SRS (High to Low)</option>';
    html += '<option value="max-srs-asc">Max SRS (Low to High)</option>';
    html += '<option value="studies-desc">Study Count (High to Low)</option>';
    html += '<option value="studies-asc">Study Count (Low to High)</option>';
    html += '<option value="site-asc">Site ID (A to Z)</option>';
    html += '<option value="site-desc">Site ID (Z to A)</option>';
    html += '<option value="investigator-asc">Investigator (A to Z)</option>';
    html += '<option value="investigator-desc">Investigator (Z to A)</option>';
    html += '</select>';
    html += '</div>';
    
    // Reset button
    html += '<div style="flex:0;">';
    html += '<button id="reset-filters" style="padding:8px 16px; background:#2196f3; color:white; border:none; border-radius:3px; cursor:pointer; margin-top:20px;">Reset Filters</button>';
    html += '</div>';
    
    html += '</div>';
    
    html += '</div>';
    html += '<div id="filter-info" style="margin-top:10px; font-size:14px; color:#666;"></div>';
    
    // Add expand/collapse all buttons
    html += '<div style="margin:10px 0; display:flex; gap:10px;">';
    html += '<button id="expand-all" style="padding:6px 12px; background:#f5f5f5; color:#333; border:1px solid #ccc; border-radius:3px; cursor:pointer; font-size:13px;">+ Expand All</button>';
    html += '<button id="collapse-all" style="padding:6px 12px; background:#f5f5f5; color:#333; border:1px solid #ccc; border-radius:3px; cursor:pointer; font-size:13px;">− Collapse All</button>';
    html += '</div>';
    
    html += '</div>';
    
    html += '<table class="cross-study-unified-table group-overview" style="width:100%;border-collapse:collapse;">';
    html += '<thead id="unified-thead"></thead>';
    
    // Create a tbody for each site
    input.dfSummary.forEach((siteRow, siteIndex) => {
        html += `<tbody id="site-tbody-${siteIndex}"></tbody>`;
    });
    
    html += '</table>';
    html += '</div>';
    
    // Set initial HTML
    el.innerHTML = html;
    
    // Flag to track if we've set the unified header
    let headerSet = false;
    
    // Now render gsmViz tables for each site
    input.dfSummary.forEach((siteRow, siteIndex) => {
        const siteTbody = document.getElementById(`site-tbody-${siteIndex}`);
        
        if (!siteTbody) return;
        
        // Create site summary row
        const investigatorName = siteRow.InvestigatorName || 'Unknown';
        const avgRiskBadge = getRiskScoreBadge(siteRow.AvgRiskScore, 'Avg');
        const maxRiskBadge = getRiskScoreBadge(siteRow.MaxRiskScore, 'Max');
        const studyCountBadge = getStudyCountBadge(siteRow.NumStudies);
        
        const summaryRow = document.createElement('tr');
        summaryRow.className = 'site-summary';
        summaryRow.style.cssText = 'background:#bbb; font-weight:bold; cursor:pointer;';
        summaryRow.dataset.siteIndex = siteIndex;
        summaryRow.dataset.avgRiskScore = siteRow.AvgRiskScore;
        summaryRow.dataset.maxRiskScore = siteRow.MaxRiskScore;
        summaryRow.dataset.numStudies = siteRow.NumStudies;
        summaryRow.dataset.siteId = siteRow.GroupID || '';
        summaryRow.dataset.investigatorName = investigatorName;
        summaryRow.innerHTML = `
            <td colspan="100" style="text-align:left; padding:5px;">
                <span class="toggle-indicator" style="display:inline-block; width:20px; font-weight:bold;">−</span>
                ${siteRow.GroupID} (${investigatorName})
                <span style="float:right;">
                    ${studyCountBadge}
                    ${avgRiskBadge}
                    ${maxRiskBadge}
                </span>
            </td>
        `;
        
        // Get study-level data for this site
        const siteResults = resultsArray.filter(d => 
            d.GroupID === siteRow.GroupID && d.GroupLevel === 'Site'
        );
        
        // Store unique study IDs for this site
        const siteStudyIds = [...new Set(siteResults.map(r => r.StudyID))];
        summaryRow.dataset.studies = JSON.stringify(siteStudyIds);
        
        // Add click event to toggle visibility
        summaryRow.addEventListener('click', function() {
            const tbody = this.parentElement;
            const studyRows = Array.from(tbody.querySelectorAll('tr:not(.site-summary)'));
            const indicator = this.querySelector('.toggle-indicator');
            
            studyRows.forEach(row => {
                if (row.style.display === 'none') {
                    row.style.display = '';
                    indicator.textContent = '−';
                } else {
                    row.style.display = 'none';
                    indicator.textContent = '+';
                }
            });
        });
        
        siteTbody.appendChild(summaryRow);
        
        // Transform data to use StudyID as GroupID (prepend as requested)
        const transformedResults = siteResults.map(d => ({
            ...d,
            GroupID: `${d.StudyID} ${d.GroupID}`
        }));

        // Prepare Metadata - Show study info on hover, but use enrollment info for the specific study
        const siteCounts = input.dfGroups.filter(d => 
            d.GroupID === siteRow.GroupID && d.GroupLevel === 'Site' && d.Param == "ParticipantCount"
        );

        const studyGroups = input.dfGroups.filter(d => 
            d.GroupLevel === 'Study'
        ).map(d=> {
            // Find the site-level ParticipantCount for this specific study-site combination
            const siteParticipantCount = siteCounts.find(count => 
                count.StudyID === d.StudyID
            );
        
            return {
                ...d,
                GroupLevel:"Site",
                GroupID: `${d.GroupID} ${siteRow.GroupID}`,
                Value: d.Param == "ParticipantCount" ? (siteParticipantCount ? siteParticipantCount.Value : "??") : d.Value
            };
        });



        // Check if gsmViz is available
        if (typeof gsmViz !== 'undefined' && gsmViz.default && gsmViz.default.groupOverview) {
            try {
                // Create a temporary container for gsmViz to render into
                const tempContainer = document.createElement('div');
                
                // Create the gsmViz groupOverview instance
                const instance = gsmViz.default.groupOverview(
                    tempContainer,
                    transformedResults,
                    {
                        GroupLevel: 'Site',
                        groupLabelKey: 'nickname',
                        SiteRiskScoreMetricID: 'Analysis_srs0001'
                    },
                    studyGroups,
                    input.dfMetrics
                );
                
                // Extract the table created by gsmViz
                const gsmVizTable = tempContainer.querySelector('table.group-overview');
                
                if (gsmVizTable) {
                    // Copy header to unified thead (only once)
                    if (!headerSet) {
                        const unifiedThead = document.getElementById('unified-thead');
                        const gsmVizThead = gsmVizTable.querySelector('thead');
                        if (gsmVizThead) {
                            unifiedThead.innerHTML = gsmVizThead.innerHTML;
                            headerSet = true;
                        }
                    }
                    
                    // Move body rows from gsmViz table to our site tbody
                    const gsmVizTbody = gsmVizTable.querySelector('tbody');
                    if (gsmVizTbody) {
                        const rows = Array.from(gsmVizTbody.querySelectorAll('tr'));
                        
                        // Sort rows by SRS (high to low)
                        rows.sort((a, b) => {
                            // Get SRS from the siteRiskScore column
                            const srsColA = a.querySelector('.group-overview--siteRiskScore');
                            const srsColB = b.querySelector('.group-overview--siteRiskScore');
                            const srsA = srsColA ? parseFloat(srsColA.textContent || 0) : 0;
                            const srsB = srsColB ? parseFloat(srsColB.textContent || 0) : 0;
                            return srsB - srsA; // High to low
                        });
                        
                        rows.forEach(row => {
                            siteTbody.appendChild(row);
                        });
                    }
                }
                
                console.log(`Created gsmViz groupOverview for site ${siteRow.GroupID}:`, instance);
            } catch (error) {
                console.error(`Error creating gsmViz for site ${siteRow.GroupID}:`, error);
                const errorRow = document.createElement('tr');
                errorRow.innerHTML = `<td colspan="100" style="padding:10px;color:#d32f2f;">Error rendering table: ${error.message}</td>`;
                siteTbody.appendChild(errorRow);
            }
        } else {
            console.warn('gsmViz library not available');
            const warningRow = document.createElement('tr');
            warningRow.innerHTML = `<td colspan="100" style="padding:10px;color:#856404;">gsmViz library not loaded. Please ensure gsmViz is included in dependencies.</td>`;
            siteTbody.appendChild(warningRow);
        }
    });
    
    // Set up filter event listeners
    setupFilters(el, input.dfSummary);
}

function setupFilters(el, dfSummary) {
    const srsMinSlider = el.querySelector('#srs-min-slider');
    const srsMaxSlider = el.querySelector('#srs-max-slider');
    const srsMinValue = el.querySelector('#srs-min-value');
    const srsMaxValue = el.querySelector('#srs-max-value');
    const studyCountFilter = el.querySelector('#study-count-filter');
    const studyFilter = el.querySelector('#study-filter');
    const searchBox = el.querySelector('#site-search');
    const sortBy = el.querySelector('#sort-by');
    const resetButton = el.querySelector('#reset-filters');
    const filterInfo = el.querySelector('#filter-info');
    
    function applySorting() {
        const sortValue = sortBy.value;
        const table = el.querySelector('.cross-study-unified-table');
        const allTbodies = Array.from(el.querySelectorAll('tbody[id^="site-tbody-"]'));
        
        // Create array of tbody elements with their sort values
        const tbodyData = allTbodies.map(tbody => {
            const summaryRow = tbody.querySelector('.site-summary');
            if (!summaryRow) return null;
            
            return {
                tbody: tbody,
                srs: parseFloat(summaryRow.dataset.avgRiskScore),
                maxSrs: parseFloat(summaryRow.dataset.maxRiskScore),
                studies: parseInt(summaryRow.dataset.numStudies),
                siteId: (summaryRow.dataset.siteId || '').toLowerCase(),
                investigator: (summaryRow.dataset.investigatorName || '').toLowerCase()
            };
        }).filter(d => d !== null);
        
        // Sort based on selection
        tbodyData.sort((a, b) => {
            switch(sortValue) {
                case 'srs-desc':
                    return b.srs - a.srs;
                case 'srs-asc':
                    return a.srs - b.srs;
                case 'max-srs-desc':
                    return b.maxSrs - a.maxSrs;
                case 'max-srs-asc':
                    return a.maxSrs - b.maxSrs;
                case 'studies-desc':
                    return b.studies - a.studies;
                case 'studies-asc':
                    return a.studies - b.studies;
                case 'site-asc':
                    return a.siteId.localeCompare(b.siteId);
                case 'site-desc':
                    return b.siteId.localeCompare(a.siteId);
                case 'investigator-asc':
                    return a.investigator.localeCompare(b.investigator);
                case 'investigator-desc':
                    return b.investigator.localeCompare(a.investigator);
                default:
                    return 0;
            }
        });
        
        // Reorder tbody elements in the table
        const thead = table.querySelector('thead');
        tbodyData.forEach(data => {
            table.appendChild(data.tbody);
        });
    }
    
    function applyFilters() {
        const minSRS = parseFloat(srsMinSlider.value);
        const maxSRS = parseFloat(srsMaxSlider.value);
        const minStudyCount = parseInt(studyCountFilter.value);
        const selectedStudies = Array.from(studyFilter.selectedOptions || []).map(option => option.value).filter(Boolean);
        const searchTerm = searchBox.value.toLowerCase().trim();
        
        let visibleCount = 0;
        let totalCount = 0;
        
        // Get all site tbody elements
        const allTbodies = el.querySelectorAll('tbody[id^="site-tbody-"]');
        
        allTbodies.forEach(tbody => {
            const summaryRow = tbody.querySelector('.site-summary');
            if (!summaryRow) return;
            
            totalCount++;
            
            const avgRiskScore = parseFloat(summaryRow.dataset.avgRiskScore);
            const numStudies = parseInt(summaryRow.dataset.numStudies);
            const siteStudies = JSON.parse(summaryRow.dataset.studies || '[]');
            const siteId = (summaryRow.dataset.siteId || '').toLowerCase();
            const investigatorName = (summaryRow.dataset.investigatorName || '').toLowerCase();
            
            let show = true;
            
            // Check SRS range
            if (avgRiskScore < minSRS || avgRiskScore > maxSRS) {
                show = false;
            }
            
            // Check study count
            if (numStudies < minStudyCount) {
                show = false;
            }
            
            // Check study filter
            if (selectedStudies.length > 0 && !selectedStudies.some(study => siteStudies.includes(study))) {
                show = false;
            }
            
            // Check search term
            if (searchTerm && !siteId.includes(searchTerm) && !investigatorName.includes(searchTerm)) {
                show = false;
            }
            
            // Show/hide the entire tbody
            if (show) {
                tbody.style.display = '';
                visibleCount++;
            } else {
                tbody.style.display = 'none';
            }
        });
        
        // Update filter info
        const filters = [];
        if (minSRS > parseFloat(srsMinSlider.min) || maxSRS < parseFloat(srsMaxSlider.max)) {
            filters.push(`SRS: ${minSRS.toFixed(1)}-${maxSRS.toFixed(1)}`);
        }
        if (minStudyCount > 1) {
            filters.push(`Min ${minStudyCount} studies`);
        }
        if (selectedStudies.length > 0) {
            filters.push(`Studies: ${selectedStudies.join(', ')}`);
        }
        if (searchTerm) {
            filters.push(`Search: "${searchTerm}"`);
        }
        
        if (filters.length > 0) {
            filterInfo.innerHTML = `<strong>Active filters:</strong> ${filters.join(', ')} | Showing ${visibleCount} of ${totalCount} sites`;
        } else {
            filterInfo.innerHTML = `Showing all ${totalCount} sites`;
        }
    }
    
    // Update SRS slider values
    srsMinSlider.addEventListener('input', function() {
        const minVal = parseFloat(this.value);
        const maxVal = parseFloat(srsMaxSlider.value);
        if (minVal > maxVal) {
            this.value = maxVal;
        }
        srsMinValue.textContent = this.value;
        applyFilters();
    });
    
    srsMaxSlider.addEventListener('input', function() {
        const minVal = parseFloat(srsMinSlider.value);
        const maxVal = parseFloat(this.value);
        if (maxVal < minVal) {
            this.value = minVal;
        }
        srsMaxValue.textContent = this.value;
        applyFilters();
    });
    
    studyCountFilter.addEventListener('input', applyFilters);
    studyFilter.addEventListener('change', applyFilters);
    searchBox.addEventListener('input', applyFilters);
    sortBy.addEventListener('change', applySorting);
    
    // Reset button
    resetButton.addEventListener('click', function() {
        srsMinSlider.value = srsMinSlider.min;
        srsMaxSlider.value = srsMaxSlider.max;
        srsMinValue.textContent = srsMinSlider.min;
        srsMaxValue.textContent = srsMaxSlider.max;
        studyCountFilter.value = 1;
        Array.from(studyFilter.options || []).forEach(option => {
            option.selected = false;
        });
        searchBox.value = '';
        sortBy.value = 'srs-desc';
        applySorting();
        applyFilters();
    });
    
    // Expand/Collapse All buttons
    const expandAllBtn = el.querySelector('#expand-all');
    const collapseAllBtn = el.querySelector('#collapse-all');
    
    expandAllBtn.addEventListener('click', function() {
        const allTbodies = el.querySelectorAll('tbody[id^="site-tbody-"]');
        allTbodies.forEach(tbody => {
            const summaryRow = tbody.querySelector('.site-summary');
            const indicator = summaryRow ? summaryRow.querySelector('.toggle-indicator') : null;
            const studyRows = Array.from(tbody.querySelectorAll('tr:not(.site-summary)'));
            
            studyRows.forEach(row => {
                row.style.display = '';
            });
            
            if (indicator) {
                indicator.textContent = '−';
            }
        });
    });
    
    collapseAllBtn.addEventListener('click', function() {
        const allTbodies = el.querySelectorAll('tbody[id^="site-tbody-"]');
        allTbodies.forEach(tbody => {
            const summaryRow = tbody.querySelector('.site-summary');
            const indicator = summaryRow ? summaryRow.querySelector('.toggle-indicator') : null;
            const studyRows = Array.from(tbody.querySelectorAll('tr:not(.site-summary)'));
            
            studyRows.forEach(row => {
                row.style.display = 'none';
            });
            
            if (indicator) {
                indicator.textContent = '+';
            }
        });
    });
    
    // Initialize sorting and filters
    applySorting();
    applyFilters();
}

function getRiskScoreBadge(score, label = 'SRS') {
    let bgColor, textColor;
    if (score >= 75) {
        bgColor = '#d32f2f'; // Red
        textColor = '#fff';
    } else if (score >= 50) {
        bgColor = '#f57c00'; // Orange
        textColor = '#fff';
    } else if (score >= 25) {
        bgColor = '#ffa726'; // Amber
        textColor = '#000';
    } else {
        bgColor = '#388e3c'; // Green
        textColor = '#fff';
    }
    
    return `<span class="gsm-srs" style="background-color:${bgColor};color:${textColor};padding:4px 8px; border-radius:4px;font-weight:bold;font-size:12px;margin-left:5px;">${score.toFixed(1)} ${label}</span>`;
}

function getStudyCountBadge(count) {
    const studyLabel = count === 1 ? 'Study' : 'Studies';
    return `<span class="gsm-studyCount" style="background-color:#757575;color:#fff;padding:4px 8px;border-radius:4px;font-weight:bold;font-size:12px;margin-left:8px;">${count} ${studyLabel}</span>`;
}
