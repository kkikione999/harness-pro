#!/bin/bash
# Documentation verification script for harness-blogs

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../../.." && pwd)"

echo "=== harness-blogs Documentation Verification ==="
echo ""

exit_code=0

# Required markdown files
required_docs=(
    "01_anthropic_harness-design-long-running-apps.md"
    "02_anthropic_effective-harnesses-for-long-running-agents.md"
    "03_langchain_anatomy-of-agent-harness.md"
    "04_langchain_improving-deep-agents-harness-engineering.md"
    "05_martinfowler_harness-engineering.md"
    "06_langchain_middleware-agent-harness.md"
    "07_langchain_frameworks-runtimes-harnesses.md"
    "08_anthropic_demystifying-evals-for-ai-agents.md"
    "09_openai_harness-engineering-codex-agent-first.md"
    "10_openai_unlocking-codex-harness-app-server.md"
    "11_openai_unrolling-codex-agent-loop.md"
    "12_openai_run-long-horizon-tasks-with-codex.md"
    "13_openai_equipping-responses-api-computer-environment.md"
    "14_openai_inside-in-house-data-agent.md"
    "HARNESS-ENGINEERING-IMPLEMENTATION-GUIDE.md"
    "investigation-report-harness-philosophy.md"
    "PROGRESSIVE-RULES-DESIGN.md"
)

echo "--- Verifying Required Documentation ---"
missing=0
for doc in "${required_docs[@]}"; do
    if [ -f "$PROJECT_ROOT/$doc" ]; then
        echo "  OK: $doc"
    else
        echo "  MISSING: $doc"
        missing=$((missing + 1))
        exit_code=1
    fi
done

echo ""
echo "--- Verifying Directory Structure ---"
required_dirs=(
    ".claude"
    ".harness"
    "progressive-rules-workspace"
    "progressive-scaffolding-workspace"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        echo "  OK: $dir/"
    else
        echo "  MISSING: $dir/"
        missing=$((missing + 1))
        exit_code=1
    fi
done

echo ""
echo "--- Verification Summary ---"
echo "Missing items: $missing"
if [ "$missing" -eq 0 ]; then
    echo "Status: PASS - All documentation verified"
else
    echo "Status: FAIL - $missing item(s) missing"
fi

echo ""
echo "=== Documentation Verification Complete ==="

exit $exit_code