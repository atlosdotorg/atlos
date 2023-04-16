#!/usr/bin/env python3

# This script is used to archive a page using Bellingcat's auto-archiver and the browsertrix-crawler Docker image.
# It also computes perceptual hashes of the extracted media.

import ipaddress
import json
import mimetypes
import os
import re
import shutil
import subprocess
import sys
from loguru import logger
import socket
from urllib.parse import urlparse
import warcio
import unicodecsv as csv
from perception import hashers
import click
import tempfile
import hashlib

# From https://github.com/bellingcat/auto-archiver/blob/dockerize/src/auto_archiver/utils/url.py#L3
is_telegram_private = re.compile(r"https:\/\/t\.me(\/c)\/(.+)\/(\d+)")
is_instagram = re.compile(r"https:\/\/www\.instagram\.com")
authwall_regexes = [is_telegram_private, is_instagram]


def is_likely_authwalled(url: str) -> bool:
    """Returns whether the given URL is likely to be behind an authentication wall."""
    return any(regex.match(url) for regex in authwall_regexes)


def compute_checksum(path: str) -> str:
    """Computes the SHA256 checksum of the file at the given path."""
    with open(path, "rb") as infile:
        return hashlib.sha256(infile.read()).hexdigest()


def find_json_objects(s):
    """Finds all JSON objects in a string. Returns a list of JSON objects. We use this instead of json.loads() because
    the Bellingcat auto-archiver doesn't strictly adhere to providing JSON output."""

    json_objects = []
    json_start_positions = [m.start() for m in re.finditer(r"\{", s)]

    for start_pos in json_start_positions:
        try:
            json_obj, end_pos = json.JSONDecoder().raw_decode(s, start_pos)
            json_objects.append(json_obj)
        except json.JSONDecodeError:
            continue

    return json_objects


def archive_page_using_browsertrix(url: str) -> dict:
    """Archives the given URL using browsertrix-crawler. Extracts screenshots."""

    if os.path.exists("crawls"):
        raise RuntimeError("crawls folder already exists")

    os.mkdir("crawls")

    docker_args = f"run -v {os.path.abspath('crawls')}:/crawls/ webrecorder/browsertrix-crawler crawl --generateWACZ --timeLimit 60 --userAgent fake --pageLimit 1 --maxDepth 1 --scopeType page --text --screenshot thumbnail,view,fullPage --behaviors autoscroll,autoplay,autofetch,siteSpecific --url"

    # Run the command in a subprocess
    try:
        result = subprocess.run(
            ["docker", *docker_args.split(), url], timeout=60 * 5, capture_output=False
        )  # NOTE: URL is UNTRUSTED. Do NOT put it in a shell command.
    except subprocess.TimeoutExpired:
        logger.warning("Crawl timed out")
        return dict(success=False)

    if result.returncode != 0:
        logger.warning("Crawl failed")
        return dict(success=False)

    # The crawl folder is crawls/collections/<first_file>/
    collections_folder = "crawls/collections/"
    first_file = os.listdir(collections_folder)[0]
    crawl_folder = os.path.join(collections_folder, first_file)
    archive_folder = os.path.join(crawl_folder, "archive")

    # Find the files we need
    pages_jsonl_file = os.path.join(crawl_folder, "pages/pages.jsonl")
    wacz_file = os.path.join(
        crawl_folder,
        list(filter(lambda k: k.endswith(".wacz"), os.listdir(crawl_folder)))[0],
    )
    screenshots_warc_file = os.path.join(archive_folder, "screenshots.warc.gz")

    # Read the pages.jsonl file
    with open(pages_jsonl_file, "r") as infile:
        pages_jsonl = infile.readlines()
        data = [json.loads(line) for line in pages_jsonl][1]

    # Extract the screenshots
    screenshots = []
    with open(screenshots_warc_file, "rb") as infile:
        for record in warcio.ArchiveIterator(infile):
            target = record.rec_headers.get_header("WARC-Target-URI", "")

            for kind in ["view", "fullPage", "thumbnail"]:
                if target.startswith(f"urn:{kind}"):
                    content_type = record.rec_headers.get_header("Content-Type", "")
                    file_extension = content_type.split("/")[-1]
                    file_path = f"crawls/{kind}.{file_extension}"
                    with open(file_path, "wb") as outfile:
                        outfile.write(record.content_stream().read())
                        screenshots.append(dict(file=file_path, kind=kind.lower()))

    return dict(success=True, data=data, wacz_file=wacz_file, screenshots=screenshots)


