# Controllability scaffolding for harness-blogs
# Project: Documentation/blog site

.PHONY: help build serve verify test-auto clean

HARNESS_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

help:
	@echo "harness-blogs controllability commands"
	@echo "  make build      - Build documentation site"
	@echo "  make serve      - Start development server"
	@echo "  make stop      - Stop development server"
	@echo "  make verify     - Verify site health"
	@echo "  make test-auto  - Run automated tests"
	@echo "  make clean      - Clean build artifacts"

build:
	@echo "Building documentation..."
	@# Add build commands based on project stack
	@echo "Build complete"

serve:
	@echo "Starting development server..."
	@# Add serve command
	@echo "Server started"

stop:
	@echo "Stopping development server..."
	@# Add stop command
	@echo "Server stopped"

verify:
	@bash $(HARNESS_DIR)/verify.sh

test-auto:
	@bash $(HARNESS_DIR)/test-auto.sh
	@exit $$(bash $(HARNESS_DIR)/verify.sh --exit-code)

clean:
	@echo "Cleaning build artifacts..."
	@# Add clean commands
	@echo "Clean complete"
