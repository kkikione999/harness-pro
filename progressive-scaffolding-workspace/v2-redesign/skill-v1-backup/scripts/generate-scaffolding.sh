#!/bin/bash
# generate-scaffolding.sh — Generate scaffolding based on project type and gaps
# Usage: ./generate-scaffolding.sh /path/to/project [--type backend|cli|mobile|embedded|desktop]
# Auto-detects project type if not specified

PROJECT_ROOT="${1:-.}"
PROJECT_TYPE=""

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            PROJECT_TYPE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates"
OUTPUT_DIR="$PROJECT_ROOT/.harness"

# Auto-detect project type if not provided
if [ -z "$PROJECT_TYPE" ]; then
    PROJECT_TYPE=$("$SCRIPT_DIR/detect-project-type.sh" "$PROJECT_ROOT" 2>/dev/null | grep "^Type:" | awk '{print $2}')
fi

# Fallback
if [ -z "$PROJECT_TYPE" ]; then
    PROJECT_TYPE="backend"
fi

# Check if content repository (not a software project)
MARKDOWN_COUNT=$(find "$PROJECT_ROOT" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
CODE_FILES=$(find "$PROJECT_ROOT" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" -o -name "*.py" -o -name "*.java" \) 2>/dev/null | wc -l | tr -d ' ')

if [ "$MARKDOWN_COUNT" -gt 10 ] && [ "$CODE_FILES" -lt 5 ]; then
    echo "ERROR: This appears to be a content repository ($MARKDOWN_COUNT .md files, $CODE_FILES code files)."
    echo "This is a CONTENT REPOSITORY, not a software project."
    echo ""
    echo "progressive-scaffolding is for SOFTWARE PROJECTS with build systems."
    echo "For content repositories, use progressive-docs instead."
    echo ""
    echo "To proceed anyway (not recommended), run with --force:"
    echo "  $0 $PROJECT_ROOT --type backend --force"
    exit 1
fi

echo "Generating scaffolding for: $PROJECT_ROOT"
echo "Project type: $PROJECT_TYPE"
echo ""

# Detect project name from directory
PROJECT_NAME=$(basename "$PROJECT_ROOT" | tr '-' '_' | tr '.' '_')

# Detect test command
TEST_COMMAND=""
if [ -f "$PROJECT_ROOT/package.json" ]; then
    TEST_COMMAND="npm test"
elif [ -f "$PROJECT_ROOT/go.mod" ]; then
    TEST_COMMAND="go test ./..."
elif [ -f "$PROJECT_ROOT/Makefile" ] && grep -q "test" "$PROJECT_ROOT/Makefile"; then
    TEST_COMMAND="make test"
elif [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
    TEST_COMMAND="cargo test"
fi

# Detect clean command
CLEAN_COMMAND=""
if [ -f "$PROJECT_ROOT/package.json" ]; then
    CLEAN_COMMAND="rm -rf node_modules"
elif [ -f "$PROJECT_ROOT/Makefile" ] && grep -q "clean" "$PROJECT_ROOT/Makefile"; then
    CLEAN_COMMAND="make clean"
fi

# Create output directories
mkdir -p "$OUTPUT_DIR/controllability"
mkdir -p "$OUTPUT_DIR/observability"

# Load templates based on project type
case $PROJECT_TYPE in
    backend)
        TEMPLATE_PATH="$TEMPLATE_DIR/backend"
        ;;
    cli)
        TEMPLATE_PATH="$TEMPLATE_DIR/cli"
        ;;
    mobile)
        TEMPLATE_PATH="$TEMPLATE_DIR/mobile"
        ;;
    embedded)
        TEMPLATE_PATH="$TEMPLATE_DIR/embedded"
        ;;
    desktop)
        TEMPLATE_PATH="$TEMPLATE_DIR/desktop"
        ;;
    *)
        TEMPLATE_PATH="$TEMPLATE_DIR/backend"
        ;;
esac

# Function to fill mustache templates
fill_template() {
    local src="$1"
    local dst="$2"

    if [ ! -f "$src" ]; then
        return
    fi

    sed -e "s/{{project-name}}/$PROJECT_NAME/g" \
        -e "s/{{test-command}}/$TEST_COMMAND/g" \
        -e "s/{{clean-command}}/$CLEAN_COMMAND/g" \
        -e "s|{{project-root}}|$PROJECT_ROOT|g" \
        "$src" > "$dst"
}

# Generate controllability scaffolding
echo "Generating controllability scaffolding..."

# Makefile
if [ -f "$TEMPLATE_PATH/controllability/Makefile.mustache" ]; then
    fill_template "$TEMPLATE_PATH/controllability/Makefile.mustache" "$OUTPUT_DIR/controllability/Makefile"
    echo "  - Created Makefile"
fi

