"""Verify the delivered place embeds the actual sources at their required locations."""
from pathlib import Path
import importlib.util
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
        self.assertEqual(lighting["LightingStyle"], ("token", "1"))
        self.assertEqual(lighting["PrioritizeLightingQuality"], ("bool", "true"))
        self.assertEqual(lighting["GlobalShadows"], ("bool", "true"))
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


if __name__ == "__main__":
    unittest.main()
