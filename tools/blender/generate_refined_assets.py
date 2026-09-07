"""Parallel architectural revision. Never writes the two existing libraries.

blender -b --python tools/blender/generate_refined_assets.py -- [--asset ID]
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import random
import sys
from collections import defaultdict
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix

# Shared detail/material state when the civic kit imports this entry point.
sys.modules.setdefault('generate_refined_assets', sys.modules[__name__])

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import generate_realistic_assets as old
import generate_mvp_assets as base
from focus_asset_specs import ASSETS, ASSET_BY_ID

OUT = ROOT / 'assets/models/refined_v2'
SOURCE = ROOT / 'assets/models/realistic'
STYLE = 'refined_v2'
PALETTE = {
    'cream':'c9bea9', 'paper':'dedbd1', 'sage':'989e8d', 'peach':'b79c88',
    'blue':'89989d', 'ochre':'ab9571', 'terracotta':'865947',
    'terracotta_light':'a1725b', 'teal':'546d68', 'coral':'91594d',
    'pink':'c5a6a3', 'navy':'485158', 'glass':'70848a', 'glass_dark':'35464c',
    'window_warm':'99917b', 'concrete':'8f9089', 'concrete_light':'bbb9ae',
    'asphalt':'454847', 'road_line':'d4d0bd', 'sidewalk':'aaa79c',
    'grass':'737f54', 'grass_light':'8c9368', 'leaf_dark':'3d5035',
    'leaf':'586b43', 'leaf_light':'788358', 'wood':'766047', 'water':'547e85',
    'white':'d9d8ce', 'black':'343735', 'frame':'d0cbbd', 'metal':'747b79',
    'roof_membrane':'656863', 'stone':'a8a18f', 'soil':'70624f', 'greenhouse_glass':'becdca',
}
TEXTURED = set(PALETTE) - {'glass','glass_dark','window_warm','water','black','frame','metal','white','road_line','greenhouse_glass'}
BODIES = {
    'House','SideWing','Apartment','ApartmentA','ApartmentB','ApartmentWing','Setback',
    'Slab','StairCore','LowWing','VillaMain','VillaWing','Tower','TowerTwin','UpperSetback',
    'Podium','Shop','OfficeGlass','OfficeWingA','OfficeWingB','OfficeSetback','Atrium',
    'Factory','OfficeAnnex','ServiceMain','SchoolMain','SchoolWingA','SchoolWingB','Gym',
    'Barn','Greenhouse',
}
GLAZED = {'Tower','TowerTwin','UpperSetback','OfficeGlass','OfficeWingA','OfficeWingB','OfficeSetback','Atrium','Greenhouse'}
FLOOR_HEIGHT = {'house':.72,'apartment':.58,'slab':.53,'villa':.72,'tower':.48,'office':.60,'service':.66,'school':.66}
DETAILS = defaultdict(list)
AUDIT = {}

def stem(obj):
    return obj.name.split('.')[0]

def linear(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4

def material(key, **kwargs):
    name = 'FOCUS_V2_' + key
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    rgb = np.array([int(PALETTE[key][i:i+2],16)/255 for i in (0,2,4)])
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*[linear(c) for c in rgb],1)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = mat.diffuse_color
    node.inputs['Roughness'].default_value = .86 if key in TEXTURED else .43
    if key in {'glass','glass_dark','water'}:
        node.inputs['Roughness'].default_value = .24
        node.inputs['Coat Weight'].default_value = .24
    if key in {'metal','black'}:
        node.inputs['Metallic'].default_value = .65
    if key=='greenhouse_glass':
        node.inputs['Alpha'].default_value=.23
        node.inputs['Roughness'].default_value=.22
        mat.surface_render_method='DITHERED'
    if key in TEXTURED:
        # Packed, portable color and roughness maps; no Blender-only noise nodes.
        rng = np.random.default_rng(int(hashlib.sha256(key.encode()).hexdigest()[:8],16))
        n = 128
        yy, xx = np.mgrid[:n,:n]
        noise = rng.normal(0,.018,(n,n))
        noise += .012*np.sin(xx*.18)*np.sin(yy*.23)
        if key == 'wood':
            noise += .034*np.sin(xx*.75 + np.sin(yy*.10)*.8)
        if key in {'asphalt','soil','grass','grass_light'}:
            noise *= 1.8
        arr = np.ones((n,n,4),dtype=np.float32)
        arr[:,:,:3] = np.clip(rgb[None,None,:]+noise[:,:,None],0,1)
        img = bpy.data.images.new(name+'_albedo',n,n,alpha=True)
        img.pixels.foreach_set(arr.ravel())
        img.pack()
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = img
        mat.node_tree.links.new(tex.outputs['Color'],node.inputs['Base Color'])
        rough = np.ones((n,n,4),dtype=np.float32)
        rough[:,:,:3] = np.clip(.84+noise[:,:,None]*2,.64,.98)
        img2 = bpy.data.images.new(name+'_roughness',n,n,alpha=True)
        img2.colorspace_settings.name = 'Non-Color'
        img2.pixels.foreach_set(rough.ravel())
        img2.pack()
        tex2 = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex2.image = img2
        mat.node_tree.links.new(tex2.outputs['Color'],node.inputs['Roughness'])
    return mat

def setmat(obj,key):
    obj.data.materials.clear()
    obj.data.materials.append(material(key))

def add(size,loc,key='frame',rotation=None):
    DETAILS[key].append((size,loc,rotation))

def flush():
    # Batch details by material: small geometry never becomes thousands of nodes.
    for key, entries in DETAILS.items():
        vs, fs = [], []
        for size, loc, rot in entries:
            i = len(vs)
            matrix = rot if rot is not None else Matrix.Identity(3)
            for a,b,c in ((-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)):
                vs.append(Vector(loc)+matrix@Vector((a*size[0]/2,b*size[1]/2,c*size[2]/2)))
            fs.extend(tuple(i+j for j in f) for f in ((3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)))
        mesh = bpy.data.meshes.new('Detail_'+key)
        mesh.from_pydata(vs,[],fs)
        mesh.update()
        obj = bpy.data.objects.new('Detail_'+key,mesh)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(material(key))
    DETAILS.clear()

def beam(start,end,thickness=.015,key='metal'):
    a,b = Vector(start),Vector(end)
    delta = b-a
    add((thickness,thickness,delta.length),(a+b)/2,key,delta.to_track_quat('Z','Y').to_matrix())

def bounds(obj):
    return old._object_bounds(obj)

def facade_box(axis,sign,plane,u,z,w,h,d,key,offset=0):
    loc = (u,plane+sign*offset,z) if axis==1 else (plane+sign*offset,u,z)
    size = (w,d,h) if axis==1 else (d,w,h)
    add(size,loc,key)

def facades(spec,bodies):
    spans = [(o,*bounds(o)) for o in bodies]
    blockers = [(o,*bounds(o)) for o in bpy.context.scene.objects if o.type=='MESH' and stem(o) in {'Door','GarageDoor','LoadingDoor','LoadingBay','Dock','BarnDoor','Storefront','ModernGlass','HealthCross','Entrance','SchoolEntrance','MarketLoading'}]
    counts = dict(front=0,rear=0,left=0,right=0)
    for obj,lo,hi in spans:
        name=stem(obj)
        glazed = name in GLAZED
        floor_h=FLOOR_HEIGHT.get(spec['kind'],.72)
        levels=max(1,round((hi.z-lo.z)/floor_h))
        if name in {'Factory','Barn','Gym'}: levels=1
        if name=='Greenhouse': levels=1
        pitch=(hi.z-lo.z)/levels
        for axis,sign,label in ((1,-1,'front'),(1,1,'rear'),(0,-1,'left'),(0,1,'right')):
            other=1-axis
            plane=lo[axis] if sign<0 else hi[axis]
            length=hi[other]-lo[other]
            columns=max(1,int((length-.14)/(.48 if glazed else .61)))
            cell=(length-.16)/columns
            ww=cell*.80 if glazed else min(.26 if spec['kind'] in {'house','villa'} else .34,cell*.55)
            hh=pitch*.70 if glazed else min(.36,pitch*.49)
            if name in {'Factory','Barn','Gym'}: hh=.27
            # Stone skirting, restrained lintel; all four sides get real construction.
            facade_box(axis,sign,plane,(lo[other]+hi[other])/2,lo.z+.065,length,.13,.026,'stone',.014)
            for floor in range(levels):
                z=lo.z+pitch*(floor+.56)
                if name in {'Factory','Barn','Gym'}: z=hi.z-.27
                for col in range(columns):
                    u=lo[other]+.08+cell*(col+.5)
                    p=Vector((u,plane+sign*.055,z) if axis==1 else (plane+sign*.055,u,z))
                    # Do not put windows inside intersecting wings or on entrances.
                    def blocked(item,margin):
                        ob,l,h=item
                        return ob!=obj and all(l[k]-margin[k] < p[k] < h[k]+margin[k] for k in range(3))
                    margins=[ww/2,ww/2,hh/2]
                    margins[axis]=.02
                    if any(blocked(s,margins) for s in spans): continue
                    if any(blocked(s,[.008+ww/2,.008+ww/2,hh/2]) for s in blockers): continue
                    key='glass' if (col+floor*3+spec['seed'])%7 in (0,1) else 'glass_dark'
                    if (col*3+floor+spec['seed'])%19==0 and not glazed:key='window_warm'
                    if name=='Greenhouse':key='greenhouse_glass'
                    else:facade_box(axis,sign,plane,u,z,ww+.045,hh+.045,.022,'black',.014)
                    facade_box(axis,sign,plane,u,z,ww,hh,.016,key,.031)
                    for du in (-ww/2,ww/2):
                        facade_box(axis,sign,plane,u+du,z,.018,hh+.025,.032,'metal' if glazed else 'frame',.042)
                    for dz in (-hh/2,hh/2):
                        facade_box(axis,sign,plane,u,z+dz,ww+.025,.018,.032,'metal' if glazed else 'frame',.042)
                    facade_box(axis,sign,plane,u,z,.012,hh,.024,'metal' if glazed else 'frame',.052)
                    if not glazed:
                        facade_box(axis,sign,plane,u,z-hh/2-.025,ww+.085,.027,.085,'concrete_light',.038)
                        if spec['kind'] in {'house','villa'} and cell>.52:
                            for du in (-ww/2-.068,ww/2+.068):
                                facade_box(axis,sign,plane,u+du,z,.09,hh+.045,.024,'sage',.035)
                                for dz in (-.10,-.05,0,.05,.10):
                                    if abs(dz)<hh/2:facade_box(axis,sign,plane,u+du,z+dz,.074,.010,.025,'teal',.05)
                    counts[label]+=1
            if glazed:
                for f in range(levels+1):
                    facade_box(axis,sign,plane,(lo[other]+hi[other])/2,lo.z+f*pitch,length+.025,.035,.042,'metal',.018)
    for obj,lo,hi in blockers:
        if stem(obj) in {'Storefront','ModernGlass','Entrance','SchoolEntrance'}:
            counts['front' if obj.location.y<0 else 'rear']+=1
    AUDIT['windows_by_side']=counts

def roof_detail(obj,spec):
    lo,hi=bounds(obj)
    if spec.get('variant')=='greenhouse':
        center=(lo.x+hi.x)/2
        count=max(2,round((hi.y-lo.y)/.38))
        for i in range(count+1):
            y=lo.y+(hi.y-lo.y)*i/count
            beam((lo.x,y,lo.z),(center,y,hi.z),.017,'metal')
            beam((center,y,hi.z),(hi.x,y,lo.z),.017,'metal')
        for x,z in ((lo.x,lo.z),(center,hi.z),(hi.x,lo.z)):
            beam((x,lo.y,z),(x,hi.y,z),.023,'metal')
        return
    # Tiles follow the actual inclined polygons, including hip and shed roofs.
    for poly in obj.data.polygons:
        normal=(obj.matrix_world.to_3x3()@poly.normal).normalized()
        if normal.z<.30 or normal.z>.999:continue
        pts=[obj.matrix_world@obj.data.vertices[i].co for i in poly.vertices]
        if len(pts)<3:continue
        origin=pts[0]
        tangent=(pts[1]-origin).normalized()
        bitangent=normal.cross(tangent).normalized()
        coords=[((p-origin).dot(tangent),(p-origin).dot(bitangent)) for p in pts]
        minx,maxx=min(p[0] for p in coords),max(p[0] for p in coords)
        miny,maxy=min(p[1] for p in coords),max(p[1] for p in coords)
        rotation=Matrix((tangent,bitangent,normal)).transposed()
        def inside(x,y):
            signs=[]
            for i,a in enumerate(coords):
                b=coords[(i+1)%len(coords)]
                signs.append((b[0]-a[0])*(y-a[1])-(b[1]-a[1])*(x-a[0]))
            return all(s>=-.0001 for s in signs) or all(s<=.0001 for s in signs)
        tilew,tileh=(.14,.24) if spec['kind']!='factory' else (.24,.44)
        for row in range(math.ceil((maxy-miny)/tileh)):
            for col in range(math.ceil((maxx-minx)/tilew)):
                x=minx+(col+.5)*tilew+(row%2)*tilew*.5
                y=miny+(row+.5)*tileh
                if not all(inside(x+dx,y+dy) for dx in (-tilew*.47,tilew*.47) for dy in (-tileh*.47,tileh*.47)):continue
                key='terracotta_light' if (row*7+col*11+spec['seed'])%11<2 else 'terracotta'
                if spec['kind']=='factory':key='metal'
                if spec.get('variant')=='greenhouse':key='glass'
                add((tilew*.95,tileh*.96,.013),origin+tangent*x+bitangent*y+normal*.01,key,rotation)
        # Continuous edge flashings give the roof clean, precise outlines.
        for i,p in enumerate(pts):
            q=pts[(i+1)%len(pts)]
            beam(p+normal*.012,q+normal*.012,.018,'metal' if spec['kind']=='factory' else 'terracotta_light')
    if hi.z-lo.z<.20:
        setmat(obj,'roof_membrane')
        w,d=hi.x-lo.x,hi.y-lo.y
        for x in (lo.x+.025,hi.x-.025):add((.045,d,.075),(x,(lo.y+hi.y)/2,hi.z+.024),'concrete_light')
        for y in (lo.y+.025,hi.y-.025):add((w,.045,.075),((lo.x+hi.x)/2,y,hi.z+.024),'concrete_light')
        for i in range(1,max(1,int(d/.38))):
            y=lo.y+i*.38
            add((w-.10,.009,.005),((lo.x+hi.x)/2,y,hi.z+.003),'black')

def buildings(spec,rng):
    old._remove_ambiguous_roof_units()
    old._replace_shed_roof(spec)
    old._fix_agriculture_geometry(spec)
    if spec['kind']=='slab' and spec.get('shape')=='offset':
        for obj in bpy.context.scene.objects:
            if stem(obj) in {'Slab','StairCore'}:obj.location.x+=.075
    remove={'Window','SideWindow','FactoryWindow','FloorBand','Mullion','Column','Railing'}
    for obj in list(bpy.context.scene.objects):
        if stem(obj) in remove:bpy.data.objects.remove(obj,do_unlink=True)
    bpy.context.view_layer.update()
    bodies=[o for o in bpy.context.scene.objects if o.type=='MESH' and stem(o) in BODIES]
    if spec.get('variant')=='greenhouse':
        for obj in list(bpy.context.scene.objects):
            if stem(obj) in {'Greenhouse','GreenhouseRoof'}:setmat(obj,'greenhouse_glass')
            if stem(obj)=='GrowBed':
                lo,hi=bounds(obj)
                for x in (obj.location.x-.25,obj.location.x+.25):
                    for i in range(6):
                        y=lo.y+.14+(hi.y-lo.y-.28)*i/5
                        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.11,location=(x,y,hi.z+.09))
                        crop=bpy.context.object;crop.name='Crop';setmat(crop,'leaf')
    # Relocate inherited entrance panels onto the nearest real wall (twin blocks,
    # offset slabs and villa wings previously left a door hanging in the gap).
    for door in [o for o in bpy.context.scene.objects if stem(o)=='Door']:
        candidates=[]
        for body in bodies:
            lo,hi=bounds(body)
            if lo.z>.15:continue
            x=max(lo.x+door.dimensions.x*.5+.05,min(hi.x-door.dimensions.x*.5-.05,door.location.x))
            distance=abs(x-door.location.x)+abs(lo.y-door.location.y)
            candidates.append((distance,x,lo.y))
        if candidates:
            _,x,y=min(candidates)
            door.location.x=x;door.location.y=y-.035
    if spec['kind']=='school':
        entry=next(o for o in bpy.context.scene.objects if stem(o)=='SchoolEntrance')
        main=next(o for o in bodies if stem(o)=='SchoolMain')
        elo,ehi=bounds(entry);mlo,mhi=bounds(main)
        gap=mlo.y-ehi.y
        if gap>0:
            old.box('EntranceLink',(entry.dimensions.x,gap+.02,.65),(entry.location.x,(ehi.y+mlo.y)/2,.325),'glass',.008)
    if spec['kind']=='office' and spec.get('shape')=='atrium':
        entry=next(o for o in bpy.context.scene.objects if stem(o)=='Entrance')
        atrium=next(o for o in bodies if stem(o)=='Atrium')
        elo,ehi=bounds(entry);alo,ahi=bounds(atrium)
        gap=alo.y-ehi.y
        if gap>0:
            old.box('EntranceLink',(entry.dimensions.x,gap+.02,.70),(entry.location.x,(ehi.y+alo.y)/2,.35),'glass',.008)
    bpy.context.view_layer.update()
    # Roofs belong to each separate wing, not an aggregate bounding box.
    if spec['kind'] in {'apartment','slab','office','school'}:
        for obj in list(bpy.context.scene.objects):
            if stem(obj) in {'FlatRoof','Roof','SchoolRoof','RoofGarden'}:bpy.data.objects.remove(obj,do_unlink=True)
        for obj in bodies:
            lo,hi=bounds(obj)
            old.box('V2Roof',(hi.x-lo.x+.06,hi.y-lo.y+.06,.07),((hi.x+lo.x)/2,(hi.y+lo.y)/2,hi.z+.035),'roof_membrane',.01)
    facades(spec,bodies)
    if spec['kind']=='house' and spec.get('feature')=='garage':
        garage=next(o for o in bpy.context.scene.objects if stem(o)=='GarageDoor')
        lo,hi=bounds(garage)
        for x in (garage.location.x-.17,garage.location.x+.17):
            facade_box(1,-1,lo.y,x,hi.z-.13,.24,.13,.018,'frame',.015)
            facade_box(1,-1,lo.y,x,hi.z-.13,.20,.09,.019,'glass_dark',.027)
        AUDIT['windows_by_side']['front']+=2
    for obj in list(bpy.context.scene.objects):
        name=stem(obj)
        if name in {'Roof','FlatRoof','WingRoof','FactoryRoof','BarnRoof','GreenhouseRoof','SchoolRoof','ServiceRoof','V2Roof','SideWingRoof'}:
            roof_detail(obj,spec)
        if name=='Balcony':
            lo,hi=bounds(obj)
            for x in (lo.x+.018,hi.x-.018):beam((x,lo.y,hi.z),(x,lo.y,hi.z+.23),.014)
            beam((lo.x,lo.y,hi.z+.23),(hi.x,lo.y,hi.z+.23),.018)
            for i in range(1,8):
                x=lo.x+(hi.x-lo.x)*i/8
                beam((x,lo.y,hi.z+.02),(x,lo.y,hi.z+.23),.010)
            for x in (lo.x,hi.x):beam((x,lo.y,hi.z+.23),(x,hi.y,hi.z+.23),.014)
        if name in {'Door','GarageDoor','LoadingDoor','LoadingBay','BarnDoor','MarketLoading','Dock'}:
            lo,hi=bounds(obj)
            y=lo.y-.012 if obj.location.y<0 else hi.y+.012
            for x in (lo.x,hi.x):add((.024,.04,hi.z-lo.z),(x,y,(lo.z+hi.z)/2),'frame')
            add((hi.x-lo.x+.04,.04,.028),((lo.x+hi.x)/2,y,hi.z),'frame')
            if name=='Door':
                add((.012,.022,.08),(hi.x-.05,y-.025,(lo.z+hi.z)/2),'metal')
            else:
                for i in range(1,7):add((hi.x-lo.x-.04,.015,.012),((lo.x+hi.x)/2,y,lo.z+(hi.z-lo.z)*i/7),'metal')
        if name=='Chimney':
            lo,hi=bounds(obj)
            add((hi.x-lo.x+.07,hi.y-lo.y+.07,.045),((hi.x+lo.x)/2,(hi.y+lo.y)/2,hi.z+.015),'stone')
            add((hi.x-lo.x-.035,hi.y-lo.y-.035,.006),((hi.x+lo.x)/2,(hi.y+lo.y)/2,hi.z+.04),'black')
        if name in {'Storefront','ModernGlass','Entrance','SchoolEntrance'}:
            lo,hi=bounds(obj)
            for i in range(5):add((.018,.04,hi.z-lo.z), (lo.x+(hi.x-lo.x)*i/4,lo.y-.012,(lo.z+hi.z)/2),'metal')
    # Drainage follows actual body walls; fixtures are wall-mounted.
    for obj in bodies:
        if stem(obj) in GLAZED or stem(obj)=='Podium':continue
        lo,hi=bounds(obj)
        for x in (lo.x+.045,hi.x-.045):
            beam((x,hi.y+.025,max(.08,lo.z)),(x,hi.y+.025,hi.z),.020,'metal')
        beam((lo.x,hi.y+.025,hi.z),(hi.x,hi.y+.025,hi.z),.026,'metal')
    # Keep lamp anchored at an actual entrance, avoiding detached decorations.
    for door in [o for o in bpy.context.scene.objects if stem(o)=='Door']:
        lo,hi=bounds(door)
        add((.065,.035,.10),(hi.x+.075,lo.y-.025,hi.z-.07),'black')
        add((.042,.012,.065),(hi.x+.075,lo.y-.049,hi.z-.07),'window_warm')

def foliage(rng,x=0.,y=0.,scale=1.,pine=False):
    old.cylinder('Trunk',.075*scale,.82*scale,(x,y,.41*scale),'wood',8)
    for j in range(6 if pine else 9):
        angle=j*2.399+rng.uniform(-.2,.2)
        level=(.68+j*.10)*scale if pine else (.84+rng.random()*.57)*scale
        spread=(.43-j*.045)*scale if pine else rng.uniform(.18,.43)*scale
        end=(x+math.cos(angle)*spread,y+math.sin(angle)*spread,level)
        beam((x,y,level*.65),end,.025*scale,'wood')
        for k in range(3):
            p=(end[0]+rng.uniform(-.11,.11)*scale,end[1]+rng.uniform(-.11,.11)*scale,end[2]+rng.uniform(-.07,.12)*scale)
            old.ico('LeafCluster',(.20 if pine else .25)*scale,p,(1,.82,.58 if pine else .92),('leaf_dark','leaf','leaf_light')[(j+k)%3],1)

def continuous_road(spec,bridge=False):
    directions=base.ROAD_CONNECTIONS[spec['variant']]
    occupied={(1,1)}
    for side,cell in {'north':(1,0),'south':(1,2),'west':(0,1),'east':(2,1)}.items():
        if side in directions:occupied.add(cell)
    def surface(half,bottom,top,name,key):
        coords=(-1.,-half,half,1.)
        verts=[];faces=[];indices={}
        def vertex(p):
            if p not in indices:indices[p]=len(verts);verts.append(p)
            return indices[p]
        def face(points):faces.append(tuple(vertex(p) for p in points))
        for i,j in sorted(occupied):
            x0,x1=coords[i:i+2];y0,y1=coords[j:j+2]
            face([(x0,y0,top),(x1,y0,top),(x1,y1,top),(x0,y1,top)])
            face([(x0,y1,bottom),(x1,y1,bottom),(x1,y0,bottom),(x0,y0,bottom)])
            for neighbor,a,b in (((i,j-1),(x0,y0),(x1,y0)),((i+1,j),(x1,y0),(x1,y1)),((i,j+1),(x1,y1),(x0,y1)),((i-1,j),(x0,y1),(x0,y0))):
                if neighbor not in occupied:face([(*a,bottom),(*b,bottom),(*b,top),(*a,top)])
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
        obj.data.materials.append(material(key))
    if bridge:
        surface(.73,-.20,0,'ContinuousDeck','concrete_light')
        surface(.46,0,.0355,'ContinuousCarriageway','asphalt')
    else:
        surface(.43,.07,.1045,'ContinuousRoad','ochre' if spec.get('style')=='dirt' else 'asphalt')
    obsolete={'BridgeRoadCenter','BridgeRoad','BridgeCenter','BridgeBranch'} if bridge else {'RoadCenter','RoadBranch'}
    for obj in list(bpy.context.scene.objects):
        if stem(obj) in obsolete:bpy.data.objects.remove(obj,do_unlink=True)
    return directions


def repaired_bridge_barriers(spec):
    """Continuous mitered curb/rails around exposed edges, including ramps."""
    import refined_bridge_geometry as bg
    for obj in list(bpy.context.scene.objects):
        if stem(obj) in {'BridgeRail','BridgePost'}:
            bpy.data.objects.remove(obj,do_unlink=True)
    ramp=spec.get('variant')=='ramp'
    connections=['north','south'] if ramp else base.ROAD_CONNECTIONS[spec['variant']]
    paths=bg.boundary_paths(connections)
    rise=float(spec.get('rise',0)) if ramp else 0.
    direction=spec.get('direction','up')
    if ramp:
        # Exact tile endpoints and common road/deck widths give flush joints.
        for obj in list(bpy.context.scene.objects):
            if stem(obj) in {'BridgeRampSlab','BridgeRampRoad','BridgeRampLine'}:
                bpy.data.objects.remove(obj,do_unlink=True)
        z0,z1=bg.grade(-1,rise,direction),bg.grade(1,rise,direction)
        base.ramp_prism('BridgeRampSlab',1.46,2.,z0,z1,.20,'concrete_light')
        base.ramp_prism('BridgeRampRoad',.92,2.,z0+.0355,z1+.0355,.0355,'asphalt')
        for y in (-.58,0,.58):
            length=.29
            ob=base.ramp_prism('BridgeRampLine',.032,length,bg.grade(y-length/2,rise,direction)+.038,bg.grade(y+length/2,rise,direction)+.038,.0025,'road_line')
            ob.location.y=y

    profiles={
        'BridgeCurb':('concrete_light',[(-.0425,0),(.0425,0),(.0425,.077),(.03,.10),(-.03,.10),(-.0425,.077)]),
        'BridgeHandrail':('teal',[(-.021,.395),(.021,.395),(.026,.400),(.026,.430),(.021,.435),(-.021,.435),(-.026,.430),(-.026,.400)]),
        'BridgeLowerRail':('teal',[(-.011,.148),(.011,.148),(.011,.170),(-.011,.170)]),
    }
    for path_index,path in enumerate(paths):
        for name,(key,profile) in profiles.items():
            vs,fs=bg.sweep(path,profile,rise,direction)
            data=bpy.data.meshes.new(name);data.from_pydata(vs,[],fs);data.update()
            ob=bpy.data.objects.new(f'{name}_{path_index}',data);bpy.context.collection.objects.link(ob);setmat(ob,key)
        posts=bg.post_positions(path)
        # Posts butt against the rails rather than overlapping coincident faces.
        # Small planar end cuts also follow the grade on inclined modules.
        for x,y in posts:
            for low,high in ((.10,.148),(.170,.395)):
                vs,fs=bg.sweep([(x,y-.018),(x,y+.018)],[(-.018,low),(.018,low),(.018,high),(-.018,high)],rise,direction)
                data=bpy.data.meshes.new('BridgeUpright');data.from_pydata(vs,[],fs);data.update()
                ob=bpy.data.objects.new('BridgeUpright',data);bpy.context.collection.objects.link(ob);setmat(ob,'teal')
        for x,y in bg.picket_positions(path,posts):
            vs,fs=bg.sweep([(x,y-.006),(x,y+.006)],[(-.006,.170),(.006,.170),(.006,.395),(-.006,.395)],rise,direction)
            data=bpy.data.meshes.new('BridgeBaluster');data.from_pydata(vs,[],fs);data.update()
            ob=bpy.data.objects.new('BridgeBaluster',data);bpy.context.collection.objects.link(ob);setmat(ob,'metal')
    AUDIT.update(bridge_barrier_layout='continuous_miter_v3',bridge_barrier_road_clearance_m=.1625,
                 bridge_barrier_paths=paths,bridge_rail_height_m=.435,bridge_open_ports=list(connections))

def extras(spec,rng):
    kind=spec['kind']
    if kind=='tree':
        # Existing species silhouette retained; soften uniform spherical crowns.
        for obj in list(bpy.context.scene.objects):
            if any(s in stem(obj).lower() for s in ('crown','foliage','pine','flower')):
                for v in obj.data.vertices:v.co*=rng.uniform(.91,1.08)
        old._add_tree_details(spec,rng)
    elif kind=='park':
        old._add_landscape_details(spec,rng)
        for obj in list(bpy.context.scene.objects):
            if stem(obj)=='BenchSeat':
                lo,hi=bounds(obj)
                for x in (lo.x+.08,hi.x-.08):add((.035,.16,.23),(x,obj.location.y,.16),'black')
            if stem(obj) in {'BenchSeat','BenchBack'}:
                lo,hi=bounds(obj)
                for i in range(1,4):add((hi.x-lo.x,.006,.008),(obj.location.x,lo.y+i*(hi.y-lo.y)/4,hi.z+.003),'black')
            if stem(obj)=='PathNS':
                lo,hi=bounds(obj)
                for j in range(int((hi.y-lo.y)/.22)):
                    add((hi.x-lo.x,.009,.006),(obj.location.x,lo.y+j*.22,hi.z+.003),'stone')
    elif kind in {'road','sloped_road'}:
        old._add_road_details(spec,rng)
        if kind=='road':
            directions=continuous_road(spec)
            for obj in list(bpy.context.scene.objects):
                if stem(obj) in {'DrainGrate','DrainSlot'}:
                    obj.location.y=math.copysign(.66,obj.location.y)
                    obj.location.z=.076 if stem(obj)=='DrainGrate' else .085
                if stem(obj)=='RoadStone':
                    x,y=obj.location.x,obj.location.y
                    on_road=(abs(x)<=.43 and (abs(y)<=.43 or ('north' if y<0 else 'south') in directions)) or (abs(y)<=.43 and ('west' if x<0 else 'east') in directions)
                    lo,hi=bounds(obj);obj.location.z+=(.1045 if on_road else .07)-lo.z
        if kind=='road' and spec.get('style')!='dirt':
            connections=base.ROAD_CONNECTIONS[spec['variant']]
            for side in (-1,1):
                for j in range(8):
                    p=-.875+j*.25
                    # Kerb stones only on the perimeter of actual carriageways.
                    if abs(p)>.43 and (('north' if p<0 else 'south') in connections):
                        add((.05,.235,.05),(side*.47,p,.095),'concrete_light')
                    if abs(p)>.43 and (('west' if p<0 else 'east') in connections):
                        add((.235,.05,.05),(p,side*.47,.095),'concrete_light')
    elif kind in {'bridge','bridge_support'}:
        old._add_bridge_details(spec,rng)
        if kind=='bridge':
            import refined_bridge_geometry as bg
            for obj in bpy.context.scene.objects:
                if stem(obj)=='ExpansionJoint':
                    obj.dimensions.z=.004
                    obj.location.z=.0375+bg.grade(obj.location.y,float(spec.get('rise',0)),spec.get('direction','up'))
                    if spec.get('variant')=='ramp':
                        slope=float(spec['rise'])/2*(1 if spec['direction']=='up' else -1)
                        obj.rotation_euler.x=math.atan(slope)
        if kind=='bridge' and spec.get('variant')!='ramp':
            continuous_road(spec,bridge=True)
            for obj in bpy.context.scene.objects:
                if stem(obj)=='DeckBolt':
                    obj.dimensions.z=.022;obj.location.z=.011
        if kind=='bridge_support':
            for obj in list(bpy.context.scene.objects):
                if stem(obj)=='FormworkJoint':bpy.data.objects.remove(obj,do_unlink=True)
            for obj in list(bpy.context.scene.objects):
                if stem(obj) in {'PierCap','AbutmentWall'}:
                    lo,hi=bounds(obj)
                    add((hi.x-lo.x,.006,.010),((lo.x+hi.x)/2,lo.y-.004,(lo.z+hi.z)/2),'stone')
    elif kind=='utility':
        old._add_utility_details(spec,rng)
        for obj in list(bpy.context.scene.objects):
            if stem(obj)=='SolarPanel':
                for x in np.linspace(-.48,.48,7):
                    p=obj.matrix_world@Vector((float(x),0,.045))
                    add((.008,.68,.009),p,'metal',obj.rotation_euler.to_matrix())
                for y in np.linspace(-.33,.33,4):
                    p=obj.matrix_world@Vector((0,float(y),.045))
                    add((.98,.008,.009),p,'metal',obj.rotation_euler.to_matrix())
        if spec['variant']=='water':
            for x in (-.16,.16):beam((x,-.99,.12),(x,-.99,3.20),.020)
            for j in range(20):beam((-.16,-.99,.15+j*.15),(.16,-.99,.15+j*.15),.016)
            for x in (-.58,.58):
                beam((x,-.58,.18),(x,.58,2.12),.025)
                beam((x,.58,.18),(x,-.58,2.12),.025)
        elif spec['variant']=='wind':
            old.box('Nacelle',(.36,.65,.30),(0,.20,3.65),'white',.05)
            old.box('AccessDoor',(.14,.026,.32),(0,-.134,.25),'metal',.006)
    elif kind=='sport':
        old._add_sport_details(spec,rng)
        w,d=[v*2-.12 for v in spec['footprint']]
        for x in (-w*.45,w*.45):add((.025,d*.88,.009),(x,0,.107),'white')
        radius=.40 if spec['variant']=='football' else .27
        for j in range(48):
            a,b=j*math.tau/48,(j+1)*math.tau/48
            beam((radius*math.cos(a),radius*math.sin(a),.112),(radius*math.cos(b),radius*math.sin(b),.112),.018,'white')
        if spec['variant']=='football':
            # Actual net volumes and aligned goal crossbars.
            for obj in bpy.context.scene.objects:
                if stem(obj)=='GoalBar':obj.location.z=.93
            for sign in (-1,1):
                x=sign*w*.44
                back=x+sign*.18
                for y in np.linspace(-.50,.50,11):beam((back,float(y),.12),(back,float(y),.92),.006,'frame')
                for z in np.linspace(.12,.92,9):beam((back,-.50,float(z)),(back,.50,float(z)),.006,'frame')
                for y in (-.50,.50):
                    beam((x,y,.93),(back,y,.93),.022,'white')
                    beam((back,y,.12),(back,y,.93),.022,'white')
        else:
            for obj in bpy.context.scene.objects:
                if stem(obj)=='Rim':obj.rotation_euler=(0,0,0)

def project_uv_and_normals():
    for obj in bpy.context.scene.objects:
        if obj.type!='MESH' or 'colonly' in obj.name:continue
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(obj.data);bm.free()
        mesh=obj.data
        uv=mesh.uv_layers.active or mesh.uv_layers.new(name='UVMap')
        for p in mesh.polygons:
            n=obj.matrix_world.to_3x3()@p.normal
            axis=max(range(3),key=lambda i:abs(n[i]))
            a,b=((1,2),(0,2),(0,1))[axis]
            for li in p.loop_indices:
                v=obj.matrix_world@mesh.vertices[mesh.loops[li].vertex_index].co
                uv.data[li].uv=(v[a]*2,v[b]*2)

def preserve_collision(spec):
    for obj in list(bpy.context.scene.objects):
        if 'colonly' in obj.name:bpy.data.objects.remove(obj,do_unlink=True)
    before=set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE/(spec['id']+'.glb')))
    imported=set(bpy.context.scene.objects)-before
    collision=[o for o in imported if o.type=='MESH' and 'colonly' in o.name]
    if not collision:raise RuntimeError('Missing source collision: '+spec['id'])
    for obj in collision:
        matrix=obj.matrix_world.copy();obj.parent=None;obj.matrix_world=matrix
    for obj in imported:
        if obj not in collision:bpy.data.objects.remove(obj,do_unlink=True)

def generate(spec):
    if spec['kind'] in {'service', 'school'}:
        import generate_refined_expansion as expansion
        from refined_civic_geometry import base_spec
        meta = expansion.generate(base_spec(spec))
        for field in ('collection', 'is_new_asset'):
            meta.pop(field, None)
        meta.update(source_asset_id=spec['id'], generator_version=2200)
        (OUT/(spec['id']+'.json')).write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        return meta
    old._reset_scene(); DETAILS.clear(); AUDIT.clear()
    rng=random.Random(spec['seed'])
    base.GENERATORS[spec['kind']](spec,rng)
    if spec['kind']=='bridge':
        repaired_bridge_barriers(spec)
    if spec['kind'] in old.BUILDING_KINDS:buildings(spec,rng)
    extras(spec,rng)
    flush()
    bpy.context.view_layer.update()
    project_uv_and_normals()
    preserve_collision(spec)
    meta=base.finalize_and_export(spec,OUT)
    meta.update(style_variant=STYLE,source_asset_id=spec['id'],collision_source='realistic',**AUDIT)
    (OUT/(spec['id']+'.json')).write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
    return meta

def _catalogo_unito(path,nuovi):
    """Il catalogo della libreria, rimettendoci dentro i modelli appena rifatti.

    La libreria e' una sola e i generatori sono due, percio' nessuno dei due puo'
    riscrivere catalog.json partendo da zero: si porterebbe via i modelli
    dell'altro. Ognuno sostituisce le proprie voci dove stanno, lascia dove
    stanno quelle che non gli appartengono e accoda quelle mai viste, cosi'
    l'ordine del negozio non si rimescola a ogni rigenerazione e rigenerare un
    solo asset con --asset resta un'operazione innocua."""
    import json as _json
    esistenti=_json.loads(path.read_text(encoding='utf-8'))['assets'] if path.exists() else []
    da_mettere={a['id']:a for a in nuovi}
    unito=[da_mettere.pop(a['id'],a) for a in esistenti]
    return unito+[a for a in nuovi if a['id'] in da_mettere]


def main():
    p=argparse.ArgumentParser();p.add_argument('--asset',action='append',choices=sorted(ASSET_BY_ID))
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    OUT.mkdir(parents=True,exist_ok=True)
    old.install_realistic_primitives()
    old.realistic_material=material; base.material=material
    base.GENERATOR_VERSION=2001
    base.add_tree_geometry=foliage
    selected=[ASSET_BY_ID[i] for i in args.asset] if args.asset else ASSETS
    catalog=[]
    for i,spec in enumerate(selected):
        print(f'[REFINED] {i+1}/{len(selected)} {spec["id"]}',flush=True)
        catalog.append(generate(spec))
    path=OUT/'catalog.json'
    catalog=_catalogo_unito(path,catalog)
    path.write_text(json.dumps(dict(style_variant='refined_v2',grid_unit_meters=2.0,elevation_step_meters=0.5,assets=catalog),ensure_ascii=False,indent=2)+chr(10),encoding='utf-8')
    print('[REFINED] Complete',len(catalog),flush=True)

if __name__=='__main__':main()
