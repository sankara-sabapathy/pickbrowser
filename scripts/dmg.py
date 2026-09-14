"""Headless macOS installer packaging. No Finder automation or permissions needed."""
import contextlib
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile

from ds_store import DSStore
from mac_alias import Alias

ROOT = Path(__file__).resolve().parent.parent
POSITIONS = {"PickBrowser.app": (170, 190), "Applications": (430, 190)}
WINDOW = "{{120, 120}, {600, 380}}"


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


@contextlib.contextmanager
def mounted(image, readonly):
    # Private mount paths avoid collisions with an installer the user has open.
    # Never recursively remove a mount directory if detaching fails.
    mount = Path(tempfile.mkdtemp(prefix="pickbrowser-dmg-mount-"))
    attached = False
    try:
        subprocess.run(["hdiutil", "attach", str(image), "-mountpoint", str(mount),
                        "-readonly" if readonly else "-readwrite", "-nobrowse", "-noautoopen"], check=True)
        attached = True
        yield mount
    finally:
        if attached:
            run("hdiutil", "detach", mount, "-quiet")
        mount.rmdir()


def write_layout(mount):
    with DSStore.open(str(mount / ".DS_Store"), "w+") as store:
        store["."]["vSrn"] = ("long", 1)
        store["."]["icvl"] = ("type", b"icnv")
        store["."]["bwsp"] = {
            "WindowBounds": WINDOW, "ShowToolbar": False, "ShowStatusBar": False,
            "ShowSidebar": False, "ContainerShowSidebar": False, "ShowTabView": False,
            "ShowPathbar": False, "PreviewPaneVisibility": False, "SidebarWidth": 0,
        }
        store["."]["icvp"] = {
            "viewOptionsVersion": 1, "arrangeBy": "none", "iconSize": 96.0,
            "textSize": 14.0, "labelOnBottom": True, "showItemInfo": False,
            "showIconPreview": False, "gridSpacing": 100.0,
            "gridOffsetX": 0.0, "gridOffsetY": 0.0,
            "scrollPositionX": 0.0, "scrollPositionY": 0.0, "backgroundType": 2,
            "backgroundImageAlias": Alias.for_file(str(mount / ".background.tiff")).to_bytes(),
        }
        for name, position in POSITIONS.items():
            store[name]["Iloc"] = position


def verify(image, version):
    run("hdiutil", "verify", image)
    with mounted(image, readonly=True) as mount:
        app = mount / "PickBrowser.app"
        if not app.is_dir() or not (mount / "Applications").is_symlink():
            raise ValueError("Installer must contain PickBrowser.app and Applications shortcut")
        if os.readlink(mount / "Applications") != "/Applications":
            raise ValueError("Incorrect Applications shortcut")
        with (app / "Contents/Info.plist").open("rb") as file:
            info = plistlib.load(file)
        if version and info["CFBundleShortVersionString"] != version:
            raise ValueError("Installer version differs from release")
        run("codesign", "--verify", "--deep", "--strict", app)
        with DSStore.open(str(mount / ".DS_Store"), "r") as store:
            for name, position in POSITIONS.items():
                if tuple(store[name]["Iloc"]) != position:
                    raise ValueError(f"Wrong icon position: {name}")
            if store["."]["bwsp"]["WindowBounds"] != WINDOW:
                raise ValueError("Incorrect installer window bounds")
            if store["."]["icvp"]["arrangeBy"] != "none":
                raise ValueError("Finder must preserve manual icon positions")
            if not store["."]["icvp"].get("backgroundImageAlias"):
                raise ValueError("Missing installer background alias")
        if not (mount / ".background.tiff").is_file():
            raise ValueError("Missing installer instructions")
    print("Verified DMG: PickBrowser.app → Applications")


def build(app, output, version):
    if not app.is_dir() or output.suffix != ".dmg":
        raise ValueError("Expected an app bundle and a .dmg output path")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".dmg-build-", dir=output.parent) as work_path:
        work = Path(work_path)
        stage = work / "contents"
        stage.mkdir()
        run("ditto", app, stage / "PickBrowser.app")
        (stage / "Applications").symlink_to("/Applications")
        run("swift", ROOT / "scripts/dmg-background.swift", stage / ".background.tiff")
        writable = work / "writable.dmg"
        # A versioned volume name prevents Finder from reusing cached view state
        # from an older installer with the same volume name.
        run("hdiutil", "create", "-quiet", "-volname", f"PickBrowser {version}", "-srcfolder", stage,
            "-fs", "HFS+", "-format", "UDRW", writable)
        with mounted(writable, readonly=False) as mount:
            write_layout(mount)
        finished = work / "PickBrowser.dmg"
        run("hdiutil", "convert", writable, "-quiet", "-format", "UDZO",
            "-imagekey", "zlib-level=9", "-o", finished)
        identity = os.environ.get("PICKBROWSER_SIGNING_IDENTITY", "-")
        if identity != "-":
            run("codesign", "--sign", identity, "--timestamp", finished)
        verify(finished, version)
        if output.exists():
            backup = Path(tempfile.mkdtemp(prefix=".previous-dmg-", dir=output.parent)) / output.name
            output.rename(backup)
            print(f"Previous installer preserved at {backup}")
        finished.rename(output)
    print(f"Built {output}")


if __name__ == "__main__":
    if len(sys.argv) == 5 and sys.argv[1] == "build":
        build(Path(sys.argv[2]).resolve(), Path(sys.argv[3]).resolve(), sys.argv[4])
    elif len(sys.argv) == 4 and sys.argv[1] == "verify":
        verify(Path(sys.argv[2]).resolve(), sys.argv[3])
    else:
        sys.exit("Usage: dmg.py build APP OUTPUT VERSION | verify DMG VERSION")
