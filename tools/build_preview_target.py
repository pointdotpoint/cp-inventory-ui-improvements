#!/usr/bin/env python3
"""Builds the inventory preview's render target for PreviewZoom (PreviewPoses/PreviewZoom.reds).

The preview surface is enlarged to 4000 x 8000 so V can be moved and zoomed without being
cropped, so the render target is made portrait (1:2) and sharp enough for it, and the camera
gets a wide field of view that the zoom steps (camera setups 12-23) are tuned for. Same values
VFocus shipped; built from the vanilla files here so nothing of VFocus is redistributed.

Usage: build_preview_target.py <vanilla json root> <out root>
The roots hold base/gameplay/gui/fullscreen/inventory/{target.ent,preview.dtex}.json, as
written by `WolvenKit.CLI convert serialize`.
"""
import json
import sys
from pathlib import Path

FOLDER = Path("base/gameplay/gui/fullscreen/inventory")
WIDTH = 2880
HEIGHT = 5760
FOV = 99


def patch_target(data):
    """Sets resolution and field of view on every render-to-texture camera; returns the count."""
    count = 0

    def walk(node):
        nonlocal count
        if isinstance(node, dict):
            if node.get("$type") == "entRenderToTextureCameraComponent":
                node["fov"] = FOV
                node["resolutionWidth"] = WIDTH
                node["resolutionHeight"] = HEIGHT
                count += 1
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(data)
    return count


def patch_texture(data):
    chunk = data["Data"]["RootChunk"]
    chunk["width"] = WIDTH
    chunk["height"] = HEIGHT
    # Fixed size: scaled to the viewport it would drop back to screen resolution.
    chunk["scaleToViewport"] = 0


def main(source, out):
    target = json.loads((source / FOLDER / "target.ent.json").read_text())
    cameras = patch_target(target)
    if cameras != 2:
        sys.exit(f"expected 2 render-to-texture cameras in target.ent, found {cameras}")
    texture = json.loads((source / FOLDER / "preview.dtex.json").read_text())
    patch_texture(texture)
    (out / FOLDER).mkdir(parents=True, exist_ok=True)
    (out / FOLDER / "target.ent.json").write_text(json.dumps(target, indent=2))
    (out / FOLDER / "preview.dtex.json").write_text(json.dumps(texture, indent=2))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(Path(sys.argv[1]), Path(sys.argv[2]))
