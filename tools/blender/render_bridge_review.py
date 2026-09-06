"""Inspection assembly of actual GLBs: two ramps, straight, corner, T and cross."""
import json
import math
import sys
from pathlib import Path
import bpy
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import render_refined_assets as renderer
ROOT=HERE.parents[1]
OUT=ROOT/'assets/previews/refined_v2/bridge_v3'

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    placements=[
        ('BRG_LOCAL_RAMP_1x1_UP_050',(0,-4,0),0),
        ('BRG_LOCAL_DECK_1x1_STRAIGHT',(0,-2,.5),0),
        ('BRG_LOCAL_DECK_1x1_CORNER',(0,0,.5),0),
        ('BRG_LOCAL_DECK_1x1_T',(2,0,.5),0),
        ('BRG_LOCAL_DECK_1x1_END',(2,-2,.5),math.pi),
        ('BRG_LOCAL_DECK_1x1_CROSS',(4,0,.5),0),
        ('BRG_LOCAL_DECK_1x1_END',(4,-2,.5),math.pi),
        ('BRG_LOCAL_DECK_1x1_END',(6,0,.5),-math.pi/2),
        ('BRG_LOCAL_RAMP_1x1_DOWN_050',(4,2,0),0),
    ]
    for aid,location,angle in placements:
        before=set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/refined_v2'/(aid+'.glb')))
        imported=set(bpy.context.scene.objects)-before
        roots=[o for o in imported if o.parent not in imported]
        holder=bpy.data.objects.new('Placed_'+aid,None);bpy.context.collection.objects.link(holder)
        for root in roots:root.parent=holder
        holder.rotation_euler.z=angle
        holder.location=(location[0]-3,location[1]+1,location[2])
        for obj in imported:
            if 'colonly' in obj.name:bpy.data.objects.remove(obj,do_unlink=True)
    path=OUT/'assembly.glb'
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_apply=True,export_extras=True)
    (OUT/'assembly.json').write_text(json.dumps(dict(description='Inspection scene only: nine connected bridge modules',placements=placements),indent=2)+'\n')
    renderer.OUT=OUT;(OUT/'renders').mkdir(exist_ok=True)
    a=dict(id='BRIDGE_ASSEMBLY',model='../../previews/refined_v2/bridge_v3/assembly.glb',footprint=[5,4],height_meters=1.275,min_z=-.2)
    for view in ('front','rear'):renderer.render(a,'refined_v2',view,1100,24,'CYCLES')

if __name__=='__main__':main()
