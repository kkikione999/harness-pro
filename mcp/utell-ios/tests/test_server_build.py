"""Tests for server.py ios_build_and_install: multi-platform build integration.

Covers BDD Expected Results:
  ER3: ios_build_and_install uses _build_xcodebuild_multi_platform
  ER4: Simple projects (no watchOS) produce identical behavior
"""

from __future__ import annotations

import os
from pathlib import Path
from unittest.mock import MagicMock, patch

import utell_ios.server as server_module


class TestIosBuildAndInstall:
    """Tests for ios_build_and_install."""

    def _set_bundle_id(self) -> None:
        """Set the module-level _bundle_id so the error guard passes."""
        server_module._bundle_id = "com.example.test"

    @patch("utell_ios.server.subprocess.run")
    @patch(
        "utell_ios.server._resolve_xcode_flag",
        return_value=["-project", "/fake.xcodeproj"],
    )
    @patch(
        "utell_ios.server._get_simulator_destination",
        return_value="platform=iOS Simulator,name=iPhone 16,OS=18.0",
    )
    @patch("utell_ios.server._build_xcodebuild_multi_platform")
    @patch("utell_ios.server.shutil.rmtree")
    def test_ios_build_and_install_calls_multi_platform(
        self,
        mock_rmtree: MagicMock,
        mock_multi_platform: MagicMock,
        mock_dest: MagicMock,
        mock_xcode_flag: MagicMock,
        mock_run: MagicMock,
    ) -> None:
        """ER3: ios_build_and_install delegates to _build_xcodebuild_multi_platform."""
        self._set_bundle_id()

        expected_cmd = [
            "xcodebuild",
            "build",
            "-scheme",
            "MyScheme",
            "-destination",
            "platform=iOS Simulator,name=iPhone 16,OS=18.0",
            "-derivedDataPath",
            os.path.join(os.path.sep, "tmp", "utell_ios_build"),
            "-project",
            "/fake.xcodeproj",
        ]
        mock_multi_platform.return_value = expected_cmd

        # Mock build subprocess to succeed
        build_result = MagicMock()
        build_result.returncode = 0
        build_result.stdout = "Build Succeeded\n"

        # Mock install subprocess to succeed
        install_result = MagicMock()
        install_result.returncode = 0
        install_result.stdout = ""

        mock_run.side_effect = [build_result, install_result]

        result = server_module.ios_build_and_install(
            scheme="MyScheme",
            project_path="/fake.xcodeproj",
        )

        # Verify _build_xcodebuild_multi_platform was called with correct args
        mock_multi_platform.assert_called_once()
        call_kwargs = mock_multi_platform.call_args
        assert call_kwargs.kwargs["scheme"] == "MyScheme"
        assert call_kwargs.kwargs["xcode_flag"] == ["-project", "/fake.xcodeproj"]
        assert (
            call_kwargs.kwargs["destination"]
            == "platform=iOS Simulator,name=iPhone 16,OS=18.0"
        )
        # derived_data_path is dynamic; just verify it was passed
        assert "derived_data_path" in call_kwargs.kwargs

    @patch("utell_ios.server.subprocess.run")
    @patch(
        "utell_ios.server._resolve_xcode_flag",
        return_value=["-project", "/fake.xcodeproj"],
    )
    @patch(
        "utell_ios.server._get_simulator_destination",
        return_value="platform=iOS Simulator,name=iPhone 16",
    )
    @patch("utell_ios.server._build_xcodebuild_multi_platform")
    @patch("utell_ios.server.shutil.rmtree")
    def test_ios_build_and_install_success_shape(
        self,
        mock_rmtree: MagicMock,
        mock_multi_platform: MagicMock,
        mock_dest: MagicMock,
        mock_xcode_flag: MagicMock,
        mock_run: MagicMock,
        tmp_path: Path,
    ) -> None:
        """ER3/ER4: Successful build returns dict with success, app_path, build_output, install_output."""
        self._set_bundle_id()

        derived_data_path = str(tmp_path / "utell_ios_build")
        expected_cmd = [
            "xcodebuild",
            "build",
            "-scheme",
            "MyScheme",
            "-destination",
            "platform=iOS Simulator,name=iPhone 16",
            "-derivedDataPath",
            derived_data_path,
            "-project",
            "/fake.xcodeproj",
        ]
        mock_multi_platform.return_value = expected_cmd

        # Create a fake .app in the expected derived data path
        products_dir = Path(derived_data_path) / "Build" / "Products" / "Debug-iphonesimulator"
        fake_app = products_dir / "MyApp.app"
        fake_app.mkdir(parents=True)

        # Mock build subprocess to succeed
        build_result = MagicMock()
        build_result.returncode = 0
        build_result.stdout = "Build Succeeded\n"

        # Mock install subprocess to succeed
        install_result = MagicMock()
        install_result.returncode = 0
        install_result.stdout = "installed"

        mock_run.side_effect = [build_result, install_result]

        # Patch tempfile.gettempdir to use our tmp_path so derived_data_path matches
        with patch("tempfile.gettempdir", return_value=str(tmp_path)):
            result = server_module.ios_build_and_install(
                scheme="MyScheme",
                project_path="/fake.xcodeproj",
            )

        assert result["success"] is True
        assert "app_path" in result
        assert "build_output" in result
        assert "install_output" in result
