"""Specifiche dichiarative del primo kit di asset di FOCUS!.

Questo modulo non importa bpy: puo essere letto anche fuori da Blender per
ispezionare il catalogo o generare dati per Godot.
"""

GRID_UNIT_METERS = 2.0


ASSETS = [
    # Residenziale bassa densita: cinque silhouette e palette differenti.
    {"id": "RES_LOW_1x1_001", "kind": "house", "footprint": [1, 1], "seed": 101, "floors": 1, "roof": "gable", "palette": "cream"},
    {"id": "RES_LOW_1x1_002", "kind": "house", "footprint": [1, 1], "seed": 102, "floors": 1, "roof": "hip", "palette": "sage"},
    {"id": "RES_LOW_1x1_003", "kind": "house", "footprint": [1, 1], "seed": 103, "floors": 2, "roof": "gable", "palette": "peach"},
    {"id": "RES_LOW_1x1_004", "kind": "house", "footprint": [1, 1], "seed": 104, "floors": 2, "roof": "flat", "palette": "blue"},
    {"id": "RES_LOW_1x1_005", "kind": "house", "footprint": [1, 1], "seed": 105, "floors": 1, "roof": "shed", "palette": "ochre"},
    {"id": "RES_LOW_1x2_006", "kind": "house", "footprint": [1, 2], "seed": 106, "floors": 1, "roof": "gable", "palette": "blue", "feature": "garage"},
    {"id": "RES_LOW_2x1_007", "kind": "house", "footprint": [2, 1], "seed": 107, "floors": 2, "roof": "gable", "palette": "sage", "feature": "duplex"},
    {"id": "RES_LOW_1x1_008", "kind": "house", "footprint": [1, 1], "seed": 108, "floors": 1, "roof": "flat", "palette": "paper", "feature": "modern"},
    {"id": "RES_LOW_1x2_009", "kind": "house", "footprint": [1, 2], "seed": 109, "floors": 2, "roof": "hip", "palette": "peach", "feature": "porch"},
    {"id": "RES_LOW_2x1_010", "kind": "house", "footprint": [2, 1], "seed": 110, "floors": 1, "roof": "shed", "palette": "ochre", "feature": "courtyard"},

    # Residenziale media e alta densita.
    {"id": "RES_MID_2x2_001", "kind": "apartment", "footprint": [2, 2], "seed": 201, "floors": 4, "palette": "cream", "balconies": True},
    {"id": "RES_MID_2x2_002", "kind": "apartment", "footprint": [2, 2], "seed": 202, "floors": 5, "palette": "sage", "balconies": False},
    {"id": "RES_MID_2x2_003", "kind": "apartment", "footprint": [2, 2], "seed": 203, "floors": 6, "palette": "peach", "balconies": True},
    {"id": "RES_MID_2x2_004", "kind": "apartment", "footprint": [2, 2], "seed": 204, "floors": 4, "palette": "blue", "balconies": True, "shape": "stepped"},
    {"id": "RES_MID_2x3_005", "kind": "apartment", "footprint": [2, 3], "seed": 205, "floors": 6, "palette": "cream", "balconies": False, "shape": "wing"},
    {"id": "RES_MID_3x2_006", "kind": "apartment", "footprint": [3, 2], "seed": 206, "floors": 5, "palette": "sage", "balconies": True, "shape": "twin"},
    {"id": "RES_HIGH_2x2_001", "kind": "slab", "footprint": [2, 2], "seed": 301, "floors": 9, "palette": "cream"},
    {"id": "RES_HIGH_2x3_002", "kind": "slab", "footprint": [2, 3], "seed": 302, "floors": 12, "palette": "blue", "shape": "offset"},
    {"id": "RES_LUX_2x2_001", "kind": "villa", "footprint": [2, 2], "seed": 401, "floors": 2, "palette": "cream", "pool": True},
    {"id": "RES_LUX_2x2_002", "kind": "villa", "footprint": [2, 2], "seed": 402, "floors": 2, "palette": "blue", "pool": False},
    {"id": "RES_LUX_2x2_003", "kind": "villa", "footprint": [2, 2], "seed": 403, "floors": 1, "palette": "sage", "pool": False, "shape": "courtyard"},
    {"id": "RES_LUX_3x2_004", "kind": "villa", "footprint": [3, 2], "seed": 404, "floors": 2, "palette": "paper", "pool": True, "shape": "modern"},
    {"id": "RES_TOWER_3x3_001", "kind": "tower", "footprint": [3, 3], "seed": 501, "floors": 16, "palette": "glass"},
    {"id": "RES_TOWER_3x3_002", "kind": "tower", "footprint": [3, 3], "seed": 502, "floors": 20, "palette": "glass", "shape": "setback"},
    {"id": "RES_TOWER_4x4_003", "kind": "tower", "footprint": [4, 4], "seed": 503, "floors": 24, "palette": "glass", "shape": "twin"},

    # Commercio, uffici e industria.
    {"id": "COM_LOW_1x1_001", "kind": "shop", "footprint": [1, 1], "seed": 601, "palette": "coral"},
    {"id": "COM_LOW_1x1_002", "kind": "shop", "footprint": [1, 1], "seed": 602, "palette": "teal"},
    {"id": "COM_LOW_1x1_003", "kind": "shop", "footprint": [1, 1], "seed": 603, "palette": "ochre", "variant": "cafe"},
    {"id": "COM_LOW_2x1_004", "kind": "shop", "footprint": [2, 1], "seed": 604, "palette": "coral", "variant": "restaurant"},
    {"id": "COM_MID_2x2_005", "kind": "shop", "footprint": [2, 2], "seed": 605, "palette": "teal", "variant": "market"},
    {"id": "COM_KIOSK_1x1_006", "kind": "shop", "footprint": [1, 1], "seed": 606, "palette": "blue", "variant": "kiosk"},
    {"id": "OFF_LOW_2x2_001", "kind": "office", "footprint": [2, 2], "seed": 701, "floors": 5, "palette": "glass"},
    {"id": "OFF_MID_2x2_002", "kind": "office", "footprint": [2, 2], "seed": 702, "floors": 7, "palette": "glass", "shape": "stepped"},
    {"id": "OFF_MID_3x3_003", "kind": "office", "footprint": [3, 3], "seed": 703, "floors": 10, "palette": "glass", "shape": "atrium"},
    {"id": "IND_LOW_2x2_001", "kind": "factory", "footprint": [2, 2], "seed": 801, "palette": "industrial"},
    {"id": "IND_LOW_3x2_002", "kind": "factory", "footprint": [3, 2], "seed": 802, "palette": "industrial", "variant": "warehouse"},
    {"id": "IND_MID_3x3_003", "kind": "factory", "footprint": [3, 3], "seed": 803, "palette": "industrial", "variant": "logistics"},

    # Spazi pubblici e servizi.
    {"id": "PARK_2x2_001", "kind": "park", "footprint": [2, 2], "seed": 901, "palette": "park"},
    {"id": "PARK_2x2_002", "kind": "park", "footprint": [2, 2], "seed": 902, "palette": "park", "variant": "playground"},
    {"id": "PARK_3x3_003", "kind": "park", "footprint": [3, 3], "seed": 903, "palette": "park", "variant": "plaza"},
    {"id": "PARK_1x1_004", "kind": "park", "footprint": [1, 1], "seed": 904, "palette": "park", "variant": "pocket"},
    {"id": "CIV_POLICE_2x2_001", "kind": "service", "service": "police", "footprint": [2, 2], "seed": 1001, "floors": 2, "palette": "cream"},
    {"id": "CIV_FIRE_2x2_001", "kind": "service", "service": "fire", "footprint": [2, 2], "seed": 1002, "floors": 2, "palette": "cream"},
    {"id": "CIV_HEALTH_3x3_001", "kind": "service", "service": "health", "footprint": [3, 3], "seed": 1003, "floors": 3, "palette": "cream"},
    {"id": "CIV_POLICE_3x2_002", "kind": "service", "service": "police", "footprint": [3, 2], "seed": 1004, "floors": 3, "palette": "blue", "variant": "central"},
    {"id": "CIV_FIRE_3x2_002", "kind": "service", "service": "fire", "footprint": [3, 2], "seed": 1005, "floors": 2, "palette": "coral", "variant": "central"},
    {"id": "CIV_HEALTH_2x2_002", "kind": "service", "service": "health", "footprint": [2, 2], "seed": 1006, "floors": 2, "palette": "cream", "variant": "clinic"},

    # Il runtime ruota/combina questi moduli in base ai vicini.
    {"id": "ROAD_LOCAL_1x1_STRAIGHT", "kind": "road", "variant": "straight", "footprint": [1, 1], "seed": 1101},
    {"id": "ROAD_LOCAL_1x1_CORNER", "kind": "road", "variant": "corner", "footprint": [1, 1], "seed": 1102},
    {"id": "ROAD_LOCAL_1x1_T", "kind": "road", "variant": "t", "footprint": [1, 1], "seed": 1103},
    {"id": "ROAD_LOCAL_1x1_CROSS", "kind": "road", "variant": "cross", "footprint": [1, 1], "seed": 1104},
    {"id": "ROAD_LOCAL_1x1_END", "kind": "road", "variant": "end", "footprint": [1, 1], "seed": 1105},
    {"id": "ROAD_DIRT_1x1_STRAIGHT", "kind": "road", "variant": "straight", "style": "dirt", "footprint": [1, 1], "seed": 1111},
    {"id": "ROAD_DIRT_1x1_CORNER", "kind": "road", "variant": "corner", "style": "dirt", "footprint": [1, 1], "seed": 1112},
    {"id": "ROAD_DIRT_1x1_T", "kind": "road", "variant": "t", "style": "dirt", "footprint": [1, 1], "seed": 1113},
    {"id": "ROAD_DIRT_1x1_CROSS", "kind": "road", "variant": "cross", "style": "dirt", "footprint": [1, 1], "seed": 1114},
    {"id": "ROAD_DIRT_1x1_END", "kind": "road", "variant": "end", "style": "dirt", "footprint": [1, 1], "seed": 1115},

    # Vegetazione riutilizzabile con instancing/MultiMesh in Godot.
    {"id": "NAT_TREE_OAK_1x1_001", "kind": "tree", "variant": "oak", "footprint": [1, 1], "seed": 1201},
    {"id": "NAT_TREE_PINE_1x1_001", "kind": "tree", "variant": "pine", "footprint": [1, 1], "seed": 1202},
    {"id": "NAT_TREE_BIRCH_1x1_001", "kind": "tree", "variant": "birch", "footprint": [1, 1], "seed": 1203},
    {"id": "NAT_TREE_CYPRESS_1x1_001", "kind": "tree", "variant": "cypress", "footprint": [1, 1], "seed": 1204},
    {"id": "NAT_TREE_FLOWER_1x1_001", "kind": "tree", "variant": "flowering", "footprint": [1, 1], "seed": 1205},
    {"id": "NAT_TREE_OAK_1x1_002", "kind": "tree", "variant": "oak", "footprint": [1, 1], "seed": 1206},

    # Prime categorie aggiuntive per espandere il quartiere MVP.
    {"id": "EDU_SCHOOL_3x3_001", "kind": "school", "footprint": [3, 3], "seed": 1301, "floors": 2, "variant": "primary"},
    {"id": "EDU_SCHOOL_4x3_002", "kind": "school", "footprint": [4, 3], "seed": 1302, "floors": 3, "variant": "secondary"},
    {"id": "AGR_BARN_2x2_001", "kind": "agriculture", "footprint": [2, 2], "seed": 1401, "variant": "barn"},
    {"id": "AGR_GREENHOUSE_3x2_001", "kind": "agriculture", "footprint": [3, 2], "seed": 1402, "variant": "greenhouse"},
    {"id": "UTIL_WIND_2x2_001", "kind": "utility", "footprint": [2, 2], "seed": 1501, "variant": "wind"},
    {"id": "UTIL_WATER_2x2_001", "kind": "utility", "footprint": [2, 2], "seed": 1502, "variant": "water"},
    {"id": "UTIL_SOLAR_3x2_001", "kind": "utility", "footprint": [3, 2], "seed": 1503, "variant": "solar"},
    {"id": "SPORT_FOOTBALL_3x2_001", "kind": "sport", "footprint": [3, 2], "seed": 1601, "variant": "football"},
    {"id": "SPORT_BASKET_2x1_001", "kind": "sport", "footprint": [2, 1], "seed": 1602, "variant": "basketball"},
]


ASSET_BY_ID = {asset["id"]: asset for asset in ASSETS}
