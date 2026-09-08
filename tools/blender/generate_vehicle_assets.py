"""Small original traffic props. Run with Blender --background --python this_file.

Exports GLBs, editable Blender source, metadata, and renders of reimported GLBs.
Blender front -Y / up +Z becomes Godot front +Z / up +Y on glTF export.
"""
import json
import math
import struct
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/vehicles'
PREVIEW = ROOT / 'assets/previews/vehicles'
COLORS = {
    'teal': '538c86', 'coral': 'c16f59', 'ochre': 'c7a458',
    'white': 'dedbd1', 'blue': '416a90', 'red': 'b7473f',
    'glass': '354c56', 'rubber': '292e30', 'metal': '9ca5a5',
    'headlight': 'f8e8b6', 'tail': 'b33132', 'beacon': '398eff',
    'ground': 'c9c7bc',
}
SPECS = [
    ('VEH_COMPACT_TEAL', 'Auto compatta', 'compact', 'teal', .55),
    ('VEH_SEDAN_CORAL', 'Berlina', 'sedan', 'coral', .64),
    ('VEH_WAGON_OCHRE', 'Station wagon', 'wagon', 'ochre', .67),
    ('VEH_AMBULANCE', 'Ambulanza', 'ambulance', 'white', .73),
    ('VEH_FIRE_ENGINE', 'Vigili del fuoco', 'fire', 'red', .80),
    ('VEH_POLICE', 'Polizia', 'police', 'blue', .64),
]


def material(key):
    name = 'FOCUS_VEH_' + key
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    rgb = [int(COLORS[key][i:i + 2], 16) / 255 for i in (0, 2, 4)]
    rgba = tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb) + (1,)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = rgba
    node = mat.node_tree.nodes['Principled BSDF']
    node.inputs['Base Color'].default_value = rgba
    node.inputs['Roughness'].default_value = .7
    return mat


def box(name, size, loc, color, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material(color))
    if bevel:
        mod = obj.modifiers.new('Tiny flat chamfer', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)


