"""Check actual exported railing geometry, ports and ramp transitions."""
import json
from pathlib import Path
from collections import Counter
import numpy as np
from review_refined_assets import glb,accessor,transform
import refined_bridge_geometry as bg

ROOT=Path(__file__).resolve().parents[2]
MODELS=ROOT/'assets/models/refined_v2'
OUT=ROOT/'assets/previews/refined_v2/bridge_v3'


def clip(poly,axis,value,lower):
    result=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        ina=a[axis]>=value if lower else a[axis]<=value
        inb=b[axis]>=value if lower else b[axis]<=value
        if ina:result.append(a)
        if ina!=inb:
            t=(value-a[axis])/(b[axis]-a[axis]);result.append(a+(b-a)*t)
    return result


def intersection_area(triangle,rect):
    poly=list(triangle)
    for axis,val,lower in ((0,rect[0],True),(0,rect[2],False),(1,rect[1],True),(1,rect[3],False)):
        if not poly:return 0
        poly=clip(poly,axis,val,lower)
    return abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1])))/2


def rail_triangles(doc,buf):
    triangles=[]
    def visit(index,parent):
        node=doc['nodes'][index];m=parent@transform(node)
        if 'mesh' in node and 'colonly' not in node.get('name',''):
            for p in doc['meshes'][node['mesh']]['primitives']:
                name=doc['materials'][p['material']].get('name','')
                if name not in {'FOCUS_V2_teal','FOCUS_V2_metal'}:continue
                v=accessor(doc,buf,p['attributes']['POSITION'])
                v=(m@np.column_stack((v,np.ones(len(v)))).T).T[:,:3]
                v=np.column_stack((v[:,0],-v[:,2],v[:,1]))
                indices=accessor(doc,buf,p['indices']).ravel().reshape(-1,3)
                triangles.extend(v[indices])
        for i in node.get('children',[]):visit(i,m)
    for i in doc['scenes'][doc.get('scene',0)]['nodes']:visit(i,np.eye(4))
    return np.array(triangles)


def main():
    assets=[a for a in json.loads((MODELS/'catalog.json').read_text())['assets'] if a['kind']=='bridge']
    assert len(assets)==7
    rows=[]
    for a in assets:
        assert a['bridge_barrier_layout']=='continuous_miter_v3'
        ports=a['bridge_open_ports'];paths=a['bridge_barrier_paths']
        assert len(paths)=={'straight':2,'corner':2,'t':3,'cross':4,'end':1,'ramp':2}[a['variant']]
        # Each connected mouth has exactly two profile ends at the tile edge;
        # every other corner is internal to a single continuous mesh.
        expected=[]
        for side in ports:
            expected.extend({'north':[(-.665,-1),(.665,-1)],'south':[(-.665,1),(.665,1)],'east':[(1,-.665),(1,.665)],'west':[(-1,-.665),(-1,.665)]}[side])
        endpoints=[tuple(p) for path in paths for p in (path[0],path[-1])]
        assert sorted(endpoints)==sorted(expected),a['id']
        rise=a.get('rise',0);direction=a.get('direction','up')
        for path in paths:
            v,f=bg.sweep(path,[(-.0425,0),(.0425,0),(.0425,.1),(-.0425,.1)],rise,direction)
            edges=Counter(tuple(sorted((p[i],p[(i+1)%len(p)]))) for p in f for i in range(len(p)))
            assert all(n==2 for n in edges.values()),'Open or duplicated profile faces'
            # Deck feet are never horizontal/floating on a sloped module.
            for i,p in enumerate(v):
                if i%4 in (0,1):assert abs(p[2]-bg.grade(p[1],rise,direction))<1e-8
        d,b=glb(MODELS/a['model']);tri=rail_triangles(d,b)
        assert len(tri)>0
        rects=[(-.46,-.46,.46,.46)]
        rects.extend({'north':(-.46,-1,.46,-.46),'south':(-.46,.46,.46,1),'east':(.46,-.46,1,.46),'west':(-1,-.46,-.46,.46)}[p] for p in ports)
        overlap=sum(intersection_area(t[:,:2],r) for t in tri for r in rects)
        assert overlap<1e-8,(a['id'],'railing crosses road',overlap)
        vertices=tri.reshape(-1,3)
        assert np.abs(vertices[:,:2]).max()<=1.000001
        assert abs(max(p[2]-bg.grade(p[1],rise,direction) for p in vertices)-.435)<1e-5
        rows.append(dict(id=a['id'],continuous_paths=len(paths),open_ports=ports,rail_triangles=len(tri),road_overlap_area=overlap,matched_port_endpoints=len(endpoints)))
    # Matching endpoint cross-sections cover straight/turned junctions and both
    # ramp directions: raise the next flat tile by the endpoint connection level.
    profile=[(-.026,.395),(.026,.395),(.026,.435),(-.026,.435)]
    for direction in ('up','down'):
        ramp=np.array(bg.sweep([(.665,-1),(.665,1)],profile,.5,direction)[0])
        for y,ring in ((-1,ramp[:4]),(1,ramp[-4:])):
            flat=np.array(bg.sweep([(.665,-1),(.665,1)],profile)[0])[:4 if y<0 else 8]
            flat=flat[:4] if y<0 else flat[-4:]
            flat[:,2]+=bg.grade(y,.5,direction)
            assert np.allclose(ring,flat)
    OUT.mkdir(parents=True,exist_ok=True)
    report=dict(bridge_count=len(rows),road_intrusions=0,continuous_paths=sum(r['continuous_paths'] for r in rows),ramp_port_transitions_checked=4,assets=rows)
    (OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
