HTMLWidgets.widget({
  name: 'Widget_RepeatMeasurementsTiles',
  type: 'output',

  factory: function (el) {
    return {
      renderValue: function (x) {
        var parse = function (v) {
          return typeof v === 'string' ? JSON.parse(v) : v;
        };
        el.innerHTML = '';
        el.gsmChart = renderRepeatMeasurementsTiles(el, {
          tiles: parse(x.tiles) || [],
          columns: parse(x.columns) || [],
          colors: x.colors || {},
          label: x.label,
          pageSize: x.pageSize
        });
      },

      resize: function () {}
    };
  }
});
