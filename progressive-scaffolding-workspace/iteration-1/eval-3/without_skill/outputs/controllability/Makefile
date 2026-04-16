.PHONY: help verify-docs generate-docs test check setup clean

help:
	@echo "Controllability Commands for harness-blogs"
	@echo "========================================="
	@echo "  verify-docs    - Verify all documentation is present"
	@echo "  generate-docs  - Generate documentation outputs"
	@echo "  test           - Run project tests"
	@echo "  check          - Run all verification checks"
	@echo "  setup          - Setup project environment"
	@echo "  clean          - Clean generated artifacts"

verify-docs:
	@./scripts/verify-docs.sh

generate-docs:
	@./scripts/generate-docs.sh

test:
	@./scripts/test.sh

check:
	@./scripts/check.sh

setup:
	@./scripts/setup.sh

clean:
	@./scripts/clean.sh