"""Tests for thunk_compiler: framework search path discovery and -F flag injection.

Covers BDD Expected Results:
  ER1: Compilation includes -F flag pointing to framework parent dir
  ER4: -F flag harmless when no frameworks present (backward compatibility)
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock, patch

from utell_ios.thunk_compiler import compile_thunk, discover_framework_search_paths


class TestDiscoverFrameworkSearchPaths:
    """Tests for discover_framework_search_paths."""

    def test_discover_framework_search_paths_finds_frameworks(
        self, tmp_products_dir: Path
    ) -> None:
        """ER1: Returns parent dir when a .framework is present."""
        tmp_products_dir.mkdir(parents=True, exist_ok=True)
        (tmp_products_dir / "HpSleeperKit.framework").mkdir()

        result = discover_framework_search_paths(str(tmp_products_dir))

        assert result == [str(tmp_products_dir)]

    def test_discover_framework_search_paths_empty_dir(
        self, tmp_products_dir: Path
    ) -> None:
        """ER4: Returns empty list when no .framework directories exist."""
        tmp_products_dir.mkdir(parents=True, exist_ok=True)

        result = discover_framework_search_paths(str(tmp_products_dir))

        assert result == []

    def test_discover_framework_search_paths_multiple_frameworks(
        self, tmp_products_dir: Path
    ) -> None:
        """ER1: Deduplicates parent dirs when multiple frameworks share the same parent."""
        tmp_products_dir.mkdir(parents=True, exist_ok=True)
        (tmp_products_dir / "Foo.framework").mkdir()
        (tmp_products_dir / "Bar.framework").mkdir()

        result = discover_framework_search_paths(str(tmp_products_dir))

        # Both frameworks share the same parent, so result is a single entry
        assert result == [str(tmp_products_dir)]


class TestCompileThunkFrameworkFlags:
    """Tests for compile_thunk -F flag behaviour."""

    @patch("utell_ios.thunk_compiler.subprocess.run")
    @patch("utell_ios.thunk_compiler._get_simulator_sdk_path", return_value="/fake/sdk")
    @patch("utell_ios.thunk_compiler.get_simulator_os_version", return_value="18.0")
    def test_compile_thunk_includes_f_flag_for_frameworks(
        self,
        mock_sdk_version: MagicMock,
        mock_sdk_path: MagicMock,
        mock_run: MagicMock,
        tmp_products_dir: Path,
    ) -> None:
        """ER1: swiftc command includes -F <dir> when a .framework is present."""
        tmp_products_dir.mkdir(parents=True, exist_ok=True)
        (tmp_products_dir / "HpSleeperKit.framework").mkdir()

        # Mock both swiftc and codesign subprocess.run calls
        swiftc_result = MagicMock()
        swiftc_result.returncode = 0
        swiftc_result.stderr = ""

        codesign_result = MagicMock()
        codesign_result.returncode = 0
        codesign_result.stderr = ""

        mock_run.side_effect = [swiftc_result, codesign_result]

        result = compile_thunk(
            thunk_source_path="fake.swift",
            output_dylib_path="out.dylib",
            build_products_dir=str(tmp_products_dir),
            product_name="MyApp",
        )

        assert result.success is True

        # First subprocess.run call is the swiftc compilation
        swiftc_call_args = mock_run.call_args_list[0]
        cmd = swiftc_call_args[0][0]

        assert "-F" in cmd
        f_index = cmd.index("-F")
        assert cmd[f_index + 1] == str(tmp_products_dir)

    @patch("utell_ios.thunk_compiler.subprocess.run")
    @patch("utell_ios.thunk_compiler._get_simulator_sdk_path", return_value="/fake/sdk")
    @patch("utell_ios.thunk_compiler.get_simulator_os_version", return_value="18.0")
    def test_compile_thunk_no_f_flag_without_frameworks(
        self,
        mock_sdk_version: MagicMock,
        mock_sdk_path: MagicMock,
        mock_run: MagicMock,
        tmp_products_dir: Path,
    ) -> None:
        """ER4: swiftc command does NOT include -F when no frameworks are present."""
        tmp_products_dir.mkdir(parents=True, exist_ok=True)

        swiftc_result = MagicMock()
        swiftc_result.returncode = 0
        swiftc_result.stderr = ""

        codesign_result = MagicMock()
        codesign_result.returncode = 0
        codesign_result.stderr = ""

        mock_run.side_effect = [swiftc_result, codesign_result]

        result = compile_thunk(
            thunk_source_path="fake.swift",
            output_dylib_path="out.dylib",
            build_products_dir=str(tmp_products_dir),
            product_name="MyApp",
        )

        assert result.success is True

        swiftc_call_args = mock_run.call_args_list[0]
        cmd = swiftc_call_args[0][0]

        assert "-F" not in cmd
