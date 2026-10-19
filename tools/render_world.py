"""Optional Blender geometry preview. Roblox materials, UI and lighting are not emulated."""
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Matrix, Vector

arguments = sys.argv[sys.argv.index('--') + 1:]
source, output = map(Path, arguments[:2])
scene_data = json.loads(source.read_text())
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
# Reuse meshes and materials for inexpensive inspection of the actual source geometry.
meshes = {}
for kind in ('Block', 'Ball', 'Cylinder'):
    if kind == 'Block':
        bpy.ops.mesh.primitive_cube_add(size=1)
    elif kind == 'Ball':
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=0.5)
    else:
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.5, depth=1)
        # Roblox cylinders run along local X; Blender cylinders along local Z.
        bpy.context.object.data.transform(Matrix.Rotation(math.pi / 2, 4, 'Y'))
    obj = bpy.context.object
    meshes[kind] = obj.data.copy()
    for face in meshes[kind].polygons:
        face.use_smooth = kind == 'Ball'
    bpy.data.objects.remove(obj, do_unlink=True)
materials = {}
# Roblox Y-up to Blender Z-up, preserving right handedness.
conversion = Matrix(((1,0,0), (0,0,-1), (0,1,0)))
for part in scene_data['parts']:
    key = (*part['color'], part['alpha'], part['material'])
    if key not in materials:
        material = bpy.data.materials.new(part['name'])
        material.diffuse_color = (*part['color'], 1)
        material.use_nodes = True
        shader = material.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = (*part['color'], 1)
        shader.inputs['Roughness'].default_value = 0.7
        if part['material'] == 'Glass':
            shader.inputs['Roughness'].default_value = 0.22
            shader.inputs['Metallic'].default_value = 0.08
        if part['material'] == 'Neon':
            shader.inputs['Emission Color'].default_value = (*part['color'], 1)
            shader.inputs['Emission Strength'].default_value = 0.5
        materials[key] = material
    obj = bpy.data.objects.new(part['name'], meshes[part['shape']])
    bpy.context.collection.objects.link(obj)
    matrix = Matrix(part['rotation']).to_4x4()
    matrix.translation = Vector(part['position'])
    obj.matrix_world = conversion.to_4x4() @ matrix
    obj.scale = part['size']
    # Per-object material slot keeps the shared geometry from sharing the last color.
    if not obj.data.materials:
        obj.data.materials.append(materials[key])
    obj.material_slots[0].link = 'OBJECT'
    obj.material_slots[0].material = materials[key]
world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (0.62, 0.78, 0.83, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = 0.7
bpy.ops.object.light_add(type='SUN')
sun = bpy.context.object
sun.rotation_euler = (0.4, -0.4, -0.6)
sun.data.energy = 2.3
sun.data.angle = 0.15
bpy.ops.object.camera_add()
camera = bpy.context.object
# Overview and the approach from spawn, selected by an optional third argument.
if len(arguments) > 2 and arguments[2] == 'approach':
    position, target, lens = (0, 15, -34), (0, 7, 52), 24
else:
    position, target, lens = (85, 72, -78), (0, 0, 37), 36
camera.location = conversion @ Vector(position)
direction = conversion @ Vector(target) - camera.location
camera.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
camera.data.lens = lens
scene = bpy.context.scene
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 48
scene.cycles.use_denoising = False
scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 1280, 800, 100
scene.view_settings.view_transform = 'AgX'
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = str(output)
bpy.ops.render.render(write_still=True)
