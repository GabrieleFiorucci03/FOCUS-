"""Render actual reimported GLBs with identical camera/light for both versions."""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/previews/refined_v2'

def render(asset,version,view,size,samples,engine,folder=None):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    # 'version' nomina il render; 'folder' dice da quale cartella leggerlo, che
    # da quando la libreria e' unica non e' piu' la stessa cosa.
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models'/(folder or version)/asset['model']))
    corners=[]
    for obj in bpy.context.scene.objects:
        if obj.type!='MESH':continue
        if 'colonly' in obj.name:
            obj.hide_render=True
        else:corners.extend(obj.matrix_world@Vector(v) for v in obj.bound_box)
    lo=Vector(tuple(min(p[i] for p in corners) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in corners) for i in range(3)))
    # Pair framing derives from the common metadata and footprint, not each render.
    height=max(asset['height_meters'],asset.get('source_height',0))
    span=max(asset['footprint'])*2
    target=Vector((0,0,asset.get('min_z',0)+height*.44))
    bpy.ops.object.camera_add()
    cam=bpy.context.object
    direction=Vector((1.3,-1.65,1.05)) if view=='front' else Vector((-1.3,1.65,1.05))
    cam.location=target+direction*max(height,span)*2
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO'
    cam.data.ortho_scale=max(span*1.56,height*1.24+span*.36)
    scene=bpy.context.scene;scene.camera=cam
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,min(asset.get('min_z',0),lo.z)-.018))
    ground=bpy.context.object
    mat=bpy.data.materials.new('StudioWarmGrey');mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.32,.33,.32,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
    ground.data.materials.append(mat)
    world=bpy.data.worlds.new('Studio')
    world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.72,.78,.85,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.65
    scene.world=world
    for loc,energy,light_size in (((-5,-8,12),1700,7),((7,3,9),1300,6)):
        bpy.ops.object.light_add(type='AREA',location=loc)
        light=bpy.context.object;light.data.energy=energy;light.data.shape='DISK';light.data.size=light_size
        light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.light_add(type='SUN',location=(0,0,12))
    sun=bpy.context.object;sun.rotation_euler=(.35,-.45,-.40);sun.data.energy=1.3;sun.data.angle=.20
    scene.render.engine=engine
    scene.cycles.samples=samples
    scene.cycles.use_denoising=True
    if engine=='BLENDER_EEVEE':
        scene.eevee.taa_render_samples=samples
    scene.render.threads_mode='FIXED';scene.render.threads=6
    scene.render.resolution_x=size;scene.render.resolution_y=size
    scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX'
    scene.view_settings.look='AgX - Medium High Contrast'
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGB'
    path=OUT/'renders'/f'{asset["id"]}__{version}__{view}.png'
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    print('[RENDER]',path.name,flush=True)

def main():
    p=argparse.ArgumentParser();p.add_argument('--asset',action='append');p.add_argument('--size',type=int,default=640)
    p.add_argument('--samples',type=int,default=24);p.add_argument('--views',default='front,rear');p.add_argument('--versions',default='realistic,refined_v2')
    p.add_argument('--skip-existing',action='store_true')
    p.add_argument('--engine',default='CYCLES',choices=['CYCLES','BLENDER_EEVEE'])
    p.add_argument('--shard',type=int,default=0);p.add_argument('--shards',type=int,default=1)
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    (OUT/'renders').mkdir(parents=True,exist_ok=True)
    # La libreria e' una cartella sola: il kit di base e l'espansione stanno
    # insieme e si distinguono per il campo 'collection' delle sue voci.
    catalog=[a for a in json.loads((ROOT/'assets/models/refined_v2/catalog.json').read_text())['assets']
             if a.get('collection')!='refined_expansion']
    source={a['id']:a for a in json.loads((ROOT/'assets/models/realistic/catalog.json').read_text())['assets']}
    for asset_index,a in enumerate(catalog):
        if asset_index%args.shards!=args.shard:continue
        if args.asset and a['id'] not in args.asset:continue
        a['source_height']=source[a['id']]['height_meters']
        for v in args.versions.split(','):
            for view in args.views.split(','):
                path=OUT/'renders'/f'{a["id"]}__{v}__{view}.png'
                if args.skip_existing and path.exists():continue
                render(a,v,view,args.size,args.samples,args.engine)

if __name__=='__main__':main()
