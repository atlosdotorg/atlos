#!/usr/bin/env python3

# This script is used to archive a page using Bellingcat's auto-archiver and Selenium.
# It also computes perceptual hashes of the extracted media.

import json
from timeout import timeout
import mimetypes
import os
import re
import base64
import shutil
import subprocess
import sys
from time import sleep
from typing import Optional
from loguru import logger
import unicodecsv as csv
from perception import hashers
import click
import tempfile
import requests
import hashlib
from selenium import webdriver
from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium.webdriver.chrome.service import Service as ChromiumService
from webdriver_manager.chrome import ChromeDriverManager
from webdriver_manager.core.os_manager import ChromeType
from selenium.webdriver.common.print_page_options import PrintOptions
from webdriver_manager.core.utils import read_version_from_cmd
from webdriver_manager.core.os_manager import PATTERN

# Make sure we install the right version of the Chrome driver
chromedriver_version = read_version_from_cmd("chromium --version", PATTERN["chromium"])

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


def maybe_download_file(url: str) -> Optional[str]:
    """Downloads the file at the given URL to a tempfile."""

    resp = requests.get(url, allow_redirects=True, timeout=10)
    if resp.status_code != 200:
        return None

    content_type = resp.headers.get("content-type")

    if content_type is None or content_type.startswith("text/html"):
        return None

    suffix = mimetypes.guess_extension(content_type) or ".bin"

    output = f"file{suffix}"
    with open(output, "wb") as outfile:
        outfile.write(resp.content)
        return output


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


def archive_page_using_selenium(url: str) -> dict:
    """Archives the given URL using Selenium."""

    try:
        # Setup driver
        options = ChromeOptions()

        # At a glance, disabling "sandboxing" sounds scary. But don't worry (too much). This is a
        # requirement since we're running Chromium within a Docker container; to get Chromium
        # sandboxing to work, we'd need to change the seccomp policy that the Docker container is
        # running under. We have some protections in place to mitigate some of the fallout of an
        # attacker finding a Chromium exploit and using it on us (e.g., cleaning the environment
        # to remove sensitive variables), but this is — to an extent — an acceptable risk
        # (given the complexity tradeoff).
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--headless=new")
        driver = webdriver.Chrome(
            service=ChromiumService(
                # If you update this version, be sure to also update the version in all Dockerfiles
                ChromeDriverManager(
                    chrome_type=ChromeType.CHROMIUM, driver_version=chromedriver_version
                ).install()
            ),
            options=options,
        )
        driver.set_window_size(1600, 1200)

        # Load the page
        driver.get(url)
        driver.implicitly_wait(5)

        # Wait for a bit
        sleep(5)

        # If there is an element with `aria-label="Close"` and `role="button"`, click it
        try:
            close_button = driver.find_element(
                "xpath", '//*[@aria-label="Close" and @role="button"]'
            )
            close_button.click()
            sleep(1)
        except:
            logger.debug("No close button found")

        # Press the escape key, just in case
        driver.find_element("tag name", "body").send_keys("\ue00c")
        sleep(1)

        # Save page data
        title = driver.title
        body_text = driver.find_element("tag name", "body").text

        driver.get_screenshot_as_file("viewport.png")

        # Get a full page screenshot
        driver.execute_script("window.scrollTo(0, 0);")
        total_width = driver.execute_script("return document.body.offsetWidth")
        total_height = driver.execute_script(
            "return document.body.parentNode.scrollHeight"
        )

        driver.set_window_size(total_width, total_height)
        driver.save_screenshot("fullpage.png")

        # Get a PDF
        print_options = PrintOptions()
        print_options.page_height = total_height / 20
        print_options.page_width = total_width / 50
        pdf_base64 = driver.print_page(print_options=print_options)
        with open("page.pdf", "wb") as outfile:
            outfile.write(base64.b64decode(pdf_base64))

        return dict(
            success=True,
            data=dict(title=title, text=body_text),
            screenshots=[
                dict(file="viewport.png", kind="viewport"),
                dict(file="fullpage.png", kind="fullpage"),
            ],
            pdf="page.pdf",
        )
    except TimeoutError as e:
        raise e
    except Exception as e:
        logger.exception(f"Failed to archive page: {e}")
        return dict(success=False)


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
                f"--cli_feeder.urls={url}",
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

    try:
        mime_type = mimetypes.guess_type(path)[0]

        if mime_type.startswith("image/") and not mime_type.startswith("image/svg"):
            hasher = hashers.PHash()
            perceptual_hash = hasher.compute(path)
            return [dict(kind="phash", hash=perceptual_hash)]
        elif mime_type.startswith("video/"):
            perceptual_hash_l1 = hashers.TMKL1().compute(path)
            return [
                dict(kind="tmkl1", hash=perceptual_hash_l1),
            ]
    except Exception as e:
        logger.error(f"Failed to generate perceptual hash.")
    return []


