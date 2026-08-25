"""Importa i GLB generati e crea tavole catalogo con render reali.

Esecuzione:
    blender --background --python tools/blender/render_asset_catalog.py
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = PROJECT_ROOT / "assets" / "models" / "generated"
PREVIEW_DIR = PROJECT_ROOT / "assets" / "previews"

GROUPS = {
    "residential": {"house", "apartment", "slab", "villa", "tower"},
    "urban": {"shop", "office", "factory", "service", "school"},
    "infrastructure": {"park", "tree", "agriculture", "utility", "sport"},
    "transport": {"road", "sloped_road", "bridge", "bridge_support"},
}


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def simple_material(name: str, color, roughness: float = 0.9):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    if principled:
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = roughness
    return mat


def add_box(size, location, material):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.active_object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def import_asset(asset: dict, position: Vector) -> None:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(MODEL_DIR / asset["model"]))
    imported = set(bpy.context.scene.objects) - before
    for obj in imported:
        if "colonly" in obj.name.lower():
            obj.hide_render = True
            obj.hide_set(True)
    roots = [obj for obj in imported if obj.parent is None or obj.parent not in imported]
    for root in roots:
        root.location += position


def point_camera(camera, target: Vector) -> None:
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def configure_render(group_name: str, columns: int, rows: int, spacing: float) -> None:
    width = max(1, columns - 1) * spacing + 10
    depth = max(1, rows - 1) * spacing + 10
    ground = simple_material("CATALOG_GROUND", (0.88, 0.84, 0.73, 1.0))
    add_box((width + 8, depth + 8, 0.12), (0, 0, -0.08), ground)

    bpy.ops.object.camera_add()
    camera = bpy.context.active_object
    camera.name = "CatalogCamera"
    target = Vector((0, 0, 2.0))
    distance = max(width, depth) * 1.35
    camera.location = target + Vector((distance, -distance, distance * 0.82))
    point_camera(camera, target)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(depth * 1.55, width * 1.18)
    bpy.context.scene.camera = camera

    bpy.ops.object.light_add(type="SUN", location=(0, 0, 25))
    sun = bpy.context.active_object
    sun.name = "CatalogSun"
    sun.rotation_euler = (math.radians(28), math.radians(-18), math.radians(-35))
    sun.data.energy = 2.2
    sun.data.angle = math.radians(18)

    bpy.ops.object.light_add(type="AREA", location=(-width * 0.28, -depth * 0.20, 28))
    area = bpy.context.active_object
    area.name = "CatalogSoftbox"
    area.data.energy = 1100
    area.data.shape = "DISK"
    area.data.size = 18
    point_camera(area, Vector((0, 0, 0)))

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.filepath = str(PREVIEW_DIR / f"catalog_{group_name}.png")
    scene.render.image_settings.color_mode = "RGBA"
    scene.world.color = (0.055, 0.055, 0.055)
    scene.view_settings.look = "AgX - Medium High Contrast"


def build_group(group_name: str, catalog: list[dict]) -> None:
    reset_scene()
    assets = [asset for asset in catalog if asset["kind"] in GROUPS[group_name]]
    columns = 5 if len(assets) <= 25 else 6
    rows = math.ceil(len(assets) / columns)
    spacing = 10.0
    x_origin = -(columns - 1) * spacing * 0.5
    y_origin = (rows - 1) * spacing * 0.5

    pad_material = simple_material("CATALOG_PAD", (0.95, 0.91, 0.80, 1.0))
    for index, asset in enumerate(assets):
        column = index % columns
        row = index // columns
        position = Vector((x_origin + column * spacing, y_origin - row * spacing, 0.08 - asset.get("min_z", 0.0)))
        footprint = asset["footprint"]
        pad_width = max(2.2, footprint[0] * asset["grid_unit_meters"] + 0.35)
        pad_depth = max(2.2, footprint[1] * asset["grid_unit_meters"] + 0.35)
        add_box((pad_width, pad_depth, 0.10), (position.x, position.y, 0.01), pad_material)
        import_asset(asset, position)

    configure_render(group_name, columns, rows, spacing)
    bpy.ops.wm.save_as_mainfile(filepath=str(PREVIEW_DIR / f"catalog_{group_name}.blend"))
    bpy.ops.render.render(write_still=True)
    print(f"[FOCUS] Render catalogo {group_name}: {len(assets)} asset")


def main() -> None:
    import json

    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    with (MODEL_DIR / "catalog.json").open("r", encoding="utf-8") as handle:
        catalog = json.load(handle)["assets"]
    for group_name in GROUPS:
        build_group(group_name, catalog)
    print(f"[FOCUS] Cataloghi completati in {PREVIEW_DIR}")


if __name__ == "__main__":
    main()
