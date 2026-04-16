.PHONY: help status metrics health-docs health-markdown check-links lint-docs

help:
	@echo "Observability Commands for harness-blogs"
	@echo "======================================="
	@echo "  status         - Show project status and file counts"
	@echo "  metrics        - Collect code metrics"
	@echo "  health-docs    - Check documentation health"
	@echo "  health-markdown - Check markdown file health"
	@echo "  check-links    - Check for broken links in docs"
	@echo "  lint-docs      - Lint documentation files"
	@echo "  all            - Run all observability checks"

status:
	@./scripts/status.sh

metrics:
	@./scripts/metrics.sh

health-docs:
	@./scripts/health-docs.sh

health-markdown:
	@./scripts/health-markdown.sh

check-links:
	@./scripts/check-links.sh

lint-docs:
	@./scripts/lint-docs.sh

all: status metrics health-markdown check-links lint-docs