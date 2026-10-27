let srsWeightingExampleIndex = 0;

function setupSRSWeightingExamples(root) {
  const summaries = root.querySelectorAll(
    '.srs-weighting-summary:not([data-srs-weighting-initialized])'
  );

  summaries.forEach(summary => {
    const totalPossible = Number(summary.dataset.totalPossible);
    const selects = summary.querySelectorAll('.srs-weighting-flag-select');
    const totalScore = summary.querySelector('.srs-weighting-total-score');
    const selectedPoints = summary.querySelector('.srs-weighting-selected-points');
    const toggle = summary.querySelector('.srs-weighting-calculator-toggle');
    const calculatorContent = summary.querySelectorAll(
      '.srs-weighting-calculator-content'
    );
    const calculatorTable = summary.querySelector('.srs-weighting-table');
    calculatorTable.id = calculatorTable.id ||
      `srs-weighting-calculator-${srsWeightingExampleIndex++}`;
    toggle.setAttribute('aria-controls', calculatorTable.id);

    function formatPoints(points) {
      return Number.isInteger(points) ? String(points) : String(Number(points.toFixed(4)));
    }

    function updateScores() {
      let totalPoints = 0;

      selects.forEach(select => {
        const weight = Number(select.selectedOptions[0].dataset.weight);
        const metricScore = select.closest('tr').querySelector(
          '.srs-weighting-metric-score'
        );
        totalPoints += weight;
        metricScore.textContent = `${formatPoints(weight)} points`;
      });

      selectedPoints.textContent = formatPoints(totalPoints);
      totalScore.textContent = totalPossible > 0
        ? (totalPoints / totalPossible * 100).toFixed(1)
        : 'Not available';
    }

    function toggleCalculator() {
      const expanded = toggle.getAttribute('aria-expanded') === 'true';
      calculatorContent.forEach(element => {
        element.hidden = expanded;
      });
      toggle.setAttribute('aria-expanded', expanded ? 'false' : 'true');
      toggle.textContent = expanded
        ? 'Show example SRS calculator'
        : 'Hide example SRS calculator';
    }

    selects.forEach(select => select.addEventListener('change', updateScores));
    toggle.addEventListener('click', toggleCalculator);
    summary.dataset.srsWeightingInitialized = 'true';
    updateScores();
  });
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    setupSRSWeightingExamples(document);
  });
} else {
  setupSRSWeightingExamples(document);
}
