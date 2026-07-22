HTMLWidgets.widget({
  name: 'Widget_PrematureDeathReasonBar',
  type: 'output',
  factory: function (el, width, height) {
    return {
      renderValue: function (input) {
        if (input.bDebug) console.log(input);
        var meta = input.metadata || {};
        var spec = input.spec || {};
        if (meta.chartId) el.id = meta.chartId;

        // Tooltip: reuse the prebuilt hover string R attached to each row.
        spec.tooltip = Object.assign({}, spec.tooltip, {
          formatter: function (count, context, details) {
            var d = (details && details.datum) || {};
            return d.hover;
          }
        });
        el.gsmChart = gsmViz.default.bars(el, input.data, spec);

        // Country-reactive swap: one spec, updateData only. A country bar click
        // in the buckets chart dispatches pdBucketFilterChanged; swap this bar to
        // that country's reason slice (or __ALL__ when the filter is cleared).
        if (meta.reactive) {
          document.addEventListener('pdBucketFilterChanged', function (e) {
            var country = (e.detail && e.detail.country) || '__ALL__';
            var rows = meta.reactive[country] || meta.reactive['__ALL__'];
            // updateData takes (chart, data, spec); spec = chart.data._spec_.
            if (rows) {
              el.gsmChart.helpers.updateData(el.gsmChart, rows, el.gsmChart.data._spec_);
            }
          });
        }
      },
      resize: function (width, height) {}
    };
  }
});
