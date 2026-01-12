"""Shared fixtures and GitHub Actions integration for CV tests."""

import os
import pytest
import yaml
from pathlib import Path

# Path constants
ROOT_DIR = Path(__file__).parent.parent
CONFIG_FILE = ROOT_DIR / "_config.yml"
DATA_DIR = ROOT_DIR / "my-cv-data"

# Track test results for GitHub summary
_test_results = {"passed": 0, "failed": 0, "failures": []}


@pytest.fixture(scope="session")
def config():
    """Load the main configuration file."""
    with open(CONFIG_FILE, "r") as f:
        return yaml.safe_load(f)


@pytest.fixture(scope="session")
def all_yaml_files():
    """Get all YAML files from the data directory."""
    return list(DATA_DIR.glob("*.yml"))


@pytest.fixture(scope="session")
def section_files(config):
    """Get section-to-file mapping from config."""
    return {s["title"]: s["file"] for s in config["sections"]}


def load_yaml_file(filename):
    """Helper to load a YAML file from the data directory."""
    filepath = DATA_DIR / filename
    if not filepath.exists():
        return None
    with open(filepath, "r") as f:
        return yaml.safe_load(f)


# GitHub Actions integration hooks

def pytest_runtest_logreport(report):
    """Emit GitHub Actions annotations for test failures."""
    if report.when == "call":
        if report.passed:
            _test_results["passed"] += 1
        elif report.failed:
            _test_results["failed"] += 1

            # Extract file info from the test if available
            file_path = None
            line_num = None
            message = str(report.longrepr) if report.longrepr else "Test failed"

            # Try to extract YAML file from the test name (parametrized tests)
            if "[" in report.nodeid and "]" in report.nodeid:
                param = report.nodeid.split("[")[1].rstrip("]")
                if param.endswith(".yml"):
                    file_path = f"my-cv-data/{param}"

            # Store failure info
            _test_results["failures"].append({
                "test": report.nodeid,
                "file": file_path,
                "line": line_num,
                "message": _get_short_message(message),
            })

            # Emit GitHub Actions annotation
            if os.environ.get("GITHUB_ACTIONS") == "true":
                if file_path:
                    print(f"::error file={file_path}::{_get_short_message(message)}")
                else:
                    print(f"::error::{report.nodeid}: {_get_short_message(message)}")


def pytest_sessionfinish(session, exitstatus):
    """Write GitHub Actions job summary."""
    if os.environ.get("GITHUB_ACTIONS") != "true":
        return

    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_file:
        return

    total = _test_results["passed"] + _test_results["failed"]

    with open(summary_file, "a") as f:
        if _test_results["failed"] == 0:
            f.write(f"## Test Results: All {total} tests passed\n\n")
        else:
            f.write(f"## Test Results: {_test_results['failed']} failed, {_test_results['passed']} passed\n\n")
            f.write("### Failures\n\n")
            f.write("| Test | File | Issue |\n")
            f.write("|------|------|-------|\n")

            for failure in _test_results["failures"]:
                test_name = failure["test"].split("::")[-1]
                file_col = failure["file"] or "-"
                message = failure["message"][:100]  # Truncate long messages
                f.write(f"| {test_name} | {file_col} | {message} |\n")


def _get_short_message(message: str) -> str:
    """Extract a short error message from pytest output."""
    lines = str(message).split("\n")
    # Look for AssertionError or the actual error message
    for line in lines:
        line = line.strip()
        if line.startswith("AssertionError:"):
            return line.replace("AssertionError:", "").strip()
        if line.startswith("E ") and "assert" not in line.lower():
            return line[2:].strip()
    # Fallback to first non-empty line
    for line in lines:
        line = line.strip()
        if line and not line.startswith("_") and not line.startswith("="):
            return line[:200]
    return "Test failed"
