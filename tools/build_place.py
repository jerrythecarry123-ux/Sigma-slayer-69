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
PLACE_NAME = "Cloud-Anglers-v0.8.rbxlx"
SOURCES = {
    "ReplicatedStorage/FishingShared/FishingConfig": ("ModuleScript", "src/shared/FishingConfig.luau"),
    "ReplicatedStorage/FishingShared/FishingRules": ("ModuleScript", "src/shared/FishingRules.luau"),
    "ReplicatedStorage/FishingShared/FishModel": ("ModuleScript", "src/shared/FishModel.luau"),
    "ReplicatedStorage/FishingShared/FishCatalog": ("ModuleScript", "src/shared/FishCatalog.luau"),
    "ReplicatedStorage/FishingShared/IslandTravelRules": ("ModuleScript", "src/shared/IslandTravelRules.luau"),
    "ServerScriptService/FishingEngine": ("ModuleScript", "src/server/FishingEngine.luau"),
    "ServerScriptService/WorldPrimitives": ("ModuleScript", "src/server/WorldPrimitives.luau"),
    "ServerScriptService/WorldNature": ("ModuleScript", "src/server/WorldNature.luau"),
    "ServerScriptService/WorldArchitecture": ("ModuleScript", "src/server/WorldArchitecture.luau"),
    "ServerScriptService/WorldLandscaping": ("ModuleScript", "src/server/WorldLandscaping.luau"),
    "ServerScriptService/WorldResidents": ("ModuleScript", "src/server/WorldResidents.luau"),
    "ServerScriptService/WorldPondBackdrops": ("ModuleScript", "src/server/WorldPondBackdrops.luau"),
    "ServerScriptService/WorldDockDetails": ("ModuleScript", "src/server/WorldDockDetails.luau"),
    "ServerScriptService/WorldTrailDetails": ("ModuleScript", "src/server/WorldTrailDetails.luau"),
    "ServerScriptService/WorldLayout": ("ModuleScript", "src/server/WorldLayout.luau"),
    "ServerScriptService/IslandTravel": ("ModuleScript", "src/server/IslandTravel.luau"),
    "ServerScriptService/PrototypeWorld": ("ModuleScript", "src/server/PrototypeWorld.luau"),
    "ServerScriptService/FishingLocations": ("ModuleScript", "src/server/FishingLocations.luau"),
    "ServerScriptService/FishingService": ("ModuleScript", "src/server/FishingService.luau"),
    "ServerScriptService/FishingProgression": ("ModuleScript", "src/server/FishingProgression.luau"),
    "ServerScriptService/FishingSaveRules": ("ModuleScript", "src/server/FishingSaveRules.luau"),
    "ServerScriptService/FishingProfileStore": ("ModuleScript", "src/server/FishingProfileStore.luau"),
    "ServerScriptService/FishingServer": ("Script", "src/server/FishingServer.server.luau"),
    "StarterPlayer/StarterPlayerScripts/FishingClient": ("LocalScript", "src/client/FishingClient.client.luau"),
    "StarterPlayer/StarterPlayerScripts/FishingAudio": ("ModuleScript", "src/client/FishingAudio.luau"),
    "StarterPlayer/StarterPlayerScripts/FishingPresentation": ("ModuleScript", "src/client/FishingPresentation.luau"),
    "StarterPlayer/StarterPlayerScripts/ResidentPresentation": ("ModuleScript", "src/client/ResidentPresentation.luau"),
    "StarterPlayer/StarterPlayerScripts/IslandTravelInterface": ("ModuleScript", "src/client/IslandTravelInterface.luau"),
    "StarterPlayer/StarterPlayerScripts/WorldScenery": ("ModuleScript", "src/client/WorldScenery.luau"),
    "StarterPlayer/StarterPlayerScripts/InterfaceLayout": ("ModuleScript", "src/client/InterfaceLayout.luau"),
    "StarterPlayer/StarterPlayerScripts/UITheme": ("ModuleScript", "src/client/UITheme.luau"),
    "StarterPlayer/StarterPlayerScripts/FishingInterface": ("ModuleScript", "src/client/FishingInterface.luau"),
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

    def property_value(node: ET.Element, kind: str, name: str, value: str) -> None:
        ET.SubElement(node.find("Properties"), kind, {"name": name}).text = value

    def color_value(node: ET.Element, name: str, rgb: tuple[int, int, int]) -> None:
        color = ET.SubElement(node.find("Properties"), "Color3", {"name": name})
        for channel, value in zip(("R", "G", "B"), rgb):
            ET.SubElement(color, channel).text = str(value / 255)

    workspace = item("Workspace", "Workspace")
    property_value(workspace, "float", "FallenPartsDestroyHeight", "-250")
    # Streaming properties are configured in the place, never from runtime Luau.
    # Keep a small guaranteed radius so the engine can scale down on phones.
    property_value(workspace, "bool", "StreamingEnabled", "true")
    property_value(workspace, "int", "StreamingMinRadius", "64")
    property_value(workspace, "int", "StreamingTargetRadius", "768")
    property_value(workspace, "token", "ModelStreamingBehavior", "2")  # Improved
    property_value(workspace, "token", "StreamingIntegrityMode", "3")  # PauseOutsideLoadedArea
    property_value(workspace, "token", "StreamOutBehavior", "2")  # Opportunistic

    lighting = item("Lighting", "Lighting")
    # Current Roblox lighting replaces the legacy Technology selection. These
    # two properties require Studio/plugin capability, so serialize them here.
    property_value(lighting, "token", "LightingStyle", "1")  # Soft: clear classic-brick lighting
    property_value(lighting, "bool", "PrioritizeLightingQuality", "true")
    property_value(lighting, "bool", "GlobalShadows", "true")
    property_value(lighting, "float", "ShadowSoftness", "0.12")
    property_value(lighting, "float", "Brightness", "3")
    property_value(lighting, "string", "TimeOfDay", "13:42:00")
    property_value(lighting, "float", "EnvironmentDiffuseScale", "0.25")
    property_value(lighting, "float", "EnvironmentSpecularScale", "0.05")
    color_value(lighting, "Ambient", (120, 145, 159))
    color_value(lighting, "OutdoorAmbient", (178, 195, 207))

    for service in ("ReplicatedStorage", "ServerScriptService", "StarterPlayer", "StarterGui"):
        item(service, service)
    starter_player = nodes["StarterPlayer"]
    property_value(starter_player, "float", "CameraMinZoomDistance", "8")
    property_value(starter_player, "float", "CameraMaxZoomDistance", "38")
    property_value(starter_player, "float", "CharacterWalkSpeed", "22")
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
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts" / PLACE_NAME)
    args = parser.parse_args()
    build(args.output)
    print(f"Built {args.output} ({len(SOURCES)} Luau scripts)")
