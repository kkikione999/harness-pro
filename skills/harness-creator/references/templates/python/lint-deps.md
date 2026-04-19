# Python Templates

## Python lint-deps.py Template

```python
#!/usr/bin/env python3
"""Lint Python layer dependencies."""

import ast
import sys
from pathlib import Path
from collections import defaultdict

# Layer mapping
LAYERS = {
    "types": 0,
    "utils": 1,
    "config": 2,
    "services": 3,
    "handlers": 4,
}

EXTERNAL_PACKAGES = {
    "os", "sys", "json", "datetime", "typing",
    "django", "flask", "fastapi", "sqlalchemy",
    "requests", "numpy", "pandas",
}

ROOT = Path(__file__).parent.parent
SRC = ROOT / "src"


def get_layer(module_name: str) -> int:
    """Get layer for a module."""
    if module_name in LAYERS:
        return LAYERS[module_name]
    return 4  # Default to highest layer


def extract_imports(file: Path) -> list[str]:
    """Extract import statements from Python file."""
    imports = []
    try:
        with open(file) as f:
            tree = ast.parse(f.read())
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    imports.append(alias.name.split(".")[0])
            elif isinstance(node, ast.ImportFrom):
                if node.module:
                    imports.append(node.module.split(".")[0])
    except Exception as e:
        print(f"Error parsing {file}: {e}", file=sys.stderr)
    return imports


def check_violations():
    """Check for layer violations."""
    violations = 0

    for file in SRC.rglob("*.py"):
        rel_path = file.relative_to(SRC)
        module_parts = rel_path.parts
        if len(module_parts) > 1:
            module_name = module_parts[0]
        else:
            module_name = file.stem

        file_layer = get_layer(module_name)
        imports = extract_imports(file)

        for imp in imports:
            if imp in EXTERNAL_PACKAGES:
                continue
            if imp not in LAYERS:
                continue

            imp_layer = get_layer(imp)
            if file_layer < imp_layer:
                print(f"VIOLATION: {file} (Layer {file_layer}) imports {imp} (Layer {imp_layer})")
                print(f"  Lower layer cannot import higher layer.")
                violations += 1

    return violations


def main():
    print("Checking Python layer dependencies...")
    violations = check_violations()
    print()
    if violations == 0:
        print("✓ No layer violations found")
        sys.exit(0)
    else:
        print(f"✗ Found {violations} violation(s)")
        sys.exit(1)


if __name__ == "__main__":
    main()
```

## Python lint-quality.py Template

```python
#!/usr/bin/env python3
"""Lint Python code quality."""

import ast
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
SRC = ROOT / "src"
MAX_LINES = 500


def check_file_length(file: Path) -> list[str]:
    """Check file doesn't exceed max lines."""
    violations = []
    with open(file) as f:
        lines = len(f.readlines())
    if lines > MAX_LINES:
        violations.append(f"{file} has {lines} lines (max {MAX_LINES})")
    return violations


def check_print_statements(file: Path) -> list[str]:
    """Check for print statements (use logging instead)."""
    violations = []
    if "test" in str(file):
        return violations  # Allow in tests
    with open(file) as f:
        content = f.read()
    if "print(" in content:
        violations.append(f"{file} contains print() - use logging instead")
    return violations


def main():
    violations = []

    for file in SRC.rglob("*.py"):
        violations.extend(check_file_length(file))
        violations.extend(check_print_statements(file))

    if violations:
        print("Quality violations:")
        for v in violations:
            print(f"  VIOLATION: {v}")
        sys.exit(1)
    else:
        print("✓ No quality violations found")
        sys.exit(0)


if __name__ == "__main__":
    main()
```

## Python validate.py Template

```python
#!/usr/bin/env python3
"""Validate Python project consistency."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent


def run(name, cmd):
    print(f"\n[{name}]")
    result = subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    return result.returncode == 0


def main():
    print("Python Project Validation")
    print("=" * 60)

    steps = [
        ("Build", ["python", "-m", "py_compile", "src"]),
        ("Lint Architecture", ["python3", "scripts/lint-deps.py"]),
        ("Lint Quality", ["python3", "scripts/lint-quality.py"]),
        ("Test", ["python", "-m", "pytest"]),
    ]

    passed = sum(1 for name, cmd in steps if run(name, cmd))
    print(f"\nPassed: {passed}/{len(steps)}")
    sys.exit(0 if passed == len(steps) else 1)


if __name__ == "__main__":
    main()
```
