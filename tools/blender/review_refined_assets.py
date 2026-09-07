"""Offline validation + browsable review + contact sheets from actual GLB renders.

Run with Python (numpy, Pillow). No changes to the game's asset references.
"""
from pathlib import Path
import hashlib
import html
import json
import struct
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/previews/refined_v2'
MODELS=ROOT/'assets/models/refined_v2'
KINDS={'house':'Case','apartment':'Palazzine','slab':'Palazzi','villa':'Ville','tower':'Torri','shop':'Commercio','office':'Uffici','factory':'Industria','school':'Scuole','service':'Servizi','agriculture':'Agricoltura','utility':'Impianti','sport':'Sport','tree':'Alberi','park':'Parchi','road':'Strade','sloped_road':'Rampe','bridge':'Ponti','bridge_support':'Supporti'}
GROUPS={
 'residenze':('Abitare',{'house','apartment','slab','villa','tower'}),
 'citta':('Lavoro e servizi',{'shop','office','factory','school','service'}),
 'paesaggio':('Verde e impianti',{'agriculture','utility','sport','tree','park'}),
 'trasporti':('Strade e ponti',{'road','sloped_road','bridge','bridge_support'}),
}

def glb(path):
    data=path.read_bytes()
    magic,version,total=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and total==len(data),path
    n,kind=struct.unpack_from('<II',data,12)
    doc=json.loads(data[20:20+n])
    offset=20+n
    size,kind=struct.unpack_from('<II',data,offset)
    return doc,data[offset+8:offset+8+size]

def accessor(doc,buf,i):
    a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']]
    dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    start=v.get('byteOffset',0)+a.get('byteOffset',0)
    item=np.dtype(dtype).itemsize
    return np.ndarray((a['count'],count),dtype=dtype,buffer=buf,offset=start,strides=(v.get('byteStride',item*count),item)).copy()

def transform(node):
    if 'matrix' in node:return np.array(node['matrix']).reshape(4,4).T
    m=np.eye(4)
    x,y,z,w=node.get('rotation',[0,0,0,1])
    m[:3,:3]=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])@np.diag(node.get('scale',[1,1,1]))
    m[:3,3]=node.get('translation',[0,0,0])
    return m

def geometry(doc,buf):
    visual=[];collisions=[];triangles=0
    def visit(i,parent):
        nonlocal triangles
        node=doc['nodes'][i];matrix=parent@transform(node)
        if 'mesh' in node:
            target=collisions if 'colonly' in node.get('name','') else visual
            for prim in doc['meshes'][node['mesh']]['primitives']:
                pos=accessor(doc,buf,prim['attributes']['POSITION'])
                assert np.isfinite(pos).all()
                xyz=(matrix@np.column_stack((pos,np.ones(len(pos)))).T).T[:,:3]
                target.extend(xyz)
                if target is visual:triangles+=len(accessor(doc,buf,prim['indices']))//3
        for child in node.get('children',[]):visit(child,matrix)
    for i in doc['scenes'][doc.get('scene',0)]['nodes']:visit(i,np.eye(4))
    return np.array(visual),np.array(collisions),triangles

def signature(vertices):
    return sorted(set(tuple(float(x) for x in p) for p in np.round(vertices,4)))

