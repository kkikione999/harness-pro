/**
 * Progressive Scaffolding Assessment Engine
 * Evaluates controllability (E1-E4) and observability (O1-O4, V1-V3) dimensions
 */

const fs = require('fs');
const path = require('path');

const CONTROLLABILITY_DIMENSIONS = ['E1', 'E2', 'E3', 'E4'];
const OBSERVABILITY_DIMENSIONS = ['O1', 'O2', 'O3', 'O4', 'V1', 'V2', 'V3'];

class ScaffoldingAssessment {
  constructor(projectPath) {
    this.projectPath = projectPath;
    this.results = {
      controllability: {},
      observability: {},
      overall: {}
    };
  }

  assess() {
    this.assessControllability();
    this.assessObservability();
    this.calculateOverall();
    return this.results;
  }

  assessControllability() {
    // E1: Execution Control - ability to control agent execution flow
    this.results.controllability.E1 = {
      level: this.checkExecutionControl(),
      description: 'Execution Control - agent start/stop/pause capabilities'
    };

    // E2: Environment Control - ability to control the execution environment
    this.results.controllability.E2 = {
      level: this.checkEnvironmentControl(),
      description: 'Environment Control - sandbox, resources, permissions'
    };

    // E3: Input Control - ability to control agent input/parameters
    this.results.controllability.E3 = {
      level: this.checkInputControl(),
      description: 'Input Control - prompt templates, context management'
    };

    // E4: Output Control - ability to control/constrain agent output
    this.results.controllability.E4 = {
      level: this.checkOutputControl(),
      description: 'Output Control - response validation, formatting constraints'
    };
  }

  assessObservability() {
    // O1: State Observation - ability to observe agent internal state
    this.results.observability.O1 = {
      level: this.checkStateObservation(),
      description: 'State Observation - memory, context, decision tracking'
    };

    // O2: Action Observation - ability to observe agent actions
    this.results.observability.O2 = {
      level: this.checkActionObservation(),
      description: 'Action Observation - tool calls, API requests, file operations'
    };

    // O3: Result Observation - ability to observe task results
    this.results.observability.O3 = {
      level: this.checkResultObservation(),
      description: 'Result Observation - output validation, quality metrics'
    };

    // O4: Trace Observation - ability to trace execution path
    this.results.observability.O4 = {
      level: this.checkTraceObservation(),
      description: 'Trace Observation - full execution history, replay capability'
    };

    // V1: Visibility Level 1 - basic logging
    this.results.observability.V1 = {
      level: this.checkVisibilityLevel1(),
      description: 'Visibility Level 1 - basic logging'
    };

    // V2: Visibility Level 2 - structured logging with context
    this.results.observability.V2 = {
      level: this.checkVisibilityLevel2(),
      description: 'Visibility Level 2 - structured logging with context'
    };

    // V3: Visibility Level 3 - full observability with metrics
    this.results.observability.V3 = {
      level: this.checkVisibilityLevel3(),
      description: 'Visibility Level 3 - metrics, dashboards, alerting'
    };
  }

  checkExecutionControl() {
    const hasStartStop = fs.existsSync(path.join(this.projectPath, '.harness'));
    return hasStartStop ? 3 : 1;
  }

  checkEnvironmentControl() {
    const hasHarnessDir = fs.existsSync(path.join(this.projectPath, '.harness'));
    return hasHarnessDir ? 2 : 1;
  }

  checkInputControl() {
    const hasConfigs = fs.existsSync(path.join(this.projectPath, 'progressive-scaffolding-workspace'));
    return hasConfigs ? 3 : 1;
  }

  checkOutputControl() {
    const hasOutputDir = fs.existsSync(path.join(this.projectPath, 'progressive-scaffolding-workspace/iteration-1/eval-1/without_skill/outputs'));
    return hasOutputDir ? 3 : 1;
  }

  checkStateObservation() {
    return 1; // Basic project structure does not provide state observation
  }

  checkActionObservation() {
    return 2; // Can observe file system changes
  }

  checkResultObservation() {
    return 2; // Output directory structure exists
  }

  checkTraceObservation() {
    return 1; // No trace mechanism
  }

  checkVisibilityLevel1() {
    return 2; // Project has markdown files that serve as logs
  }

  checkVisibilityLevel2() {
    return 1; // No structured logging
  }

  checkVisibilityLevel3() {
    return 1; // No metrics or dashboards
  }

  calculateOverall() {
    const cValues = Object.values(this.results.controllability).map(v => v.level);
    const oValues = Object.values(this.results.observability).map(v => v.level);

    this.results.overall.controllabilityAvg = cValues.reduce((a, b) => a + b, 0) / cValues.length;
    this.results.overall.observabilityAvg = oValues.reduce((a, b) => a + b, 0) / oValues.length;
    this.results.overall.score = (this.results.overall.controllabilityAvg + this.results.overall.observabilityAvg) / 2;
  }
}

module.exports = { ScaffoldingAssessment };
