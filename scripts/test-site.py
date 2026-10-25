#!/usr/bin/env python3
"""Checks site/index.html without a browser: structure, links, accessibility basics, the download
contract and the facts the page states about the app. Standard library only; CI and pages.yml run it
before deploying. The browser tests are in site/tests/ (Playwright).

    python3 scripts/test-site.py [path/to/index.html]
"""
import html.parser
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGE = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else os.path.join(ROOT, "site", "index.html")

ALLOWED_HOSTS = {"fonts.googleapis.com", "fonts.gstatic.com"}
REQUIRED_TEXT = [
    "⌃⌥G", "⌃⌥R", "⌃⌥W", "⌃⌥E",
    "macOS 14 or later",
    "Claude", "OpenAI", "xAI", "Gemini", "Mistral", "DeepSeek", "LM Studio", "Ollama",
    "Keychain", "Style Guide", "Write with AI", "Insights",
    "download/latest.json", "download/Grammar-Review.dmg", "download/Grammar-Review.zip",
    "scripts/run.sh", "github.com/modakoda/grammar-review",
]
FORBIDDEN_TEXT = ["TODO", "lorem ipsum", "Nothing except your settings is stored", "Nothing except settings is saved"]
DOWNLOAD_IDS = ["download", "dlMeta", "dlZip", "heroDlMeta", "dlInstall", "dlStepTitle", "dlStepText", "dlSha", "dlShaList", "start", "source", "startLede"]
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}