def build(spec):
    asset_id, label, kind, color, length = spec
    clear()
    width = .29 if kind not in ('ambulance', 'fire') else .32
    box('Chassis', (width, length, .105), (0, 0, .11), color, .012)
    box('Lower trim', (width * .91, length * .94, .028), (0, 0, .066), 'rubber')
    # Glass volume with a colored roof and pillars: readable at city-camera scale.
    van = kind in ('ambulance', 'fire')
    cabin_len = .22 if van else length * .53
    cabin_y = -length * .28 if van else .012
    cabin_z = .213 if van else .20
    cabin_h = .13 if van else .105
    box('Cabin glass', (width * .83, cabin_len, cabin_h), (0, cabin_y, cabin_z), 'glass', .014)
    roof_z = cabin_z + cabin_h / 2
    box('Roof', (width * .87, cabin_len + .012, .025), (0, cabin_y, roof_z), color, .006)
    for side in (-1, 1):
        box('Window pillar', (.015, .025, cabin_h), (side * width * .42, cabin_y + .018, cabin_z), color)
    if kind == 'wagon':
        box('Rear cargo roof', (width * .86, .12, .09), (0, length * .31, .20), color, .006)
        box('Rear glass', (width * .71, .008, .053), (0, length * .40 + .012, .21), 'glass')
    if kind == 'ambulance':
        box('Medical compartment', (width, .40, .25), (0, .145, .21), 'white', .008)
        for side in (-1, 1):
            x = side * (width / 2 + .002)
            box('Emergency stripe', (.007, length * .92, .035), (x, .004, .14), 'coral')
            # Teal medical cross, no text or textures.
            box('Medical mark vertical', (.009, .034, .11), (x, .14, .258), 'teal')
            box('Medical mark horizontal', (.009, .11, .034), (x, .14, .258), 'teal')
        for x in (-.074, .074):
            box('Rear door window', (.10, .009, .064), (x, .348, .277), 'glass')
        box('Rear door seam', (.009, .008, .17), (0, .348, .23), 'metal')
    if kind == 'fire':
        box('Equipment body', (width, .43, .19), (0, .155, .20), 'red', .008)
        for side in (-1, 1):
            for y in (.035, .175, .315):
                box('Equipment shutter', (.009, .115, .105), (side * .164, y, .213), 'metal')
            box('Reflective band', (.012, .72, .023), (side * .165, 0, .132), 'white')
        for x in (-.076, .076):
            box('Ladder rail', (.018, .43, .018), (x, .12, .316), 'metal')
        for y in (-.075, .003, .081, .159, .237, .315):
            box('Ladder rung', (.15, .014, .014), (0, y, .318), 'metal')
    if kind == 'police':
        for side in (-1, 1):
            box('White door panel', (.009, .28, .075), (side * .147, .015, .119), 'white')
            box('Door badge', (.012, .042, .047), (side * .153, .015, .12), 'ochre')
        box('White hood', (.25, .12, .008), (0, -.238, .168), 'white')
    for side in (-1, 1):
        box('Headlight', (.064, .012, .035), (side * width * .29, -length / 2 - .002, .125), 'headlight')
        box('Tail light', (.049, .012, .032), (side * width * .32, length / 2 + .002, .12), 'tail')
    box('Front bumper', (width * .86, .016, .023), (0, -length / 2, .075), 'metal')
    box('Rear bumper', (width * .86, .016, .023), (0, length / 2, .075), 'metal')
    if kind in ('ambulance', 'fire', 'police'):
        box('Lightbar base', (.21, .07, .017), (0, cabin_y, roof_z + .025), 'rubber')
    # One static mesh, with wheel pivots and beacons kept separately for animation.
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = 'Body'
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.empty_add(type='PLAIN_AXES')
    root = bpy.context.object
    root.name = asset_id
    body.parent = root
    wheel_names = []
    radius = .054
    for side, side_name in ((-1, 'L'), (1, 'R')):
        for y, end in ((-length * .30, 'F'), (length * .30, 'R')):
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=.034,
                                               end_fill_type='NGON', location=(side * width / 2, y, radius),
                                               rotation=(0, math.pi / 2, 0))
            wheel = bpy.context.object
            wheel.name = f'Wheel_{end}{side_name}'
            wheel.data.materials.append(material('rubber'))
            wheel.data.materials.append(material('metal'))
            for face in wheel.data.polygons:
                if len(face.vertices) == 8:
                    face.material_index = 1
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            wheel.parent = root
            wheel_names.append(wheel.name)
    beacons = []
    if kind in ('ambulance', 'fire', 'police'):
        for side, suffix in ((-1, 'L'), (1, 'R')):
            beacon = box('Beacon_' + suffix, (.077, .065, .029), (side * .064, cabin_y, roof_z + .045), 'beacon', .004)
            beacon.parent = root
            beacons.append(beacon.name)
    root['asset_id'] = asset_id
    root['kind'] = kind
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    corners = [o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
    lo = [min(v[i] for v in corners) for i in range(3)]
    hi = [max(v[i] for v in corners) for i in range(3)]
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    assert triangles < 900, (asset_id, triangles)
    assert hi[0] - lo[0] < .37 and abs(lo[2]) < .0001
    bpy.ops.export_scene.gltf(filepath=str(OUT / f'{asset_id}.glb'), export_format='GLB',
                              export_apply=True, export_extras=True, export_cameras=False, export_lights=False)
    meta = dict(id=asset_id, label=label, kind=kind, model=f'{asset_id}.glb',
                dimensions_blender_xyz=[round(hi[i] - lo[i], 4) for i in range(3)],
                triangles=triangles, mesh_nodes=len(meshes), wheel_nodes=wheel_names,
                beacon_nodes=beacons, wheel_radius=radius, wheel_rotation_axis='X',
                forward_godot=[0, 0, 1], origin='ground_center', textures=0)
    (OUT / f'{asset_id}.json').write_text(json.dumps(meta, indent=2) + '\n', encoding='utf-8')
    return meta


def import_vehicle(asset, location):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(OUT / asset['model']))
    added = set(bpy.context.scene.objects) - before
    for obj in added:
        if obj.parent is None:
            obj.location += Vector(location)
    return added


