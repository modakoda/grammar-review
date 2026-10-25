#!/usr/bin/env python3
"""Tests scripts/assemble-site.py against fake releases (no network; a fake gh stands in for GitHub):

    python3 scripts/test-assemble-site.py
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "assemble-site.py"
SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
BASE_URL = "https://example.test/grammar-review/"

FAKE_GH = """\
import json, os, shutil, sys
from pathlib import Path

data = Path(os.environ["FAKE_GH_DATA"])
args = sys.argv[1:]
if args[:2] == ["release", "list"]:
    print(json.dumps([{"tagName": tag} for tag in json.loads((data / "order.json").read_text())]))
elif args[:2] == ["release", "view"]:
    folder = data / args[2]
    view = json.loads((folder / "view.json").read_text())
    view["assets"] = [{"name": path.name, "size": path.stat().st_size} for path in sorted((folder / "assets").iterdir())]
    print(json.dumps(view))
elif args[:2] == ["release", "download"]:
    target, name = Path(args[args.index("--dir") + 1]), args[args.index("--pattern") + 1]
    shutil.copyfile(data / args[2] / "assets" / name, target / name)
    with (data / "downloads.log").open("a") as log:
        log.write(args[2] + " " + name + "\\n")
else:
    sys.exit("fake gh: unexpected arguments " + " ".join(args))
