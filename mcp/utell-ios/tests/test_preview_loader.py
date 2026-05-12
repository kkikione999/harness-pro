"""Tests for preview_loader: watchOS detection and multi-platform xcodebuild.

Covers BDD Expected Results:
  ER2: watchOS targets pre-built; iOS app builds/installs
  ER4: No false watchOS detection for simple projects
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

from utell_ios.preview_loader import (
    _build_xcodebuild_multi_platform,
    _scheme_has_watchos_targets,
)


class TestSchemeHasWatchosTargets:
    """Tests for _scheme_has_watchos_targets."""

    @patch("utell_ios.preview_loader.subprocess.run")
    def test_scheme_has_watchos_targets_detects_watchos(
        self, mock_run: MagicMock
    ) -> None:
        """ER2: Detects watchOS SDKROOT in build settings."""
        mock_result = MagicMock()
        mock_result.stdout = "    SDKROOT = watchos\n    PLATFORM_NAME = watchos\n"
        mock_run.return_value = mock_result

        result = _scheme_has_watchos_targets("MyApp", [])

        assert result is True

    @patch("utell_ios.preview_loader.subprocess.run")
    def test_scheme_has_watchos_targets_no_watchos(
        self, mock_run: MagicMock
    ) -> None:
        """ER4: Returns False for iOS-only schemes."""
        mock_result = MagicMock()
        mock_result.stdout = "    SDKROOT = iphoneos\n    PLATFORM_NAME = iphoneos\n"
        mock_run.return_value = mock_result

        result = _scheme_has_watchos_targets("MyApp", [])

        assert result is False


class TestBuildXcodebuildMultiPlatform:
    """Tests for _build_xcodebuild_multi_platform."""

    @patch("utell_ios.preview_loader.subprocess.run")
    @patch("utell_ios.preview_loader._scheme_has_watchos_targets", return_value=True)
    @patch(
        "utell_ios.preview_loader._get_watchos_simulator_destination",
        return_value="platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)",
    )
    def test_build_xcodebuild_multi_platform_with_watchos(
        self,
        mock_watchos_dest: MagicMock,
        mock_has_watchos: MagicMock,
        mock_run: MagicMock,
    ) -> None:
        """ER2: Pre-builds watchOS target then returns iOS build command."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        cmd = _build_xcodebuild_multi_platform(
            scheme="MyScheme",
            xcode_flag=["-project", "fake.xcodeproj"],
            destination="platform=iOS Simulator,name=iPhone 16",
            derived_data_path="/tmp/dd",
        )

        # subprocess.run was called once for the watchOS pre-build
        assert mock_run.call_count == 1
        watchos_call_args = mock_run.call_args_list[0]
        watchos_cmd = watchos_call_args[0][0]
        # The destination is a separate element in the command list
        dest_idx = watchos_cmd.index("-destination")
        assert "platform=watchOS Simulator" in watchos_cmd[dest_idx + 1]

        # Returned command is the iOS build command
        assert cmd[0] == "xcodebuild"
        assert cmd[1] == "build"
        assert "-scheme" in cmd
        scheme_idx = cmd.index("-scheme")
        assert cmd[scheme_idx + 1] == "MyScheme"
        assert "-destination" in cmd
        dest_idx = cmd.index("-destination")
        assert cmd[dest_idx + 1] == "platform=iOS Simulator,name=iPhone 16"
        assert "-project" in cmd
        assert "fake.xcodeproj" in cmd

    @patch("utell_ios.preview_loader.subprocess.run")
    @patch("utell_ios.preview_loader._scheme_has_watchos_targets", return_value=False)
    def test_build_xcodebuild_multi_platform_without_watchos(
        self,
        mock_has_watchos: MagicMock,
        mock_run: MagicMock,
    ) -> None:
        """ER4: No watchOS pre-build; returns standard iOS build command."""
        cmd = _build_xcodebuild_multi_platform(
            scheme="MyScheme",
            xcode_flag=["-project", "fake.xcodeproj"],
            destination="platform=iOS Simulator,name=iPhone 16",
            derived_data_path="/tmp/dd",
        )

        # No subprocess.run call for watchOS pre-build
        assert mock_run.call_count == 0

        expected = [
            "xcodebuild",
            "build",
            "-scheme",
            "MyScheme",
            "-destination",
            "platform=iOS Simulator,name=iPhone 16",
            "-derivedDataPath",
            "/tmp/dd",
            "-project",
            "fake.xcodeproj",
        ]
        assert cmd == expected

    @patch("utell_ios.preview_loader.subprocess.run")
    @patch("utell_ios.preview_loader._scheme_has_watchos_targets", return_value=False)
    def test_build_xcodebuild_multi_platform_with_extra_args(
        self,
        mock_has_watchos: MagicMock,
        mock_run: MagicMock,
    ) -> None:
        """ER2 completeness: extra_args are appended to the returned command."""
        cmd = _build_xcodebuild_multi_platform(
            scheme="MyScheme",
            xcode_flag=["-project", "fake.xcodeproj"],
            destination="platform=iOS Simulator,name=iPhone 16",
            derived_data_path="/tmp/dd",
            extra_args=[
                "OTHER_SWIFT_FLAGS=-Xfrontend -enable-implicit-dynamic",
                "DEBUG_INFORMATION_FORMAT=dwarf",
            ],
        )

        assert mock_run.call_count == 0

        assert "OTHER_SWIFT_FLAGS=-Xfrontend -enable-implicit-dynamic" in cmd
        assert "DEBUG_INFORMATION_FORMAT=dwarf" in cmd
        assert "-project" in cmd
        assert "fake.xcodeproj" in cmd
