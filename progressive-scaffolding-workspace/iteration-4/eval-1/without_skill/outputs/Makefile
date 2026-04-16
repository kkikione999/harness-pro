# Open-ClaudeCode - Root Makefile (agent harness entrypoint)
# Delegates to .harness/controllability/Makefile for all operations.
# This file exists so that agents can discover the harness from the project root.

HARNESS_DIR := .harness/controllability

.PHONY: help lint lint-v lint-p0 lint-rule check verify test-auto status logs health trace clean

# Pass through to harness Makefile
help lint lint-v lint-p0 lint-rule check verify test-auto status logs health trace clean:
	$(MAKE) -C $(HARNESS_DIR) $@
