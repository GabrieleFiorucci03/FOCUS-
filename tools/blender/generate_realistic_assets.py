"""Genera una variante piu dettagliata del kit FOCUS! senza toccare l'MVP.

La geometria di base resta quella dichiarata in ``focus_asset_specs.py``:
stessi ID, footprint, orientamento, quote e collisioni. Questo generatore
applica una direzione piu realistica e aggiunge un secondo livello di dettagli,
scrivendo per impostazione predefinita in ``assets/models/realistic``.

Esecuzione:
    blender --background --python tools/blender/generate_realistic_assets.py
    blender --background --python tools/blender/generate_realistic_assets.py -- --asset ID
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

import generate_mvp_assets as mvp  # noqa: E402
from focus_asset_specs import ASSETS, ASSET_BY_ID, GRID_UNIT_METERS  # noqa: E402


STYLE_ID = "realistic_preview_v1"
GENERATOR_VERSION = 1001

# Toni piu naturali e meno saturi. Le chiavi restano quelle dell'MVP per poter
# riusare tutte le ricette geometriche senza duplicarle.
REALISTIC_COLORS = {
    "cream": (0.70, 0.60, 0.46, 1.0),
    "paper": (0.82, 0.78, 0.67, 1.0),
    "sage": (0.36, 0.49, 0.35, 1.0),
    "peach": (0.68, 0.39, 0.29, 1.0),
    "blue": (0.25, 0.43, 0.52, 1.0),
    "ochre": (0.65, 0.43, 0.13, 1.0),
    "terracotta": (0.43, 0.14, 0.09, 1.0),
    "terracotta_light": (0.59, 0.25, 0.15, 1.0),
    "teal": (0.045, 0.30, 0.29, 1.0),
    "coral": (0.64, 0.14, 0.13, 1.0),
    "pink": (0.72, 0.37, 0.47, 1.0),
    "navy": (0.035, 0.08, 0.13, 1.0),
    "glass": (0.16, 0.37, 0.43, 1.0),
    "glass_dark": (0.035, 0.12, 0.16, 1.0),
    "window_warm": (0.82, 0.48, 0.16, 1.0),
    "concrete": (0.42, 0.43, 0.41, 1.0),
    "concrete_light": (0.62, 0.60, 0.54, 1.0),
    "asphalt": (0.055, 0.065, 0.07, 1.0),
    "road_line": (0.78, 0.61, 0.19, 1.0),
    "sidewalk": (0.44, 0.42, 0.37, 1.0),
    "grass": (0.19, 0.39, 0.18, 1.0),
    "grass_light": (0.33, 0.51, 0.22, 1.0),
    "leaf_dark": (0.055, 0.25, 0.12, 1.0),
    "leaf": (0.10, 0.38, 0.17, 1.0),
    "leaf_light": (0.27, 0.50, 0.17, 1.0),
    "wood": (0.22, 0.095, 0.035, 1.0),
    "water": (0.055, 0.34, 0.48, 1.0),
    "white": (0.76, 0.76, 0.72, 1.0),
    "black": (0.012, 0.015, 0.018, 1.0),
}

MATERIAL_SETTINGS = {
    "glass": {"metallic": 0.0, "roughness": 0.12},
    "glass_dark": {"metallic": 0.05, "roughness": 0.10},
    "water": {"metallic": 0.0, "roughness": 0.08},
    "asphalt": {"metallic": 0.0, "roughness": 0.94},
    "concrete": {"metallic": 0.0, "roughness": 0.88},
    "concrete_light": {"metallic": 0.0, "roughness": 0.86},
    "wood": {"metallic": 0.0, "roughness": 0.72},
    "navy": {"metallic": 0.32, "roughness": 0.40},
    "teal": {"metallic": 0.18, "roughness": 0.42},
    "black": {"metallic": 0.70, "roughness": 0.26},
}

BUILDING_KINDS = {
    "house", "apartment", "slab", "villa", "tower", "shop", "office",
    "factory", "service", "school", "agriculture",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Genera il kit realistico FOCUS!")
    parser.add_argument(
        "--asset",
        action="append",
        choices=sorted(ASSET_BY_ID),
        help="Genera uno o piu ID; l'opzione puo essere ripetuta",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=PROJECT_ROOT / "assets" / "models" / "realistic",
        help="Cartella di destinazione separata",
    )
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(argv)


def realistic_material(color_name: str, *, metallic: float = 0.0, roughness: float = 0.82):
    settings = MATERIAL_SETTINGS.get(color_name, {})
    metallic = settings.get("metallic", metallic)
    roughness = settings.get("roughness", max(0.36, roughness - 0.10))
    name = f"FOCUS_REAL_{color_name.upper()}"
    existing = bpy.data.materials.get(name)
    if existing:
        return existing

    mat = bpy.data.materials.new(name)
    color = REALISTIC_COLORS[color_name]
    mat.diffuse_color = color
    mat.use_nodes = True
    node = mat.node_tree.nodes.get("Principled BSDF")
    if node:
        node.inputs["Base Color"].default_value = color
        node.inputs["Metallic"].default_value = metallic
        node.inputs["Roughness"].default_value = roughness
        if "IOR" in node.inputs:
            node.inputs["IOR"].default_value = 1.46
        if color_name in {"glass", "glass_dark", "water"}:
            if "Coat Weight" in node.inputs:
                node.inputs["Coat Weight"].default_value = 0.32
            if "Coat Roughness" in node.inputs:
                node.inputs["Coat Roughness"].default_value = 0.08
    return mat


def assign_material(obj, color_name: str, *, metallic: float = 0.0, roughness: float = 0.82):
    obj.data.materials.append(realistic_material(color_name, metallic=metallic, roughness=roughness))
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
        modifier = obj.modifiers.new("RealisticBevel", "BEVEL")
        modifier.width = min(bevel * 0.75, min(size) * 0.22)
        modifier.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def cylinder(name: str, radius: float, depth: float, location, color: str, vertices: int = 8, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=max(16, vertices * 2), radius=radius, depth=depth,
        location=location, rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    return assign_material(obj, color)


def cone(name: str, radius1: float, radius2: float, depth: float, location, color: str, vertices: int = 8, rotation_z: float = 0.0):
    bpy.ops.mesh.primitive_cone_add(
        vertices=max(16, vertices * 2), radius1=radius1, radius2=radius2,
        depth=depth, location=location, rotation=(0.0, 0.0, rotation_z),
    )
    obj = bpy.context.active_object
    obj.name = name
    return assign_material(obj, color)


def torus(name: str, major_radius: float, minor_radius: float, location, color: str, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=24, minor_segments=8, major_radius=major_radius,
        minor_radius=minor_radius, location=location, rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    return assign_material(obj, color)


def ico(name: str, radius: float, location, scale, color: str, subdivisions: int = 1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=max(2, subdivisions), radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return assign_material(obj, color)


def install_realistic_primitives() -> None:
    """Fa usare alle ricette MVP materiali e primitive della nuova variante."""
    mvp.GENERATOR_VERSION = GENERATOR_VERSION
    mvp.COLORS.update(REALISTIC_COLORS)
    mvp.material = realistic_material
    mvp.assign_material = assign_material
    mvp.box = box
    mvp.cylinder = cylinder
    mvp.cone = cone
    mvp.torus = torus
    mvp.ico = ico


def _scene_bounds() -> tuple[Vector, Vector]:
    corners = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.name.endswith("-colonly"):
            continue
        corners.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not corners:
        return Vector((0, 0, 0)), Vector((0, 0, 0))
    return (
        Vector((min(p.x for p in corners), min(p.y for p in corners), min(p.z for p in corners))),
        Vector((max(p.x for p in corners), max(p.y for p in corners), max(p.z for p in corners))),
    )


def _reset_scene() -> None:
    """Azzera la scena e libera le mesh orfane fra un asset e il successivo."""
    mvp.reset_scene()
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for curve in list(bpy.data.curves):
        if curve.users == 0:
            bpy.data.curves.remove(curve)


def _combined_boxes(name: str, entries: list[tuple[tuple, tuple]], color: str) -> None:
    """Crea molti parallelepipedi in una sola mesh, evitando centinaia di oggetti."""
    if not entries:
        return
    vertices = []
    faces = []
    for size, location in entries:
        sx, sy, sz = (value * 0.5 for value in size)
        x, y, z = location
        start = len(vertices)
        vertices.extend(
            (
                (x - sx, y - sy, z - sz), (x + sx, y - sy, z - sz),
                (x + sx, y + sy, z - sz), (x - sx, y + sy, z - sz),
                (x - sx, y - sy, z + sz), (x + sx, y - sy, z + sz),
                (x + sx, y + sy, z + sz), (x - sx, y + sy, z + sz),
            )
        )
        faces.extend(
            (
                (start + 0, start + 1, start + 2, start + 3),
                (start + 4, start + 7, start + 6, start + 5),
                (start + 0, start + 4, start + 5, start + 1),
                (start + 1, start + 5, start + 6, start + 2),
                (start + 2, start + 6, start + 7, start + 3),
                (start + 4, start + 0, start + 3, start + 7),
            )
        )
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign_material(obj, color)


def _add_window_frames() -> None:
    candidates = [
        obj for obj in list(bpy.context.scene.objects)
        if obj.type == "MESH" and any(
            token in obj.name.lower()
            for token in ("window", "storefront", "modernglass", "entrance")
        )
    ]
    frames = []
    sills = []
    for obj in candidates:
        dimensions = obj.dimensions
        center = obj.location
        # Finestra su facciata nord/sud.
        if dimensions.y <= 0.12 and dimensions.x > 0.12 and dimensions.z > 0.14:
            thickness = max(0.035, dimensions.y + 0.014)
            width = dimensions.x + 0.055
            height = dimensions.z + 0.055
            for z in (center.z - height * 0.5, center.z + height * 0.5):
                frames.append(((width, thickness, 0.035), (center.x, center.y, z)))
            for x in (center.x - width * 0.5, center.x + width * 0.5):
                frames.append(((0.035, thickness, height), (x, center.y, center.z)))
            sills.append(((width + 0.04, thickness + 0.035, 0.035), (center.x, center.y, center.z - height * 0.5 - 0.018)))
        # Finestra sulle facciate laterali.
        elif dimensions.x <= 0.12 and dimensions.y > 0.12 and dimensions.z > 0.14:
            thickness = max(0.035, dimensions.x + 0.014)
            width = dimensions.y + 0.055
            height = dimensions.z + 0.055
            for z in (center.z - height * 0.5, center.z + height * 0.5):
                frames.append(((thickness, width, 0.035), (center.x, center.y, z)))
            for y in (center.y - width * 0.5, center.y + width * 0.5):
                frames.append(((thickness, 0.035, height), (center.x, y, center.z)))
            sills.append(((thickness + 0.035, width + 0.04, 0.035), (center.x, center.y, center.z - height * 0.5 - 0.018)))
    _combined_boxes("WindowFrames", frames, "black")
    _combined_boxes("WindowSills", sills, "concrete_light")


def _add_rooftop_details(spec: dict, rng: random.Random) -> None:
    # I dettagli devono partire dalla superficie del tetto, non dall'oggetto
    # piu alto della scena (per esempio un'antenna o una ciminiera gia presente).
    flat_roof_names = {
        "roof",
        "flatroof",
        "serviceroof",
        "schoolroof",
        "crown",
        "roofgarden",
    }
    roof_candidates = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        base_name = obj.name.lower().split(".", 1)[0]
        if base_name in flat_roof_names:
            roof_candidates.append(_object_bounds(obj))
    if not roof_candidates:
        return

    lower, upper = max(roof_candidates, key=lambda bounds_pair: bounds_pair[1].z)
    width = upper.x - lower.x
    depth = upper.y - lower.y
    if width < 0.8 or depth < 0.8:
        return

    z = upper.z
    detail_margin = min(0.44, width * 0.16)
    detail_depth = min(0.38, depth * 0.16)
    x = max(lower.x + detail_margin, min(upper.x - detail_margin, width * 0.12))
    y = max(lower.y + detail_depth, min(upper.y - detail_depth, depth * 0.08))

    # Il vecchio parallelepipedo HVAC, molto chiaro e privo di basamento,
    # sembrava un cubo sospeso. Manteniamo solo uno sfiato compatto appoggiato
    # direttamente alla quota del tetto.
    cylinder("RoofVent", 0.055, 0.34, (x, y, z + 0.17), "navy", 12)
    cylinder("RoofVentCap", 0.085, 0.045, (x, y, z + 0.35), "black", 12)

    if spec["kind"] in {"tower", "office", "service"}:
        mast_h = min(0.9, max(0.45, (upper.z - lower.z) * 0.08))
        cylinder("AntennaMast", 0.025, mast_h, (x + detail_margin, y, z + mast_h * 0.5), "black", 12)
        for dz in (0.32, 0.52):
            if dz < mast_h:
                box("AntennaBar", (0.24, 0.025, 0.025), (x + detail_margin, y, z + dz), "black", 0.003)


def _fix_agriculture_geometry(spec: dict) -> None:
    """Allinea le coperture agricole alla rispettiva struttura."""
    if spec.get("variant") != "barn":
        return
    barn = bpy.data.objects.get("Barn")
    roof = bpy.data.objects.get("BarnRoof")
    if barn is None or roof is None:
        return
    roof.location.x = barn.location.x
    roof.location.y = barn.location.y


def _replace_shed_roof(spec: dict) -> None:
    """Sostituisce la lastra ruotata con una falda a cuneo ben appoggiata."""
    if spec.get("kind") != "house" or spec.get("roof") != "shed":
        return
    house = bpy.data.objects.get("House")
    old_roof = bpy.data.objects.get("Roof")
    if house is None or old_roof is None:
        return

    lower, upper = _object_bounds(house)
    bpy.data.objects.remove(old_roof, do_unlink=True)
    half_width = (upper.x - lower.x + 0.16) * 0.5
    half_depth = (upper.y - lower.y + 0.18) * 0.5
    center_x = (lower.x + upper.x) * 0.5
    center_y = (lower.y + upper.y) * 0.5
    base_z = upper.z
    low_z = base_z + 0.12
    high_z = base_z + 0.38
    vertices = [
        (center_x - half_width, center_y - half_depth, low_z),
        (center_x + half_width, center_y - half_depth, low_z),
        (center_x + half_width, center_y + half_depth, high_z),
        (center_x - half_width, center_y + half_depth, high_z),
        (center_x - half_width, center_y - half_depth, base_z),
        (center_x + half_width, center_y - half_depth, base_z),
        (center_x + half_width, center_y + half_depth, base_z),
        (center_x - half_width, center_y + half_depth, base_z),
    ]
    faces = [
        (0, 1, 2, 3),
        (4, 7, 6, 5),
        (0, 4, 5, 1),
        (1, 5, 6, 2),
        (2, 6, 7, 3),
        (3, 7, 4, 0),
    ]
    mesh = bpy.data.meshes.new("Roof_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    roof = bpy.data.objects.new("Roof", mesh)
    bpy.context.collection.objects.link(roof)
    assign_material(roof, "terracotta")
    bevel = roof.modifiers.new("RealisticBevel", "BEVEL")
    bevel.width = 0.012
    bevel.segments = 2
    bpy.ops.object.select_all(action="DESELECT")
    roof.select_set(True)
    bpy.context.view_layer.objects.active = roof
    bpy.ops.object.modifier_apply(modifier=bevel.name)

    # La casa 10 ha un'ala bassa: una copertura dedicata evita che la sommità
    # chiara della muratura sembri attraversare la falda principale.
    side_wing = bpy.data.objects.get("SideWing")
    if side_wing is not None:
        wing_lower, wing_upper = _object_bounds(side_wing)
        box(
            "SideWingRoof",
            (wing_upper.x - wing_lower.x + 0.10, wing_upper.y - wing_lower.y + 0.10, 0.09),
            (
                (wing_lower.x + wing_upper.x) * 0.5,
                (wing_lower.y + wing_upper.y) * 0.5,
                wing_upper.z + 0.045,
            ),
            "terracotta_light",
            0.012,
        )


def _add_twin_tower_facade(spec: dict) -> None:
    """Completa la torre secondaria con la stessa scansione della principale."""
    if spec.get("id") != "RES_TOWER_4x4_003":
        return
    twin = bpy.data.objects.get("TowerTwin")
    if twin is None:
        return

    lower, upper = _object_bounds(twin)
    width = upper.x - lower.x
    depth = upper.y - lower.y
    height = upper.z - lower.z
    center_x = (lower.x + upper.x) * 0.5
    center_y = (lower.y + upper.y) * 0.5
    center_z = (lower.z + upper.z) * 0.5

    # Fasce orizzontali allineate ai piani della torre principale.
    floor_z = lower.z
    while floor_z < upper.z - 0.06:
        box(
            "TwinFloorBand",
            (width + 0.10, depth + 0.10, 0.065),
            (center_x, center_y, floor_z),
            "paper",
            0.010,
        )
        floor_z += 0.48
    box(
        "TwinFloorBand",
        (width + 0.10, depth + 0.10, 0.065),
        (center_x, center_y, upper.z),
        "paper",
        0.010,
    )

    # Montanti su tutte e quattro le facciate, proporzionati alla torre bassa.
    for fraction in (-0.34, 0.0, 0.34):
        x = center_x + width * fraction
        for y in (lower.y - 0.025, upper.y + 0.025):
            box("TwinMullion", (0.055, 0.040, height - 0.08), (x, y, center_z), "teal", 0.008)
        y = center_y + depth * fraction
        for x_side in (lower.x - 0.025, upper.x + 0.025):
            box("TwinMullion", (0.040, 0.055, height - 0.08), (x_side, y, center_z), "teal", 0.008)

    box(
        "TwinCrown",
        (width * 0.84, depth * 0.84, 0.30),
        (center_x, center_y, upper.z + 0.15),
        "terracotta_light",
        0.045,
    )


def _remove_ambiguous_roof_units() -> None:
    """Rimuove i volumi tecnici che sembrano cubi bianchi sospesi."""
    for obj in list(bpy.context.scene.objects):
        if obj.name.lower().split(".", 1)[0] == "roofunit":
            bpy.data.objects.remove(obj, do_unlink=True)


def _object_bounds(obj) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points))),
        Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points))),
    )


def _pipe_between(name: str, start, end, radius: float, color: str):
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=16,
        radius=radius,
        depth=direction.length,
        location=(start_v + end_v) * 0.5,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    return assign_material(obj, color)


def _add_roof_drainage() -> None:
    """Aggiunge grondaia, pluviale e terminale senza anelli decorativi."""
    roof_names = {"roof", "flatroof", "wingroof", "serviceroof", "schoolroof"}
    candidates = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        base_name = obj.name.lower().split(".", 1)[0]
        if base_name not in roof_names:
            continue
        lower, upper = _object_bounds(obj)
        candidates.append((lower, upper))
    if not candidates:
        return

    # Il tetto principale e quello con la linea di gronda piu alta: in questo
    # modo le ali basse di ville e scuole non spostano il pluviale principale.
    lower, upper = max(candidates, key=lambda bounds_pair: bounds_pair[0].z)
    eave_z = lower.z + 0.025
    gutter_y = lower.y - 0.012
    gutter_x = (lower.x + upper.x) * 0.5
    gutter_length = max(0.40, upper.x - lower.x - 0.05)
    pipe_x = upper.x - 0.075
    pipe_top = eave_z + 0.018
    pipe_bottom = 0.13
    color = "concrete"

    cylinder(
        "RoofGutter",
        0.018,
        gutter_length,
        (gutter_x, gutter_y, eave_z),
        color,
        16,
        (0, math.pi / 2, 0),
    )
    _pipe_between(
        "Downpipe",
        (pipe_x, gutter_y, pipe_bottom),
        (pipe_x, gutter_y, pipe_top),
        0.016,
        color,
    )
    _pipe_between(
        "DownpipeOutlet",
        (pipe_x, gutter_y, pipe_bottom),
        (pipe_x, gutter_y - 0.11, 0.07),
        0.018,
        color,
    )


def _add_building_details(spec: dict, rng: random.Random) -> None:
    _add_window_frames()
    lower, upper = _scene_bounds()
    footprint = spec["footprint"]
    front_y = -footprint[1] * GRID_UNIT_METERS * 0.5 + 0.10

    # Applique esterna e piccolo marciapiede d'ingresso, sempre dentro il lotto.
    lamp_z = min(0.72, max(0.38, (upper.z - lower.z) * 0.28))
    box("WallLampBase", (0.10, 0.055, 0.16), (0, front_y, lamp_z), "black", 0.012)
    box("WallLampGlass", (0.07, 0.06, 0.09), (0, front_y - 0.01, lamp_z), "window_warm", 0.01)
    box("EntranceStep", (0.66, 0.26, 0.06), (0, front_y + 0.11, 0.03), "concrete_light", 0.012)

    if spec["kind"] not in {"house", "villa", "agriculture"} or spec.get("roof") == "flat":
        _add_rooftop_details(spec, rng)

    # Sistema di raccolta acqua coerente: grondaia collegata, pluviale sottile
    # e terminale inclinato. Nessun toro completo, che sembrerebbe un anello.
    if spec["kind"] in {"house", "villa", "apartment", "school", "service"}:
        _add_roof_drainage()

    if spec["kind"] in {"factory", "agriculture"}:
        # Nervature verticali per dare scala alle grandi superfici industriali.
        span = min(upper.x - lower.x, footprint[0] * GRID_UNIT_METERS - 0.30)
        for index in range(-3, 4):
            x = index * span / 7.0
            box("FacadeRib", (0.025, 0.035, min(upper.z * 0.72, 1.2)), (x, front_y, min(upper.z * 0.36, 0.6)), "navy", 0.002)


def _add_tree_details(spec: dict, rng: random.Random) -> None:
    variant = spec.get("variant", "oak")
    lower, upper = _scene_bounds()
    trunk_top = max(0.58, min(upper.z * 0.48, 0.96))
    branch_color = "white" if variant == "birch" else "wood"
    for index, angle in enumerate((0.35, 2.45, 4.55)):
        start = Vector((0, 0, trunk_top * 0.72))
        end = Vector((math.cos(angle) * 0.34, math.sin(angle) * 0.34, trunk_top + 0.28 + index * 0.04))
        mvp.beam_between("Branch", start, end, 0.045, 0.045, branch_color)
    if variant != "cypress":
        for index in range(7):
            angle = index * (math.tau / 7.0) + rng.uniform(-0.18, 0.18)
            radius = rng.uniform(0.17, 0.26)
            z = rng.uniform(trunk_top, max(trunk_top + 0.15, upper.z - 0.10))
            ico(
                "FoliageCluster", radius,
                (math.cos(angle) * rng.uniform(0.18, 0.46), math.sin(angle) * rng.uniform(0.18, 0.46), z),
                (1.0, 0.85, 0.92),
                "leaf_light" if index % 3 == 0 else "leaf", 2,
            )
    for angle in (0, math.tau / 3, math.tau * 2 / 3):
        box(
            "RootFlare", (0.28, 0.065, 0.055),
            (math.cos(angle) * 0.10, math.sin(angle) * 0.10, 0.035),
            branch_color, 0.012, (0, 0, angle),
        )


def _add_landscape_details(spec: dict, rng: random.Random) -> None:
    footprint = spec["footprint"]
    extent_x = footprint[0] * GRID_UNIT_METERS * 0.5 - 0.22
    extent_y = footprint[1] * GRID_UNIT_METERS * 0.5 - 0.22
    positions = (
        (-extent_x * 0.72, -extent_y * 0.76),
        (extent_x * 0.74, -extent_y * 0.68),
        (-extent_x * 0.76, extent_y * 0.70),
        (extent_x * 0.68, extent_y * 0.76),
    )
    for index, (x, y) in enumerate(positions):
        ico("Shrub", 0.16 + (index % 2) * 0.04, (x, y, 0.16), (1.0, 0.88, 0.82), "leaf_dark" if index % 2 else "leaf", 2)
        for petal in range(3):
            angle = petal * math.tau / 3 + index
            ico("Flower", 0.025, (x + math.cos(angle) * 0.12, y + math.sin(angle) * 0.12, 0.16), (1, 1, 1), "pink", 1)


def _add_road_details(spec: dict, rng: random.Random) -> None:
    style = spec.get("style", "local")
    if spec["kind"] == "road":
        if style == "dirt":
            for index in range(12):
                side = -1 if index % 2 else 1
                x = side * rng.uniform(0.48, 0.82)
                y = rng.uniform(-0.82, 0.82)
                ico("RoadStone", rng.uniform(0.025, 0.065), (x, y, 0.12), (1.4, 0.9, 0.55), "concrete", 1)
        else:
            for x in (-0.64, 0.64):
                for y in (-0.42, 0.42):
                    box("DrainGrate", (0.16, 0.10, 0.012), (x, y, 0.125), "black", 0.003)
                    for groove in (-0.045, 0, 0.045):
                        box("DrainSlot", (0.012, 0.082, 0.006), (x + groove, y, 0.134), "navy", 0.001)
    else:
        length = spec["footprint"][1] * GRID_UNIT_METERS - 0.02
        rise = spec["rise"]
        for y in (-length * 0.40, length * 0.40):
            t = (y + length * 0.5) / length
            z = (rise * t) if spec["direction"] == "up" else (rise * (1.0 - t))
            for x in (-0.62, 0.62):
                cylinder("RoadReflector", 0.025, 0.18, (x, y, z + 0.16), "white", 12)
                box("Reflector", (0.04, 0.025, 0.055), (x, y - 0.018, z + 0.20), "road_line", 0.004)


def _add_bridge_details(spec: dict, rng: random.Random) -> None:
    if spec["kind"] == "bridge_support":
        height = spec.get("support_height", 0.5)
        for z in (height * 0.30, height * 0.66):
            box("FormworkJoint", (1.42, 0.018, 0.018), (0, -0.31, z), "black", 0.002)
        for x in (-0.48, 0.48):
            for y in (-0.24, 0.24):
                cylinder("AnchorBolt", 0.025, 0.055, (x, y, max(0.12, height - 0.04)), "black", 12)
        return

    if spec.get("variant") == "ramp":
        length = GRID_UNIT_METERS - 0.02
        rise = spec["rise"]
        for y in (-length * 0.43, length * 0.43):
            t = (y + length * 0.5) / length
            z = (rise * t) if spec["direction"] == "up" else (rise * (1.0 - t))
            box("ExpansionJoint", (0.90, 0.055, 0.018), (0, y, z + 0.055), "black", 0.004)
        return

    for y in (-0.52, 0.52):
        box("UnderDeckBeam", (1.32, 0.13, 0.18), (0, y, -0.25), "concrete", 0.015)
    for x in (-0.52, 0.52):
        for y in (-0.52, 0.52):
            cylinder("DeckBolt", 0.024, 0.04, (x, y, 0.055), "black", 12)
    box("ExpansionJoint", (0.88, 0.055, 0.018), (0, -0.43, 0.045), "black", 0.004)


def _add_utility_details(spec: dict, rng: random.Random) -> None:
    variant = spec.get("variant")
    if variant == "solar":
        for y in (-0.62, 0.62):
            box("CableTray", (4.10, 0.055, 0.055), (0, y, 0.14), "black", 0.008)
    elif variant == "water":
        for z in (0.75, 1.40):
            for rotation in (math.radians(45), math.radians(-45)):
                box("TankBrace", (1.55, 0.055, 0.055), (0, -0.59, z), "black", 0.006, (0, rotation, 0))
    elif variant == "wind":
        for x in (-0.42, 0.42):
            box("MaintenanceFence", (0.055, 1.10, 0.62), (x, 0.75, 0.35), "black", 0.008)


def _add_sport_details(spec: dict, rng: random.Random) -> None:
    footprint = spec["footprint"]
    width = footprint[0] * GRID_UNIT_METERS - 0.22
    depth = footprint[1] * GRID_UNIT_METERS - 0.22
    for x in (-width * 0.49, width * 0.49):
        for y in (-depth * 0.40, 0, depth * 0.40):
            cylinder("FencePost", 0.025, 0.72, (x, y, 0.39), "black", 12)
        for z in (0.20, 0.52, 0.74):
            box("FenceRail", (0.035, depth * 0.90, 0.025), (x, 0, z), "black", 0.003)
    for x in (-width * 0.44, width * 0.44):
        cylinder("FloodlightPole", 0.035, 1.62, (x, depth * 0.43, 0.86), "navy", 12)
        box("Floodlight", (0.32, 0.14, 0.20), (x, depth * 0.43, 1.67), "window_warm", 0.012, (math.radians(-18), 0, 0))


def add_realistic_details(spec: dict, rng: random.Random) -> None:
    kind = spec["kind"]
    _remove_ambiguous_roof_units()
    _replace_shed_roof(spec)
    _add_twin_tower_facade(spec)
    if kind == "agriculture":
        _fix_agriculture_geometry(spec)
    if kind in BUILDING_KINDS:
        _add_building_details(spec, rng)
    if kind == "tree":
        _add_tree_details(spec, rng)
    elif kind == "park":
        _add_landscape_details(spec, rng)
    elif kind in {"road", "sloped_road"}:
        _add_road_details(spec, rng)
    elif kind in {"bridge", "bridge_support"}:
        _add_bridge_details(spec, rng)
    elif kind == "utility":
        _add_utility_details(spec, rng)
    elif kind == "sport":
        _add_sport_details(spec, rng)


def generate_asset(spec: dict, output_dir: Path) -> dict:
    _reset_scene()
    rng = random.Random(spec["seed"])
    mvp.GENERATORS[spec["kind"]](spec, rng)
    add_realistic_details(spec, rng)
    metadata = mvp.finalize_and_export(spec, output_dir)
    metadata["style_variant"] = STYLE_ID
    metadata["source_asset_id"] = spec["id"]
    with (output_dir / f"{spec['id']}.json").open("w", encoding="utf-8") as handle:
        json.dump(metadata, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    return metadata


def main() -> None:
    args = parse_args()
    output_dir = args.output.resolve()
    selected = [ASSET_BY_ID[asset_id] for asset_id in args.asset] if args.asset else ASSETS
    install_realistic_primitives()

    catalog = []
    for index, spec in enumerate(selected, start=1):
        print(f"[FOCUS REAL] {index}/{len(selected)} Generazione {spec['id']}")
        catalog.append(generate_asset(spec, output_dir))

    catalog_path = output_dir / "catalog.json"
    if args.asset and catalog_path.exists():
        with catalog_path.open("r", encoding="utf-8") as handle:
            existing_catalog = json.load(handle).get("assets", [])
        by_id = {item["id"]: item for item in existing_catalog}
        by_id.update({item["id"]: item for item in catalog})
        catalog = [by_id[spec["id"]] for spec in ASSETS if spec["id"] in by_id]

    with catalog_path.open("w", encoding="utf-8") as handle:
        json.dump(
            {
                "generator_version": GENERATOR_VERSION,
                "style_variant": STYLE_ID,
                "grid_unit_meters": mvp.GRID_UNIT_METERS,
                "elevation_step_meters": mvp.ELEVATION_STEP_METERS,
                "assets": catalog,
            },
            handle,
            ensure_ascii=False,
            indent=2,
        )
        handle.write("\n")
    print(f"[FOCUS REAL] Completato: {len(catalog)} asset in {output_dir}")


if __name__ == "__main__":
    main()
