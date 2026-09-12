#!/usr/bin/env python3
"""Fail release if the signed feed is missing expected metadata or asset routing."""
import pathlib
import sys
import xml.etree.ElementTree as ET

feed, archive, version, repository = sys.argv[1:]
raw = pathlib.Path(feed).read_text()
assert "edSignature" in raw and "<!-- sparkle-signatures:" in raw, "Feed and archive must both be signed"
root = ET.fromstring(raw)
items = root.findall("./channel/item")
assert len(items) == 1, "Release feed must describe exactly the built release"
item = items[0]
ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
assert item.findtext("sparkle:version", namespaces=ns) == version
enclosure = item.find("enclosure")
assert enclosure is not None
assert enclosure.attrib["url"] == f"https://github.com/{repository}/releases/download/v{version}/PickBrowser-macOS.zip"
assert int(enclosure.attrib["length"]) == pathlib.Path(archive).stat().st_size
assert enclosure.attrib[f"{{{ns['sparkle']}}}edSignature"]
print("Release feed metadata verified")
