"""Test that entries in YAML files have required fields."""

import pytest
import yaml
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "my-cv-data"

# Required fields for each file type based on actual data structure
# Note: Some fields are conditionally required based on entry type
REQUIRED_FIELDS = {
    "education.yml": ["university", "degree", "subject", "year"],
    "appointments.yml": ["role", "organization", "dept", "start"],
    "grants.yml": ["sponsor", "title", "my_role", "start", "end", "status"],
    "teaching.yml": ["university", "course", "title", "semester", "year", "role"],
    "advising.yml": ["firstname", "lastname", "degree", "field", "university"],  # role optional for B.S.
    "talks.yml": ["title", "date", "event", "org", "location"],
    "workshops.yml": ["title", "date", "event"],  # location optional for remote presentations
    "awards.yml": ["title", "org", "year"],
    "awards_advisee.yml": ["award", "recipient", "year"],
    "convene.yml": ["role", "session", "event", "location", "date"],
    "media.yml": ["title", "publication", "date"],
    "review.yml": ["name", "type"],
    "interests.yml": ["name"],
    "languages.yml": ["language", "proficiency"],
    "training.yml": ["title", "org", "start"],
    "teams_advised.yml": ["project_title", "program", "year", "period", "status"],
    "university_service.yml": ["role", "organization", "start_year"],
    "department_service.yml": ["role", "program", "start_year"],
    "professional_service.yml": ["role", "organization", "start_year"],
}

# Conditional required fields: field is required unless condition is met
CONDITIONAL_FIELDS = {
    "advising.yml": {
        "role": lambda entry: entry.get("degree") == "B.S.",  # role not required for undergrads
    },
}


def load_yaml_file(filename):
    """Load a YAML file from the data directory."""
    filepath = DATA_DIR / filename
    if not filepath.exists():
        return None
    with open(filepath, "r") as f:
        return yaml.safe_load(f)


def get_files_with_required_fields():
    """Get list of (filename, required_fields) tuples for existing files."""
    cases = []
    for filename, fields in REQUIRED_FIELDS.items():
        if (DATA_DIR / filename).exists():
            cases.append((filename, fields))
    return cases


def get_entry_identifier(entry, index):
    """Get a human-readable identifier for an entry."""
    # Try common identifier fields
    for field in ["title", "name", "project_title", "award", "role"]:
        if field in entry and entry[field]:
            return str(entry[field])[:50]
    # Try firstname + lastname for advising
    if "firstname" in entry and "lastname" in entry:
        return f"{entry.get('firstname', '')} {entry.get('lastname', '')}".strip()
    return f"entry {index}"


@pytest.mark.parametrize("filename,required_fields", get_files_with_required_fields())
def test_required_fields_present(filename, required_fields):
    """Test that each entry in a YAML file has required fields."""
    data = load_yaml_file(filename)

    if data is None:
        pytest.skip(f"{filename} does not exist")

    if not isinstance(data, list):
        pytest.skip(f"{filename} is not a list of entries")

    errors = []
    for i, entry in enumerate(data):
        if not isinstance(entry, dict):
            errors.append(f"Entry {i}: Not a dictionary")
            continue

        missing = [f for f in required_fields if f not in entry or entry[f] is None]
        if missing:
            identifier = get_entry_identifier(entry, i)
            errors.append(f"'{identifier}' missing: {', '.join(missing)}")

    if errors:
        # Limit output to first 10 errors for readability
        error_msg = f"{filename} has entries with missing required fields:\n"
        error_msg += "\n".join(f"  - {e}" for e in errors[:10])
        if len(errors) > 10:
            error_msg += f"\n  ... and {len(errors) - 10} more"
        pytest.fail(error_msg)


def test_advising_role_required_for_graduate_students():
    """Test that graduate students (non-B.S.) in advising.yml have a role field."""
    data = load_yaml_file("advising.yml")

    if data is None:
        pytest.skip("advising.yml does not exist")

    errors = []
    for i, entry in enumerate(data):
        if not isinstance(entry, dict):
            continue

        # Skip undergrads - they don't need role
        if entry.get("degree") == "B.S.":
            continue

        if "role" not in entry or entry["role"] is None:
            identifier = get_entry_identifier(entry, i)
            errors.append(f"'{identifier}' (degree={entry.get('degree')}) missing: role")

    if errors:
        error_msg = "advising.yml: Graduate students must have 'role' field:\n"
        error_msg += "\n".join(f"  - {e}" for e in errors[:10])
        pytest.fail(error_msg)
