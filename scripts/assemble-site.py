#!/usr/bin/env python3
"""Assembles the GitHub Pages site: site/, plus downloads and updates made from the GitHub releases.

    scripts/assemble-site.py OUT [--base-url URL] [--releases DIR] [--site DIR]

OUT gets a copy of site/ and:

  download/Grammar-Review.dmg    the latest release, at URLs that stay the same from release
  download/Grammar-Review.zip    to release (the website links to them)
  download/latest.json           what that release is; "version" is null before the first one
  updates/Grammar-Review-<version>.zip
                                 the recent releases signed for Sparkle
  appcast.xml                    Sparkle's update feed, listing those

The releases come from GitHub through `gh` (it needs GH_TOKEN, and GH_REPO outside a clone): the
newest published releases, not drafts or prereleases, that have the release.json asset written by
scripts/release.sh. --releases DIR reads them from DIR instead, one folder per release holding
github.json (tagName, publishedAt, body and url, as `gh release view --json` prints them),
release.json and its files. scripts/test-assemble-site.py tests it that way.

The script checks what it wrote before it exits, and fails rather than publish a broken feed.
"""

from __future__ import annotations

import argparse
import base64
import datetime
import email.utils
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BASE_URL = "https://modakoda.github.io/grammar-review/"
RELEASE_LIMIT = 10
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
SAFE_NAME = re.compile(r"^[0-9A-Za-z][0-9A-Za-z._+-]*$")
LATEST_KEYS = {"version", "published", "minimumSystemVersion", "notarized", "files"}


def warn(message: str) -> None:
    prefix = "::warning::" if os.environ.get("GITHUB_ACTIONS") else "warning: "
    print(prefix + message, file=sys.stderr)


class CheckFailed(Exception):
    pass


@dataclass
class Release:
    tag: str
    published: datetime.datetime
    notes: str
    folder: Path
    version: str
    build: str
    minimum_system: str
    notarized: bool
    zip: Path
    dmg: Path
    sparkle: dict | None


def parse_date(text: str) -> datetime.datetime:
    """GitHub's "2026-10-21T09:30:00Z" (fromisoformat only takes "Z" from Python 3.11)."""
    date = datetime.datetime.fromisoformat(text.replace("Z", "+00:00"))
    if date.tzinfo is None:
        date = date.replace(tzinfo=datetime.timezone.utc)
    return date.astimezone(datetime.timezone.utc)


def iso(date: datetime.datetime) -> str:
    return date.strftime("%Y-%m-%dT%H:%M:%SZ")


def load_release(folder: Path) -> Release:
    """Reads one release folder; raises ValueError (or KeyError) when it's unusable."""
    github = json.loads((folder / "github.json").read_text(encoding="utf-8"))
    metadata = json.loads((folder / "release.json").read_text(encoding="utf-8"))
    version = str(metadata["version"])
    names = {}
    for kind in ("zip", "dmg"):
        name = str(metadata[kind])
        if not SAFE_NAME.match(name):
            raise ValueError(f"unsafe {kind} name {name!r}")
        names[kind] = name
    if not SAFE_NAME.match(version):
        raise ValueError(f"unsafe version {version!r}")
    sparkle = metadata.get("sparkle")
    if sparkle is not None:
        signature = base64.b64decode(str(sparkle["edSignature"]), validate=True)
        if len(signature) != 64 or int(sparkle["length"]) <= 0:
            raise ValueError("the Sparkle signature or length isn't valid")
        sparkle = {"edSignature": str(sparkle["edSignature"]), "length": int(sparkle["length"])}
    tag = str(github["tagName"])
    if tag.removeprefix("v") != version:
        warn(f"{tag}: release.json says version {version}")
    return Release(
        tag=tag,
        published=parse_date(str(github["publishedAt"])),
        notes=str(github.get("body") or "").strip(),
        folder=folder,
        version=version,
        build=str(metadata["build"]),
        minimum_system=str(metadata["minimumSystemVersion"]),
        notarized=bool(metadata["notarized"]),
        zip=folder / names["zip"],
        dmg=folder / names["dmg"],
        sparkle=sparkle,
    )


def load_releases(folder: Path) -> list[Release]:
    """The usable releases in `folder`, newest first."""
    releases = []
    for entry in sorted(path for path in folder.iterdir() if path.is_dir()):
        if not (entry / "release.json").is_file():
            warn(f"{entry.name}: no release.json (not made by scripts/release.sh); skipped")
            continue
        try:
            releases.append(load_release(entry))
        except (OSError, ValueError, KeyError, TypeError) as error:
            warn(f"{entry.name}: unusable release.json or github.json ({error}); skipped")
    releases.sort(key=lambda release: release.published, reverse=True)
    return releases



