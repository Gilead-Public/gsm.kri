HTMLWidgets.widget({
  name: 'Widget_RecordDuplication',
  type: 'output',

  factory: function(el, width, height) {
    return {
      renderValue: function(input) {
        const parsedInput = {};
        Object.keys(input).forEach(key => {
          try {
            parsedInput[key] = typeof input[key] === 'string' ? JSON.parse(input[key]) : input[key];
          } catch (e) {
            parsedInput[key] = input[key];
          }
        });

        el.innerHTML = '';
        renderRecordDuplicationTable(el, parsedInput);
      },

      resize: function(width, height) {
        // Handle resize if needed
      }
    };
  }
});
