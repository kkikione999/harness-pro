# Open-ClaudeCode - Root Makefile (agent harness entrypoint)
# Delegates to .harness/controllability/Makefile for all operations.
# This file exists so that agents can discover the harness from the project root.

HARNESS_DIR := .harness/controllability

.PHONY: help lint lint-v lint-p0 lint-rule check verify test-auto status logs health trace clean all

# Full orchestration: lint then verify then health (chained multi-step)
all:
	@$(MAKE) -C $(HARNESS_DIR) lint && $(MAKE) -C $(HARNESS_DIR) verify && $(MAKE) -C $(HARNESS_DIR) health

# Pass through to harness Makefile
help lint lint-v lint-p0 lint-rule check verify test-auto status logs health trace clean:
	$(MAKE) -C $(HARNESS_DIR) $@
