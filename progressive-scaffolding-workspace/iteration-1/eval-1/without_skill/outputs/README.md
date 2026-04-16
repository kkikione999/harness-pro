# Progressive Scaffolding Assessment

Assessment framework for evaluating controllability and observability levels in agent scaffolding projects.

## Dimensions

### Controllability (E1-E4)
- **E1**: Execution Control - agent start/stop/pause capabilities
- **E2**: Environment Control - sandbox, resources, permissions
- **E3**: Input Control - prompt templates, context management
- **E4**: Output Control - response validation, formatting constraints

### Observability (O1-O4, V1-V3)
- **O1**: State Observation - memory, context, decision tracking
- **O2**: Action Observation - tool calls, API requests, file operations
- **O3**: Result Observation - output validation, quality metrics
- **O4**: Trace Observation - full execution history, replay capability
- **V1**: Visibility Level 1 - basic logging
- **V2**: Visibility Level 2 - structured logging with context
- **V3**: Visibility Level 3 - metrics, dashboards, alerting

## Level Scale
1. **None/Minimal** - No mechanism present
2. **Basic** - Simple mechanism exists but limited
3. **Moderate** - Functional mechanism with some gaps
4. **Full** - Comprehensive mechanism fully implemented

## Usage

```javascript
const { ScaffoldingAssessment } = require('./index');
const { AssessmentReporter } = require('./reporters/assessment');

const assessment = new ScaffoldingAssessment('/path/to/project');
const results = assessment.assess();

const reporter = new AssessmentReporter(results);
console.log(reporter.generateMarkdown());
```

## Structure
- `configs/` - Assessment configuration
- `rules/` - Controllability and observability rules
- `validators/` - Validation engine
- `reporters/` - Report generation
- `tests/` - Test suite
