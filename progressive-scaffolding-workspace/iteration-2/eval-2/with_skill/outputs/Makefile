# Progressive Scaffolding Skill Makefile
# Brings the skill to Level 2 controllability

.SILENT: assess generate verify test

# Default target
all: assess

# Run full assessment (E1-E4, O1-O4, V1-V3)
assess:
	@echo "=== Running Assessment Probes ==="
	@bash scripts/detect-project-type.sh .
	@bash scripts/detect-controllability.sh .
	@bash scripts/detect-observability.sh .
	@bash scripts/detect-verification.sh .

# Generate scaffolding for a target project
# Usage: make generate PROJECT=/path/to/project
generate:
ifndef PROJECT
	@echo "Error: PROJECT not defined. Usage: make generate PROJECT=/path/to/project"
	@exit 1
endif
	@echo "=== Generating Scaffolding ==="
	@bash scripts/generate-scaffolding.sh $(PROJECT)

# Verify scaffolding exists and is functional
verify:
	@echo "=== Verifying Scaffolding ==="
	@bash scripts/run-probes.sh .harness

# Run skill tests
test:
	@echo "=== Running Tests ==="
	@find . -name "*_test.sh" -exec bash {} \; || echo "No tests found"

# Run all probes and output JSON
assess-json:
	@echo '{"controllability":' > assessment-results.json
	@bash scripts/detect-controllability.sh . | grep "^Controllability Score:" | awk '{print "\""$$2" "$$3"\""}' >> assessment-results.json
	@echo ',"observability":' >> assessment-results.json
	@bash scripts/detect-observability.sh . | grep "^Observability Score:" | awk '{print "\""$$2" "$$3"\""}' >> assessment-results.json
	@echo ',"verification":' >> assessment-results.json
	@bash scripts/detect-verification.sh . | grep "^Verification Score:" | awk '{print "\""$$2" "$$3"\""}' >> assessment-results.json
	@echo '}' >> assessment-results.json

# Self-check: verify this skill meets Level 2
check-usable: assess
	@echo ""
	@echo "=== Usability Check ==="
	@CONTROLLABILITY=$$(bash scripts/detect-controllability.sh . | grep "^Controllability Score:" | awk '{print $$3}' | cut -d'/' -f1); \
	OBSERVABILITY=$$(bash scripts/detect-observability.sh . | grep "^Observability Score:" | awk '{print $$3}' | cut -d'/' -f1); \
	VERIFICATION=$$(bash scripts/detect-verification.sh . | grep "^Verification Score:" | awk '{print $$3}' | cut -d'/' -f1); \
	echo "Controllability: $$CONTROLLABILITY/12 (need 8+)"; \
	echo "Observability: $$OBSERVABILITY/12 (need 8+)"; \
	echo "Verification: $$VERIFICATION/9 (need 6+)"; \
	if [ $$CONTROLLABILITY -ge 8 ] && [ $$OBSERVABILITY -ge 8 ] && [ $$VERIFICATION -ge 6 ]; then \
		echo "Status: USABLE"; exit 0; \
	else \
		echo "Status: NOT YET USABLE"; exit 1; \
	fi

# Show help
help:
	@echo "Progressive Scaffolding Skill Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make assess       - Run all assessment probes"
	@echo "  make generate      - Generate scaffolding (requires PROJECT=...)"
	@echo "  make verify        - Verify .harness scaffolding"
	@echo "  make test          - Run tests"
	@echo "  make check-usable  - Check if skill meets Level 2"
	@echo "  make help          - Show this help"