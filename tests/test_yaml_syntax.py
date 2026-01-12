"""Test that all YAML files have valid syntax."""

import pytest
import yaml
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "my-cv-data"


def get_yaml_files():
    """Get all YAML files in the data directory."""
    if not DATA_DIR.exists():
        return []
    return list(DATA_DIR.glob("*.yml"))


@pytest.mark.parametrize("yaml_file", get_yaml_files(), ids=lambda f: f.name)
def test_yaml_syntax_valid(yaml_file):
    """Test that each YAML file has valid syntax."""
    with open(yaml_file, "r") as f:
        try:
            data = yaml.safe_load(f)
            assert data is not None, f"{yaml_file.name} is empty or contains only comments"
        except yaml.YAMLError as e:
            # Extract line number if available
            if hasattr(e, "problem_mark") and e.problem_mark:
                line = e.problem_mark.line + 1
                col = e.problem_mark.column + 1
                pytest.fail(f"YAML syntax error at line {line}, column {col}: {e.problem}")
            else:
                pytest.fail(f"YAML syntax error: {e}")
