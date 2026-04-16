/**
 * Controllability Rules for Scaffolding Assessment
 * Dimensions: E1-E4
 */

const CONTROLLABILITY_RULES = {
  E1: {
    name: 'Execution Control',
    description: 'Ability to control agent execution flow',
    check: (projectPath) => {
      const hasHarness = require('fs').existsSync(require('path').join(projectPath, '.harness'));
      return {
        score: hasHarness ? 3 : 1,
        evidence: hasHarness ? '.harness directory present' : 'No execution control mechanism'
      };
    }
  },
  E2: {
    name: 'Environment Control',
    description: 'Ability to control execution environment',
    check: (projectPath) => {
      const hasHarness = require('fs').existsSync(require('path').join(projectPath, '.harness'));
      return {
        score: hasHarness ? 2 : 1,
        evidence: hasHarness ? 'Environment configuration possible' : 'No environment control'
      };
    }
  },
  E3: {
    name: 'Input Control',
    description: 'Ability to control agent input and parameters',
    check: (projectPath) => {
      const hasWorkspace = require('fs').existsSync(
        require('path').join(projectPath, 'progressive-scaffolding-workspace')
      );
      return {
        score: hasWorkspace ? 3 : 1,
        evidence: hasWorkspace ? 'Scaffolding workspace with input configuration' : 'No input control'
      };
    }
  },
  E4: {
    name: 'Output Control',
    description: 'Ability to control and constrain agent output',
    check: (projectPath) => {
      const hasOutput = require('fs').existsSync(
        require('path').join(projectPath, 'progressive-scaffolding-workspace/iteration-2/eval-1/without_skill/outputs')
      );
      return {
        score: hasOutput ? 3 : 1,
        evidence: hasOutput ? 'Output directory structure established' : 'No output control'
      };
    }
  }
};

module.exports = { CONTROLLABILITY_RULES };
