HTMLWidgets.widget({
    name: 'Widget_BarChart',
    type: 'output',
    factory: function(el, width, height) {
        return {
            renderValue: function(input) {
                if (input.bDebug)
                    console.log(input);

                // Coerce `input.lChartConfig` to an object if it is not already.
                if (Object.prototype.toString.call(input.lChartConfig) !== '[object Object]') {
                    input.lChartConfig = {};
                };

                // Assign a unique ID to the element.
                el.id = `barChart--${input.lChartConfig.MetricID}_${input.strOutcome}`;

                // Add click event listener to chart.
                input.lChartConfig.clickCallback = clickCallback(el, input);

                // Generate bar chart.
                const instance = gsmViz.default.barChart(
                    el,
                    input.dfResults,
                    input.lChartConfig,
                    input.vThreshold,
                    input.dfGroups
                );

                // Add dropdowns that highlight group ID(s).
                const { widgetControls } = addWidgetControls(
                    el,
                    input.dfResults,
                    input.lChartConfig,
                    input.dfGroups,
                    input.bAddGroupSelect
                );

                // Add a dropdown that changes the outcome variable.
                const outcomeSelect = addOutcomeSelect(
                    widgetControls,
                    input.dfResults,
                    input.lChartConfig,
                    input.dfGroups,
                    input.strOutcome,
                    input.vOutcomeOptions
                );
            },
            resize: function(width, height) {
            }
        };
    }
});
