/**
 * Assessment Reporter
 * Generates formatted assessment reports
 */

class AssessmentReporter {
  constructor(results) {
    this.results = results;
  }

  generateMarkdown() {
    let md = '# Scaffolding Assessment Report\n\n';
    md += '## Controllability Dimensions (E1-E4)\n\n';
    md += '| Dimension | Level | Description |\n';
    md += '|-----------|-------|-------------|\n';

    for (const [dim, data] of Object.entries(this.results.controllability)) {
      md += `| ${dim} | ${data.level} | ${data.description} |\n`;
    }

    md += '\n## Observability Dimensions (O1-O4, V1-V3)\n\n';
    md += '| Dimension | Level | Description |\n';
    md += '|-----------|-------|-------------|\n';

    for (const [dim, data] of Object.entries(this.results.observability)) {
      md += `| ${dim} | ${data.level} | ${data.description} |\n`;
    }

    md += '\n## Overall Scores\n\n';
    md += `- Controllability Average: ${this.results.overall.controllabilityAvg.toFixed(2)}/4\n`;
    md += `- Observability Average: ${this.results.overall.observabilityAvg.toFixed(2)}/4\n`;
    md += `- Overall Score: ${this.results.overall.score.toFixed(2)}/4\n`;

    return md;
  }

  generateJSON() {
    return JSON.stringify(this.results, null, 2);
  }
}

module.exports = { AssessmentReporter };
