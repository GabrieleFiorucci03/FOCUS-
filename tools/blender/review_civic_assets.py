"""Validate and render the actual civic GLBs; build an offline review gallery.

blender -b --python tools/blender/review_civic_assets.py -- [--asset ID] [--skip-existing]
"""
import argparse
import html
import json
import struct
import shutil
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import render_refined_assets as renderer

ROOT = HERE.parents[1]
OUT = ROOT / 'assets/previews/civic_v3'
MODELS = ROOT / 'assets/models/refined_v2'


def validate(a):
    path = MODELS / a['model']
    data = path.read_bytes()
    magic, version, size = struct.unpack_from('<4sII', data)
    assert magic == b'glTF' and version == 2 and size == len(data), path
    count, _ = struct.unpack_from('<II', data, 12)
    doc = json.loads(data[20:20+count])
    assert all('bufferView' in i and 'uri' not in i for i in doc.get('images', []))
    assert a['front_axis'] == '-Y' and a['grid_unit_meters'] == 2
    assert json.loads(path.with_suffix('.json').read_text(encoding='utf-8')) == a
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(path))
    visual, collisions = [], []
    triangles = 0
    for ob in bpy.context.scene.objects:
        if ob.type != 'MESH':
            continue
        vertices = [ob.matrix_world @ v.co for v in ob.data.vertices]
        if 'colonly' in ob.name:
            collisions.extend(vertices)
        else:
            visual.extend(vertices)
            ob.data.calc_loop_triangles()
            triangles += len(ob.data.loop_triangles)
            assert ob.data.uv_layers, (a['id'], 'missing UV')
    assert collisions and visual
    assert triangles == a['triangles'], (a['id'], triangles, a['triangles'])
    xyz = np.array([tuple(v) for v in visual])
    assert np.isfinite(xyz).all()
    lo, hi = xyz.min(axis=0), xyz.max(axis=0)
    for axis in (0, 1):
        assert lo[axis] >= -a['footprint'][axis]-.001, (a['id'], 'lot min', lo.tolist())
        assert hi[axis] <= a['footprint'][axis]+.001, (a['id'], 'lot max', hi.tolist())
    assert abs((hi[2]-lo[2])-a['height_meters']) < .002
    assert min(a['windows_by_side'].values()) > 0
    return dict(id=a['id'], triangles=triangles, bytes=len(data),
                bounds=[lo.round(4).tolist(), hi.round(4).tolist()],
                embedded_images=len(doc.get('images', [])), collision_vertices=len(collisions))


def gallery(assets):
    cards = []
    for a in assets:
        views = ''.join(f'<a href="renders/{a["id"]}__civic_v3__{v}.png"><img src="renders/{a["id"]}__civic_v3__{v}.png" alt="{v}" loading="lazy"></a>' for v in ('front', 'rear'))
        cards.append(f'<article><h2>{html.escape(a["name"])}</h2><p>{a["footprint"][0]} × {a["footprint"][1]} celle · {a["triangles"]:,} triangoli</p><div>{views}</div><small>{a["id"]}</small></article>')
    (OUT / 'index.html').write_text('''<!doctype html><html lang="it"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>FOCUS! · Edifici civici</title>
<style>body{margin:40px auto;max-width:1280px;padding:0 24px;background:#edeae3;color:#333a36;font:16px system-ui}h1{font-size:38px}main{display:grid;grid-template-columns:1fr 1fr;gap:24px}article{padding:20px;background:#faf8f3;border-radius:12px}article div{display:flex}img{width:100%;border-radius:6px}a{width:50%}small{color:#5c675f}h2{margin:0}p{color:#606960}@media(max-width:700px){main{grid-template-columns:1fr}}</style>
<h1>Architetture civiche</h1><p>Ospedali, soccorso, sicurezza e istruzione. Viste frontali e posteriori dei modelli 3D esportati nel gioco.</p><main>''' + ''.join(cards) + '</main></html>', encoding='utf-8')
    # Contact sheet from Blender's decoded images, without external dependencies.
    tile = 600
    sheet = np.ones((tile*((len(assets)+4)//5), tile*5, 4), dtype=np.float32)
    for i, a in enumerate(assets):
        path = OUT / 'renders' / f'{a["id"]}__civic_v3__front.png'
        im = bpy.data.images.load(str(path), check_existing=False)
        pixels = np.empty(tile*tile*4, dtype=np.float32)
        im.pixels.foreach_get(pixels)
        row = ((len(assets)+4)//5)-1-i//5
        sheet[row*tile:(row+1)*tile, (i%5)*tile:(i%5+1)*tile] = pixels.reshape(tile,tile,4)
        bpy.data.images.remove(im)
    im = bpy.data.images.new('CivicReview', width=sheet.shape[1], height=sheet.shape[0], alpha=True)
    im.pixels.foreach_set(sheet.ravel())
    im.filepath_raw = str(OUT / 'contact_sheet.png')
    im.file_format = 'PNG'
    im.save()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--asset', action='append')
    p.add_argument('--skip-existing', action='store_true')
    args = p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    (OUT / 'renders').mkdir(parents=True, exist_ok=True)
    (OUT / '.gdignore').touch()
    renderer.OUT = OUT
    catalog = json.loads((MODELS / 'catalog.json').read_text(encoding='utf-8'))['assets']
    assert len({a['id'] for a in catalog}) == len(catalog)
    assets = [a for a in catalog if a.get('architecture_revision') == 'civic_v3']
    rows = []
    for a in assets:
        if args.asset and a['id'] not in args.asset:
            continue
        rows.append(validate(a))
        for view in ('front', 'rear'):
            path = OUT / 'renders' / f'{a["id"]}__civic_v3__{view}.png'
            if not (args.skip_existing and path.exists()):
                renderer.render(a, 'civic_v3', view, 600, 16, 'CYCLES', folder='refined_v2')
            # Keep the normal full-catalog review entry points current, too.
            collection = a.get('collection', 'refined_v2')
            canonical = ROOT / 'assets/previews' / collection / 'renders'
            canonical.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, canonical / f'{a["id"]}__{collection}__{view}.png')
    if not args.asset:
        gallery(assets)
        (OUT / 'validation.json').write_text(json.dumps(dict(asset_count=len(rows), render_count=len(rows)*2, assets=rows), indent=2)+'\n', encoding='utf-8')
    print('[CIVIC] Validated', len(rows), flush=True)


if __name__ == '__main__':
    main()
