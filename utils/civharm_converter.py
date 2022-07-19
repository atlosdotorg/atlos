#!/usr/bin/env python3

import click
import unicodecsv as csv
from dateutil.parser import parse as date_parse
from collections import defaultdict


@click.command()
@click.argument("infile", type=click.File("rb"))
@click.argument("outfile", type=click.File("wb"))
@click.option("--only-geolocated", type=click.BOOL)
def run(infile, outfile, only_geolocated):
    """Convert from a CIVHARM spreadsheet export (CSV) to something importable by Atlos."""

    reader = csv.DictReader(infile)
    writer = csv.DictWriter(
        outfile,
        [
            "sensitive",
            "description",
            "latitude",
            "longitude",
            "more_info",
            "civilian_impact",
            "event",
            "casualty",
            "military_infrastructure",
            "weapon",
            "date_recorded",
            "status",
            "tags"
        ]
        + ["source_" + str(i) for i in range(1, 23)],
    )

    writer.writeheader()
    for row in reader:
        identifier = row["Incident no. "]
        if identifier.startswith("CIV") and len(row["Narrative"]) > 7:
            comments = row['Comments'].strip()
            if len(comments) > 0:
                comments = f"\n\n{comments}"

            location = row['Location'].strip()
            if len(location) == 0:
                location = "No reported location."
            else:
                location = f"Reported near {location}."

            more_info = f"Corresponds to **{identifier}** in CIVHARM. {location} {comments}"

            sensitive = []
            if row["Private Information Visible"] == "Yes":
                sensitive.append("Personal Information Visible")
            if "graphic" in row["Narrative"].lower():
                sensitive.append("Graphic Violence")
            if len(sensitive) == 0:
                sensitive.append("Not Sensitive")

            description = row["Narrative"]
            if len(description) > 239:
                description = description[:237] + "…"

            civilian_impact_mapping = defaultdict(lambda: "")
            civilian_impact_mapping.update(
                {
                    "Administrative": "Structure/Administrative",
                    "Commercial": "Structure/Commercial",
                    "Cultural": "Structure/Cultural",
                    "Healthcare": "Structure/Healthcare",
                    "Industrial": "Structure/Industrial",
                    "Religious": "Structure/Religious",
                    "Residential": "Structure/Residential",
                    "School or childcare": "Structure/School or Childcare",
                }
            )

            civilian_impact = [
                civilian_impact_mapping[row["Type of area affected"]]]

            weapon_system_mapping = defaultdict(lambda: "")
            weapon_system_mapping.update(
                {
                    "Small arms": "Small Arm",
                    "Ballistic missile": "Launch System/Self-Propelled",
                    "Cluster munitions": "Munition/Cluster",
                    "Cruise missile": "Launch System/Self-Propelled",
                    "HE rocket artillery": "Launch System/Artillery",
                    "Incendiary munitions": "Munition/Incendiary",
                    "Land mines": "Land Mine",
                    "Thermobaric munition": "Munition/Thermobaric",
                }
            )

            weapon = [weapon_system_mapping[row["Weapon System"]]]

            military_infrastructure_mapping = defaultdict(lambda: "")
            military_infrastructure_mapping.update({"Air strike": "Aircraft"})

            military_infrastructure = [
                military_infrastructure_mapping[row["Weapon System"]]
            ]

            try:
                date_recorded = date_parse(
                    row["Reported Date"]).strftime("%Y-%m-%d")
            except:
                date_recorded = ""

            status = "Completed" if row["BCAT\n (geolocated)"] == "TRUE" else "Unclaimed"

            if only_geolocated and row["BCAT\n (geolocated)"] != "TRUE":
                print(f"Skipping {identifier}: not geolocated and published")
                continue

            values = {
                "more_info": more_info,
                "sensitive": ", ".join(sensitive),
                "description": description,
                "civilian_impact": ", ".join(civilian_impact),
                "weapon": ", ".join(weapon),
                "military_infrastructure": ", ".join(military_infrastructure),
                "date_recorded": date_recorded,
                "status": status,
                "latitude": row["Lat"],
                "longitude": row["Lon"],
                "tags": "CIVHARM, Bulk Import"
            }

            source_number = 1
            for k, v in row.items():
                if k.startswith("Source") and v is not None and len(v) > 0:
                    values["source_" + str(source_number)] = v
                    source_number += 1

            writer.writerow(
                values
            )
        else:
            print(f"Skipping {identifier}: {row['Narrative']}...")


if __name__ == "__main__":
    run()
