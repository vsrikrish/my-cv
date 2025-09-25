#!/usr/bin/env python3
"""
Convert grants YAML data to Excel format for easy sharing and analysis.
"""

import os
import yaml
import pandas as pd
from datetime import datetime

STATUS_MAP = {
    "active": "Active",
    "complete": "Completed",
    "under_review": "Under Review",
    "not_funded": "Not Funded",
}


def load_grants_data(yaml_path="my-cv-data/grants.yml"):
    """Load grants data from YAML file"""
    with open(yaml_path, "r") as f:
        grants = yaml.load(f, Loader=yaml.BaseLoader)
    return grants


def format_amount(amount):
    """Format amount as currency if present"""
    if amount:
        try:
            return int(amount.replace("_", ""))
        except (ValueError, AttributeError):
            return amount
    return ""


def grants_to_dataframe(grants):
    """Convert grants list to pandas DataFrame"""

    # Extract all unique fields from grants
    all_fields = set()
    for grant in grants:
        all_fields.update(grant.keys())

    # Create list of dictionaries for DataFrame
    rows = []
    for grant in grants:
        row = {}

        # Standard fields
        row["Status"] = STATUS_MAP[grant.get("status", "")]
        row["Title"] = grant.get("title", "")
        row["Sponsor"] = grant.get("sponsor", "")
        row["Program"] = grant.get("program", "")
        row["My Role"] = grant.get("my_role", grant.get("role", ""))  # Backward compatibility
        row["Overall PI"] = grant.get("overall_pi", grant.get("PI", ""))  # Backward compatibility
        row["Rice PI"] = grant.get("rice_pi", "")
        row["Start Year"] = grant.get("start", "")
        row["End Year"] = grant.get("end", "")
        row["Rice Amount"] = format_amount(grant.get("total_award", ""))
        row["Total Project"] = format_amount(grant.get("total_project", ""))
        row["Grant Number"] = grant.get("number", "")
        row["Collaborative"] = "Yes" if grant.get("collaborative") else "No"
        row["Subaward From"] = grant.get("subaward_from", "")

        rows.append(row)

    return pd.DataFrame(rows)


def main():
    """Main function to convert grants to Excel"""

    # Load grants data
    print("Loading grants data...")
    grants = load_grants_data()

    # Convert to DataFrame
    print("Converting to DataFrame...")
    df = grants_to_dataframe(grants)

    # Sort by status and start year
    status_order = {"active": 1, "complete": 2, "under_review": 3, "not_funded": 4}
    df["status_sort"] = df["Status"].map(status_order)
    df = df.sort_values(["status_sort", "Start Year"], ascending=[True, False])
    df = df.drop("status_sort", axis=1)

    # Create output filename with timestamp
    timestamp = datetime.now().strftime("%Y-%m-%d")
    output_file = f"temp_output/grants_summary_{timestamp}.xlsx"

    # Ensure temp_output directory exists
    os.makedirs("temp_output", exist_ok=True)

    # delete file if it exists
    if os.path.exists(output_file):
        os.remove(output_file)

    # Write to Excel with formatting
    print(f"Writing to {output_file}...")
    with pd.ExcelWriter(output_file, engine="openpyxl") as writer:

        # Write main grants sheet
        df.to_excel(writer, sheet_name="All Grants", index=False)

        # Write separate sheets by status
        for status in df["Status"].unique():
            status_df = df[df["Status"] == status].copy()
            if not status_df.empty:
                sheet_name = status.replace("_", " ").title()
                status_df.to_excel(writer, sheet_name=sheet_name, index=False)

        # Auto-adjust column widths
        for sheet_name in writer.sheets:
            worksheet = writer.sheets[sheet_name]
            for column in worksheet.columns:
                max_length = 0
                column_letter = column[0].column_letter
                for cell in column:
                    try:
                        if len(str(cell.value)) > max_length:
                            max_length = len(str(cell.value))
                    except:
                        pass
                adjusted_width = min(max_length + 2, 50)  # Cap at 50 characters
                worksheet.column_dimensions[column_letter].width = adjusted_width

    print(f"✓ Grants data exported to {output_file}")
    for status in STATUS_MAP.keys():
        print(f"  {STATUS_MAP[status]}: {len(df[df['Status'] == STATUS_MAP[status]])}")


if __name__ == "__main__":
    main()