def render_scene(path, target, scale, size=(1500, 1000)):
    scene = bpy.context.scene
    bpy.ops.object.camera_add(location=Vector(target) + Vector((3, -4.8, 4.5)))
    camera = bpy.context.object
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = scale
    scene.camera = camera
    scene.world = bpy.data.worlds.new('Vehicle studio')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.7, .76, .82, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .65
    bpy.ops.object.light_add(type='AREA', location=(-3, -4, 6))
    bpy.context.object.data.energy = 450
    bpy.context.object.data.shape = 'DISK'
    bpy.context.object.data.size = 5
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 6
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = 'AgX'
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def previews(assets):
    clear()
    for index, asset in enumerate(assets):
        import_vehicle(asset, ((index % 3 - 1) * .88, (index // 3) * 1.12, 0))
    # Save the editable asset collection before adding studio objects.
    source = OUT / 'source'
    source.mkdir(exist_ok=True)
    (source / '.gdignore').write_text('', encoding='utf-8')
    bpy.ops.wm.save_as_mainfile(filepath=str(source / 'vehicles.blend'))
    box('Studio floor', (200, 200, .04), (0, 0, -.027), 'ground')
    render_scene(PREVIEW / 'catalog.png', (0, .55, .08), 3.55)
    clear()
    road = ROOT / 'assets/models/refined_v2/ROAD_LOCAL_1x1_STRAIGHT.glb'
    for y in (-2, 0, 2):
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(road))
        for obj in set(bpy.context.scene.objects) - before:
            if 'colonly' in obj.name:
                obj.hide_render = True
            if obj.parent is None:
                obj.location.y += y
    # Asphalt is at z=.1045 in the existing refined road generator.
    for index, asset in enumerate(assets):
        x = -.23 if index % 2 == 0 else .23
        added = import_vehicle(asset, (x, (index // 2 - 1) * 1.75, .105))
        if index % 2:
            for obj in added:
                if obj.parent is None:
                    obj.rotation_mode = 'XYZ'
                    obj.rotation_euler.z = math.pi
    box('Ground', (200, 200, .04), (0, 0, -.03), 'ground')
    render_scene(PREVIEW / 'road_scale.png', (0, 0, .05), 6.9, (1100, 1100))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    assets = [build(spec) for spec in SPECS]
    checks = []
    for asset in assets:
        payload = (OUT / asset['model']).read_bytes()
        magic, version, total = struct.unpack_from('<4sII', payload)
        assert magic == b'glTF' and version == 2 and total == len(payload)
        size, kind = struct.unpack_from('<II', payload, 12)
        assert kind == 0x4E4F534A
        gltf = json.loads(payload[20:20 + size])
        names = {node['name'] for node in gltf['nodes']}
        assert {asset['id'], 'Body', *asset['wheel_nodes'], *asset['beacon_nodes']} <= names
        assert not gltf.get('images') and not gltf.get('textures')
        triangles = sum(gltf['accessors'][p['indices']]['count'] // 3
                        for mesh in gltf['meshes'] for p in mesh['primitives'])
        assert triangles == asset['triangles'], (asset['id'], triangles)
        assert sum('mesh' in n for n in gltf['nodes']) == asset['mesh_nodes']
        checks.append(dict(id=asset['id'], passed=True, triangles=triangles, bytes=len(payload)))
    (PREVIEW / 'validation.json').write_text(json.dumps(checks, indent=2) + '\n', encoding='utf-8')
    (OUT / 'catalog.json').write_text(json.dumps(dict(collection='vehicles', assets=assets), indent=2) + '\n', encoding='utf-8')
    previews(assets)
    print('VEHICLES_OK', [(a['id'], a['triangles']) for a in assets], flush=True)


if __name__ == '__main__':
    main()