def validate(catalog):
    source={a['id']:a for a in json.loads((ROOT/'assets/models/realistic/catalog.json').read_text())['assets']}
    assert set(source)=={a['id'] for a in catalog},'Catalog IDs differ'
    assert len(catalog)==91
    originals=json.loads((OUT/'original_hashes.json').read_text(encoding='utf-8-sig'))
    for entry in originals:
        assert hashlib.sha256(Path(entry['Path']).read_bytes()).hexdigest().upper()==entry['Hash'],entry['Path']
    rows=[]
    for a in catalog:
        old=source[a['id']]
        for k in ('id','kind','footprint','grid_unit_meters','elevation_step_meters','seed','front_axis','origin_mode','connections','rise','direction','support_height'):
            assert a.get(k)==old.get(k),(a['id'],k)
        d,b=glb(MODELS/a['model']);od,ob=glb(ROOT/'assets/models/realistic'/a['model'])
        v,c,tri=geometry(d,b);ov,oc,_=geometry(od,ob)
        collision_match=signature(c)==signature(oc)
        if a.get('architecture_revision')=='civic_v3':
            assert a['collision_mode']=='simplified_component_boxes'
            assert len(c)>0 and np.isfinite(c).all()
            assert np.max(np.abs(c[:,[0,2]])-np.array(a['footprint']))<=.01
        else:
            assert collision_match,(a['id'],'collision changed')
        assert len(v)>0 and len(c)>0
        assert tri==a['triangles'],(a['id'],tri,a['triangles'])
        for img in d.get('images',[]):assert 'bufferView' in img and 'uri' not in img
        # glTF axes: X, up Y, depth Z. Record inherited and new lot overhangs.
        xy=np.max(np.abs(v[:,[0,2]]),axis=0)
        oxy=np.max(np.abs(ov[:,[0,2]]),axis=0)
        over=np.maximum(0,xy-np.array(a['footprint']))
        counts=a.get('windows_by_side')
        if counts:assert all(v>0 for v in counts.values()),(a['id'],'missing facade glazing')
        assert np.max(np.maximum(0,xy-np.maximum(oxy,a['footprint'])))<=.01,(a['id'],'new lot overhang')
        rows.append(dict(id=a['id'],collision_matches_source=collision_match,triangles=tri,previous_triangles=old['triangles'],bytes=(MODELS/a['model']).stat().st_size,embedded_images=len(d.get('images',[])),windows_by_side=counts,lot_overhang_m=np.round(over,3).tolist(),new_overhang_m=np.round(np.maximum(0,xy-np.maximum(oxy,a['footprint'])),3).tolist()))
    report=dict(asset_count=len(rows),original_files_unchanged=len(originals),collision_match_count=sum(r['collision_matches_source'] for r in rows),triangles=sum(r['triangles'] for r in rows),previous_triangles=sum(r['previous_triangles'] for r in rows),model_bytes=sum(r['bytes'] for r in rows),assets=rows)
    (OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    return report

def make_gallery(catalog,report):
    settings=json.loads((ROOT/'data/catalog.json').read_text(encoding='utf-8-sig'))['tipi']
    for a in catalog:
        group=next(k for k,(_,kinds) in GROUPS.items() if a['kind'] in kinds)
        a['group']=group
        a['kind_label']=KINDS[a['kind']]
        definition=settings.get(a['kind'],{})
        label=definition.get('nome',KINDS[a['kind']])
        for k in ('variant','service','shape','feature','direction'):
            value=a.get(k)
            label=definition.get('nomi',{}).get(value,label)
            qual=definition.get('qualificatori',{}).get(value)
            if qual:label+=' '+qual
        a['label']=label
        if a.get('style')=='dirt':a['label']+=' sterrata'
    payload=json.dumps(catalog,ensure_ascii=False).replace('</',r'<\/')
    text='''<!doctype html><html lang="it"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>FOCUS! — Studio degli asset / 02</title>
<style>
*{box-sizing:border-box} :root{font-family:Inter,Segoe UI,sans-serif;color:#24342d;background:#eeeee7}body{margin:0}button,input,select{font:inherit}button,a{touch-action:manipulation}button{cursor:pointer}header{background:#203a30;color:#eef0e6;padding:46px 5vw 40px}.eyebrow{font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:#b5c7b5}h1{font-family:Georgia,serif;font-size:clamp(38px,5vw,70px);font-weight:400;letter-spacing:-.035em;margin:16px 0;line-height:1.02}header p{max-width:680px;font-size:16px;line-height:1.65;color:#cdd8cb}.top{display:flex;justify-content:space-between;align-items:center}.tag{border:1px solid #718477;border-radius:50px;padding:9px 14px;font-size:12px}.metrics{display:flex;gap:40px;margin-top:28px;font-size:13px;color:#bdcaba}.metrics strong{display:block;color:#fff;font:28px Georgia;margin-bottom:4px}main{padding:0 4vw 40px}.controls{position:sticky;top:0;z-index:3;background:#eeeee7f5;backdrop-filter:blur(12px);padding:20px 0 14px;border-bottom:1px solid #d4d8ce;display:flex;flex-wrap:wrap;gap:10px;align-items:center}.controls button,select,input{border:1px solid #c4ccc0;background:transparent;border-radius:6px;padding:10px 12px;color:#24342d}button.active{background:#203a30;color:#fff}.search{margin-left:auto;min-width:160px}#count{font-size:13px;color:#647363;margin:22px 0}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px}.card{background:#fafaf5;border:1px solid #d8ddd2;border-radius:10px;overflow:hidden}.cardhead{display:flex;justify-content:space-between;padding:16px 17px 0;font-size:12px;color:#627060}.card h2{font:23px Georgia;margin:8px 17px 16px}.pair{display:grid;grid-template-columns:1fr 1fr}.shot{position:relative;cursor:zoom-in;padding:0;border:0;background:#bbc1bc;overflow:hidden}.shot img{width:100%;display:block;aspect-ratio:1}.shot span{position:absolute;bottom:9px;left:9px;background:#f4f6eff0;color:#273c30;padding:5px 7px;border-radius:4px;font-size:10px;letter-spacing:.06em;text-transform:uppercase}.new span{background:#254132ed;color:#fff}.foot{display:flex;justify-content:space-between;gap:8px;align-items:center;padding:13px 17px}.foot code{font:10px Consolas,monospace;color:#6b7669}.foot a{font-size:12px;color:#344f3f;text-decoration:none;border-bottom:1px solid #9aad99}.note{margin:30px 0;max-width:900px;color:#667362;font-size:13px;line-height:1.7}.single .pair{grid-template-columns:1fr}.single .old{display:none}dialog{border:0;border-radius:12px;background:#eeeee7;color:#24342d;padding:22px;max-width:1200px;width:95vw}dialog::backdrop{background:#112218cf}dialog .pair{margin-top:18px}dialog .shot{cursor:default}dialog .shot img{max-height:67vh;object-fit:contain}.modalbar{display:flex;justify-content:space-between;align-items:center;gap:12px}.modalbar button{padding:9px 15px;background:#203a30;color:white;border:0;border-radius:6px}.modalbar h2{font:25px Georgia;margin:0}.sub{font-size:12px;color:#6b7669;margin-top:6px}.modnav{display:flex;gap:8px;flex-wrap:wrap}footer{border-top:1px solid #d4d8ce;padding:20px 0;color:#6b7669;font-size:12px}@media(max-width:1100px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:650px){.grid{grid-template-columns:1fr}.metrics{gap:22px}.search{margin-left:0;width:100%}.tag{display:none}dialog{padding:12px}dialog .pair{grid-template-columns:1fr 1fr}.modalbar h2{font-size:19px}.modnav button{padding:8px}header{padding-top:30px}}
</style>
<header><div class="top"><div class="eyebrow">FOCUS! / Asset design study</div><div class="tag">Proposta separata · nessuna sostituzione</div></div><h1>La stessa città.<br>Più materia, più carattere.</h1><p>Una revisione dei 91 modelli originali: colori minerali, facciate complete, infissi, coperture e dettagli costruttivi. Tutte le immagini sono render dei file 3D consegnati.</p><div class="metrics"><div><strong>91 / 91</strong>asset ricreati</div><div><strong>4 lati</strong>visibili nelle due viste</div><div><strong>02</strong>versioni a confronto</div></div></header>
<main><div class="controls"><button class="active" data-group="all">Tutti</button><button data-group="residenze">Abitare</button><button data-group="citta">Lavoro e servizi</button><button data-group="paesaggio">Verde e impianti</button><button data-group="trasporti">Strade e ponti</button><input class="search" id="search" placeholder="Cerca nome o ID…" aria-label="Cerca asset"><select id="view" aria-label="Angolo di vista"><option value="front">Fronte + destra</option><option value="rear">Retro + sinistra</option></select><select id="mode" aria-label="Modalità confronto"><option value="pair">Confronto</option><option value="single">Solo proposta</option></select></div><p id="count"></p><div class="grid" id="grid"></div><p class="note">Confronti a parità di camera, luce e scala. La proposta mantiene ID, ingombri dichiarati e collisioni del catalogo attuale. Il dettaglio geometrico è maggiore: questa è una libreria da valutare visivamente; la verifica delle prestazioni in gioco e gli eventuali LOD precedono una futura sostituzione. Le due librerie precedenti e i riferimenti del gioco sono invariati.</p><footer>FOCUS! · Studio 02 · Settembre 2026 · <a href="validation.json">Rapporto di verifica</a> · <a href="README.md">Note della proposta</a></footer></main>
<dialog id="modal"><div class="modalbar"><div><h2 id="mtitle"></h2><div class="sub" id="mid"></div></div><div class="modnav"><button id="prev" aria-label="Asset precedente">←</button><button id="flip">Cambia vista</button><button id="next" aria-label="Asset successivo">→</button><button id="close">Chiudi</button></div></div><div class="pair" id="mpair"></div></dialog>
<script>
const assets=PAYLOAD;let group='all',view='front',filtered=assets,index=0;const $=s=>document.querySelector(s);
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function shot(a,v,modal=false){return `<button class="shot ${v==='realistic'?'old':'new'}" ${modal?'tabindex="-1"':`data-id="${a.id}"`} aria-label="Apri confronto ${esc(a.label)}"><img ${modal?'':'loading="lazy"'} src="renders/${a.id}__${v}__${view}.png" alt="${esc(a.label)} — ${v==='realistic'?'attuale':'proposta'}, ${view==='front'?'fronte':'retro'}"><span>${v==='realistic'?'Attuale':'Proposta 02'}</span></button>`}
function draw(){const q=$('#search').value.toLowerCase();filtered=assets.filter(a=>(group==='all'||a.group===group)&&(a.id+' '+a.label).toLowerCase().includes(q));$('#count').textContent=`${filtered.length} asset · Clicca un'immagine per ingrandire il confronto`;$('#grid').innerHTML=filtered.map(a=>`<article class="card"><div class="cardhead"><span>${esc(a.kind_label.toUpperCase())}</span><span>${a.footprint.join(' × ')} celle</span></div><h2>${esc(a.label)}</h2><div class="pair">${shot(a,'realistic')}${shot(a,'refined_v2')}</div><div class="foot"><code>${a.id}</code><a href="../../models/refined_v2/${a.model}" download>Modello GLB ↗</a></div></article>`).join('')}
function show(){const a=filtered[index];if(!a)return;$('#mtitle').textContent=a.label;$('#mid').textContent=a.id+' · '+(view==='front'?'Fronte + destra':'Retro + sinistra');$('#mpair').innerHTML=shot(a,'realistic',true)+shot(a,'refined_v2',true)}
document.querySelectorAll('[data-group]').forEach(b=>b.onclick=()=>{group=b.dataset.group;document.querySelectorAll('[data-group]').forEach(x=>x.classList.toggle('active',x===b));draw()});$('#search').oninput=draw;$('#view').onchange=e=>{view=e.target.value;draw()};$('#mode').onchange=e=>$('#grid').classList.toggle('single',e.target.value==='single');$('#grid').onclick=e=>{let b=e.target.closest('[data-id]');if(!b)return;index=filtered.findIndex(a=>a.id===b.dataset.id);show();$('#modal').showModal()};$('#close').onclick=()=>$('#modal').close();$('#next').onclick=()=>{index=(index+1)%filtered.length;show()};$('#prev').onclick=()=>{index=(index+filtered.length-1)%filtered.length;show()};$('#flip').onclick=()=>{view=view==='front'?'rear':'front';$('#view').value=view;show();draw()};document.addEventListener('keydown',e=>{if(!$('#modal').open)return;if(e.key==='ArrowRight')$('#next').click();if(e.key==='ArrowLeft')$('#prev').click()});$('#modal').onclick=e=>{if(e.target===$('#modal'))$('#modal').close()};draw();
</script></html>'''.replace('PAYLOAD',payload)
    # Keep new bridge renders fresh in browsers that cached earlier revisions.
    text=text.replace('${view}.png"', '${view}.png?rev=${a.bridge_barrier_layout||"02"}"')
    links=[]
    if (OUT/'bridge_v3/index.html').exists():
        links.append('<a href="bridge_v3/index.html">Ponti: parapetti continui e prova dei raccordi →</a>')
    if (OUT.parent/'refined_expansion/index.html').exists():
        links.append('<a id="expansion-link" href="../refined_expansion/index.html">48 nuovi modelli →</a>')
    if links:text=text.replace('<main>','<main><p style="display:flex;gap:25px;flex-wrap:wrap;padding:20px 0;margin:0">'+' '.join(links)+'</p>',1)
    (OUT/'index.html').write_text(text,encoding='utf-8')

def font(size):
    return ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',size)

def sheets(catalog):
    for group,(title,kinds) in GROUPS.items():
        assets=[a for a in catalog if a['kind'] in kinds]
        cols=5;w=350;h=390;rows=(len(assets)+cols-1)//cols
        img=Image.new('RGB',(cols*w,rows*h+145),'#eeeee7');d=ImageDraw.Draw(img)
        d.text((28,20),'FOCUS! / PROPOSTA 02',font=font(19),fill='#617260')
        d.text((28,49),title,font=font(40),fill='#203a30')
        d.text((28,105),f'{len(assets)} modelli · Render reali della nuova libreria',font=font(18),fill='#617260')
        for i,a in enumerate(assets):
            path=OUT/'renders'/f'{a["id"]}__refined_v2__front.png'
            if not path.exists():continue
            x=(i%cols)*w;y=145+(i//cols)*h
            shot=Image.open(path).convert('RGB');shot.thumbnail((w-14,w-14))
            img.paste(shot,(x+7,y))
            d.text((x+12,y+w-9),a.get('label',a['kind']),font=font(16),fill='#203a30')
            d.text((x+12,y+w+15),a['id'],font=font(12),fill='#617260')
        img.save(OUT/f'catalog_{group}.jpg',quality=91)
    chosen=['RES_LOW_1x1_001','RES_MID_3x2_006','RES_TOWER_4x4_003','CIV_FIRE_3x2_002','AGR_GREENHOUSE_3x2_001','SPORT_FOOTBALL_3x2_001']
    canvas=Image.new('RGB',(1440,1560),'#eeeee7');d=ImageDraw.Draw(canvas)
    d.text((28,22),'FOCUS! — Materiali, facciate, dettagli',font=font(36),fill='#203a30')
    d.text((28,76),'ATTUALE  /  PROPOSTA 02     ·     Stessa luce, stessa camera, modelli reali',font=font(18),fill='#617260')
    for i,aid in enumerate(chosen):
        x=(i%2)*720;y=125+(i//2)*475
        for j,v in enumerate(('realistic','refined_v2')):
            path=OUT/'renders'/f'{aid}__{v}__front.png'
            if not path.exists():continue
            shot=Image.open(path).convert('RGB');shot=shot.resize((350,350),Image.Resampling.LANCZOS)
            canvas.paste(shot,(x+10+j*350,y))
            d.text((x+22+j*350,y+360),'Attuale' if j==0 else 'Proposta 02',font=font(17),fill='#203a30')
        d.text((x+22,y+392),aid,font=font(17),fill='#617260')
    canvas.save(OUT/'comparison.jpg',quality=93)

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--allow-incomplete',action='store_true')
    args=parser.parse_args()
    # La libreria e' una cartella sola: il kit di base e l'espansione stanno
    # insieme e si distinguono per il campo 'collection' delle sue voci.
    catalog=[a for a in json.loads((MODELS/'catalog.json').read_text())['assets']
             if a.get('collection')!='refined_expansion']
    if not args.allow_incomplete:
        for a in catalog:
            for version in ('realistic','refined_v2'):
                for view in ('front','rear'):
                    with Image.open(OUT/'renders'/f'{a["id"]}__{version}__{view}.png') as im:im.verify()
    report=validate(catalog);make_gallery(catalog,report);sheets(catalog)
    print(json.dumps({k:v for k,v in report.items() if k!='assets'},indent=2))
