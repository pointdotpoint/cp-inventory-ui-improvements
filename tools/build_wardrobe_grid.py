#!/usr/bin/env python3
"""Build the card grids (4 to 7 columns) from serialized Equipment-EX wardrobe JSON.

One grid per column count, library items Root4..Root7, each with its own cell item
(wardrobeCell4..wardrobeCell7) of width 1344 / columns and proportional height (192 x 216
at seven columns): the item display (224 x 202, scaled at runtime to the cell) on top and
room for a two-line item name under it, which WardrobeTabs.reds adds to each cell. Cell
roots are all named wardrobeCardItem, which is how the script recognises them.

Usage: build_wardrobe_grid.py wardrobe.inkwidget.json grid.inkwidget.json
Deserialize the output with WolvenKit, then pack at wardrobe_tabs/gui/grid.inkwidget.
"""
import copy
import json
import sys
from pathlib import Path

COLUMNS = (7, 6, 5, 4)
CELL_HEIGHT_AT_7 = 216
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


def renumber(value, offset):
    """Shifts every HandleId / HandleRefId in one library item: WolvenKit's JSON wants handle
    ids unique across the file, and the copies would repeat them."""
    if isinstance(value, dict):
        for key in ("HandleId", "HandleRefId"):
            if key in value:
                value[key] = str(int(value[key]) + offset)
        for child in value.values():
            renumber(child, offset)
    elif isinstance(value, list):
        for child in value:
            renumber(child, offset)


def instances(item):
    # Both the editor package and the cooked package must describe the same geometry.
    return (item["package"]["Data"]["File"]["RootChunk"],
            item["packageData"]["Data"]["Chunks"][0])


def build(source):
    result = copy.deepcopy(source)
    library = result["Data"]["RootChunk"]
    items = {item["name"]["$value"]: item for item in library["libraryItems"]}
    roots, cells = [], []
    for columns in COLUMNS:
        root = copy.deepcopy(items["InventoryGridSlot"])
        root["name"]["$value"] = f"Root{columns}"
        cell = copy.deepcopy(items["InventoryGridItem"])
        cell["name"]["$value"] = f"wardrobeCell{columns}"
        build_one(items, root, cell, columns)
        renumber(root, 10000 * columns)
        renumber(cell, 10000 * columns + 5000)
        roots.append(root)
        cells.append(cell)
    library["libraryItems"] = roots + cells
    # Each item's cooked package is a buffer numbered in item order; copies would repeat ids.
    for index, item in enumerate(library["libraryItems"]):
        item["packageData"]["BufferId"] = str(index)
    library["rootDefinitionIndex"] = 0
    library["externalDependenciesForInternalItems"] = []
    library["externalLibraries"] = []
    return result


def build_one(items, root, cell, columns):
    for original, target, item in zip(instances(items["Root"]), instances(root), instances(cell)):
        grid = copy.deepcopy(find_widget(original, "vendor_virtualgrid"))
        assert grid is not None, "Equipment-EX grid layout changed"
        assert grid["size"]["X"] == 1344
        assert grid["children"]["Data"]["children"] == []
        templates = grid["logicController"]["Data"]["itemTemplates"]
        assert len(templates) == 2
        assert templates[0]["widgetItem"]["$value"] == "InventoryGridItem:EquipmentEx.InventoryGridItemController"
        assert templates[1]["widgetItem"]["$value"] == "InventoryGridSlot:EquipmentEx.InventoryGridSlotController"
        templates[0]["widgetItem"]["$value"] = f"wardrobeCell{columns}:EquipmentEx.InventoryGridItemController"
        templates[0]["widgetLibrary"]["library"]["DepotPath"]["$value"] = "wardrobe_tabs\\gui\\grid.inkwidget"
        grid["parentWidget"] = None
        grid["name"]["$value"] = GRID_NAME
        grid["userData"] = target["rootWidget"]["Data"]["userData"]
        target["rootWidget"]["Data"] = grid
        target["gameController"] = None
        widget = item["rootWidget"]["Data"]
        assert (widget["size"]["X"], widget["size"]["Y"]) == (224, 202)
        widget["size"].update(X=grid["size"]["X"] / columns, Y=CELL_HEIGHT_AT_7 * 7 / columns)
        widget["name"]["$value"] = CELL_NAME
        assert round(grid["size"]["X"] / widget["size"]["X"]) == columns


if __name__ == "__main__":
    source_path, output_path = map(Path, sys.argv[1:])
    output = build(json.loads(source_path.read_text()))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(output, indent=2) + "\n")
    for columns in COLUMNS:
        print(f"Root{columns}: {columns} columns of {1344 / columns:.1f} x {CELL_HEIGHT_AT_7 * 7 / columns:.1f}")
    print(f"Built {output_path}")
