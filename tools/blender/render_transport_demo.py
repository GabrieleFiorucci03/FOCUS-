"""Crea una dimostrazione reale di ponte modulare e strada in pendenza."""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[1]
sys.path.insert(0, str(SCRIPT_DIR))

import render_asset_catalog as catalog_render  # noqa: E402


MODEL_DIR = PROJECT_ROOT / "assets" / "models" / "generated"
PREVIEW_DIR = PROJECT_ROOT / "assets" / "previews"


def point_camera(camera, target: Vector) -> None:
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def main() -> None:
    with (MODEL_DIR / "catalog.json").open("r", encoding="utf-8") as handle:
        assets = {asset["id"]: asset for asset in json.load(handle)["assets"]}

    catalog_render.reset_scene()
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    grass = catalog_render.simple_material("DEMO_GRASS", (0.24, 0.52, 0.22, 1.0))
    earth = catalog_render.simple_material("DEMO_EARTH", (0.34, 0.21, 0.11, 1.0))
    water = catalog_render.simple_material("DEMO_WATER", (0.05, 0.38, 0.58, 1.0), 0.28)
    ground = catalog_render.simple_material("DEMO_GROUND", (0.13, 0.17, 0.12, 1.0))

    # Scenario ponte: due sponde, due rampe e tre campate intercambiabili.
    bridge_x = -5.0
    catalog_render.add_box((8.0, 5.8, 0.45), (bridge_x, -5.95, -0.225), earth)
    catalog_render.add_box((8.0, 5.8, 0.45), (bridge_x, 5.95, -0.225), earth)
    catalog_render.add_box((8.0, 5.8, 0.06), (bridge_x, -5.95, 0.03), grass)
    catalog_render.add_box((8.0, 5.8, 0.06), (bridge_x, 5.95, 0.03), grass)
    catalog_render.add_box((8.0, 6.2, 0.10), (bridge_x, 0, -0.12), water)

    catalog_render.import_asset(assets["ROAD_LOCAL_1x1_STRAIGHT"], Vector((bridge_x, -6, 0.08)))
    catalog_render.import_asset(assets["BRG_LOCAL_RAMP_1x1_UP_050"], Vector((bridge_x, -4, 0.08)))
    for y in (-2.0, 0.0, 2.0):
        catalog_render.import_asset(assets["BRG_LOCAL_DECK_1x1_STRAIGHT"], Vector((bridge_x, y, 0.58)))
        catalog_render.import_asset(assets["BRG_SUPPORT_PIER_1x1_LOW_050"], Vector((bridge_x, y, 0.03)))
    catalog_render.import_asset(assets["BRG_LOCAL_RAMP_1x1_DOWN_050"], Vector((bridge_x, 4, 0.08)))
    catalog_render.import_asset(assets["ROAD_LOCAL_1x1_STRAIGHT"], Vector((bridge_x, 6, 0.08)))

    north_abutment = catalog_render.import_asset(assets["BRG_SUPPORT_ABUTMENT_1x1_050"], Vector((bridge_x, -3.05, 0.03)))
    south_abutment = catalog_render.import_asset(assets["BRG_SUPPORT_ABUTMENT_1x1_050"], Vector((bridge_x, 3.05, 0.03)))
    for root in north_abutment:
        root.rotation_euler.z = math.pi
    for root in south_abutment:
        root.rotation_euler.z = 0

    # Scenario collina: due moduli da 0,5 m raggiungono una terrazza alta 1 m.
    hill_x = 5.0
    catalog_render.add_box((5.0, 4.0, 0.45), (hill_x, -5.0, -0.225), earth)
    catalog_render.add_box((5.0, 6.0, 1.0), (hill_x, 3.0, 0.50), earth)
    catalog_render.add_box((5.0, 4.0, 0.06), (hill_x, -5.0, 0.03), grass)
    catalog_render.add_box((5.0, 6.0, 0.06), (hill_x, 3.0, 1.03), grass)
    catalog_render.import_asset(assets["ROAD_LOCAL_1x1_STRAIGHT"], Vector((hill_x, -5, 0.08)))
    catalog_render.import_asset(assets["ROAD_LOCAL_SLOPE_1x1_UP_050"], Vector((hill_x, -3, 0.08)))
    catalog_render.import_asset(assets["ROAD_LOCAL_SLOPE_1x1_UP_050"], Vector((hill_x, -1, 0.58)))
    catalog_render.import_asset(assets["ROAD_LOCAL_1x1_STRAIGHT"], Vector((hill_x, 1, 1.08)))
    catalog_render.import_asset(assets["ROAD_LOCAL_1x1_STRAIGHT"], Vector((hill_x, 3, 1.08)))

    catalog_render.add_box((22.0, 18.0, 0.18), (0, 0, -0.52), ground)

    bpy.ops.object.camera_add()
    camera = bpy.context.active_object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 22.0
    target = Vector((0, 0, 0.7))
    camera.location = target + Vector((18, -22, 17))
    point_camera(camera, target)
    bpy.context.scene.camera = camera

    bpy.ops.object.light_add(type="SUN", location=(0, 0, 20))
    sun = bpy.context.active_object
    sun.rotation_euler = (math.radians(30), math.radians(-18), math.radians(-38))
    sun.data.energy = 2.5
    sun.data.angle = math.radians(16)
    bpy.ops.object.light_add(type="AREA", location=(-8, -10, 18))
    area = bpy.context.active_object
    area.data.energy = 950
    area.data.size = 12
    point_camera(area, target)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_DIR / "transport_modular_demo.png")
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=str(PREVIEW_DIR / "transport_modular_demo.blend"))
    bpy.ops.render.render(write_still=True)
    print("[FOCUS] Demo ponte modulare e strada in pendenza completata")


if __name__ == "__main__":
    main()
