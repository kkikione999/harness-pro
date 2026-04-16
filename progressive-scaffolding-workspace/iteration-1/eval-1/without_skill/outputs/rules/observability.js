/**
 * Observability Rules for Scaffolding Assessment
 * Dimensions: O1-O4, V1-V3
 */

const OBSERVABILITY_RULES = {
  O1: {
    name: 'State Observation',
    description: 'Ability to observe agent internal state',
    check: () => ({
      score: 1,
      evidence: 'No state observation mechanism present'
    })
  },
  O2: {
    name: 'Action Observation',
    description: 'Ability to observe agent actions',
    check: () => ({
      score: 2,
      evidence: 'File system changes can be observed'
    })
  },
  O3: {
    name: 'Result Observation',
    description: 'Ability to observe task results',
    check: () => ({
      score: 2,
      evidence: 'Output directory enables result observation'
    })
  },
  O4: {
    name: 'Trace Observation',
    description: 'Ability to trace execution path',
    check: () => ({
      score: 1,
      evidence: 'No trace mechanism available'
    })
  },
  V1: {
    name: 'Visibility Level 1',
    description: 'Basic logging capability',
    check: () => ({
      score: 2,
      evidence: 'Markdown documentation serves as basic logs'
    })
  },
  V2: {
    name: 'Visibility Level 2',
    description: 'Structured logging with context',
    check: () => ({
      score: 1,
      evidence: 'No structured logging implemented'
    })
  },
  V3: {
    name: 'Visibility Level 3',
    description: 'Full observability with metrics',
    check: () => ({
      score: 1,
      evidence: 'No metrics or dashboards available'
    })
  }
};

module.exports = { OBSERVABILITY_RULES };