def gh(*arguments: str) -> str:
    result = subprocess.run(["gh", *arguments], capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"assemble-site: gh {' '.join(arguments)} failed: {result.stderr.strip()}")
    return result.stdout


def fetch_releases(folder: Path, limit: int) -> None:
    """Downloads into `folder` what assembling needs: release.json of the newest `limit` releases,
    the dmg and zip of the newest one that has both, and the zip of each one signed for Sparkle."""
    listing = json.loads(gh("release", "list", "--exclude-drafts", "--exclude-pre-releases", "--limit", str(limit), "--json", "tagName"))
    need_latest = True
    for index, item in enumerate(listing):
        tag = item["tagName"]
        view = json.loads(gh("release", "view", tag, "--json", "tagName,publishedAt,body,url,assets"))
        assets = {asset["name"] for asset in view["assets"]}
        if "release.json" not in assets:
            warn(f"{tag}: no release.json (not made by scripts/release.sh); skipped")
            continue
        target = folder / f"{index:03d}"
        target.mkdir(parents=True)
        github = {key: view.get(key) for key in ("tagName", "publishedAt", "body", "url")}
        (target / "github.json").write_text(json.dumps(github), encoding="utf-8")
        gh("release", "download", tag, "--dir", str(target), "--pattern", "release.json")
        try:
            metadata = json.loads((target / "release.json").read_text(encoding="utf-8"))
            zip_name, dmg_name = str(metadata["zip"]), str(metadata["dmg"])
        except (ValueError, KeyError, TypeError) as error:
            warn(f"{tag}: unusable release.json ({error}); skipped")
            continue
        wanted = []
        if need_latest and {zip_name, dmg_name} <= assets:
            wanted = [zip_name, dmg_name]
            need_latest = False
        elif metadata.get("sparkle") and zip_name in assets:
            wanted = [zip_name]
        for name in wanted:
            if SAFE_NAME.match(name):
                gh("release", "download", tag, "--dir", str(target), "--pattern", name)



def file_info(path: Path, name: str) -> dict:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1 << 20), b""):
            digest.update(chunk)
    return {"name": name, "size": path.stat().st_size, "sha256": digest.hexdigest()}


