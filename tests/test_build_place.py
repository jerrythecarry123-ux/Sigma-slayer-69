"""Verify the delivered place embeds the actual sources at their required locations."""
from pathlib import Path
import importlib.util
import json
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("build_place", ROOT / "tools/build_place.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class PlaceTests(unittest.TestCase):
    def test_sources_and_instance_types(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "prototype.rbxlx"
            builder.build(path)
            root = ET.parse(path).getroot()
        self.assertEqual(root.tag, "roblox")
        self.assertEqual(root.attrib["version"], "4")
        sources = {}
        referents = set()

        def walk(parent, prefix=""):
            for node in parent.findall("Item"):
                referent = node.attrib["referent"]
                self.assertNotIn(referent, referents)
                referents.add(referent)
                properties = node.find("Properties")
                name = properties.find("string[@name='Name']").text
                path = f"{prefix}/{name}" if prefix else name
                source = properties.find("ProtectedString[@name='Source']")
                if source is not None:
                    sources[path] = (node.attrib["class"], source.text)
                walk(node, path)

        walk(root)
        self.assertEqual(set(sources), set(builder.SOURCES))
        self.assertEqual(
            {source for _, source in builder.SOURCES.values()},
            {path.relative_to(ROOT).as_posix() for path in (ROOT / "src").rglob("*.luau")},
            "Every production module must be embedded in the downloadable Studio file",
        )
        for path, (class_name, relative_source) in builder.SOURCES.items():
            self.assertEqual(sources[path], (class_name, (ROOT / relative_source).read_text(encoding="utf-8")))

    def test_world_render_and_streaming_settings_survive_export(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "world.rbxlx"
            builder.build(path)
            root = ET.parse(path).getroot()
        def properties(service):
            node = root.find(f"Item[@class='{service}']/Properties")
            return {entry.attrib["name"]: (entry.tag, entry.text) for entry in node}
        lighting = properties("Lighting")
        self.assertEqual(lighting["LightingStyle"], ("token", "0"))
        self.assertEqual(lighting["PrioritizeLightingQuality"], ("bool", "true"))
        self.assertEqual(lighting["GlobalShadows"], ("bool", "true"))
        self.assertEqual(lighting["ExposureCompensation"], ("float", "-0.2"))
        self.assertEqual(lighting["EnvironmentSpecularScale"], ("float", "0"))
        world = properties("Workspace")
        self.assertEqual(world["StreamingEnabled"], ("bool", "true"))
        self.assertEqual(world["StreamingIntegrityMode"], ("token", "3"))
        self.assertEqual(world["ModelStreamingBehavior"], ("token", "2"))
        self.assertLess(float(world["FallenPartsDestroyHeight"][1]), -150)
        self.assertGreater(float(world["StreamingTargetRadius"][1]), float(world["StreamingMinRadius"][1]))
        movement = properties("StarterPlayer")
        self.assertEqual(movement["CharacterWalkSpeed"], ("float", "22"))

    def test_repeatable_build(self):
        with tempfile.TemporaryDirectory() as temp:
            first, second = Path(temp) / "first.rbxlx", Path(temp) / "second.rbxlx"
            builder.build(first)
            builder.build(second)
            self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_material_variants_embed_shared_texture_maps_without_changing_base_physics(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "materials.rbxlx"
            builder.build(path)
            root = ET.parse(path).getroot()
        manifest = json.loads((ROOT / "tools/world_materials.json").read_text())
        service = root.find("Item[@class='MaterialService']")
        self.assertIsNotNone(service)
        self.assertEqual([p.attrib["name"] for p in service.find("Properties")], ["Name"],
                         "Per-part variants must not replace global base materials")
        variants = service.findall("Item[@class='MaterialVariant']")
        self.assertEqual(len(variants), 6)
        definitions = {entry["name"]: entry for entry in manifest["variants"]}
        native_tokens = {"Wood": 512, "Fabric": 1312, "Slate": 800, "Plaster": 2310, "Limestone": 820, "Sand": 1296}
        references = set()
        for node in variants:
            properties = node.find("Properties")
            name = properties.find("string[@name='Name']").text
            definition = definitions[name]
            self.assertEqual(int(properties.find("token[@name='BaseMaterial']").text), native_tokens[definition["base_material"]])
            self.assertGreater(float(properties.find("float[@name='StudsPerTile']").text), 0)
            for property_name, key in (("ColorMap", "color_map_id"), ("NormalMap", "normal_map_id"), ("RoughnessMap", "roughness_map_id")):
                url = properties.find(f"Content[@name='{property_name}']/url").text
                self.assertEqual(url, "rbxassetid://" + definition[key])
                references.add(url)
            for omitted in ("MetalnessMap", "CustomPhysicalProperties", "EmissiveMaskContent", "EmissiveStrength"):
                self.assertIsNone(properties.find(f"*[@name='{omitted}']"), omitted + " must retain its default")
        self.assertEqual(len(references), 18, "Six materials share three texture maps each")
        self.assertNotIn("Use2022Materials", ET.tostring(root, encoding="unicode"))


if __name__ == "__main__":
    unittest.main()