"""


def signature(seed: int) -> str:
    return base64.b64encode(bytes([seed]) * 64).decode()


class AssembleSiteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.site = self.root / "site"
        self.site.mkdir()
        (self.site / "index.html").write_text("<!doctype html><title>Grammar Review</title>\n")
        (self.site / "tests").mkdir()
        (self.site / "tests" / "site.spec.mjs").write_text("// not deployed\n")
        self.releases = self.root / "releases"
        self.releases.mkdir()
        self.out = self.root / "out"

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def add_release(
        self,
        version: str,
        published: str,
        *,
        build: str | None = None,
        notarized: bool = True,
        signed: bool = True,
        notes: str = "",
        files: bool = True,
        metadata: dict | None = None,
    ) -> Path:
        folder = self.releases / f"v{version}"
        folder.mkdir()
        github = {"tagName": f"v{version}", "publishedAt": published, "body": notes, "url": f"https://github.test/releases/v{version}"}
        (folder / "github.json").write_text(json.dumps(github))
        zip_name, dmg_name = f"Grammar-Review-{version}.zip", f"Grammar-Review-{version}.dmg"
        if files:
            (folder / zip_name).write_bytes(f"zip {version}".encode() * 100)
            (folder / dmg_name).write_bytes(f"dmg {version}".encode() * 120)
        info = {
            "version": version,
            "build": build or version,
            "minimumSystemVersion": "14.0",
            "notarized": notarized,
            "zip": zip_name,
            "dmg": dmg_name,
        }
        if signed:
            length = (folder / zip_name).stat().st_size if files else 1
            info["sparkle"] = {"edSignature": signature(len(version)), "length": length}
        (folder / "release.json").write_text(json.dumps(metadata if metadata is not None else info))
        return folder

    def assemble(self, *extra: str) -> subprocess.CompletedProcess:
        result = subprocess.run(
            [sys.executable, "-I", str(SCRIPT), str(self.out), "--releases", str(self.releases), "--site", str(self.site), "--base-url", BASE_URL, *extra],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def latest(self) -> dict:
        return json.loads((self.out / "download" / "latest.json").read_text())

    def items(self) -> list[ET.Element]:
        return list(ET.parse(self.out / "appcast.xml").getroot().iter("item"))

    def test_no_releases_yet(self) -> None:
        result = self.assemble()
        self.assertEqual((self.out / "index.html").read_text(), (self.site / "index.html").read_text())
        self.assertFalse((self.out / "tests").exists(), "site/tests is not deployed")
        self.assertEqual(self.latest(), {"version": None, "published": None, "minimumSystemVersion": None, "notarized": None, "files": {}})
        self.assertEqual(sorted(path.name for path in (self.out / "download").iterdir()), ["latest.json"])
        self.assertEqual(self.items(), [])
        self.assertFalse((self.out / "updates").exists())
        self.assertIn("no release yet", result.stdout)

    def test_latest_release_and_feed(self) -> None:
        self.add_release("0.3.0", "2026-10-20T09:30:00Z", notes="## What's new\n* Faster <checks> & fixes")
        self.add_release("0.2.0", "2026-09-01T12:00:00Z", notarized=False)
        self.add_release("0.1.0", "2026-08-01T12:00:00Z", signed=False)
        self.assemble()

        latest = self.latest()
        self.assertEqual(latest["version"], "0.3.0")
        self.assertEqual(latest["published"], "2026-10-20T09:30:00Z")
        self.assertEqual(latest["minimumSystemVersion"], "14.0")
        self.assertIs(latest["notarized"], True)
        for kind in ("dmg", "zip"):
            source = self.releases / "v0.3.0" / f"Grammar-Review-0.3.0.{kind}"
            published = self.out / "download" / f"Grammar-Review.{kind}"
            self.assertEqual(published.read_bytes(), source.read_bytes())
            self.assertEqual(latest["files"][kind], {
                "name": f"Grammar-Review.{kind}",
                "size": source.stat().st_size,
                "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            })

        items = self.items()
        self.assertEqual([item.findtext("title") for item in items], ["Version 0.3.0", "Version 0.2.0"], "unsigned releases aren't updates")
        newest = items[0]
        self.assertEqual(newest.findtext("pubDate"), "Tue, 20 Oct 2026 09:30:00 +0000")
        self.assertEqual(newest.findtext(f"{SPARKLE}version"), "0.3.0")
        self.assertEqual(newest.findtext(f"{SPARKLE}shortVersionString"), "0.3.0")
        self.assertEqual(newest.findtext(f"{SPARKLE}minimumSystemVersion"), "14.0.0")
        description = newest.find("description")
        self.assertEqual(description.get(f"{SPARKLE}format"), "markdown")
        self.assertEqual(description.text, "## What's new\n* Faster <checks> & fixes")
        self.assertIsNone(items[1].find("description"), "no notes, no description")
        enclosure = newest.find("enclosure")
        self.assertEqual(enclosure.get("url"), BASE_URL + "updates/Grammar-Review-0.3.0.zip")
        self.assertEqual(enclosure.get(f"{SPARKLE}edSignature"), signature(5))
        self.assertEqual(enclosure.get("type"), "application/octet-stream")
        archive = self.out / "updates" / "Grammar-Review-0.3.0.zip"
        self.assertEqual(enclosure.get("length"), str(archive.stat().st_size))
        self.assertEqual(sorted(path.name for path in (self.out / "updates").iterdir()), ["Grammar-Review-0.2.0.zip", "Grammar-Review-0.3.0.zip"])
        self.assertIn('xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"', (self.out / "appcast.xml").read_text())

    def test_unsigned_latest_release(self) -> None:
        self.add_release("0.2.0", "2026-10-20T09:30:00Z", notarized=False, signed=False)
        self.add_release("0.1.0", "2026-09-01T12:00:00Z")
        self.assemble()
        self.assertEqual(self.latest()["version"], "0.2.0")
        self.assertIs(self.latest()["notarized"], False)
        self.assertEqual([item.findtext(f"{SPARKLE}shortVersionString") for item in self.items()], ["0.1.0"])

    def test_latest_needs_both_files(self) -> None:
        newest = self.add_release("0.2.0", "2026-10-20T09:30:00Z")
        (newest / "Grammar-Review-0.2.0.dmg").unlink()
        self.add_release("0.1.0", "2026-09-01T12:00:00Z")
        self.assemble()
        self.assertEqual(self.latest()["version"], "0.1.0")
        self.assertEqual(len(self.items()), 2)

    def test_skips_unusable_releases(self) -> None:
        self.add_release("0.4.0", "2026-10-21T09:30:00Z", metadata={"version": "../../evil", "zip": "x.zip", "dmg": "x.dmg"})
        (self.releases / "v0.3.0").mkdir()
        (self.releases / "v0.3.0" / "github.json").write_text(json.dumps({"tagName": "v0.3.0", "publishedAt": "2026-10-20T00:00:00Z"}))
        broken = self.add_release("0.2.5", "2026-10-01T00:00:00Z")
        info = json.loads((broken / "release.json").read_text())
        info["sparkle"]["length"] += 1
        (broken / "release.json").write_text(json.dumps(info))
        self.add_release("0.2.0", "2026-09-01T12:00:00Z")
        result = self.assemble()
        self.assertEqual(self.latest()["version"], "0.2.5")
        self.assertEqual([item.findtext("title") for item in self.items()], ["Version 0.2.0"])
        self.assertIn("v0.4.0: unusable", result.stderr)
        self.assertIn("v0.3.0: no release.json", result.stderr)
        self.assertIn("v0.2.5: the zip's size doesn't match", result.stderr)

    def test_feed_keeps_the_newest_releases(self) -> None:
        for minor in range(1, 6):
            self.add_release(f"0.{minor}.0", f"2026-0{minor}-01T00:00:00Z")
        self.assemble("--limit", "3")
        self.assertEqual([item.findtext(f"{SPARKLE}shortVersionString") for item in self.items()], ["0.5.0", "0.4.0", "0.3.0"])
        self.assertEqual(len(list((self.out / "updates").iterdir())), 3)

    def test_warns_about_a_build_number_that_didnt_change(self) -> None:
        self.add_release("0.2.0", "2026-10-20T09:30:00Z", build="1")
        self.add_release("0.1.0", "2026-09-01T12:00:00Z", build="1")
        result = self.assemble()
        self.assertIn("CFBundleVersion 1", result.stderr)

    def test_fetches_only_what_it_needs_from_github(self) -> None:
        self.add_release("0.3.0", "2026-10-20T09:30:00Z", notes="Newest")
        self.add_release("0.2.0", "2026-09-01T12:00:00Z")
        self.add_release("0.1.0", "2026-08-01T12:00:00Z", signed=False)
        data = self.root / "github"
        for folder in sorted(self.releases.iterdir()):
            github = json.loads((folder / "github.json").read_text())
            shutil.copytree(folder, data / github["tagName"] / "assets", ignore=shutil.ignore_patterns("github.json"))
            (data / github["tagName"] / "view.json").write_text(json.dumps(github))
        (data / "v0.0.1" / "assets").mkdir(parents=True)
        (data / "v0.0.1" / "assets" / "Grammar Review.dmg").write_bytes(b"dmg")
        (data / "v0.0.1" / "view.json").write_text(json.dumps({"tagName": "v0.0.1", "publishedAt": "2026-07-01T00:00:00Z", "body": "", "url": ""}))
        (data / "order.json").write_text(json.dumps(["v0.3.0", "v0.2.0", "v0.1.0", "v0.0.1"]))
        bin_folder = self.root / "bin"
        bin_folder.mkdir()
        (bin_folder / "gh").write_text(f"#!{sys.executable}\n" + FAKE_GH)
        (bin_folder / "gh").chmod(0o755)

        environment = dict(os.environ, PATH=f"{bin_folder}{os.pathsep}{os.environ.get('PATH', '')}", FAKE_GH_DATA=str(data))
        result = subprocess.run(
            [sys.executable, "-I", str(SCRIPT), str(self.out), "--site", str(self.site), "--base-url", BASE_URL],
            capture_output=True,
            text=True,
            env=environment,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sorted((data / "downloads.log").read_text().splitlines()), sorted([
            "v0.3.0 release.json", "v0.3.0 Grammar-Review-0.3.0.zip", "v0.3.0 Grammar-Review-0.3.0.dmg",
            "v0.2.0 release.json", "v0.2.0 Grammar-Review-0.2.0.zip",
            "v0.1.0 release.json",
        ]))
        self.assertIn("v0.0.1: no release.json", result.stderr)
        self.assertEqual(self.latest()["version"], "0.3.0")
        self.assertEqual([item.findtext(f"{SPARKLE}shortVersionString") for item in self.items()], ["0.3.0", "0.2.0"])
        self.assertEqual(self.items()[0].findtext("description"), "Newest")

    def test_replaces_an_earlier_output(self) -> None:
        self.out.mkdir()
        (self.out / "stale.txt").write_text("old")
        self.assemble()
        self.assertFalse((self.out / "stale.txt").exists())


if __name__ == "__main__":
    unittest.main()