# Start script
if [ -f "$TEMPLATE_PATH/controllability/start.sh.mustache" ]; then
    fill_template "$TEMPLATE_PATH/controllability/start.sh.mustache" "$OUTPUT_DIR/controllability/start.sh"
    chmod +x "$OUTPUT_DIR/controllability/start.sh"
    echo "  - Created start.sh"
fi

# Stop script
if [ -f "$TEMPLATE_PATH/controllability/stop.sh.mustache" ]; then
    fill_template "$TEMPLATE_PATH/controllability/stop.sh.mustache" "$OUTPUT_DIR/controllability/stop.sh"
    chmod +x "$OUTPUT_DIR/controllability/stop.sh"
    echo "  - Created stop.sh"
fi

# Verify script
if [ -f "$TEMPLATE_PATH/controllability/verify.sh.mustache" ]; then
    fill_template "$TEMPLATE_PATH/controllability/verify.sh.mustache" "$OUTPUT_DIR/controllability/verify.sh"
    chmod +x "$OUTPUT_DIR/controllability/verify.sh"
    echo "  - Created verify.sh"
fi

# Test-auto script
if [ -f "$TEMPLATE_PATH/controllability/test-auto.sh.mustache" ]; then
    fill_template "$TEMPLATE_PATH/controllability/test-auto.sh.mustache" "$OUTPUT_DIR/controllability/test-auto.sh"
    chmod +x "$OUTPUT_DIR/controllability/test-auto.sh"
    echo "  - Created test-auto.sh"
fi

# Import direction lint (if template exists)
if [ -f "$TEMPLATE_PATH/controllability/lint-import-direction.sh.mustache" ]; then
    fill_template "$TEMPLATE_PATH/controllability/lint-import-direction.sh.mustache" "$OUTPUT_DIR/controllability/lint-import-direction.sh"
    chmod +x "$OUTPUT_DIR/controllability/lint-import-direction.sh"
    echo "  - Created lint-import-direction.sh"
fi

# Dependency analysis (if template exists)
if [ -f "$TEMPLATE_PATH/controllability/analyze-deps.sh.mustache" ]; then
    fill_template "$TEMPLATE_PATH/controllability/analyze-deps.sh.mustache" "$OUTPUT_DIR/controllability/analyze-deps.sh"
    chmod +x "$OUTPUT_DIR/controllability/analyze-deps.sh"
    echo "  - Created analyze-deps.sh"
fi

# CI pipeline (top-level template, not project-type-specific)
if [ -f "$TEMPLATE_DIR/ci-pipeline.yml.mustache" ]; then
    mkdir -p "$OUTPUT_DIR/ci"
    fill_template "$TEMPLATE_DIR/ci-pipeline.yml.mustache" "$OUTPUT_DIR/ci/ci-pipeline.yml"
    echo "  - Created ci/ci-pipeline.yml"
    echo "    (Copy to .github/workflows/ci.yml to enable)"
fi

# Generate observability scaffolding
echo ""
echo "Generating observability scaffolding..."

# Log script
if [ -f "$TEMPLATE_PATH/observability/log.sh.mustache" ]; then
    fill_template "$TEMPLATE_PATH/observability/log.sh.mustache" "$OUTPUT_DIR/observability/log.sh"
    chmod +x "$OUTPUT_DIR/observability/log.sh"
    echo "  - Created log.sh"
fi

# Metrics script
if [ -f "$TEMPLATE_PATH/observability/metrics.sh.mustache" ]; then
    fill_template "$TEMPLATE_PATH/observability/metrics.sh.mustache" "$OUTPUT_DIR/observability/metrics.sh"
    chmod +x "$OUTPUT_DIR/observability/metrics.sh"
    echo "  - Created metrics.sh"
fi

# Health script
if [ -f "$TEMPLATE_PATH/observability/health.sh.mustache" ]; then
    fill_template "$TEMPLATE_PATH/observability/health.sh.mustache" "$OUTPUT_DIR/observability/health.sh"
    chmod +x "$OUTPUT_DIR/observability/health.sh"
    echo "  - Created health.sh"
fi

# Trace script
if [ -f "$TEMPLATE_PATH/observability/trace.sh.mustache" ]; then
    fill_template "$TEMPLATE_PATH/observability/trace.sh.mustache" "$OUTPUT_DIR/observability/trace.sh"
    chmod +x "$OUTPUT_DIR/observability/trace.sh"
    echo "  - Created trace.sh"
fi

echo ""
echo "Scaffolding generation complete!"
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Detected configuration:"
echo "  Project name: $PROJECT_NAME"
echo "  Test command: ${TEST_COMMAND:-none}"
echo "  Clean command: ${CLEAN_COMMAND:-none}"
echo ""
echo "To use:"
echo "  cd $OUTPUT_DIR/controllability && make verify"
echo "  cd $OUTPUT_DIR/controllability && make test-auto"
echo "  cd $OUTPUT_DIR/observability && ./log.sh recent"
