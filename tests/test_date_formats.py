"""Test that date fields have valid formats."""

import pytest
import yaml
import re
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "my-cv-data"

# Patterns for date validation
YEAR_PATTERN = re.compile(r"^\d{4}$")
DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# Files with year-only fields (YYYY format)
YEAR_FIELDS = {
    "education.yml": ["year"],
    "appointments.yml": ["start", "end"],
    "grants.yml": ["start", "end"],
    "teaching.yml": ["year"],
    "awards.yml": ["year"],
    "awards_advisee.yml": ["year"],
    "training.yml": ["start", "end"],
    "university_service.yml": ["start_year", "end_year"],
    "department_service.yml": ["start_year", "end_year"],
    "professional_service.yml": ["start_year", "end_year"],
    "teams_advised.yml": ["year"],
    "advising.yml": ["join_year", "degree_year"],
}

# Files with full date fields (YYYY-MM-DD format)
DATE_FIELDS = {
    "talks.yml": ["date"],
    "workshops.yml": ["date"],
    "convene.yml": ["date"],
    "media.yml": ["date"],
}


def load_yaml_file(filename):
    """Load a YAML file from the data directory."""
    filepath = DATA_DIR / filename
    if not filepath.exists():
        return None
    with open(filepath, "r") as f:
        return yaml.safe_load(f)


def get_entry_identifier(entry, index):
    """Get a human-readable identifier for an entry."""
    for field in ["title", "name", "project_title", "award", "role"]:
        if field in entry and entry[field]:
            return str(entry[field])[:40]
    if "firstname" in entry and "lastname" in entry:
        return f"{entry.get('firstname', '')} {entry.get('lastname', '')}".strip()
    return f"entry {index}"


def get_year_validation_cases():
    """Generate test cases for year field validation."""
    cases = []
    for filename, fields in YEAR_FIELDS.items():
        if (DATA_DIR / filename).exists():
            for field in fields:
                cases.append((filename, field))
    return cases


def get_date_validation_cases():
    """Generate test cases for date field validation."""
    cases = []
    for filename, fields in DATE_FIELDS.items():
        if (DATA_DIR / filename).exists():
            for field in fields:
                cases.append((filename, field))
    return cases


@pytest.mark.parametrize("filename,field", get_year_validation_cases())
def test_year_format(filename, field):
    """Test that year fields contain valid YYYY format."""
    data = load_yaml_file(filename)

    if data is None:
        pytest.skip(f"{filename} does not exist")

    if not isinstance(data, list):
        pytest.skip(f"{filename} is not a list")

    errors = []
    for i, entry in enumerate(data):
        if not isinstance(entry, dict):
            continue

        value = entry.get(field)
        if value is None:
            continue  # Optional field or handled by required field tests

        value_str = str(value)
        # Allow "present" for end dates
        if value_str.lower() == "present":
            continue

        if not YEAR_PATTERN.match(value_str):
            identifier = get_entry_identifier(entry, i)
            errors.append(f"'{identifier}': {field}='{value}' (expected YYYY)")

    if errors:
        error_msg = f"Invalid year format in {filename}:\n"
        error_msg += "\n".join(f"  - {e}" for e in errors[:10])
        if len(errors) > 10:
            error_msg += f"\n  ... and {len(errors) - 10} more"
        pytest.fail(error_msg)


@pytest.mark.parametrize("filename,field", get_date_validation_cases())
def test_date_format(filename, field):
    """Test that date fields contain valid YYYY-MM-DD format."""
    data = load_yaml_file(filename)

    if data is None:
        pytest.skip(f"{filename} does not exist")

    if not isinstance(data, list):
        pytest.skip(f"{filename} is not a list")

    errors = []
    for i, entry in enumerate(data):
        if not isinstance(entry, dict):
            continue

        value = entry.get(field)
        if value is None:
            continue

        value_str = str(value)
        if not DATE_PATTERN.match(value_str):
            identifier = get_entry_identifier(entry, i)
            errors.append(f"'{identifier}': {field}='{value}' (expected YYYY-MM-DD)")

    if errors:
        error_msg = f"Invalid date format in {filename}:\n"
        error_msg += "\n".join(f"  - {e}" for e in errors[:10])
        if len(errors) > 10:
            error_msg += f"\n  ... and {len(errors) - 10} more"
        pytest.fail(error_msg)
