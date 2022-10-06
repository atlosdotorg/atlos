#!/usr/bin/env python3

import click
import unicodecsv as csv
from dateutil.parser import parse as date_parse
from collections import defaultdict
import re


def strip_to_float(string):
    return re.sub("[^0-9\.]", "", string)


@click.command()
@click.option("--civharm", type=click.File("rb"))
@click.option("--outfile", type=click.File("wb"))
def run(civharm, outfile):
    """Convert from a CIVHARM spreadsheet export (CSV) to something importable by Atlos."""

    reader = csv.DictReader(civharm)
    writer = csv.DictWriter(
        outfile,
        [
            "sensitive",
            "description",
            "latitude",
            "longitude",
            "more_info",
            "type",
            "impact",
            "equipment",
            "date",
            "status",
            "location",
            "tags",
        ]
        + ["source_" + str(i) for i in range(1, 23)],
    )

    writer.writeheader()
    for row in reader:
        identifier = row["Incident no. "]
        if identifier.startswith("CIV") and len(row["Narrative"]) > 7:
            comments = row["Comments"]
            if len(comments) > 0:
                comments = f"\n\n{comments}"

            location = row["Location"].strip()
            if len(location) == 0:
                location = "No reported location."
            else:
                location = f"Reported near {location}."

            more_info = (
                f"Corresponds to **{identifier}**. {location}"
            )

            if len(more_info) >= 2750:
                more_info = more_info[:2750] + "…"

            sensitive = []
            if row["Private Information Visible"] == "Yes":
                sensitive.append("Personal Information Visible")
            if "graphic" in row["Narrative"].lower() or row["Graphic"] == "TRUE":
                sensitive.append("Graphic Violence")
            if len(sensitive) == 0:
                sensitive.append("Not Sensitive")

            description = identifier + ": " + row["Narrative"]
            if len(description) > 239:
                description = description[:237] + "…"

            impact_mapping = {
                "Roads/Highways": ["Roads/Highways/Transport"],
                "Undefined": [],
                "": []
            }

            impact = [row["Type of area affected"]] if row["Type of area affected"] not in impact_mapping else impact_mapping[row["Type of area affected"]]

            equipment_mapping = {
                "Undefined": [],
                "": []
            }

            equipment = [row["Weapon System"]] if row["Weapon System"] not in equipment_mapping else equipment_mapping[row["Weapon System"]]

            type = ["Civilian Harm"]

            try:
                date = date_parse(row["Reported Date"]).strftime("%Y-%m-%d")
            except:
                date = ""

            status = (
                "Completed"
                if row.get("BCAT\n (geolocated)", "TRUE") == "TRUE"
                else "Unclaimed"
            )

            values = {
                "more_info": more_info,
                "sensitive": ", ".join(sensitive),
                "description": description,
                "type": ", ".join(type),
                "equipment": ", ".join(equipment),
                "impact": ", ".join(impact),
                "date": date,
                "status": status,
                "latitude": strip_to_float(row["Lat"]),
                "longitude": strip_to_float(row["Lon"]),
                "location": f"{strip_to_float(row['Lat'])}, {strip_to_float(row['Lon'])}" if len(strip_to_float(row['Lon'])) > 0 else "",
                "tags": "CIVHARM, Bulk Import",
            }

            source_number = 1
            for k, v in row.items():
                if k.startswith("Source") and v is not None and len(v) > 0:
                    values["source_" + str(source_number)] = v
                    source_number += 1

            writer.writerow(values)
        else:
            print(f"Skipping {identifier}: {row['Narrative']}...")


if __name__ == "__main__":
    run()
