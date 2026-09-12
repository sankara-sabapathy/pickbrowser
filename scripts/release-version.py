#!/usr/bin/env python3
"""An existing tag on HEAD is retry-stable; otherwise advance SemVer from VERSION/tags."""
import pathlib
import re
import subprocess


def parse(value):
    if not re.fullmatch(r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)", value):
        raise ValueError(f"Not a release version: {value!r}")
    return tuple(map(int, value.split(".")))


def next_version(base, all_tags, head_tags):
    def versions(tags):
        result = []
        for tag in tags:
            if tag.startswith("v"):
                try:
                    result.append(parse(tag[1:]))
                except ValueError:
                    pass
        return result

    existing = versions(head_tags)
    if existing:
        return ".".join(map(str, max(existing)))
    minimum = parse(base)
    latest = max(versions(all_tags), default=(-1, -1, -1))
    result = minimum if minimum > latest else (*latest[:2], latest[2] + 1)
    return ".".join(map(str, result))


if __name__ == "__main__":
    def tags(*args):
        return subprocess.check_output(["git", "tag", *args], text=True).splitlines()
    print(next_version(pathlib.Path("VERSION").read_text().strip(), tags(), tags("--points-at", "HEAD")))
