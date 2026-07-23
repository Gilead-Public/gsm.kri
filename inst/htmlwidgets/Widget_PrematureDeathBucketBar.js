// Breathing room, in px, required on each side of an on-bar label.
var LABEL_FIT_PAD = 2;

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

        // gsm.viz's segment-label floor (annotations.labels.segment.minSize)
        // measures the value axis only, so a hair-thin bar that is tall enough
        // keeps a label wider than the bar itself, spilling over its neighbours
        // -- every label on a study with many sites. Blank a label that does not
        // fit across the bar; returning null makes the plugin skip it. Zooming
        // in widens the bars, so the labels come back.
        var segment = ((spec.annotations || {}).labels || {}).segment;
        if (segment) {
          segment.formatter = function (value, context, details) {
            // Mirrors gsm.viz's default text for value: "auto" (counts, or
            // one-decimal percentages once the fill button sets stat).
            var text = details.valueType === 'percent'
              ? Number(value).toFixed(1) + '%'
              : String(value);
            var bar = context.chart.getDatasetMeta(context.datasetIndex).data[context.dataIndex];
            if (!bar) return text;
            var font = context.chart.options.font || {};
            var c2d = context.chart.ctx;
            c2d.save();
            c2d.font = (font.size || 12) + 'px ' + (font.family || 'sans-serif');
            var textWidth = c2d.measureText(text).width;
            c2d.restore();
            // Bucket charts are vertical, so the bar's thickness is its width.
            return textWidth + LABEL_FIT_PAD <= bar.width ? text : null;
          };
        }

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