class Page(html.parser.HTMLParser):
    """Collects what the checks need in one pass."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids = []
        self.hrefs = []
        self.imgs = []
        self.headings = []
        self.scripts = []
        self.styles = []
        self.external = []
        self.titles = 0
        self.meta = {}
        self.lang = None
        self.stack = []
        self.unbalanced = []
        self.text = []
        self.landmarks = set()
        self.buttons_without_name = 0
        self.inline_handlers = 0
        self._in = None
        self._buf = []
        self._button = None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "html":
            self.lang = a.get("lang")
        if tag == "title":
            self.titles += 1
        if tag == "meta" and a.get("name"):
            self.meta[a["name"]] = a.get("content", "")
        if "id" in a:
            self.ids.append(a["id"])
        if tag == "a" and "href" in a:
            self.hrefs.append(a["href"])
        if tag == "img":
            self.imgs.append(a)
        if tag in ("main", "header", "footer", "nav"):
            self.landmarks.add(tag)
        if re.fullmatch(r"h[1-6]", tag):
            self.headings.append(int(tag[1]))
        for name, value in attrs:
            if name.startswith("on"):
                self.inline_handlers += 1
            if name in ("src", "href") and value and value.startswith(("http://", "https://", "//")):
                host = re.sub(r"^(https?:)?//", "", value).split("/")[0]
                if host not in ("github.com",):
                    self.external.append((tag, host))
        if tag == "script":
            self._in = "script"
            self._buf = []
            if a.get("src"):
                self.external.append(("script", a["src"]))
        elif tag == "style":
            self._in = "style"
            self._buf = []
        if tag == "button":
            self._button = {"attrs": a, "text": []}
        if tag not in VOID:
            self.stack.append(tag)

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        if tag == "script" and self._in == "script":
            self.scripts.append("".join(self._buf))
            self._in = None
        elif tag == "style" and self._in == "style":
            self.styles.append("".join(self._buf))
            self._in = None
        if tag == "button" and self._button is not None:
            b = self._button
            name = "".join(b["text"]).strip() or b["attrs"].get("aria-label") or b["attrs"].get("title")
            if not name:
                self.buttons_without_name += 1
            self._button = None
        if self.stack and self.stack[-1] == tag:
            self.stack.pop()
        else:
            self.unbalanced.append(tag)

    def handle_data(self, data):
        if self._in:
            self._buf.append(data)
        else:
            self.text.append(data)
            if self._button is not None:
                self._button["text"].append(data)


def parse():
    with open(PAGE, encoding="utf-8") as f:
        source = f.read()
    page = Page()
    page.feed(source)
    page.close()
    return source, page


SOURCE, P = parse()
TEXT = " ".join(P.text)


class Structure(unittest.TestCase):
    def test_document_basics(self):
        self.assertTrue(SOURCE.lstrip().lower().startswith("<!doctype html>"))
        self.assertEqual(P.lang, "en")
        self.assertEqual(P.titles, 1)
        self.assertIn("viewport", P.meta)
        self.assertIn("width=device-width", P.meta["viewport"])
        self.assertTrue(P.meta.get("description"))
        self.assertIn("color-scheme", P.meta)

    def test_tags_are_balanced(self):
        self.assertEqual(P.unbalanced, [], f"closing tags without an opening one: {P.unbalanced}")
        self.assertEqual(P.stack, [], f"never closed: {P.stack}")

    def test_ids_are_unique(self):
        dupes = sorted({i for i in P.ids if P.ids.count(i) > 1})
        self.assertEqual(dupes, [], f"duplicate ids: {dupes}")

    def test_anchor_links_resolve(self):
        ids = set(P.ids)
        broken = sorted({h for h in P.hrefs if h.startswith("#") and h != "#" and h[1:] not in ids})
        self.assertEqual(broken, [], f"links to missing ids: {broken}")

    def test_landmarks_and_skip_link(self):
        self.assertTrue({"main", "header", "footer", "nav"} <= P.landmarks)
        self.assertIn("#main", P.hrefs)

    def test_headings_make_an_outline(self):
        self.assertEqual(P.headings.count(1), 1, "exactly one h1")
        self.assertEqual(P.headings[0], 1, "the h1 comes first")
        for previous, current in zip(P.headings, P.headings[1:]):
            self.assertLessEqual(current, previous + 1, f"heading level jumps from h{previous} to h{current}")

    def test_images_have_alt_text(self):
        for img in P.imgs:
            self.assertIn("alt", img, f"img without alt: {img}")
            self.assertTrue(img.get("src"))
            self.assertTrue(os.path.exists(os.path.join(os.path.dirname(PAGE), img["src"])), f"missing image {img['src']}")

    def test_buttons_have_names(self):
        self.assertEqual(P.buttons_without_name, 0)

    def test_no_inline_event_handlers(self):
        self.assertEqual(P.inline_handlers, 0)

    def test_only_fonts_come_from_outside(self):
        hosts = {host for _, host in P.external if "/" not in host}
        self.assertTrue(hosts <= ALLOWED_HOSTS, f"unexpected external hosts: {hosts - ALLOWED_HOSTS}")
        self.assertFalse([s for t, s in P.external if t == "script"], "scripts must be inline")
        self.assertEqual(len(P.scripts), 1, "one inline script")

    def test_theme_and_motion_are_handled(self):
        css = "\n".join(P.styles)
        self.assertIn("prefers-color-scheme: light", css)
        self.assertIn("prefers-reduced-motion: reduce", css)
        self.assertIn(":focus-visible", css)
        self.assertIn("--red", css)


class Content(unittest.TestCase):
    def test_states_the_facts(self):
        everything = SOURCE
        for needle in REQUIRED_TEXT:
            self.assertIn(needle, everything, f"the page should mention {needle!r}")

    def test_has_no_stale_wording(self):
        for needle in FORBIDDEN_TEXT:
            self.assertNotIn(needle.lower(), SOURCE.lower(), f"stale or placeholder text: {needle!r}")

    def test_download_contract(self):
        ids = set(P.ids)
        missing = [i for i in DOWNLOAD_IDS if i not in ids]
        self.assertEqual(missing, [], f"the download script needs these ids: {missing}")
        self.assertGreaterEqual(SOURCE.count("data-dl"), 3, "download buttons in the nav, hero and card")
        script = P.scripts[0]
        for needle in ("download/latest.json", "notarized", "minimumSystemVersion", "sha256", "releaseSoon", "releaseReady"):
            self.assertIn(needle, script)
        self.assertIn('data-state="soon"', SOURCE, "the page starts in the no-release state")
        self.assertIn("First release coming soon", SOURCE)

    def test_models_section_lists_every_service(self):
        for name in ("Claude", "GPT", "Grok", "Gemini", "Mistral", "DeepSeek", "Local model"):
            self.assertIn(f"<b>{name}</b>", SOURCE, f"a brain card for {name}")


class Script(unittest.TestCase):
    def test_javascript_parses(self):
        node = shutil.which("node")
        if not node:
            self.skipTest("node isn't installed")
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as f:
            f.write(P.scripts[0])
            path = f.name
        try:
            result = subprocess.run([node, "--check", path], capture_output=True, text=True)
        finally:
            os.unlink(path)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_script_is_strict_and_self_contained(self):
        script = P.scripts[0]
        self.assertIn("'use strict'", script)
        self.assertNotIn("document.write", script)
        self.assertNotIn("eval(", script)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]] + [a for a in sys.argv[1:] if a.startswith("-")], verbosity=1)
