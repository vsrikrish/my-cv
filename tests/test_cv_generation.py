"""Test that CV generation runs without errors."""

import pytest
import sys
from pathlib import Path

# Add parent directory to path for imports
ROOT_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT_DIR))


def test_config_file_valid():
    """Test that _config.yml is valid and has required structure."""
    import yaml

    config_path = ROOT_DIR / "_config.yml"
    assert config_path.exists(), "_config.yml not found"

    with open(config_path, "r") as f:
        config = yaml.safe_load(f)

    # Check required top-level keys
    assert "person" in config, "Config missing 'person' section"
    assert "paths" in config, "Config missing 'paths' section"
    assert "sections" in config, "Config missing 'sections' section"

    # Check person has required fields
    person = config["person"]
    for field in ["first_name", "last_name", "email"]:
        assert field in person, f"Person missing required field: {field}"

    # Check paths
    assert "yaml_path" in config["paths"], "Config missing yaml_path"
    assert "bib_path" in config["paths"], "Config missing bib_path"


def test_section_files_exist():
    """Test that all section files referenced in config exist."""
    import yaml

    with open(ROOT_DIR / "_config.yml", "r") as f:
        config = yaml.safe_load(f)

    yaml_path = ROOT_DIR / config["paths"]["yaml_path"]

    missing_files = []
    for section in config["sections"]:
        section_file = yaml_path / section["file"]
        if not section_file.exists():
            missing_files.append(section["file"])

    if missing_files:
        pytest.fail(f"Section files not found: {', '.join(missing_files)}")


def test_cv_class_loads():
    """Test that CV class loads data without errors."""
    import filters
    from generate_cv import CV, CONFIG_FILE

    my_filters = [
        filters.escape_tex,
        filters.select_by_attr_name,
        filters.sort_by_attr,
        filters.sort_first_year,
        filters.extract_year,
        filters.trim_university,
    ]

    # This should not raise any exceptions
    cv = CV(CONFIG_FILE, filters=my_filters)

    # Verify data was loaded
    assert cv.data is not None, "CV data is None"
    assert "person" in cv.data, "CV data missing person"
    assert "sections" in cv.data, "CV data missing sections"
    assert len(cv.data["sections"]) > 0, "No sections loaded"


def test_template_rendering():
    """Test that templates can be rendered without errors."""
    import filters
    from generate_cv import CV, CONFIG_FILE, TEMPLATES

    my_filters = [
        filters.escape_tex,
        filters.select_by_attr_name,
        filters.sort_by_attr,
        filters.sort_first_year,
        filters.extract_year,
        filters.trim_university,
    ]

    cv = CV(CONFIG_FILE, filters=my_filters)

    # Try to render each template
    for template_name, config in TEMPLATES.items():
        try:
            output = cv.render_tex(config["template"])
            assert len(output) > 0, f"Empty output for {template_name}"
            # Basic sanity check - should contain LaTeX
            assert "\\begin" in output or "\\documentclass" in output, \
                f"{template_name} doesn't look like LaTeX"
        except Exception as e:
            pytest.fail(f"Failed to render {template_name}: {e}")
