HTMLWidgets.widget({
  name: 'Widget_PrematureDeathBucketBar',
  type: 'output',
  factory: function (el, width, height) {
    return {
      renderValue: function (input) {
        if (input.bDebug) console.log(input);
        var meta = input.metadata || {};
        var spec = input.spec || {};
        if (meta.chartId) el.id = meta.chartId;

        // Build the {chartId, level, groupId, ...} payload from point._datum.
        function payload(point) {
          var d = (point && point._datum) || {};
          return {
            chartId: el.id,
            level: meta.level,
            groupId: d.GroupID,
            outerGroupId: d.OuterGroupID,
            category: d.Category,
            country: d.Level === 'country' ? d.GroupID : d.OuterGroupID,
            invid: d.Level === 'site' ? d.GroupID : undefined
          };
        }
        function dispatch(point) {
          el.dispatchEvent(new CustomEvent('pdBucketClick', { bubbles: true, detail: payload(point) }));
        }

        // Tooltip: "Category — Subjects: n (pct%)", plus the parent country on
        // the site chart. gsm.viz titles the tooltip with the x-axis category
        // (the site id) only, and the site chart shows every country's sites
        // until one is picked, so the parent has to be named explicitly.
        // Chart.js renders a returned array as one line per element.
        spec.tooltip = Object.assign({}, spec.tooltip, {
          formatter: function (count, context, details) {
            var d = (details && details.datum) || {};
            var lines = [d.Category + ' — Subjects: ' + d.n + ' (' + Number(d.pct).toFixed(1) + '%)'];
            // Only the site chart has a parent tier. The study and country
            // charts carry a missing OuterGroupID, which the widget's JSON
            // serializer (na = "string") writes as the literal string "NA".
            if (d.OuterGroupID && d.OuterGroupID !== 'NA') {
              lines.push('Country: ' + d.OuterGroupID);
            }
            return lines;
          }
        });

        // All three bucket charts are flat `bars`; the country->site drilldown
        // narrows the site chart via helpers.updateData (driven by the report),
        // so keep the original rows here for that reactive re-slice.
        el.pdAllData = input.data;
        spec.callbacks = Object.assign({}, spec.callbacks, { onClick: dispatch });
        el.gsmChart = gsmViz.default.bars(el, input.data, spec);
      },
      resize: function (width, height) {}
    };
  }
});
