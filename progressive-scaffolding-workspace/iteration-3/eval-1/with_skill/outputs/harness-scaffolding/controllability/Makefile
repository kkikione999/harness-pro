# Generated Makefile for Open-ClaudeCode
# Progressive Scaffolding — Controllability layer
# This Makefile wraps the existing Golden Principle lint infrastructure.

.PHONY: help lint check verify test-auto clean logs health trace status

HARNESS_DIR := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)
PROJECT_ROOT := $(shell cd "$(HARNESS_DIR)/../.." && pwd)
CHECK_SCRIPT := $(PROJECT_ROOT)/rules/scripts/check.py
LOG_DIR      := $(PROJECT_ROOT)/.harness/observability/logs

# Default target
help:
	@echo "Open-ClaudeCode - Agent Harness Commands:"
	@echo ""
	@echo "  make lint       - Run Golden Principle linters (GP-001..GP-008)"
	@echo "  make lint-v     - Run linters with verbose output"
	@echo "  make lint-p0    - Run only P0 (critical) rules"
	@echo "  make lint-rule  - Run a specific rule (usage: make lint-rule RULE=GP-001)"
	@echo "  make check      - Alias for lint (full check)"
	@echo "  make verify     - Verify project structure + lint pass"
	@echo "  make test-auto  - Automated lint + result parsing + log capture"
	@echo "  make status     - Show project status (file counts, recent results)"
	@echo "  make logs       - Show recent lint logs"
	@echo "  make health     - Output JSON health status"
	@echo "  make trace      - Run a command with correlation ID (usage: make trace CMD='...')"
	@echo "  make clean      - Clean generated logs and temp files"

# Run all Golden Principle linters
lint:
	@echo "Running Golden Principle checks..."
	@python3 "$(CHECK_SCRIPT)" 2>&1

# Verbose lint
lint-v:
	@echo "Running Golden Principle checks (verbose)..."
	@python3 "$(CHECK_SCRIPT)" --verbose 2>&1

# P0-only critical checks
lint-p0:
	@echo "Running P0 (critical) checks..."
	@python3 "$(CHECK_SCRIPT)" --priority P0 2>&1

# Single rule
lint-rule:
	@echo "Running rule $(RULE)..."
	@python3 "$(CHECK_SCRIPT)" --rule "$(RULE)" --verbose 2>&1

# Full check alias
check: lint

# Verify project structure + lint pass
verify:
	@echo "=== Project Verification ==="
	@echo ""
	@echo "Checking project structure..."
	@test -d "$(PROJECT_ROOT)/src" && echo "  [OK] src/ exists" || (echo "  [FAIL] src/ missing" && exit 1)
	@test -d "$(PROJECT_ROOT)/rules/scripts" && echo "  [OK] rules/scripts/ exists" || (echo "  [FAIL] rules/scripts/ missing" && exit 1)
	@test -f "$(CHECK_SCRIPT)" && echo "  [OK] check.py exists" || (echo "  [FAIL] check.py missing" && exit 1)
	@test -f "$(PROJECT_ROOT)/package/package.json" && echo "  [OK] package.json exists" || (echo "  [FAIL] package.json missing" && exit 1)
	@echo ""
	@echo "Running lint checks..."
	@python3 "$(CHECK_SCRIPT)" 2>&1
	@EXIT_CODE=$$?; \
	if [ $$EXIT_CODE -eq 0 ]; then \
		echo ""; \
		echo "VERIFICATION PASSED: All checks passed"; \
	else \
		echo ""; \
		echo "VERIFICATION FAILED: Some checks failed (exit code: $$EXIT_CODE)"; \
	fi
	@exit $$?

# Automated test with structured output and log capture
test-auto:
	@echo "=== Automated Test Run ==="
	@echo "Timestamp: $$(date -Iseconds)"
	@echo "Correlation ID: $${CORRELATION_ID:-auto-$$(date +%s)}"
	@mkdir -p "$(LOG_DIR)"
	@python3 "$(CHECK_SCRIPT)" 2>&1 | tee "$(LOG_DIR)/test-auto-$$(date +%Y%m%d-%H%M%S).log"; \
	EXIT_CODE=$${PIPESTATUS[0]}; \
	echo ""; \
	if [ $$EXIT_CODE -eq 0 ]; then \
		echo '{"status":"pass","framework":"gp-lint","timestamp":"'$$(date -Iseconds)'"}'; \
		echo "RESULT: All Golden Principle checks passed"; \
	else \
		echo '{"status":"fail","framework":"gp-lint","timestamp":"'$$(date -Iseconds)'"}'; \
		echo "RESULT: Some checks failed (exit code: $$EXIT_CODE)"; \
	fi; \
	exit $$EXIT_CODE

# Show project status
status:
	@echo "=== Open-ClaudeCode Project Status ==="
	@echo "Source files (TS/TSX): $$(find $(PROJECT_ROOT)/src -name '*.ts' -o -name '*.tsx' 2>/dev/null | wc -l | tr -d ' ')"
	@echo "Tool files:            $$(find $(PROJECT_ROOT)/src/tools -name '*.ts' -o -name '*.tsx' 2>/dev/null | wc -l | tr -d ' ')"
	@echo "Command files:         $$(find $(PROJECT_ROOT)/src/commands -name '*.ts' -o -name '*.tsx' 2>/dev/null | wc -l | tr -d ' ')"
	@echo "Hook files:            $$(find $(PROJECT_ROOT)/src/hooks -name '*.ts' -o -name '*.tsx' 2>/dev/null | wc -l | tr -d ' ')"
	@echo "Component files:       $$(find $(PROJECT_ROOT)/src/components -name '*.ts' -o -name '*.tsx' 2>/dev/null | wc -l | tr -d ' ')"
	@echo "Lint scripts:          $$(ls $(PROJECT_ROOT)/rules/scripts/lint-*.sh 2>/dev/null | wc -l | tr -d ' ')"
	@echo "Recent test log:       $$(ls -t $(LOG_DIR)/test-auto-*.log 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo 'none')"
	@echo "Last lint result:      $$(tail -1 $$(ls -t $(LOG_DIR)/test-auto-*.log 2>/dev/null | head -1) 2>/dev/null || echo 'no results yet')"

# Show recent logs
logs:
	@"$(PROJECT_ROOT)/.harness/observability/log.sh" recent 50

# Health check (JSON output)
health:
	@"$(PROJECT_ROOT)/.harness/observability/health.sh"

# Run a command with correlation tracing
trace:
	@"$(PROJECT_ROOT)/.harness/observability/trace.sh" $(CMD)

# Clean generated artifacts
clean:
	@echo "Cleaning harness logs and temp files..."
	@rm -f "$(LOG_DIR)"/*.log
	@rm -f /tmp/test-output.txt
	@rm -f "$(PROJECT_ROOT)/.harness/Open_ClaudeCode.pid"
	@echo "Done"
