"""Shared fixtures for utell-ios test suite."""

import pytest
from pathlib import Path


@pytest.fixture
def tmp_products_dir(tmp_path: Path) -> Path:
    """Create a temporary build products directory."""
    return tmp_path / "Debug-iphonesimulator"
