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

        // Tooltip: "Category — Subjects: n (pct%)". details.datum carries n and pct.
        spec.tooltip = Object.assign({}, spec.tooltip, {
          formatter: function (count, context, details) {
            var d = (details && details.datum) || {};
            return d.Category + ' — Subjects: ' + d.n + ' (' + Number(d.pct).toFixed(1) + '%)';
          }
        });

        // All three bucket charts are flat `bars`; the country->site drilldown
        // narrows the site chart via helpers.updateData (driven by the report),
        // so keep the original rows here for that reactive re-slice.
        el.pdAllData = input.data;
        spec.callbacks = Object.assign({}, spec.callbacks, { onClick: function (p) { dispatch(p); } });
        el.gsmChart = gsmViz.default.bars(el, input.data, spec);
      },
      resize: function (width, height) {}
    };
  }
});
