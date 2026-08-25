"""Generatore procedurale Blender 4.x per il primo kit 3D di FOCUS!.

Esecuzione:
    blender --background --python tools/blender/generate_mvp_assets.py
    blender --background --python tools/blender/generate_mvp_assets.py -- --asset ID

Ogni asset viene costruito con primitive, unito per ridurre i nodi, corredato
da collisione semplificata ed esportato come GLB con metadata JSON.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[1]
sys.path.insert(0, str(SCRIPT_DIR))

from focus_asset_specs import ASSETS, ASSET_BY_ID, ELEVATION_STEP_METERS, GRID_UNIT_METERS  # noqa: E402


GENERATOR_VERSION = 3

COLORS = {
    "cream": (0.82, 0.70, 0.52, 1.0),
    "paper": (0.93, 0.88, 0.73, 1.0),
    "sage": (0.46, 0.64, 0.48, 1.0),
    "peach": (0.88, 0.52, 0.39, 1.0),
    "blue": (0.34, 0.58, 0.68, 1.0),
    "ochre": (0.85, 0.58, 0.20, 1.0),
    "terracotta": (0.62, 0.24, 0.15, 1.0),
    "terracotta_light": (0.78, 0.37, 0.23, 1.0),
    "teal": (0.08, 0.47, 0.45, 1.0),
    "coral": (0.88, 0.27, 0.25, 1.0),
    "pink": (0.91, 0.55, 0.64, 1.0),
    "navy": (0.08, 0.19, 0.30, 1.0),
    "glass": (0.22, 0.55, 0.66, 1.0),
    "glass_dark": (0.08, 0.27, 0.37, 1.0),
    "window_warm": (0.95, 0.68, 0.29, 1.0),
    "concrete": (0.55, 0.56, 0.53, 1.0),
    "concrete_light": (0.72, 0.70, 0.62, 1.0),
    "asphalt": (0.12, 0.15, 0.17, 1.0),
    "road_line": (0.94, 0.75, 0.25, 1.0),
    "sidewalk": (0.58, 0.56, 0.49, 1.0),
    "grass": (0.28, 0.58, 0.28, 1.0),
    "grass_light": (0.46, 0.72, 0.32, 1.0),
    "leaf_dark": (0.10, 0.40, 0.22, 1.0),
    "leaf": (0.18, 0.58, 0.29, 1.0),
    "leaf_light": (0.43, 0.72, 0.28, 1.0),
    "wood": (0.35, 0.18, 0.08, 1.0),
    "water": (0.12, 0.62, 0.78, 1.0),
    "white": (0.92, 0.91, 0.85, 1.0),
    "black": (0.025, 0.03, 0.035, 1.0),
}

FACADE_COLORS = {
    "cream": "cream",
    "sage": "sage",
    "peach": "peach",
    "blue": "blue",
    "ochre": "ochre",
    "paper": "paper",
    "glass": "glass_dark",
    "industrial": "concrete",
    "park": "grass",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Genera gli asset low-poly FOCUS!")
    parser.add_argument("--asset", choices=sorted(ASSET_BY_ID), help="Genera un solo ID")
    parser.add_argument(
        "--output",
        type=Path,
        default=PROJECT_ROOT / "assets" / "models" / "generated",
        help="Cartella di destinazione",
    )
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection" and collection.users == 0:
            bpy.data.collections.remove(collection)


def material(color_name: str, *, metallic: float = 0.0, roughness: float = 0.82):
    name = f"FOCUS_{color_name.upper()}"
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = COLORS[color_name]
    mat.use_nodes = True
    node = mat.node_tree.nodes.get("Principled BSDF")
    if node:
        node.inputs["Base Color"].default_value = COLORS[color_name]
        node.inputs["Metallic"].default_value = metallic
        node.inputs["Roughness"].default_value = roughness
    return mat


def assign_material(obj, color_name: str, *, metallic: float = 0.0, roughness: float = 0.82):
    obj.data.materials.append(material(color_name, metallic=metallic, roughness=roughness))
    return obj


def box(name: str, size, location, color: str | None, bevel: float = 0.025, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if color:
        assign_material(obj, color)
    if bevel > 0:
        modifier = obj.modifiers.new("LowPolyBevel", "BEVEL")
        modifier.width = min(bevel, min(size) * 0.24)
        modifier.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def cylinder(name: str, radius: float, depth: float, location, color: str, vertices: int = 8, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    return assign_material(obj, color)


def torus(name: str, major_radius: float, minor_radius: float, location, color: str, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=10,
        minor_segments=4,
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    return assign_material(obj, color)


def cone(name: str, radius1: float, radius2: float, depth: float, location, color: str, vertices: int = 8, rotation_z: float = 0.0):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
        rotation=(0.0, 0.0, rotation_z),
    )
    obj = bpy.context.active_object
    obj.name = name
    return assign_material(obj, color)


def ico(name: str, radius: float, location, scale, color: str, subdivisions: int = 1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return assign_material(obj, color)


def gable_roof(name: str, width: float, depth: float, base_z: float, height: float, color: str):
    x = width * 0.5
    y = depth * 0.5
    verts = [(-x, -y, base_z), (x, -y, base_z), (0, -y, base_z + height),
             (-x, y, base_z), (x, y, base_z), (0, y, base_z + height)]
    faces = [(0, 3, 4, 1), (0, 2, 5, 3), (2, 1, 4, 5), (0, 1, 2), (3, 5, 4)]
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return assign_material(obj, color)


def ramp_prism(name: str, width: float, length: float, z_start: float, z_end: float, thickness: float, color: str | None):
    """Prisma inclinato lungo Y; il lato nord (-Y) usa z_start."""
    x = width * 0.5
    y = length * 0.5
    verts = [
        (-x, -y, z_start), (x, -y, z_start), (x, y, z_end), (-x, y, z_end),
        (-x, -y, z_start - thickness), (x, -y, z_start - thickness),
        (x, y, z_end - thickness), (-x, y, z_end - thickness),
    ]
    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return assign_material(obj, color) if color else obj


def beam_between(name: str, start, end, width: float, depth: float, color: str):
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    bpy.ops.mesh.primitive_cube_add(location=(start_v + end_v) * 0.5)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Y", "Z")
    obj.scale = (width * 0.5, direction.length * 0.5, depth * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return assign_material(obj, color)


def hip_roof(name: str, width: float, depth: float, base_z: float, height: float, color: str):
    x = width * 0.5
    y = depth * 0.5
    verts = [(-x, -y, base_z), (x, -y, base_z), (x, y, base_z), (-x, y, base_z), (0, 0, base_z + height)]
    faces = [(0, 3, 2, 1), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)]
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return assign_material(obj, color)


def roof_for(kind: str, width: float, depth: float, base_z: float, rng: random.Random):
    if kind == "gable":
        return gable_roof("Roof", width + 0.16, depth + 0.18, base_z, 0.52, "terracotta")
    if kind == "hip":
        return hip_roof("Roof", width + 0.16, depth + 0.18, base_z, 0.54, "terracotta")
    if kind == "shed":
        return box("Roof", (width + 0.16, depth + 0.18, 0.12), (0, 0, base_z + 0.10), "terracotta", 0.015, (0, math.radians(-10), 0))
    roof = box("Roof", (width + 0.12, depth + 0.12, 0.12), (0, 0, base_z + 0.06), "terracotta", 0.025)
    if rng.random() > 0.5:
        box("RoofPlanter", (width * 0.35, depth * 0.20, 0.13), (0.25, 0.0, base_z + 0.16), "sage", 0.02)
    return roof


def door(x: float, y: float, z: float, width: float = 0.32, height: float = 0.62, color: str = "wood"):
    return box("Door", (width, 0.045, height), (x, y, z + height * 0.5), color, 0.015)


def front_windows(width: float, front_y: float, floors: int, floor_height: float, base_z: float, columns: int, color: str = "glass_dark", back: bool = True, x_offset: float = 0.0):
    for floor in range(floors):
        z = base_z + floor_height * (floor + 0.57)
        for col in range(columns):
            x = x_offset + (col - (columns - 1) * 0.5) * min(0.62, width / (columns + 0.4))
            if floor == 0 and abs(x) < 0.22:
                continue
            box("Window", (0.28, 0.038, 0.28), (x, front_y - 0.022, z), color, 0.012)
            if back:
                box("Window", (0.28, 0.038, 0.28), (x, -front_y + 0.022, z), color, 0.012)


def side_windows(depth: float, side_x: float, floors: int, floor_height: float, base_z: float, columns: int, color: str = "glass_dark"):
    for floor in range(floors):
        z = base_z + floor_height * (floor + 0.57)
        for col in range(columns):
            y = (col - (columns - 1) * 0.5) * min(0.65, depth / (columns + 0.4))
            box("SideWindow", (0.038, 0.28, 0.28), (side_x + 0.022, y, z), color, 0.012)
            box("SideWindow", (0.038, 0.28, 0.28), (-side_x - 0.022, y, z), color, 0.012)


def add_tree_geometry(rng: random.Random, x=0.0, y=0.0, scale=1.0, pine=False):
    trunk_h = 0.72 * scale
    cylinder("Trunk", 0.11 * scale, trunk_h, (x, y, trunk_h * 0.5), "wood", 7)
    if pine:
        cone("PineLower", 0.55 * scale, 0.05, 0.85 * scale, (x, y, trunk_h + 0.25 * scale), "leaf_dark", 7)
        cone("PineUpper", 0.42 * scale, 0.0, 0.80 * scale, (x, y, trunk_h + 0.70 * scale), "leaf", 7)
        return
    colors = ["leaf_dark", "leaf", "leaf_light"]
    for index, offset in enumerate(((-0.20, 0.0, 0.0), (0.18, 0.05, 0.03), (0.0, -0.10, 0.27))):
        radius = rng.uniform(0.42, 0.52) * scale
        ico(
            f"Crown{index}",
            radius,
            (x + offset[0] * scale, y + offset[1] * scale, trunk_h + 0.35 * scale + offset[2] * scale),
            (1.0, 0.90, rng.uniform(0.82, 1.10)),
            colors[index],
        )


def generate_house(spec, rng):
    floors = spec["floors"]
    footprint = spec["footprint"]
    width = min(footprint[0] * GRID_UNIT_METERS - 0.45, rng.uniform(1.40, 1.58) + (footprint[0] - 1) * 1.55)
    depth = min(footprint[1] * GRID_UNIT_METERS - 0.45, rng.uniform(1.30, 1.50) + (footprint[1] - 1) * 1.55)
    floor_h = 0.72
    height = floors * floor_h
    facade = FACADE_COLORS[spec["palette"]]
    box("Foundation", (width + 0.12, depth + 0.12, 0.12), (0, 0, 0.06), "concrete_light", 0.02)
    box("House", (width, depth, height), (0, 0, 0.12 + height * 0.5), facade, 0.035)
    front_y = -depth * 0.5
    feature = spec.get("feature", "standard")
    entrance_x = -width * 0.22 if feature == "garage" else 0
    if feature != "duplex":
        door(entrance_x, front_y - 0.025, 0.12, color="teal" if spec["palette"] == "ochre" else "wood")
    columns = max(2, footprint[0] * 2)
    if feature == "duplex":
        front_windows(width, front_y, max(1, floors - 1), floor_h, 0.12 + floor_h, columns)
    else:
        front_windows(width, front_y, floors, floor_h, 0.12, columns)
    side_windows(depth, width * 0.5, floors, floor_h, 0.12, max(1, footprint[1]))
    roof_for(spec["roof"], width, depth, 0.12 + height, rng)
    if feature == "garage":
        box("GarageDoor", (0.70, 0.05, 0.56), (width * 0.24, front_y - 0.035, 0.40), "navy", 0.015)
    elif feature == "duplex":
        door(width * 0.27, front_y - 0.03, 0.12, 0.30, 0.58, "teal")
        door(-width * 0.27, front_y - 0.03, 0.12, 0.30, 0.58, "wood")
    elif feature == "modern":
        box("ModernGlass", (0.58, 0.045, 0.58), (width * 0.25, front_y - 0.03, 0.48), "glass", 0.015)
        box("ModernCanopy", (0.76, 0.35, 0.09), (-0.20, front_y - 0.18, 0.72), "teal", 0.015)
    elif feature == "porch":
        box("PorchRoof", (1.10, 0.52, 0.10), (0, front_y - 0.25, 0.78), "terracotta", 0.02)
        for x in (-0.44, 0.44):
            cylinder("PorchPost", 0.035, 0.68, (x, front_y - 0.42, 0.40), "wood", 6)
    elif feature == "courtyard":
        box("SideWing", (width * 0.34, depth * 0.72, height * 0.72), (width * 0.39, depth * 0.14, height * 0.36), "paper", 0.035)
    if rng.random() > 0.45 and spec["roof"] != "flat":
        box("Chimney", (0.18, 0.18, 0.50), (width * 0.27, 0.15, height + 0.40), "terracotta", 0.02)


def generate_apartment(spec, rng):
    floors = spec["floors"]
    floor_h = 0.58
    footprint = spec["footprint"]
    width = footprint[0] * GRID_UNIT_METERS - 0.85
    depth = footprint[1] * GRID_UNIT_METERS - 1.00
    height = floors * floor_h
    facade = FACADE_COLORS[spec["palette"]]
    shape = spec.get("shape", "block")
    if shape == "twin":
        block_width = width * 0.43
        box("ApartmentA", (block_width, depth, height), (-width * 0.28, 0, height * 0.5), facade, 0.045)
        box("ApartmentB", (block_width, depth, height * 0.88), (width * 0.28, 0, height * 0.44), "paper", 0.045)
        box("Bridge", (width * 0.32, depth * 0.38, floor_h), (0, 0.15, floor_h * 1.5), "terracotta_light", 0.03)
    else:
        box("Apartment", (width, depth, height), (0, 0, height * 0.5), facade, 0.045)
        if shape == "stepped":
            box("Setback", (width * 0.66, depth * 0.68, floor_h * 1.8), (width * 0.10, depth * 0.08, height + floor_h * 0.9), "paper", 0.04)
        elif shape == "wing":
            box("ApartmentWing", (width * 0.58, depth * 0.40, height * 0.68), (width * 0.30, -depth * 0.28, height * 0.34), "terracotta_light", 0.04)
    front_y = -depth * 0.5
    door(0, front_y - 0.025, 0, 0.40, 0.55, "teal")
    front_windows(width, front_y, floors, floor_h, 0, max(4, footprint[0] * 2), back=True)
    side_windows(depth, width * 0.5, floors, floor_h, 0, max(3, footprint[1] * 2))
    if spec.get("balconies"):
        side = -1 if spec["seed"] % 2 else 1
        for floor in range(1, floors):
            z = floor * floor_h + 0.06
            x = side * width * 0.30
            box("Balcony", (0.82, 0.30, 0.08), (x, front_y - 0.15, z), "concrete_light", 0.012)
            box("Railing", (0.82, 0.035, 0.24), (x, front_y - 0.29, z + 0.14), "teal", 0.01)
    box("FlatRoof", (width + 0.10, depth + 0.10, 0.13), (0, 0, height + 0.065), "terracotta", 0.025)
    box("RoofUnit", (0.62, 0.48, 0.32), (0.50, 0.15, height + 0.23), "concrete", 0.025)


def generate_slab(spec, rng):
    floors = spec["floors"]
    floor_h = 0.53
    footprint = spec["footprint"]
    width = footprint[0] * GRID_UNIT_METERS - 0.72
    depth = footprint[1] * GRID_UNIT_METERS - 1.18
    height = floors * floor_h
    facade = FACADE_COLORS[spec.get("palette", "cream")]
    offset = 0.34 if spec.get("shape") == "offset" else 0.0
    box("Slab", (width, depth, height), (-offset, 0, height * 0.5), facade, 0.035)
    box("StairCore", (0.48, depth + 0.12, height + 0.35), (width * 0.35 - offset, 0, (height + 0.35) * 0.5), "terracotta_light", 0.03)
    if offset:
        box("LowWing", (width * 0.38, depth * 0.78, height * 0.42), (width * 0.34, 0.15, height * 0.21), "paper", 0.04)
    front_windows(width, -depth * 0.5, floors, floor_h, 0, 5, "glass_dark")
    side_windows(depth, width * 0.5, floors, floor_h, 0, 2, "glass_dark")
    door(-0.45, -depth * 0.5 - 0.025, 0, 0.44, 0.54, "navy")
    box("Roof", (width + 0.10, depth + 0.10, 0.12), (0, 0, height + 0.06), "terracotta", 0.02)


def generate_villa(spec, rng):
    facade = FACADE_COLORS[spec["palette"]]
    footprint = spec["footprint"]
    main_w = min(footprint[0] * GRID_UNIT_METERS - 1.20, 3.75)
    main_d = min(footprint[1] * GRID_UNIT_METERS - 1.55, 2.45)
    floor_h = 0.72
    height = spec["floors"] * floor_h
    box("VillaMain", (main_w, main_d, height), (-0.35, 0.25, height * 0.5), facade, 0.045)
    wing_x = main_w * 0.43
    box("VillaWing", (min(1.55, main_w * 0.46), 1.15, floor_h), (wing_x, -0.45, floor_h * 0.5), "paper", 0.04)
    main_roof = roof_for("flat" if spec["seed"] % 2 == 0 else "gable", main_w, main_d, height, rng)
    main_roof.location.x = -0.35
    main_roof.location.y = 0.25
    box("WingRoof", (min(1.63, main_w * 0.49), 1.22, 0.12), (wing_x, -0.45, floor_h + 0.06), "terracotta", 0.02)
    front_y = -0.66
    door(0.75, front_y - 0.025, 0, 0.36, 0.62, "teal")
    front_windows(main_w, -main_d * 0.5 + 0.25, spec["floors"], floor_h, 0, 3, x_offset=-0.35)
    if spec.get("pool"):
        pool_x = -1.35 if footprint[0] >= 3 else -0.65
        box("PoolBorder", (1.45, 0.78, 0.09), (pool_x, -1.38, 0.045), "white", 0.03)
        box("PoolWater", (1.28, 0.62, 0.055), (pool_x, -1.38, 0.085), "water", 0.025)
    else:
        add_tree_geometry(rng, -1.25, -1.18, 0.55)


def generate_tower(spec, rng):
    floors = spec["floors"]
    floor_h = 0.48
    tower_h = floors * floor_h
    footprint = spec["footprint"]
    podium_size = min(footprint[0], footprint[1]) * GRID_UNIT_METERS - 1.45
    shape = spec.get("shape", "single")
    box("Podium", (podium_size, podium_size * 0.94, 0.75), (0, 0, 0.375), "paper", 0.08)
    tower_width = 2.72 if shape != "twin" else 2.22
    tower_x = -1.25 if shape == "twin" else 0
    lower_height = tower_h * 0.66 if shape == "setback" else tower_h
    box("Tower", (tower_width, 2.72, lower_height), (tower_x, 0, 0.75 + lower_height * 0.5), "glass_dark", 0.07)
    if shape == "twin":
        box("TowerTwin", (tower_width, 2.45, tower_h * 0.72), (1.25, 0.30, 0.75 + tower_h * 0.36), "glass", 0.07)
        box("SkyBridge", (1.35, 0.72, 0.62), (0, 0.15, 0.75 + tower_h * 0.48), "terracotta_light", 0.04)
    elif shape == "setback":
        box("UpperSetback", (2.15, 2.15, tower_h * 0.34), (0.18, 0.12, 0.75 + tower_h * 0.83), "glass", 0.06)
    for floor in range(floors + 1):
        z = 0.75 + floor * floor_h
        upper = shape == "setback" and floor > int(floors * 0.66)
        band_width = 2.25 if upper else tower_width + 0.10
        band_depth = 2.25 if upper else 2.82
        band_x = 0.18 if upper else tower_x
        band_y = 0.12 if upper else 0
        box("FloorBand", (band_width, band_depth, 0.065), (band_x, band_y, z), "cream", 0.012)
    for x, y in ((-0.78, -1.395), (0, -1.395), (0.78, -1.395), (-0.78, 1.395), (0, 1.395), (0.78, 1.395)):
        box("Mullion", (0.055, 0.04, lower_height - 0.08), (x + tower_x, y, 0.75 + lower_height * 0.5), "teal", 0.008)
    for y, x in ((-0.78, -1.395), (0, -1.395), (0.78, -1.395), (-0.78, 1.395), (0, 1.395), (0.78, 1.395)):
        box("Mullion", (0.04, 0.055, lower_height - 0.08), (x + tower_x, y, 0.75 + lower_height * 0.5), "teal", 0.008)
    box("Crown", (tower_width * 0.83, 2.25, 0.46), (tower_x, 0, 0.75 + tower_h + 0.23), "terracotta_light", 0.06)
    cylinder("Antenna", 0.055, 1.35, (tower_x, 0, 0.75 + tower_h + 1.10), "navy", 8)


def generate_shop(spec, rng):
    accent = spec["palette"]
    footprint = spec["footprint"]
    variant = spec.get("variant", "shop")
    width = footprint[0] * GRID_UNIT_METERS - 0.35
    depth = footprint[1] * GRID_UNIT_METERS - 0.52
    height = 1.15 if variant == "market" else 0.90
    box("Shop", (width, depth, height), (0, 0, height * 0.5), "paper", 0.04)
    box("Storefront", (width * 0.72, 0.04, 0.48), (0, -depth * 0.5 - 0.025, 0.36), "glass_dark", 0.012)
    door(width * 0.27, -depth * 0.5 - 0.05, 0, 0.30, 0.54, accent)
    box("Sign", (width * 0.82, 0.10, 0.24), (0, -depth * 0.5 - 0.08, height - 0.14), accent, 0.025)
    box("Awning", (width * 0.88, 0.36, 0.10), (0, -depth * 0.5 - 0.18, 0.60), "terracotta_light" if accent == "coral" else "ochre", 0.02, (math.radians(7), 0, 0))
    if variant == "cafe":
        for x in (-0.38, 0.38):
            cylinder("CafeTable", 0.13, 0.08, (x, -depth * 0.5 - 0.52, 0.22), "wood", 8)
            cylinder("CafePost", 0.025, 0.20, (x, -depth * 0.5 - 0.52, 0.10), "navy", 6)
    elif variant == "restaurant":
        box("Terrace", (width * 0.46, 0.72, 0.08), (-width * 0.22, -depth * 0.5 - 0.38, 0.04), "wood", 0.02)
    elif variant == "market":
        box("MarketLoading", (0.86, 0.05, 0.62), (width * 0.28, depth * 0.5 + 0.03, 0.31), "navy", 0.015)
    box("Roof", (width + 0.10, depth + 0.10, 0.11), (0, 0, height + 0.055), "teal", 0.025)


def generate_office(spec, rng):
    floors, floor_h = spec["floors"], 0.60
    footprint = spec["footprint"]
    width = footprint[0] * GRID_UNIT_METERS - 0.80
    depth = footprint[1] * GRID_UNIT_METERS - 1.00
    height = floors * floor_h
    shape = spec.get("shape", "block")
    if shape == "atrium":
        wing_w = width * 0.42
        box("OfficeWingA", (wing_w, depth, height), (-width * 0.28, 0, height * 0.5), "glass_dark", 0.06)
        box("OfficeWingB", (wing_w, depth, height * 0.78), (width * 0.28, 0, height * 0.39), "glass", 0.06)
        box("Atrium", (width * 0.32, depth * 0.55, height * 0.42), (0, -depth * 0.14, height * 0.21), "glass", 0.05)
    else:
        box("OfficeGlass", (width, depth, height), (0, 0, height * 0.5), "glass_dark", 0.06)
        if shape == "stepped":
            box("OfficeSetback", (width * 0.68, depth * 0.72, floor_h * 2.0), (0.22, 0.15, height + floor_h), "glass", 0.05)
    for floor in range(floors + 1):
        box("FloorBand", (width + 0.07, depth + 0.07, 0.075), (0, 0, floor * floor_h), "paper", 0.01)
    for x in (-width * 0.5, width * 0.5):
        box("Column", (0.16, depth + 0.10, height), (x, 0, height * 0.5), "teal", 0.018)
    box("Entrance", (1.15, 0.30, 0.72), (0, -depth * 0.5 - 0.12, 0.36), "glass", 0.025)
    box("RoofGarden", (1.35, 1.10, 0.15), (0.45, 0.25, height + 0.075), "grass", 0.02)


def generate_factory(spec, rng):
    footprint = spec["footprint"]
    variant = spec.get("variant", "factory")
    width = footprint[0] * GRID_UNIT_METERS - 0.65
    depth = footprint[1] * GRID_UNIT_METERS - 1.05
    height = 1.62 if variant == "logistics" else 1.35
    box("Factory", (width, depth, height), (0, 0, height * 0.5), "concrete", 0.035)
    gable_roof("FactoryRoof", width + 0.14, depth + 0.16, height, 0.55, "navy")
    box("LoadingDoor", (1.08, 0.05, 0.88), (-0.65, -depth * 0.5 - 0.03, 0.44), "teal", 0.015)
    door(0.78, -depth * 0.5 - 0.03, 0, 0.32, 0.62, "terracotta_light")
    for x in (-0.95, 0, 0.95):
        box("FactoryWindow", (0.48, 0.04, 0.28), (x, -depth * 0.5 - 0.025, 1.03), "glass_dark", 0.012)
    cylinder("Stack", 0.18, 1.65, (1.15, 0.62, height + 0.62), "terracotta", 10)
    cylinder("StackCap", 0.23, 0.12, (1.15, 0.62, height + 1.48), "navy", 10)
    if variant == "warehouse":
        for x in (-width * 0.30, 0, width * 0.30):
            box("LoadingBay", (0.82, 0.05, 0.72), (x, depth * 0.5 + 0.03, 0.36), "navy", 0.012)
    elif variant == "logistics":
        box("OfficeAnnex", (1.55, 1.45, 1.08), (width * 0.30, -depth * 0.32, 0.54), "paper", 0.035)
        for x in (-width * 0.32, 0, width * 0.32):
            box("Dock", (0.92, 0.05, 0.68), (x, depth * 0.5 + 0.03, 0.34), "teal", 0.012)


def generate_park(spec, rng):
    footprint = spec["footprint"]
    width = footprint[0] * GRID_UNIT_METERS - 0.10
    depth = footprint[1] * GRID_UNIT_METERS - 0.10
    variant = spec.get("variant", "fountain")
    base_color = "sidewalk" if variant == "plaza" else "grass"
    box("ParkBase", (width, depth, 0.10), (0, 0, 0.05), base_color, 0.04)
    box("PathNS", (0.54, depth, 0.035), (0, 0, 0.115), "ochre", 0.012)
    box("PathEW", (width, 0.54, 0.035), (0, 0, 0.115), "ochre", 0.012)
    if variant == "playground":
        box("PlaySurface", (1.65, 1.35, 0.055), (0.55, 0.42, 0.15), "blue", 0.05)
        box("SlidePlatform", (0.52, 0.52, 0.12), (0.58, 0.45, 0.52), "ochre", 0.025)
        for x in (0.38, 0.78):
            cylinder("PlayPost", 0.04, 0.68, (x, 0.45, 0.46), "coral", 6)
        box("Slide", (0.35, 0.85, 0.09), (0.58, -0.02, 0.32), "teal", 0.015, (math.radians(-22), 0, 0))
        box("SwingTop", (0.95, 0.10, 0.10), (-0.75, 0.50, 0.93), "wood", 0.015)
        for x in (-1.10, -0.40):
            cylinder("SwingPost", 0.04, 0.92, (x, 0.50, 0.50), "wood", 6)
    else:
        radius = 0.72 if variant == "plaza" else 0.53
        cylinder("FountainBase", radius, 0.18, (0, 0, 0.20), "white", 12)
        cylinder("FountainWater", radius - 0.13, 0.05, (0, 0, 0.315), "water", 12)
    tree_x = width * 0.32
    tree_y = depth * 0.32
    tree_positions = ((-tree_x, tree_y, False), (tree_x, -tree_y, True)) if variant == "pocket" else (
        (-tree_x, -tree_y, False), (tree_x, -tree_y, True), (-tree_x, tree_y, True), (tree_x, tree_y, False)
    )
    for x, y, pine in tree_positions:
        add_tree_geometry(rng, x, y, 0.62, pine)
    for x, y, rot in ((-0.72, -0.48, 0), (0.72, 0.48, math.pi)):
        box("BenchSeat", (0.68, 0.20, 0.10), (x, y, 0.28), "wood", 0.015, (0, 0, rot))
        box("BenchBack", (0.68, 0.08, 0.30), (x, y + (0.11 if rot == 0 else -0.11), 0.42), "wood", 0.015, (0, 0, rot))


def add_cross_symbol(y: float, z: float):
    box("HealthCross", (0.62, 0.045, 0.18), (0, y, z), "coral", 0.02)
    box("HealthCross", (0.18, 0.045, 0.62), (0, y - 0.005, z), "coral", 0.02)


def generate_service(spec, rng):
    service = spec["service"]
    floors = spec["floors"]
    footprint = spec["footprint"]
    width = footprint[0] * GRID_UNIT_METERS - 0.75
    depth = footprint[1] * GRID_UNIT_METERS - 0.90
    floor_h = 0.66
    height = floors * floor_h
    accent = {"police": "blue", "fire": "coral", "health": "teal"}[service]
    box("ServiceMain", (width, depth, height), (0, 0, height * 0.5), "paper", 0.055)
    box("AccentBand", (width + 0.06, depth + 0.06, 0.18), (0, 0, height - 0.18), accent, 0.02)
    front_y = -depth * 0.5
    if service == "fire":
        for x in (-0.75, 0, 0.75):
            box("GarageDoor", (0.58, 0.05, 0.70), (x, front_y - 0.03, 0.35), "navy", 0.015)
            box("GarageStripe", (0.48, 0.06, 0.08), (x, front_y - 0.065, 0.38), "coral", 0.01)
    elif service == "health":
        box("EntranceCanopy", (1.35, 0.55, 0.14), (0, front_y - 0.28, 0.70), "teal", 0.025)
        door(0, front_y - 0.055, 0, 0.62, 0.72, "glass_dark")
        add_cross_symbol(front_y - 0.06, height - 0.52)
        side_windows(depth, width * 0.5, floors, floor_h, 0, 4, "glass")
    else:
        door(0, front_y - 0.03, 0, 0.52, 0.66, "navy")
        box("PoliceCanopy", (1.10, 0.48, 0.13), (0, front_y - 0.22, 0.69), "blue", 0.02)
    front_windows(width, front_y, floors, floor_h, 0, max(3, footprint[0] * 2), "glass_dark", back=True)
    box("ServiceRoof", (width + 0.12, depth + 0.12, 0.13), (0, 0, height + 0.065), accent, 0.025)
    if service == "police":
        cylinder("RadioMast", 0.035, 1.10, (0.65, 0, height + 0.62), "navy", 8)


def generate_school(spec, rng):
    footprint = spec["footprint"]
    width = footprint[0] * GRID_UNIT_METERS - 0.80
    depth = footprint[1] * GRID_UNIT_METERS - 1.05
    floors = spec["floors"]
    floor_h = 0.66
    height = floors * floor_h
    variant = spec["variant"]
    wing_depth = depth * (0.38 if variant == "secondary" else 0.32)
    box("SchoolMain", (width, depth * 0.52, height), (0, depth * 0.15, height * 0.5), "paper", 0.055)
    box("SchoolWingA", (width * 0.30, wing_depth, height * 0.72), (-width * 0.34, -depth * 0.28, height * 0.36), "cream", 0.045)
    box("SchoolWingB", (width * 0.30, wing_depth, height * 0.72), (width * 0.34, -depth * 0.28, height * 0.36), "cream", 0.045)
    front_y = -depth * 0.45
    box("SchoolEntrance", (1.35, 0.42, 0.72), (0, front_y, 0.36), "glass_dark", 0.025)
    box("SchoolCanopy", (1.60, 0.68, 0.13), (0, front_y - 0.10, 0.77), "teal", 0.025)
    front_windows(width, -depth * 0.11, floors, floor_h, 0, max(6, footprint[0] * 2), "glass", back=True)
    box("SchoolRoof", (width + 0.12, depth * 0.52 + 0.12, 0.13), (0, depth * 0.15, height + 0.065), "terracotta", 0.025)
    if variant == "secondary":
        box("Gym", (width * 0.42, depth * 0.34, 1.15), (width * 0.22, depth * 0.40, 0.575), "blue", 0.05)


def generate_agriculture(spec, rng):
    footprint = spec["footprint"]
    width = footprint[0] * GRID_UNIT_METERS - 0.62
    depth = footprint[1] * GRID_UNIT_METERS - 0.80
    variant = spec["variant"]
    box("FarmGround", (footprint[0] * GRID_UNIT_METERS - 0.10, footprint[1] * GRID_UNIT_METERS - 0.10, 0.08), (0, 0, 0.04), "grass_light", 0.03)
    if variant == "barn":
        box("Barn", (width * 0.64, depth * 0.72, 1.35), (-0.35, 0, 0.755), "coral", 0.04)
        gable_roof("BarnRoof", width * 0.64 + 0.16, depth * 0.72 + 0.18, 1.43, 0.62, "terracotta")
        box("BarnDoor", (0.78, 0.05, 0.92), (-0.35, -depth * 0.36 - 0.03, 0.52), "wood", 0.018)
        cylinder("Silo", 0.42, 1.52, (width * 0.29, 0.32, 0.84), "concrete_light", 10)
        cone("SiloRoof", 0.46, 0, 0.34, (width * 0.29, 0.32, 1.77), "navy", 10)
        for x, y in ((1.10, -0.80), (1.35, -0.42), (0.88, -0.35)):
            cylinder("HayBale", 0.20, 0.42, (x, y, 0.22), "ochre", 10, (0, math.pi / 2, 0))
    else:
        house_w = width * 0.44
        for x in (-width * 0.25, width * 0.25):
            box("Greenhouse", (house_w, depth * 0.86, 0.72), (x, 0, 0.40), "glass", 0.025)
            gable = gable_roof("GreenhouseRoof", house_w + 0.10, depth * 0.86 + 0.10, 0.76, 0.38, "glass")
            gable.location.x = x
        for x in (-width * 0.25, width * 0.25):
            box("GrowBed", (house_w * 0.70, depth * 0.62, 0.10), (x, 0, 0.14), "leaf", 0.018)


def generate_utility(spec, rng):
    footprint = spec["footprint"]
    width = footprint[0] * GRID_UNIT_METERS - 0.12
    depth = footprint[1] * GRID_UNIT_METERS - 0.12
    variant = spec["variant"]
    box("UtilityGround", (width, depth, 0.08), (0, 0, 0.04), "grass", 0.03)
    if variant == "wind":
        mast_h = 3.65
        cylinder("WindMast", 0.13, mast_h, (0, 0, mast_h * 0.5), "white", 10)
        cylinder("WindHub", 0.20, 0.30, (0, -0.12, mast_h), "ochre", 10, (math.pi / 2, 0, 0))
        blade_length = 1.25
        for angle in (0, 2 * math.pi / 3, 4 * math.pi / 3):
            x = math.sin(angle) * blade_length * 0.48
            z = mast_h + math.cos(angle) * blade_length * 0.48
            box("WindBlade", (0.13, 0.07, blade_length), (x, -0.28, z), "paper", 0.025, (0, angle, 0))
        box("Transformer", (0.62, 0.48, 0.48), (1.05, 0.85, 0.28), "teal", 0.03)
    elif variant == "water":
        tank_z = 2.65
        for x, y in ((-0.58, -0.58), (0.58, -0.58), (-0.58, 0.58), (0.58, 0.58)):
            cylinder("WaterLeg", 0.075, 2.20, (x, y, 1.10), "navy", 7)
        cylinder("WaterTank", 0.95, 1.15, (0, 0, tank_z), "teal", 12)
        cone("WaterRoof", 1.00, 0.0, 0.48, (0, 0, tank_z + 0.815), "terracotta", 12)
        cylinder("WaterPipe", 0.10, 2.10, (0, 0, 1.12), "blue", 8)
    else:
        rows, columns = 2, 4
        for row in range(rows):
            for col in range(columns):
                x = (col - (columns - 1) * 0.5) * 1.20
                y = (row - (rows - 1) * 0.5) * 1.25
                box("SolarPanel", (1.02, 0.72, 0.08), (x, y, 0.42), "glass_dark", 0.018, (math.radians(18), 0, 0))
                cylinder("SolarPost", 0.035, 0.32, (x, y + 0.10, 0.20), "concrete", 6)
        box("SolarInverter", (0.62, 0.45, 0.52), (width * 0.38, depth * 0.36, 0.30), "teal", 0.025)


def generate_sport(spec, rng):
    footprint = spec["footprint"]
    width = footprint[0] * GRID_UNIT_METERS - 0.12
    depth = footprint[1] * GRID_UNIT_METERS - 0.12
    variant = spec["variant"]
    surface = "grass" if variant == "football" else "terracotta_light"
    box("SportBase", (width, depth, 0.09), (0, 0, 0.045), surface, 0.025)
    box("MidLine", (0.045, depth * 0.88, 0.015), (0, 0, 0.105), "white", 0.003)
    box("BoundaryFront", (width * 0.90, 0.045, 0.015), (0, -depth * 0.44, 0.105), "white", 0.003)
    box("BoundaryBack", (width * 0.90, 0.045, 0.015), (0, depth * 0.44, 0.105), "white", 0.003)
    if variant == "football":
        for x in (-width * 0.44, width * 0.44):
            box("GoalBar", (0.045, 1.05, 0.045), (x, 0, 0.58), "white", 0.005)
            for y in (-0.50, 0.50):
                cylinder("GoalPost", 0.025, 0.92, (x, y, 0.47), "white", 6)
    else:
        for x in (-width * 0.36, width * 0.36):
            cylinder("HoopPost", 0.035, 1.10, (x, 0, 0.59), "navy", 7)
            box("Backboard", (0.08, 0.72, 0.48), (x, 0, 1.18), "white", 0.012)
            torus("Rim", 0.15, 0.018, (x - (0.10 if x > 0 else -0.10), 0, 1.08), "coral", (0, math.pi / 2, 0))


ROAD_CONNECTIONS = {
    "straight": ("north", "south"),
    "corner": ("north", "east"),
    "t": ("north", "east", "west"),
    "cross": ("north", "east", "south", "west"),
    "end": ("north",),
}


def generate_road(spec, rng):
    connections = ROAD_CONNECTIONS[spec["variant"]]
    style = spec.get("style", "local")
    tile_color = "grass" if style == "dirt" else "sidewalk"
    road_color = "ochre" if style == "dirt" else "asphalt"
    box("RoadTile", (1.98, 1.98, 0.07), (0, 0, 0.035), tile_color, 0.015)
    box("RoadCenter", (0.86, 0.86, 0.035), (0, 0, 0.087), road_color, 0.01)
    branches = {
        "north": ((0.86, 0.60, 0.035), (0, -0.70, 0.087), (0.08, 0.27, 0.012), (0, -0.71, 0.112)),
        "south": ((0.86, 0.60, 0.035), (0, 0.70, 0.087), (0.08, 0.27, 0.012), (0, 0.71, 0.112)),
        "east": ((0.60, 0.86, 0.035), (0.70, 0, 0.087), (0.27, 0.08, 0.012), (0.71, 0, 0.112)),
        "west": ((0.60, 0.86, 0.035), (-0.70, 0, 0.087), (0.27, 0.08, 0.012), (-0.71, 0, 0.112)),
    }
    for direction in connections:
        road_size, road_location, line_size, line_location = branches[direction]
        box("RoadBranch", road_size, road_location, road_color, 0.006)
        if style != "dirt":
            box("RoadLine", line_size, line_location, "road_line", 0.004)
    if spec["variant"] == "end" and style != "dirt":
        box("EndMark", (0.60, 0.07, 0.012), (0, 0.28, 0.112), "white", 0.004)


def generate_sloped_road(spec, rng):
    footprint = spec["footprint"]
    length = footprint[1] * GRID_UNIT_METERS - 0.02
    rise = spec["rise"]
    z_start, z_end = (0.0, rise) if spec["direction"] == "up" else (rise, 0.0)
    style = spec["style"]
    base_color = "grass" if style == "dirt" else "sidewalk"
    road_color = "ochre" if style == "dirt" else "asphalt"
    ramp_prism("SlopeBase", 1.98, length, z_start, z_end, 0.08, base_color)
    ramp_prism("SlopeRoad", 0.90, length, z_start + 0.025, z_end + 0.025, 0.025, road_color)
    if style != "dirt":
        inset = (z_end - z_start) * 0.11
        ramp_prism("SlopeLine", 0.075, length * 0.78, z_start + inset + 0.052, z_end - inset + 0.052, 0.012, "road_line")
    for x in (-0.64, 0.64):
        beam_between(
            "SlopeCurb",
            (x, -length * 0.5, z_start + 0.07),
            (x, length * 0.5, z_end + 0.07),
            0.075,
            0.07,
            "concrete_light" if style != "dirt" else "wood",
        )
    ramp_prism(f"{spec['id']}-colonly", 1.92, length, z_start + 0.08, z_end + 0.08, 0.16, None)


def add_bridge_railing_y(x: float, y_start: float, y_end: float, z_start: float = 0.0, z_end: float = 0.0):
    rail_height = 0.38
    beam_between(
        "BridgeRail",
        (x, y_start, z_start + rail_height),
        (x, y_end, z_end + rail_height),
        0.055,
        0.055,
        "teal",
    )
    for y, z in ((y_start, z_start), ((y_start + y_end) * 0.5, (z_start + z_end) * 0.5), (y_end, z_end)):
        cylinder("BridgePost", 0.035, rail_height, (x, y, z + rail_height * 0.5), "teal", 7)


def add_bridge_railing_x(y: float, x_start: float, x_end: float, z: float = 0.0):
    rail_height = 0.38
    beam_between("BridgeRail", (x_start, y, z + rail_height), (x_end, y, z + rail_height), 0.055, 0.055, "teal")
    for x in (x_start, (x_start + x_end) * 0.5, x_end):
        cylinder("BridgePost", 0.035, rail_height, (x, y, z + rail_height * 0.5), "teal", 7)


def generate_bridge(spec, rng):
    variant = spec["variant"]
    if variant == "ramp":
        length = GRID_UNIT_METERS - 0.02
        rise = spec["rise"]
        z_start, z_end = (0.0, rise) if spec["direction"] == "up" else (rise, 0.0)
        ramp_prism("BridgeRampSlab", 1.45, length, z_start, z_end, 0.16, "concrete_light")
        ramp_prism("BridgeRampRoad", 0.94, length, z_start + 0.025, z_end + 0.025, 0.025, "asphalt")
        inset = (z_end - z_start) * 0.11
        ramp_prism("BridgeRampLine", 0.075, length * 0.78, z_start + inset + 0.052, z_end - inset + 0.052, 0.012, "road_line")
        add_bridge_railing_y(-0.69, -length * 0.5, length * 0.5, z_start, z_end)
        add_bridge_railing_y(0.69, -length * 0.5, length * 0.5, z_start, z_end)
        ramp_prism(f"{spec['id']}-colonly", 1.38, length, z_start + 0.08, z_end + 0.08, 0.20, None)
        return

    connections = ROAD_CONNECTIONS[variant]
    slab_z = -0.10
    road_z = 0.018
    box("BridgeCenter", (0.92, 0.92, 0.20), (0, 0, slab_z), "concrete_light", 0.018)
    box("BridgeRoadCenter", (0.82, 0.82, 0.035), (0, 0, road_z), "asphalt", 0.008)
    branches = {
        "north": ((1.38, 0.62, 0.20), (0, -0.69, slab_z), (0.92, 0.62, 0.035), (0, -0.69, road_z)),
        "south": ((1.38, 0.62, 0.20), (0, 0.69, slab_z), (0.92, 0.62, 0.035), (0, 0.69, road_z)),
        "east": ((0.62, 1.38, 0.20), (0.69, 0, slab_z), (0.62, 0.92, 0.035), (0.69, 0, road_z)),
        "west": ((0.62, 1.38, 0.20), (-0.69, 0, slab_z), (0.62, 0.92, 0.035), (-0.69, 0, road_z)),
    }
    for direction in connections:
        slab_size, slab_location, road_size, road_location = branches[direction]
        box("BridgeBranch", slab_size, slab_location, "concrete_light", 0.014)
        box("BridgeRoad", road_size, road_location, "asphalt", 0.006)

    if variant == "straight":
        add_bridge_railing_y(-0.69, -0.99, 0.99)
        add_bridge_railing_y(0.69, -0.99, 0.99)
    else:
        if "north" in connections:
            add_bridge_railing_y(-0.69, -0.99, -0.28)
            add_bridge_railing_y(0.69, -0.99, -0.28)
        if "south" in connections:
            add_bridge_railing_y(-0.69, 0.28, 0.99)
            add_bridge_railing_y(0.69, 0.28, 0.99)
        if "east" in connections:
            add_bridge_railing_x(-0.69, 0.28, 0.99)
            add_bridge_railing_x(0.69, 0.28, 0.99)
        if "west" in connections:
            add_bridge_railing_x(-0.69, -0.99, -0.28)
            add_bridge_railing_x(0.69, -0.99, -0.28)
    if variant == "end":
        add_bridge_railing_x(0.48, -0.69, 0.69)


def generate_bridge_support(spec, rng):
    height = spec["support_height"]
    variant = spec["variant"]
    if variant == "abutment":
        box("AbutmentWall", (1.55, 0.48, height), (0, 0.30, height * 0.5), "concrete", 0.035)
        box("AbutmentCap", (1.68, 0.62, 0.16), (0, 0.30, height + 0.08), "concrete_light", 0.025)
        for x in (-0.78, 0.78):
            box("WingWall", (0.18, 1.18, height * 0.82), (x, 0.02, height * 0.41), "concrete", 0.025)
        return
    box("PierFoot", (1.30, 0.92, 0.16), (0, 0, 0.08), "concrete", 0.035)
    column_height = max(0.18, height - 0.20)
    for x in (-0.34, 0.34):
        cylinder("PierColumn", 0.16, column_height, (x, 0, 0.16 + column_height * 0.5), "concrete", 10)
    box("PierCap", (1.50, 0.62, 0.18), (0, 0, height - 0.09), "concrete_light", 0.025)


def generate_tree(spec, rng):
    variant = spec["variant"]
    if variant in ("oak", "pine"):
        add_tree_geometry(rng, 0, 0, 1.0, variant == "pine")
    elif variant == "birch":
        cylinder("BirchTrunk", 0.10, 0.92, (0, 0, 0.46), "white", 7)
        for index, (x, y, z) in enumerate(((-0.18, 0, 1.12), (0.20, 0.04, 1.16), (0, -0.10, 1.48))):
            ico(f"BirchCrown{index}", 0.46, (x, y, z), (0.90, 0.82, 1.08), "leaf_light")
    elif variant == "cypress":
        cylinder("CypressTrunk", 0.09, 0.88, (0, 0, 0.44), "wood", 7)
        cone("CypressLower", 0.38, 0.13, 1.36, (0, 0, 1.12), "leaf_dark", 9)
        cone("CypressUpper", 0.27, 0.0, 1.10, (0, 0, 1.88), "leaf", 9)
    else:
        cylinder("FlowerTrunk", 0.11, 0.78, (0, 0, 0.39), "wood", 7)
        for index, (x, y, z) in enumerate(((-0.20, 0, 1.00), (0.20, 0.05, 1.04), (0, -0.10, 1.30))):
            ico(f"FlowerCrown{index}", 0.43, (x, y, z), (1.0, 0.90, 0.95), "pink" if index != 1 else "paper")


GENERATORS = {
    "house": generate_house,
    "apartment": generate_apartment,
    "slab": generate_slab,
    "villa": generate_villa,
    "tower": generate_tower,
    "shop": generate_shop,
    "office": generate_office,
    "factory": generate_factory,
    "park": generate_park,
    "service": generate_service,
    "school": generate_school,
    "agriculture": generate_agriculture,
    "utility": generate_utility,
    "sport": generate_sport,
    "road": generate_road,
    "sloped_road": generate_sloped_road,
    "bridge": generate_bridge,
    "bridge_support": generate_bridge_support,
    "tree": generate_tree,
}


def join_visual_meshes(asset_id: str):
    visuals = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and not obj.name.endswith("-colonly")]
    if not visuals:
        raise RuntimeError(f"{asset_id}: nessuna mesh generata")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in visuals:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = visuals[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = f"{asset_id}_Visual"
    return joined


def object_z_bounds(obj) -> tuple[float, float]:
    values = [(obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box]
    return min(values), max(values)


def triangle_count(obj) -> int:
    return sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons)


def finalize_and_export(spec, output_dir: Path) -> dict:
    asset_id = spec["id"]
    visual = join_visual_meshes(asset_id)
    min_z, max_z = object_z_bounds(visual)
    height = max(0.12, max_z - min_z)
    footprint = spec["footprint"]

    bpy.ops.object.empty_add(type="PLAIN_AXES", location=(0, 0, 0))
    root = bpy.context.active_object
    root.name = asset_id
    root["asset_id"] = asset_id
    root["kind"] = spec["kind"]
    root["footprint_x"] = footprint[0]
    root["footprint_y"] = footprint[1]
    root["grid_unit_meters"] = GRID_UNIT_METERS
    root["seed"] = spec["seed"]
    root["height_meters"] = round(height, 4)
    root["min_z"] = round(min_z, 4)
    root["max_z"] = round(max_z, 4)
    root["origin_mode"] = spec.get("origin_mode", "ground")
    root["generator_version"] = GENERATOR_VERSION
    visual.parent = root

    existing_collisions = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name.endswith("-colonly")]
    if existing_collisions:
        for collision in existing_collisions:
            collision.parent = root
            collision.display_type = "WIRE"
    else:
        collision_height = 0.12 if spec["kind"] == "road" else height
        collision_width = footprint[0] * GRID_UNIT_METERS * (0.82 if spec["kind"] == "tree" else 0.90)
        collision_depth = footprint[1] * GRID_UNIT_METERS * (0.82 if spec["kind"] == "tree" else 0.90)
        collision_center_z = 0.06 if spec["kind"] == "road" else min_z + collision_height * 0.5
        collision = box(
            f"{asset_id}-colonly",
            (collision_width, collision_depth, collision_height),
            (0, 0, collision_center_z),
            None,
            0,
        )
        collision.parent = root
        collision.display_type = "WIRE"

    output_dir.mkdir(parents=True, exist_ok=True)
    glb_path = output_dir / f"{asset_id}.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        export_apply=True,
        export_extras=True,
        export_cameras=False,
        export_lights=False,
    )

    metadata = {
        "id": asset_id,
        "kind": spec["kind"],
        "footprint": footprint,
        "grid_unit_meters": GRID_UNIT_METERS,
        "elevation_step_meters": ELEVATION_STEP_METERS,
        "height_meters": round(height, 3),
        "min_z": round(min_z, 3),
        "max_z": round(max_z, 3),
        "triangles": triangle_count(visual),
        "seed": spec["seed"],
        "model": glb_path.name,
        "front_axis": "-Y",
        "origin_mode": spec.get("origin_mode", "ground"),
        "generator_version": GENERATOR_VERSION,
    }
    if "variant" in spec:
        metadata["variant"] = spec["variant"]
    if "service" in spec:
        metadata["service"] = spec["service"]
    for optional_key in ("style", "shape", "feature", "direction", "rise", "connections", "origin_mode", "support_height"):
        if optional_key in spec:
            metadata[optional_key] = spec[optional_key]
    with (output_dir / f"{asset_id}.json").open("w", encoding="utf-8") as handle:
        json.dump(metadata, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    return metadata


def generate_asset(spec, output_dir: Path) -> dict:
    reset_scene()
    rng = random.Random(spec["seed"])
    GENERATORS[spec["kind"]](spec, rng)
    return finalize_and_export(spec, output_dir)


def main() -> None:
    args = parse_args()
    output_dir = args.output.resolve()
    selected = [ASSET_BY_ID[args.asset]] if args.asset else ASSETS
    catalog = []
    for index, spec in enumerate(selected, start=1):
        print(f"[FOCUS] {index}/{len(selected)} Generazione {spec['id']}")
        catalog.append(generate_asset(spec, output_dir))
    with (output_dir / "catalog.json").open("w", encoding="utf-8") as handle:
        json.dump(
            {
                "generator_version": GENERATOR_VERSION,
                "grid_unit_meters": GRID_UNIT_METERS,
                "elevation_step_meters": ELEVATION_STEP_METERS,
                "assets": catalog,
            },
            handle,
            ensure_ascii=False,
            indent=2,
        )
        handle.write("\n")
    print(f"[FOCUS] Completato: {len(catalog)} asset in {output_dir}")


if __name__ == "__main__":
    main()
