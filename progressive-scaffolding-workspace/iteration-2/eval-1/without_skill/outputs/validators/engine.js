/**
 * Validation Engine for Scaffolding Assessment
 */

const { ScaffoldingAssessment } = require('../index');
const path = require('path');

class ValidationEngine {
  constructor(projectPath) {
    this.projectPath = projectPath;
    this.assessment = new ScaffoldingAssessment(projectPath);
  }

  validate() {
    const results = this.assessment.assess();
    return this.formatResults(results);
  }

  formatResults(results) {
    return {
      controllability: Object.entries(results.controllability).reduce((acc, [key, val]) => {
        acc[key] = { level: val.level, description: val.description };
        return acc;
      }, {}),
      observability: Object.entries(results.observability).reduce((acc, [key, val]) => {
        acc[key] = { level: val.level, description: val.description };
        return acc;
      }, {}),
      overall: results.overall
    };
  }
}

module.exports = { ValidationEngine };
