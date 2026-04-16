# Generated Makefile for {{project-name}}
# This Makefile provides standard commands for Controllability

.PHONY: help run stop test verify test-auto clean logs

# Default target
help:
	@echo "{{project-name}} - Available commands:"
	@echo "  make run       - Start the service"
	@echo "  make stop      - Stop the service"
	@echo "  make test      - Run tests"
	@echo "  make verify    - Verify service health"
	@echo "  make test-auto - Automated test with result parsing"
	@echo "  make logs      - Show recent logs"

# Run / Start the service
run:
	@echo "Starting {{project-name}}..."
	@cd .. && ./controllability/start.sh

# Stop the service
stop:
	@echo "Stopping {{project-name}}..."
	@./stop.sh

# Run tests
test:
	@echo "Running tests..."
	@{{test-command}}

# Verify service health
verify:
	@./verify.sh
	@EXIT_CODE=$$?
	@if [ $$EXIT_CODE -eq 0 ]; then \
		echo "✓ Service is healthy"; \
	else \
		echo "✗ Service is unhealthy (exit code: $$EXIT_CODE)"; \
	fi
	@exit $$EXIT_CODE

# Automated test with structured output
test-auto:
	@echo "Running automated tests..."
	@./test-auto.sh
	@EXIT_CODE=$$?
	@if [ $$EXIT_CODE -eq 0 ]; then \
		echo "✓ All tests passed"; \
	else \
		echo "✗ Tests failed (exit code: $$EXIT_CODE)"; \
		./log.sh recent 20
	fi
	@exit $$EXIT_CODE

# Show recent logs
logs:
	@./log.sh recent 50

# Clean up
clean:
	@echo "Cleaning..."
	@{{clean-command}}
