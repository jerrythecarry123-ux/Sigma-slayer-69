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
for kind in ('Block', 'Ball', 'Cylinder', 'Wedge'):
    if kind == 'Block':
        bpy.ops.mesh.primitive_cube_add(size=1)
    elif kind == 'Ball':
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=0.5)
    elif kind == 'Wedge':
        mesh=bpy.data.meshes.new('Wedge')
        mesh.from_pydata([(-.5,-.5,-.5),(.5,-.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(-.5,.5,.5),(.5,.5,.5)],[],[(0,2,3,1),(2,4,5,3),(0,1,5,4),(0,4,2),(1,3,5)])
        mesh.update()
        obj=bpy.data.objects.new('Wedge',mesh)
        bpy.context.collection.objects.link(obj)
        bpy.context.view_layer.objects.active=obj
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
def linear(rgb):
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)
parts=list(scene_data['parts'])
# Native Terrain water is approximated by ellipses only in this offline renderer.
for water in scene_data.get('layout',{}).get('Waters',[]):
    center=list(water['Center']);center[1]-=.08
    parts.append(dict(name='NativeTerrainWater',color=[.20,.63,.66],alpha=.96,material='Water',shape='Cylinder',position=center,size=[.16,water['Radius'][0]*2,water['Radius'][1]*2],rotation=[[0,-1,0],[1,0,0],[0,0,1]],shadow=False))
for part in parts:
    if part['alpha']<=0: continue
    key = (*part['color'], part['alpha'], part['material'])
    if key not in materials:
        material = bpy.data.materials.new(part['name'])
        material.diffuse_color = (*part['color'], 1)
        material.use_nodes = True
        shader = material.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = (*linear(part['color']), 1)
        shader.inputs['Roughness'].default_value = 0.7
        if part['material'] in ('Glass','Water'):
            shader.inputs['Roughness'].default_value = 0.22
            shader.inputs['Metallic'].default_value = 0.08
        if part['material'] == 'Water':
            shader.inputs['Roughness'].default_value = .16
            shader.inputs['Metallic'].default_value = .18
            shader.inputs['Coat Weight'].default_value = .4
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
    obj.visible_shadow=bool(part.get('shadow',True))
    # Per-object material slot keeps the shared geometry from sharing the last color.
    if not obj.data.materials:
        obj.data.materials.append(materials[key])
    obj.material_slots[0].link = 'OBJECT'
    obj.material_slots[0].material = materials[key]
world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (*linear((.68,.82,.88)),1)
world.node_tree.nodes['Background'].inputs[1].default_value = 0.7
bpy.ops.object.light_add(type='SUN')
sun = bpy.context.object
sun.rotation_euler = (0.4, -0.4, -0.6)
sun.data.energy = 2.3
sun.data.angle = 0.15
bpy.ops.object.camera_add()
camera = bpy.context.object
# Offline art views, all rendered from the generated production geometry.
views={
 'overview':((680,600,-760),(0,10,-30),40),
 'harbor':((158,108,-160),(0,19,36),32),
 'approach':((0,24,-85),(0,17,45),24),
 'grove':((-151,83,-105),(-246,38,25),38),
 'forest':((165,78,92),(268,34,-12),36),
 'cove':((-150,66,-110),(-264,11,-218),36),
 'summit':((158,107,-335),(264,67,-247),35),
}
position,target,lens=views.get(arguments[2] if len(arguments)>2 else 'harbor',views['harbor'])
camera.location = conversion @ Vector(position)
direction = conversion @ Vector(target) - camera.location
camera.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
camera.data.lens = lens
camera.data.clip_end = 5000
scene = bpy.context.scene
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 40
scene.cycles.use_denoising = False
scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 1280, 800, 100
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = str(output)
bpy.ops.render.render(write_still=True)
