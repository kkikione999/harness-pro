# Generated Makefile for Open-ClaudeCode
# This Makefile provides standard commands for Controllability

.PHONY: help run stop test verify test-auto clean logs lint

# Default target
help:
	@echo "Open-ClaudeCode - Available commands:"
	@echo "  make run       - Start the CLI"
	@echo "  make stop      - Stop the CLI"
	@echo "  make verify    - Verify CLI is functional"
	@echo "  make test-auto - Automated verification with structured output"
	@echo "  make logs      - Show recent logs"
	@echo "  make lint      - Lint source files"
	@echo "  make clean     - Clean generated files"

# Run / Start the CLI
run:
	@echo "Starting Open-ClaudeCode..."
	@cd .. && ./controllability/start.sh

# Stop the CLI
stop:
	@echo "Stopping Open-ClaudeCode..."
	@./stop.sh

# Run tests (no test framework detected)
test:
	@echo "Running tests..."
	@$(error No test framework detected. Open-ClaudeCode has no built-in test infrastructure.)

# Verify CLI health
verify:
	@./verify.sh
	@EXIT_CODE=$$?
	@if [ $$EXIT_CODE -eq 0 ]; then \
		echo "CLI verification passed"; \
	else \
		echo "CLI verification failed (exit code: $$EXIT_CODE)"; \
	fi
	@exit $$EXIT_CODE

# Automated test with structured output
test-auto:
	@echo "Running automated verification..."
	@./test-auto.sh
	@EXIT_CODE=$$?
	@if [ $$EXIT_CODE -eq 0 ]; then \
		echo "VERIFICATION: PASS"; \
	else \
		echo "VERIFICATION: FAIL"; \
		./log.sh recent 20; \
	fi
	@exit $$EXIT_CODE

# Show recent logs
logs:
	@./log.sh recent 50

# Lint source files
lint:
	@./lint-check.sh 2>/dev/null || echo "Lint: No linter configured"

# Clean up generated files
clean:
	@echo "Cleaning..."
	@rm -f ../.harness/observability/logs/*.log
	@rm -f ../.harness/Open-ClaudeCode.pid
	@rm -f ../.harness/test-result.json
	@echo "Cleaned .harness generated files"