def archive_using_auto_archiver(
    url: str, config: str = "auto_archiver_config.yaml"
) -> dict:
    """Archives the given URL using the Bellingcat auto-archiver."""

    if os.path.exists("auto_archiver"):
        raise RuntimeError("auto_archiver folder already exists")

    if not os.path.exists(config):
        raise RuntimeError("auto archiver config not found")

    if os.path.exists("db.csv"):
        os.remove("db.csv")

    os.mkdir("auto_archiver")

    try:
        # Run the command in a subprocess
        result = subprocess.run(
            [
                "auto-archiver",
                "--config",
                config,
                f'--cli_feeder.urls="{url}"',
            ],
            timeout=60 * 60,
            capture_output=True,
        )  # NOTE: URL is UNTRUSTED. Do NOT put it in a shell command.
    except subprocess.TimeoutExpired:
        logger.warning("Auto archive timed out")
        return dict(success=False)

    if result.returncode != 0:
        logger.warning("Auto archive failed")
        return dict(success=False)

    # Read the database
    with open("db.csv", "rb") as infile:
        reader = csv.DictReader(infile)
        data = list(reader)[0].get("metadata")

    # Parse the JSON
    objects = find_json_objects(data)

    # Find all the output files
    files = [os.path.join("auto_archiver", p) for p in os.listdir("auto_archiver")]

    return dict(success=True, metadata=objects, files=files)


def generate_perceptual_hashes(path: str) -> dict:
    """Generates a perceptual hash for the given file."""

    mime_type = mimetypes.guess_type(path)[0]

    if mime_type.startswith("image"):
        hasher = hashers.PHash()
        perceptual_hash = hasher.compute(path)
        return [dict(kind="phash", hash=perceptual_hash)]
    elif mime_type.startswith("video"):
        perceptual_hash_l1 = hashers.TMKL1().compute(path)

        return [
            dict(kind="tmkl1", hash=perceptual_hash_l1),
        ]
    return []


@click.command()
@click.option("--url", type=str)
@click.option("--out", type=click.Path())
@click.option("--auto-archiver-config", type=click.Path())
def run(url, out, auto_archiver_config):
    """Archive the given URL."""

    did_finish = False

    # Make sure the paths are absolute, since we'll be changing directories
    auto_archiver_config = os.path.abspath(auto_archiver_config)
    out = os.path.abspath(out)

    with tempfile.TemporaryDirectory() as t:
        os.chdir(t)

        try:
            # Archive the page using browsertrix-crawler
            logger.info("Archiving the page using browsertrix-crawler...")
            browsertrix_crawler_archive = archive_page_using_browsertrix(url)

            # Archive the page using the Bellingcat auto-archiver
            logger.info("Archiving the page using the Bellingcat auto-archiver...")
            auto_archiver_archive = archive_using_auto_archiver(
                url, config=auto_archiver_config
            )

            # Merge all the artifacts into a nice output folder
            logger.info("Finalizing artifacts...")
            if not os.path.exists(out):
                os.mkdir(out)

            artifacts = []
            if browsertrix_crawler_archive["success"]:
                for screenshot in browsertrix_crawler_archive["screenshots"]:
                    shutil.copyfile(
                        screenshot["file"],
                        os.path.join(out, os.path.basename(screenshot["file"])),
                    )
                    artifacts.append(
                        dict(
                            kind=screenshot["kind"],
                            sha256=compute_checksum(screenshot["file"]),
                            file=os.path.basename(screenshot["file"]),
                        )
                    )

                shutil.copyfile(
                    browsertrix_crawler_archive["wacz_file"],
                    os.path.join(out, "archive.wacz"),
                )
                artifacts.append(
                    dict(
                        kind="wacz",
                        file="archive.wacz",
                        sha256=compute_checksum(
                            browsertrix_crawler_archive["wacz_file"]
                        ),
                    )
                )

            if auto_archiver_archive["success"]:
                for file in auto_archiver_archive["files"]:
                    path = os.path.basename(file)
                    shutil.copyfile(
                        file,
                        os.path.join(out, path),
                    )
                    artifacts.append(
                        dict(
                            kind="media",
                            file=path,
                            sha256=compute_checksum(file),
                            perceptual_hashes=generate_perceptual_hashes(file),
                        )
                    )

            # Write the metadata
            with open(os.path.join(out, "metadata.json"), "w") as outfile:
                json.dump(
                    dict(
                        page_info=browsertrix_crawler_archive.get("data"),
                        artifacts=artifacts,
                        content_info=auto_archiver_archive.get("metadata"),
                        crawl_successful=browsertrix_crawler_archive["success"],
                        auto_archive_successful=auto_archiver_archive["success"],
                        is_likely_authwalled=is_likely_authwalled(url),
                    ),
                    outfile,
                )

            did_finish = True
            logger.success("Archival complete")
        except Exception as e:
            logger.error(str(e))
        finally:
            if not did_finish:
                logger.error("Archival failed")
                sys.exit(1)


if __name__ == "__main__":
    run()
