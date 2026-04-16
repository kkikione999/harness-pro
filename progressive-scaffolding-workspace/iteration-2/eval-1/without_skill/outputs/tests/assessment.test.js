/**
 * Scaffolding Assessment Tests
 */

const assert = require('assert');

function runTests(assessmentResults) {
  let passed = 0;
  let failed = 0;

  // Test: All controllability dimensions present
  try {
    assert.ok(assessmentResults.controllability.E1, 'E1 should be present');
    assert.ok(assessmentResults.controllability.E2, 'E2 should be present');
    assert.ok(assessmentResults.controllability.E3, 'E3 should be present');
    assert.ok(assessmentResults.controllability.E4, 'E4 should be present');
    passed++;
  } catch (e) {
    failed++;
    console.error('Failed: Controllability dimensions test', e.message);
  }

  // Test: All observability dimensions present
  try {
    assert.ok(assessmentResults.observability.O1, 'O1 should be present');
    assert.ok(assessmentResults.observability.O2, 'O2 should be present');
    assert.ok(assessmentResults.observability.O3, 'O3 should be present');
    assert.ok(assessmentResults.observability.O4, 'O4 should be present');
    assert.ok(assessmentResults.observability.V1, 'V1 should be present');
    assert.ok(assessmentResults.observability.V2, 'V2 should be present');
    assert.ok(assessmentResults.observability.V3, 'V3 should be present');
    passed++;
  } catch (e) {
    failed++;
    console.error('Failed: Observability dimensions test', e.message);
  }

  // Test: Levels are within valid range (1-4)
  try {
    const allDimensions = {
      ...assessmentResults.controllability,
      ...assessmentResults.observability
    };
    for (const [dim, data] of Object.entries(allDimensions)) {
      assert.ok(data.level >= 1 && data.level <= 4, `${dim} level should be 1-4`);
    }
    passed++;
  } catch (e) {
    failed++;
    console.error('Failed: Level range test', e.message);
  }

  // Test: Overall scores calculated
  try {
    assert.ok(typeof assessmentResults.overall.controllabilityAvg === 'number', 'Controllability avg should be number');
    assert.ok(typeof assessmentResults.overall.observabilityAvg === 'number', 'Observability avg should be number');
    assert.ok(typeof assessmentResults.overall.score === 'number', 'Overall score should be number');
    passed++;
  } catch (e) {
    failed++;
    console.error('Failed: Overall scores test', e.message);
  }

  return { passed, failed };
}

module.exports = { runTests };
