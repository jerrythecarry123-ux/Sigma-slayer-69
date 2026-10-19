#!/usr/bin/env python3
"""Build a Roblox XML place from source, using only the Python standard library.

No downloads, plugins, Roblox credentials or changes to a user's place are needed.
The prototype's server script creates its isolated world when Play is pressed.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "ReplicatedStorage/FishingShared/FishingConfig": ("ModuleScript", "src/shared/FishingConfig.luau"),
    "ReplicatedStorage/FishingShared/FishingRules": ("ModuleScript", "src/shared/FishingRules.luau"),
    "ServerScriptService/FishingEngine": ("ModuleScript", "src/server/FishingEngine.luau"),
    "ServerScriptService/PrototypeWorld": ("ModuleScript", "src/server/PrototypeWorld.luau"),
    "ServerScriptService/FishingService": ("ModuleScript", "src/server/FishingService.luau"),
    "ServerScriptService/FishingServer": ("Script", "src/server/FishingServer.server.luau"),
    "StarterPlayer/StarterPlayerScripts/FishingClient": ("LocalScript", "src/client/FishingClient.client.luau"),
}


def build(output: Path) -> None:
    root = ET.Element("roblox", {"version": "4"})
    ET.SubElement(root, "External").text = "null"
    ET.SubElement(root, "External").text = "nil"
    nodes: dict[str, ET.Element] = {}

    def item(path: str, class_name: str) -> ET.Element:
        if path in nodes:
            return nodes[path]
        parent_path, _, name = path.rpartition("/")
        parent = nodes[parent_path] if parent_path else root
        node = ET.SubElement(parent, "Item", {
            "class": class_name, "referent": f"RBX{len(nodes) + 1:08X}",
        })
        properties = ET.SubElement(node, "Properties")
        ET.SubElement(properties, "string", {"name": "Name"}).text = name
        nodes[path] = node
        return node

    workspace = item("Workspace", "Workspace")
    ET.SubElement(workspace.find("Properties"), "float", {
        "name": "FallenPartsDestroyHeight",
    }).text = "-80"
    lighting = item("Lighting", "Lighting")
    ET.SubElement(lighting.find("Properties"), "float", {"name": "ClockTime"}).text = "14"
    for service in ("ReplicatedStorage", "ServerScriptService", "StarterPlayer", "StarterGui"):
        item(service, service)
    item("ReplicatedStorage/FishingShared", "Folder")
    item("StarterPlayer/StarterPlayerScripts", "StarterPlayerScripts")

    for path, (class_name, relative_source) in SOURCES.items():
        node = item(path, class_name)
        source = (ROOT / relative_source).read_text(encoding="utf-8")
        ET.SubElement(node.find("Properties"), "ProtectedString", {"name": "Source"}).text = source

    ET.indent(root, space="  ")
    output.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(root).write(output, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/Molnfiskarna-Prototype.rbxlx")
    args = parser.parse_args()
    build(args.output)
    print(f"Built {args.output} ({len(SOURCES)} Luau scripts)")
