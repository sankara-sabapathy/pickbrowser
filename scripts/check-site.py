#!/usr/bin/env python3
"""Check the buildless Pages entrypoint and every local asset reference."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
import subprocess

site = Path(__file__).resolve().parent.parent / "site"


class Check(HTMLParser):
    def handle_starttag(self, tag, attributes):
        attributes = dict(attributes)
        if tag == "img":
            assert "alt" in attributes, "Images need alternative text"
        for key in ("src", "href"):
            url = attributes.get(key, "")
            parsed = urlsplit(url)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            target = (site / unquote(parsed.path)).resolve()
            assert target.is_relative_to(site), f"Asset outside site: {url}"
            assert target.exists(), f"Missing site asset: {url}"


page = (site / "index.html").read_text()
assert '<html lang="en">' in page and 'name="viewport"' in page
Check().feed(page)
subprocess.run(["node", "--check", str(site / "release.js")], check=True)
print("Static website assets and JavaScript verified")
