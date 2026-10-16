#!/usr/bin/env python3
"""Writes the installed female photo-mode pose list for the inventory preview.

Scans this machine's Cyberpunk 2077 install and writes:

  tools/poses_female.txt
  mod/archive/pc/mod/PreviewPoses.archive.xl
  mod/r6/tweaks/PreviewPoses/poses.yaml

Vanilla clips come from the five female body animsets (natural, idle, action,
and the two Phantom Liberty sets), read as WolvenKit JSON. Mod clips are the
PhotoModePoses records appended to photo_mode.character.femalePoses. A clip
already claimed by an earlier pack is kept once. Facial sets, male poses, and
NPC-only poses are not listed.

The .xl attaches the five vanilla sets, plus every mod set aimed at a female
photo mode entity, to both preview entities. Those entities are also V's
third-person body, so the sets load during gameplay.

A pack installed after this run is absent until the script is run again and
the paperdoll graph is rebuilt with tools/build_pose_graph.py.
"""
import json
import os
import re
import subprocess
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
GAME = os.environ.get(
    "GAME",
    os.path.expanduser("~/.local/share/Steam/steamapps/common/Cyberpunk 2077"),
)
POSE_LIST = os.path.join(TOOLS, "poses_female.txt")
XL_PATH = os.path.join(ROOT, "mod", "archive", "pc", "mod", "PreviewPoses.archive.xl")
CACHE = os.environ.get("PREVIEW_POSES_CACHE", "/tmp/preview-poses-vanilla")

PREVIEW_ENTITIES = (
    r"ep1\characters\entities\player\player_wa_tpp_ep1.ent",
    r"base\characters\entities\player\player_wa_tpp.ent",
)

# Pack name, archive relative to the game, extract regex, path inside the archive.
VANILLA_SETS = (
    (
        "natural",
        "archive/pc/content/basegame_4_animation.archive",
        r"photomode__v_female__natural\.anims$",
        "base/animations/ui/photomode/photomode__v_female__natural.anims",
    ),
    (
        "idle",
        "archive/pc/content/basegame_4_animation.archive",
        r"photomode__female__idle\.anims$",
        "base/animations/ui/photomode/photomode__female__idle.anims",
    ),
    (
        "action",
        "archive/pc/content/basegame_4_animation.archive",
        r"photomode__female__action\.anims$",
        "base/animations/ui/photomode/photomode__female__action.anims",
    ),
    (
        "ep1 idle",
        "archive/pc/ep1/ep1_2_gamedata.archive",
        r"ep1_photomode__female__idle\.anims$",
        "ep1/animations/ui/photomode/ep1_photomode__female__idle.anims",
    ),
    (
        "ep1 action",
        "archive/pc/ep1/ep1_2_gamedata.archive",
        r"ep1_photomode__female__action\.anims$",
        "ep1/animations/ui/photomode/ep1_photomode__female__action.anims",
    ),
)

# JSON already serialized in this workspace's earlier extracts. Used when present
# so a rerun does not have to extract the vanilla sets again.
KNOWN_JSON = {
    "natural": "/tmp/pm-graph/base/animations/ui/photomode/photomode__v_female__natural.anims.json",
    "idle": "/tmp/pm-graph/base/animations/ui/photomode/photomode__female__idle.anims.json",
    "action": "/tmp/pm-graph/base/animations/ui/photomode/photomode__female__action.anims.json",
    "ep1 idle": "/tmp/pose-anims/ep1/animations/ui/photomode/ep1_photomode__female__idle.anims.json",
    "ep1 action": "/tmp/pose-anims/ep1/animations/ui/photomode/ep1_photomode__female__action.anims.json",
}

ANIMATION_PACKS_TWEAK = "PhotoModeUIImprovements/animations.yaml"

FEMALE_KEY = re.compile(r"^photo_mode\.character\.femalePoses\s*:")
FIELD_KEY = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$")


def record_id(stripped, prefix):
    """Id from a top-level `Prefix.<id>:` line. Ids may contain spaces."""
    if not stripped.startswith(prefix):
        return None
    body = stripped[len(prefix):]
    if not body.endswith(":"):
        return None
    name = body[:-1].strip()
    if not name:
        return None
    return name


def append_ref(stripped):
    """Pose id from a femalePoses list item. The id may contain spaces."""
    if not stripped.startswith("-"):
        return None
    marker = "PhotoModePoses."
    at = stripped.find(marker)
    if at < 0:
        return None
    ref = stripped[at + len(marker):].strip()
    if " #" in ref:
        ref = ref.split(" #", 1)[0].rstrip()
    if not ref or ref.endswith(":"):
        return None
    return ref


def indent_of(line):
    width = 0
    for char in line:
        if char == " ":
            width += 1
        elif char == "\t":
            width += 4
        else:
            break
    return width


