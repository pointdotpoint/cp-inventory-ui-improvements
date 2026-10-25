#!/usr/bin/env python3
"""Build a separate seven-column card grid from serialized Equipment-EX wardrobe JSON.

Cells are 192 x 216: the item display (224 x 202, scaled to 0.75 at runtime) on top and
room for a two-line item name under it, which WardrobeTabs.reds adds to each cell.

Usage: build_wardrobe_grid.py wardrobe.inkwidget.json grid.inkwidget.json
Deserialize the output with WolvenKit, then pack at wardrobe_tabs/gui/grid.inkwidget.
"""
import copy
import json
import sys
from pathlib import Path

COLUMNS = 7
CELL_HEIGHT = 216
GRID_NAME = "wardrobeCardGrid"
CELL_NAME = "wardrobeCardItem"


def find_widget(value, name):
    if isinstance(value, dict):
        if value.get("name", {}).get("$value") == name:
            return value
        for child in value.values():
            found = find_widget(child, name)
            if found is not None:
                return found
    elif isinstance(value, list):
        for child in value:
            found = find_widget(child, name)
            if found is not None:
                return found
    return None


def instances(item):
    # Both the editor package and the cooked package must describe the same geometry.
    return (item["package"]["Data"]["File"]["RootChunk"],
            item["packageData"]["Data"]["Chunks"][0])


def build(source):
    result = copy.deepcopy(source)
    library = result["Data"]["RootChunk"]
    items = {item["name"]["$value"]: item for item in library["libraryItems"]}
    root = copy.deepcopy(items["InventoryGridSlot"])
    root["name"]["$value"] = "Root"
    cell = items["InventoryGridItem"]
    for original, target, item in zip(instances(items["Root"]), instances(root), instances(cell)):
        grid = copy.deepcopy(find_widget(original, "vendor_virtualgrid"))
        assert grid is not None, "Equipment-EX grid layout changed"
        assert grid["size"]["X"] == 1344
        assert grid["children"]["Data"]["children"] == []
        templates = grid["logicController"]["Data"]["itemTemplates"]
        assert len(templates) == 2
        assert templates[0]["widgetItem"]["$value"] == "InventoryGridItem:EquipmentEx.InventoryGridItemController"
        assert templates[1]["widgetItem"]["$value"] == "InventoryGridSlot:EquipmentEx.InventoryGridSlotController"
        templates[0]["widgetLibrary"]["library"]["DepotPath"]["$value"] = "wardrobe_tabs\\gui\\grid.inkwidget"
        grid["parentWidget"] = None
        grid["name"]["$value"] = GRID_NAME
        grid["userData"] = target["rootWidget"]["Data"]["userData"]
        target["rootWidget"]["Data"] = grid
        target["gameController"] = None
        widget = item["rootWidget"]["Data"]
        assert (widget["size"]["X"], widget["size"]["Y"]) == (224, 202)
        widget["size"].update(X=grid["size"]["X"] / COLUMNS, Y=CELL_HEIGHT)
        widget["name"]["$value"] = CELL_NAME
        assert round(grid["size"]["X"] / widget["size"]["X"]) == COLUMNS
    library["libraryItems"] = [root, cell]
    library["rootDefinitionIndex"] = 0
    library["externalDependenciesForInternalItems"] = []
    library["externalLibraries"] = []
    return result


if __name__ == "__main__":
    source_path, output_path = map(Path, sys.argv[1:])
    output = build(json.loads(source_path.read_text()))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(output, indent=2) + "\n")
    print(f"Built {output_path}: {COLUMNS} columns of {1344 / COLUMNS} x {CELL_HEIGHT}")