def write_latest(out: Path, releases: list[Release]) -> Release | None:
    """Copies the newest release with both files to download/ and describes it in latest.json."""
    download = out / "download"
    download.mkdir(exist_ok=True)
    latest = next((release for release in releases if release.zip.is_file() and release.dmg.is_file()), None)
    info: dict = {"version": None, "published": None, "minimumSystemVersion": None, "notarized": None, "files": {}}
    if latest is not None:
        files = {}
        for kind, source in (("dmg", latest.dmg), ("zip", latest.zip)):
            name = f"Grammar-Review.{kind}"
            shutil.copyfile(source, download / name)
            files[kind] = file_info(download / name, name)
        info = {
            "version": latest.version,
            "published": iso(latest.published),
            "minimumSystemVersion": latest.minimum_system,
            "notarized": latest.notarized,
            "files": files,
        }
    (download / "latest.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
    return latest


def sparkle_system_version(version: str) -> str:
    """Sparkle wants major.minor.patch: "14.0" → "14.0.0"."""
    parts = version.split(".")
    return ".".join(parts + ["0"] * (3 - len(parts)))


def write_appcast(out: Path, releases: list[Release], base_url: str, limit: int) -> list[Release]:
    """Copies the zips of releases signed for Sparkle to updates/ and lists them in appcast.xml."""
    listed = []
    for release in releases[:limit]:
        if release.sparkle is None:
            continue
        if not release.zip.is_file():
            warn(f"{release.tag}: signed for Sparkle, but its zip wasn't downloaded; not in the feed")
            continue
        if release.zip.stat().st_size != release.sparkle["length"]:
            warn(f"{release.tag}: the zip's size doesn't match its Sparkle signature; not in the feed")
            continue
        listed.append(release)

    ET.register_namespace("sparkle", SPARKLE)
    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "Grammar Review"
    ET.SubElement(channel, "link").text = base_url
    ET.SubElement(channel, "description").text = "Updates to Grammar Review"
    ET.SubElement(channel, "language").text = "en"
    updates = out / "updates"
    for release in listed:
        name = f"Grammar-Review-{release.version}.zip"
        updates.mkdir(exist_ok=True)
        shutil.copyfile(release.zip, updates / name)
        item = ET.SubElement(channel, "item")
        ET.SubElement(item, "title").text = f"Version {release.version}"
        ET.SubElement(item, "pubDate").text = email.utils.format_datetime(release.published)
        ET.SubElement(item, f"{{{SPARKLE}}}version").text = release.build
        ET.SubElement(item, f"{{{SPARKLE}}}shortVersionString").text = release.version
        ET.SubElement(item, f"{{{SPARKLE}}}minimumSystemVersion").text = sparkle_system_version(release.minimum_system)
        if release.notes:
            ET.SubElement(item, "description", {f"{{{SPARKLE}}}format": "markdown"}).text = release.notes
        ET.SubElement(item, "enclosure", {
            "url": base_url + "updates/" + name,
            "length": str(release.sparkle["length"]),
            "type": "application/octet-stream",
            f"{{{SPARKLE}}}edSignature": release.sparkle["edSignature"],
        })
    ET.indent(rss)
    ET.ElementTree(rss).write(out / "appcast.xml", encoding="utf-8", xml_declaration=True)
    with (out / "appcast.xml").open("a", encoding="utf-8") as file:
        file.write("\n")
    return listed



def check(out: Path, base_url: str) -> None:
    """Re-reads latest.json and appcast.xml and checks them against the files they describe."""

    def require(condition: bool, message: str) -> None:
        if not condition:
            raise CheckFailed(message)

    latest = json.loads((out / "download" / "latest.json").read_text(encoding="utf-8"))
    require(set(latest) == LATEST_KEYS, f"latest.json has the keys {sorted(latest)}")
    if latest["version"] is None:
        require(latest["files"] == {}, "latest.json lists files without a version")
    else:
        require(isinstance(latest["notarized"], bool), "latest.json: notarized isn't true or false")
        require(set(latest["files"]) == {"dmg", "zip"}, "latest.json doesn't list both the dmg and the zip")
        for kind, info in latest["files"].items():
            require(info["name"] == f"Grammar-Review.{kind}", f"latest.json: unexpected {kind} name")
            require(file_info(out / "download" / info["name"], info["name"]) == info, f"latest.json: the {kind}'s size or sha256 is wrong")

    root = ET.parse(out / "appcast.xml").getroot()
    require(root.tag == "rss" and root.find("channel") is not None, "appcast.xml isn't an RSS feed")
    builds = []
    for item in root.iter("item"):
        enclosure = item.find("enclosure")
        require(enclosure is not None, "an appcast item has no enclosure")
        url = enclosure.get("url", "")
        require(url.startswith(base_url + "updates/"), f"unexpected update URL {url}")
        archive = out / url[len(base_url):]
        require(archive.is_file(), f"{url} isn't in the site")
        require(str(archive.stat().st_size) == enclosure.get("length"), f"{url}: wrong length")
        signature = enclosure.get(f"{{{SPARKLE}}}edSignature", "")
        require(len(base64.b64decode(signature, validate=True)) == 64, f"{url}: no EdDSA signature")
        for tag in ("version", "shortVersionString", "minimumSystemVersion"):
            require(bool(item.findtext(f"{{{SPARKLE}}}{tag}")), f"{url}: no sparkle:{tag}")
        builds.append(item.findtext(f"{{{SPARKLE}}}version"))
    duplicates = sorted({build for build in builds if builds.count(build) > 1})
    if duplicates:
        warn(f"several updates have CFBundleVersion {', '.join(duplicates)}; Sparkle can't tell them apart")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("out", type=Path, help="where to assemble the site (replaced)")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help=f"the site's public URL (default {DEFAULT_BASE_URL})")
    parser.add_argument("--releases", type=Path, help="read releases from this folder instead of GitHub")
    parser.add_argument("--site", type=Path, default=ROOT / "site", help="the static site to copy (default site/)")
    parser.add_argument("--limit", type=int, default=RELEASE_LIMIT, help=f"releases in the update feed (default {RELEASE_LIMIT})")
    args = parser.parse_args()
    base_url = args.base_url.rstrip("/") + "/"

    if args.out.exists():
        shutil.rmtree(args.out)
    shutil.copytree(args.site, args.out, ignore=shutil.ignore_patterns("tests", ".DS_Store"))
    with tempfile.TemporaryDirectory() as temporary:
        folder = args.releases
        if folder is None:
            folder = Path(temporary)
            fetch_releases(folder, args.limit)
        releases = load_releases(folder)
        latest = write_latest(args.out, releases)
        listed = write_appcast(args.out, releases, base_url, args.limit)
    try:
        check(args.out, base_url)
    except (CheckFailed, OSError, ValueError, KeyError, ET.ParseError) as error:
        print(f"assemble-site: self-check failed: {error}", file=sys.stderr)
        return 1

    if latest is None:
        print("Downloads: no release yet (download/latest.json has \"version\": null)")
    else:
        notarized = "notarized" if latest.notarized else "NOT notarized"
        print(f"Downloads: {latest.version} ({notarized}, {latest.tag})")
    print(f"Update feed: {', '.join(release.version for release in listed) or 'no updates'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