def unquote(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        body = value[1:-1]
        if value[0] == '"':
            body = body.replace('\\"', '"').replace("\\\\", "\\")
        return body
    return value


def clip_names(json_path):
    doc = json.load(open(json_path))
    found = []

    def walk(obj):
        if isinstance(obj, dict):
            anims = obj.get("animations")
            if isinstance(anims, list) and anims and isinstance(anims[0], dict) and "Data" in anims[0]:
                found.append(anims)
                return
            for value in obj.values():
                walk(value)
        elif isinstance(obj, list):
            for value in obj:
                walk(value)

    walk(doc)
    if not found:
        raise SystemExit(f"{json_path}: no animations")
    names = []
    for entry in found[0]:
        try:
            name = entry["Data"]["animation"]["Data"]["name"]["$value"]
        except (KeyError, TypeError):
            continue
        if isinstance(name, str) and name and name != "None":
            names.append(name)
    if not names:
        raise SystemExit(f"{json_path}: no clip names")
    return names


def ensure_json(pack, archive_rel, regex, inner_rel):
    known = KNOWN_JSON.get(pack)
    if known and os.path.isfile(known):
        return known
    cached = os.path.join(CACHE, inner_rel + ".json")
    if os.path.isfile(cached):
        return cached
    archive = os.path.join(GAME, archive_rel)
    if not os.path.isfile(archive):
        raise SystemExit(f"missing archive {archive}")
    os.makedirs(CACHE, exist_ok=True)
    subprocess.run(
        ["WolvenKit.CLI", "extract", archive, "-o", CACHE, "-r", regex],
        check=True,
    )
    binary = os.path.join(CACHE, inner_rel)
    if not os.path.isfile(binary):
        raise SystemExit(f"extract did not write {binary}")
    subprocess.run(["WolvenKit.CLI", "convert", "serialize", binary], check=True)
    if not os.path.isfile(cached):
        raise SystemExit(f"serialize did not write {cached}")
    return cached


def vanilla_packs():
    packs = []
    seen = set()
    for pack, archive_rel, regex, inner_rel in VANILLA_SETS:
        path = ensure_json(pack, archive_rel, regex, inner_rel)
        clips = []
        skipped = 0
        for name in clip_names(path):
            if name in seen:
                skipped += 1
                continue
            seen.add(name)
            clips.append(name)
        print(f"vanilla {pack}: {len(clips)} clips ({skipped} already listed)")
        if clips:
            packs.append((pack, clips))
    return packs, seen


def is_generated_animations(path):
    """PhotoModeUIImprovements' AMM animation packs. They reuse clips that real pose packs
    also list, so they are read last: a clip then stays in its pose pack."""
    rel = os.path.relpath(path, os.path.join(GAME, "r6", "tweaks")).replace("\\", "/")
    return rel.lower() == ANIMATION_PACKS_TWEAK.lower()


def tweak_files():
    root = os.path.join(GAME, "r6", "tweaks")
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for name in sorted(filenames):
            if name.endswith((".yaml", ".yml")):
                found.append(os.path.join(dirpath, name))
    found.sort(key=is_generated_animations)
    return found


def parse_tweaks():
    """Pose records, category display names, and femalePoses append order."""
    poses = {}
    categories = {}
    order = []
    for path in tweak_files():
        with open(path, errors="replace") as handle:
            lines = handle.read().splitlines()
        index = 0
        while index < len(lines):
            line = lines[index]
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                index += 1
                continue
            pose_name = record_id(stripped, "PhotoModePoses.") if indent_of(line) == 0 else None
            cat_name = record_id(stripped, "PhotoModePoseCategories.") if indent_of(line) == 0 else None
            female_match = FEMALE_KEY.match(stripped) if indent_of(line) == 0 else None
            if pose_name or cat_name:
                kind = "pose" if pose_name else "cat"
                name = pose_name or cat_name
                base = indent_of(line)
                fields = {}
                index += 1
                while index < len(lines):
                    inner = lines[index]
                    inner_stripped = inner.strip()
                    if not inner_stripped or inner_stripped.startswith("#"):
                        index += 1
                        continue
                    if indent_of(inner) <= base:
                        break
                    field = FIELD_KEY.match(inner_stripped)
                    if field:
                        fields[field.group(1)] = unquote(field.group(2))
                    index += 1
                if kind == "pose":
                    poses[name] = fields
                else:
                    categories[name] = fields
                continue
            if female_match:
                base = indent_of(line)
                header_ref = append_ref(stripped)
                if header_ref:
                    order.append(header_ref)
                index += 1
                while index < len(lines):
                    inner = lines[index]
                    inner_stripped = inner.strip()
                    if not inner_stripped or inner_stripped.startswith("#"):
                        index += 1
                        continue
                    # YAML permits sequence dashes at the mapping key's indentation.
                    if indent_of(inner) <= base and not inner_stripped.startswith("-"):
                        break
                    ref = append_ref(inner_stripped)
                    if ref:
                        order.append(ref)
                    index += 1
                continue
            index += 1
    return poses, categories, order


def mod_packs(seen):
    poses, categories, order = parse_tweaks()
    groups = []
    index_of = {}
    missing = 0
    skipped = 0
    added = 0
    for pose_id in order:
        record = poses.get(pose_id)
        if record is None or not record.get("animationName"):
            missing += 1
            continue
        animation = record["animationName"]
        if animation in seen:
            skipped += 1
            continue
        category = record.get("category", "")
        if category.startswith("PhotoModePoseCategories."):
            category = category.split(".", 1)[1]
        display = categories.get(category, {}).get("displayName", "").strip()
        pack = display or category or "unknown"
        seen.add(animation)
        if pack not in index_of:
            index_of[pack] = len(groups)
            groups.append((pack, []))
        groups[index_of[pack]][1].append(animation)
        added += 1
    print(f"mods: {added} clips, {len(groups)} packs, {skipped} already listed, {missing} missing records")
    return groups


def write_pose_list(packs):
    lines = [
        "# Female body poses for the inventory preview, in switch order.",
        "# `# pack: name` starts a pack. A single-word `# name` comment does too.",
        "# Pose 0 is the vanilla preview pose and is not in this file.",
        "# Regenerated by tools/build_installed_poses.py from the current install.",
        "",
    ]
    for name, clips in packs:
        if "\n" in name or "\r" in name:
            raise SystemExit(f"pack name {name!r} spans lines")
        lines.append(f"# pack: {name}")
        lines.extend(clips)
        lines.append("")
    with open(POSE_LIST, "w") as handle:
        handle.write("\n".join(lines))


def is_female_photo_entity(entity):
    normalized = entity.replace("/", "\\").strip().lower()
    base = normalized.split("\\")[-1]
    if base == "photomode_wa.ent":
        return True
    return "player_wa_photomode" in normalized


def mod_sets():
    root = os.path.join(GAME, "archive", "pc", "mod")
    found = []
    seen = set()
    files = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for name in sorted(filenames):
            if name.endswith(".xl"):
                files.append(os.path.join(dirpath, name))
    files.sort()
    for path in files:
        # This file is rewritten by this script. Its preview-entity entries are not photo mode sets.
        if os.path.basename(path) == "PreviewPoses.archive.xl":
            continue
        lines = open(path, errors="replace").read().splitlines()
        in_animations = False
        block_indent = 0
        entity = None
        for line in lines:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            indent = indent_of(line)
            if re.match(r"animations\s*:\s*$", stripped):
                in_animations = True
                block_indent = indent
                entity = None
                continue
            if not in_animations:
                continue
            if indent <= block_indent:
                in_animations = False
                entity = None
                continue
            entity_match = re.match(r"^-?\s*entity\s*:\s*(.+)$", stripped)
            if entity_match:
                entity = unquote(entity_match.group(1))
                continue
            set_match = re.match(r"^-?\s*set\s*:\s*(.+)$", stripped)
            if set_match and entity and is_female_photo_entity(entity):
                animset = unquote(set_match.group(1)).replace("/", "\\")
                key = animset.lower()
                if key not in seen:
                    seen.add(key)
                    found.append(animset)
    return found


def write_xl(sets):
    lines = [
        "# Female photo mode animation sets for the inventory and wardrobe preview.",
        "# These entities are also V's third-person body, so the sets load with V",
        "# during gameplay, not only while a menu is open.",
        "# Regenerated by tools/build_installed_poses.py from the current install.",
        "animations:",
    ]
    for entity in PREVIEW_ENTITIES:
        for animset in sets:
            lines.append(f"  - entity: {entity}")
            lines.append(f"    set: {animset}")
    lines.append("")
    os.makedirs(os.path.dirname(XL_PATH), exist_ok=True)
    with open(XL_PATH, "w") as handle:
        handle.write("\n".join(lines))


def main():
    if not os.path.isdir(os.path.join(GAME, "r6", "tweaks")):
        raise SystemExit(f"game tweaks not found under {GAME}")
    packs, seen = vanilla_packs()
    packs.extend(mod_packs(seen))
    if not packs:
        raise SystemExit("no poses")
    write_pose_list(packs)
    sys.path.insert(0, TOOLS)
    import build_pose_graph
    poses, pack_of, pack_names = build_pose_graph.load_pose_file()
    build_pose_graph.write_catalog(poses, pack_of, pack_names)
    vanilla_paths = [item[3].replace("/", "\\") for item in VANILLA_SETS]
    sets = []
    seen_sets = set()
    for animset in vanilla_paths + mod_sets():
        key = animset.lower()
        if key in seen_sets:
            continue
        seen_sets.add(key)
        sets.append(animset)
    write_xl(sets)
    print(f"wrote {len(poses)} poses in {len(pack_names)} packs, {len(sets)} animation sets")
    for name in pack_names[:8]:
        count = sum(1 for pack in pack_of if pack_names[pack] == name)
        print(f"  {count:4}  {name}")
    if len(pack_names) > 8:
        print(f"  ... {len(pack_names) - 8} more packs")


if __name__ == "__main__":
    main()