def analyze_artifact(
    path: str, perceptually_hash: bool = True, kind: str = "file"
) -> dict:
    return dict(
        kind=kind,
        file=os.path.basename(path),
        sha256=compute_checksum(path),
        perceptual_hashes=generate_perceptual_hashes(path) if perceptually_hash else [],
    )


@timeout(60 * 3)
@click.command()
@click.option("--url", type=str)
@click.option("--file", type=click.Path())
@click.option("--out", type=click.Path())
@click.option("--auto-archiver-config", type=click.Path())
def run(url, file, out, auto_archiver_config):
    """Archive the given URL."""

    did_finish = False

    if out is None:
        out = os.path.join(os.getcwd(), "out")
        logger.info(f"Output directory not specified, using {out}")

    # Make sure the paths are absolute, since we'll be changing directories
    if auto_archiver_config:
        auto_archiver_config = os.path.abspath(auto_archiver_config)

    out = os.path.abspath(out)

    if not os.path.exists(out):
        os.mkdir(out)

    with tempfile.TemporaryDirectory() as t:
        os.chdir(t)

        artifacts = []
        selenium_archive = {}
        auto_archiver_archive = {}

        # try:
        # First, archive the file, if given
        if file is not None:
            logger.info("Archiving the file...")
            if os.path.join(out, os.path.basename(file)) != file:
                shutil.copyfile(
                    file,
                    os.path.join(out, os.path.basename(file)),
                )
            artifacts.append(
                analyze_artifact(file, perceptually_hash=True, kind="file")
            )

        # Then, archive the URL, if given
        if url is not None:
            # Archive the file directly, if possible/needed
            logger.info("Archiving the data directly...")
            direct_archive = maybe_download_file(url)
            if direct_archive is None:
                logger.info("No direct archive available/necessary for this URL")
            else:
                logger.info(
                    "Direct archive available/necessary for this URL (is not HTML)"
                )

            # Archive the page using Selenium
            logger.info("Archiving the page using Selenium...")
            selenium_archive = archive_page_using_selenium(url)

            # Archive the page using the Bellingcat auto-archiver
            logger.info("Archiving the page using the Bellingcat auto-archiver...")
            auto_archiver_archive = archive_using_auto_archiver(
                url, config=auto_archiver_config
            )

            # Merge all the artifacts into a nice output folder
            logger.info("Finalizing screenshots and page pdf...")

            if selenium_archive["success"]:
                for screenshot in selenium_archive["screenshots"]:
                    shutil.copyfile(
                        screenshot["file"],
                        os.path.join(out, os.path.basename(screenshot["file"])),
                    )
                    artifacts.append(
                        analyze_artifact(
                            screenshot["file"],
                            perceptually_hash=False,
                            kind=screenshot["kind"],
                        )
                    )

                shutil.copyfile(
                    selenium_archive["pdf"],
                    os.path.join(out, "page.pdf"),
                )
                artifacts.append(
                    analyze_artifact(
                        selenium_archive["pdf"], perceptually_hash=False, kind="pdf"
                    )
                )

            logger.info("Finalizing auto archiver files...")

            if auto_archiver_archive["success"]:
                for file in auto_archiver_archive["files"]:
                    path = os.path.basename(file)
                    shutil.copyfile(
                        file,
                        os.path.join(out, path),
                    )
                    artifacts.append(analyze_artifact(file, kind="media"))

            logger.info("Finalizing direct archive (if applicable)...")

            if direct_archive is not None:
                path = os.path.basename(direct_archive)
                shutil.copyfile(
                    direct_archive,
                    os.path.join(out, path),
                )
                artifacts.append(analyze_artifact(direct_archive, kind="direct_file"))

        # Write the metadata
        with open(os.path.join(out, "metadata.json"), "w") as outfile:
            json.dump(
                dict(
                    page_info=selenium_archive.get("data"),
                    artifacts=artifacts,
                    content_info=auto_archiver_archive.get("metadata"),
                    crawl_successful=selenium_archive.get("success"),
                    auto_archive_successful=auto_archiver_archive.get("success"),
                    is_likely_authwalled=is_likely_authwalled(url)
                    if url is not None
                    else False,
                ),
                outfile,
            )

        did_finish = True
        logger.success("Processing complete")
        # except Exception as e:
        #     logger.error(str(e.with_traceback(None)))
        # finally:
        #     if not did_finish:
        #         logger.error("Processing failed")
        #         sys.exit(1)


if __name__ == "__main__":
    run()
