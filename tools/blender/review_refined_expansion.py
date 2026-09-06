"""Validate and present the expansion using only renders of its exported GLBs."""
from pathlib import Path
from collections import Counter
import argparse
import hashlib
import html
import json
import math
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0,str(Path(__file__).resolve().parent))
from review_refined_assets import glb,geometry

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/previews/refined_expansion'
MODELS=ROOT/'assets/models/refined_v2'
GROUPS={'residenze':'Ville e giardini','citta':'Palazzi e grattacieli','negozi':'Negozi e locali','industria':'Fabbriche','impianti':'Energia e acqua','servizi':'Sport e servizi'}

def validate(catalog,complete=True):
    assert len(catalog)==48 and len({a['id'] for a in catalog})==48
    # La libreria e' una cartella sola: il kit di base sono le voci senza
    # 'collection', l'espansione quelle che lo dichiarano.
    previous=[a for a in json.loads((ROOT/'assets/models/refined_v2/catalog.json').read_text(encoding='utf-8'))['assets']
              if a.get('collection')!='refined_expansion']
    assert not ({a['id'] for a in previous}&{a['id'] for a in catalog})
    hashes=json.loads((OUT/'existing_model_hashes.json').read_text(encoding='utf-8'))
    for path,value in hashes.items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==value,path
    rows=[];renders=0
    for a in catalog:
        doc,buf=glb(MODELS/a['model']);v,c,tri=geometry(doc,buf)
        assert len(v)>0 and len(c)>0 and np.isfinite(v).all(),a['id']
        assert tri==a['triangles'],(a['id'],tri,a['triangles'])
        assert v[:,1].min()>=-.002,(a['id'],'below ground')
        over=np.maximum(0,np.max(np.abs(v[:,[0,2]]),axis=0)-a['footprint'])
        assert over.max()<.01,(a['id'],'outside lot',over.tolist())
        assert a['front_axis']=='-Y' and a['grid_unit_meters']==2
        for img in doc.get('images',[]):assert 'bufferView' in img and 'uri' not in img,a['id']
        counts=a.get('windows_by_side')
        if counts:assert min(counts.values())>0,(a['id'],'missing glazing',counts)
        for view in ('front','rear'):
            p=OUT/'renders'/f'{a["id"]}__refined_expansion__{view}.png'
            if complete:assert p.exists(),p
            if p.exists():
                with Image.open(p) as im:im.verify()
                renders+=1
        rows.append(dict(id=a['id'],triangles=tri,bytes=(MODELS/a['model']).stat().st_size,embedded_images=len(doc.get('images',[])),windows_by_side=counts,lot_overhang_m=over.round(4).tolist()))
    report=dict(asset_count=len(rows),existing_files_unchanged=len(hashes),accepted_models_unchanged=91,unique_palette_sets=len({tuple(a['palette']) for a in catalog}),render_count=renders,triangles=sum(r['triangles'] for r in rows),model_bytes=sum(r['bytes'] for r in rows),groups=dict(Counter(a['group'] for a in catalog)),assets=rows)
    (OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    return report

PAGE=r'''<!doctype html>
<html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>FOCUS! — Nuove architetture / 03</title>
<style>
*{box-sizing:border-box} :root{font-family:Segoe UI,Arial,sans-serif;color:#293b35;background:#efeee6}body{margin:0}button,input,select{font:inherit}button,a{touch-action:manipulation}button{cursor:pointer}a{color:inherit}header{background:#243a35;color:#f4f1e6;padding:28px 5vw 34px}.top{display:flex;justify-content:space-between;gap:20px;font-size:12px;align-items:center}.eyebrow{letter-spacing:.16em;text-transform:uppercase;color:#c0caba}.top a{border:1px solid #758780;border-radius:30px;padding:10px 14px;text-decoration:none}.intro{display:grid;grid-template-columns:1fr 1fr;align-items:center;gap:5vw;margin-top:25px}h1{font:normal clamp(40px,4.6vw,72px)/1.04 Georgia,serif;letter-spacing:-.035em;margin:0 0 20px}.intro p{max-width:590px;color:#d2d9cd;line-height:1.7;font-size:16px}.hero{display:grid;grid-template-columns:1fr 1fr;gap:8px}.hero img{width:100%;display:block;border-radius:7px}.hero img:first-child{grid-column:span 2;aspect-ratio:1.9;object-fit:cover;object-position:50% 54%}.hero img:not(:first-child){aspect-ratio:1.8;object-fit:cover;object-position:50% 58%}.metrics{display:flex;gap:28px;font-size:12px;color:#b9c8bb;margin:26px 0 0}.metrics strong{font:28px Georgia;color:#f6f4eb;display:block;margin-bottom:5px}main{padding:0 4vw 40px}.toolbar{position:sticky;top:0;z-index:2;background:#efeee6f5;backdrop-filter:blur(12px);padding:18px 0 13px;border-bottom:1px solid #ccd2c7;display:flex;gap:8px;flex-wrap:wrap;align-items:center}button,select,input{border:1px solid #bdc8bc;border-radius:6px;background:transparent;color:inherit;padding:10px 12px}.toolbar button.active{color:#fff;background:#243a35;border-color:#243a35}input{flex:1;min-width:170px}select{max-width:180px}#count{font-size:13px;color:#6a7869;margin:20px 0}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px}.card{border-radius:10px;background:#fbfaf5;border:1px solid #d3d8cc;overflow:hidden}.shot{width:100%;border:0;padding:0;display:block;position:relative;border-radius:0;background:#a8ada8;cursor:zoom-in}.shot img{display:block;width:100%;aspect-ratio:1;object-fit:cover}.pill{position:absolute;top:12px;left:12px;font-size:10px;background:#f8f7eef0;color:#3e5147;border-radius:20px;padding:7px 9px;letter-spacing:.08em;text-transform:uppercase}.info{padding:17px 19px}.meta{font-size:11px;color:#72816f;display:flex;justify-content:space-between;align-items:center;gap:6px}.palette{display:flex;gap:5px}.swatch{width:13px;height:13px;border-radius:50%;border:1px solid #0001}h2{font:24px Georgia,serif;margin:11px 0}.desc{font-size:13px;line-height:1.6;color:#657161;min-height:42px;margin:0 0 15px}.foot{border-top:1px solid #e0e3d8;padding-top:11px;display:flex;justify-content:space-between;align-items:center;gap:8px}.foot code{font:10px Consolas,monospace;color:#81907c}.foot a{font-size:12px;text-decoration:none;border-bottom:1px solid #a9bba3}#empty{display:none;padding:40px;text-align:center}.note{font-size:13px;color:#6d7968;line-height:1.75;margin:30px 0;max-width:850px}footer{font-size:12px;border-top:1px solid #ccd2c7;padding-top:20px;color:#71806b;display:flex;flex-wrap:wrap;gap:20px}dialog{border:0;border-radius:12px;background:#efeee6;color:#293b35;padding:20px;max-width:1150px;width:95vw}dialog::backdrop{background:#10271ee0}.modalbar{display:flex;align-items:center;justify-content:space-between;gap:14px}.modalbar h2{margin:0;font-size:25px}.modnav{display:flex;gap:7px}.modnav button{background:#243a35;color:#fff;border:0}.sub{font-size:12px;color:#6a7868;margin-top:8px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:16px}.pair figure{margin:0}.pair img{width:100%;display:block;max-height:64vh;object-fit:contain;border-radius:5px;background:#a8ada8}.pair figcaption{font-size:11px;letter-spacing:.08em;text-transform:uppercase;padding:8px 0;color:#75816d}.modalfoot{display:flex;justify-content:space-between;gap:16px;align-items:center;font-size:13px;line-height:1.6}.modalfoot a{white-space:nowrap}.modalfoot p{max-width:770px}.download{background:#243a35;color:#fff;text-decoration:none;padding:10px 14px;border-radius:5px}:focus-visible{outline:3px solid #bd905b;outline-offset:3px}@media(min-width:1600px){.grid{grid-template-columns:repeat(4,minmax(0,1fr))}}@media(max-width:1100px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}.intro{gap:30px}.toolbar{position:static}}@media(max-width:650px){.grid{grid-template-columns:1fr}.intro{grid-template-columns:1fr}.hero{display:none}.top{align-items:flex-start}.top a{font-size:11px}.metrics{gap:22px}header{padding:25px 5vw}.toolbar button{font-size:12px;padding:9px}.toolbar input{width:100%}.modalbar{align-items:flex-start}.modnav button{padding:8px}.pair{grid-template-columns:1fr}dialog{max-height:94vh;padding:14px}.pair img{max-height:48vh}.modalfoot{display:block}.modalfoot a{display:inline-block}.modalbar h2{font-size:21px}}
</style></head><body>
<header><div class="top"><span class="eyebrow">FOCUS! / Asset collection · 03</span><a href="../refined_v2/index.html">← I 91 modelli precedenti</a></div><div class="intro"><div><h1>Nuove architetture.<br>Più modi di fare città.</h1><p>Ville tra il verde, torri sullo skyline, botteghe di quartiere e grandi infrastrutture. Quarantotto nuovi modelli nello stile approvato, con forme, materiali e palette proprie.</p><div class="metrics"><div><strong>48</strong>nuovi modelli</div><div><strong>139</strong>modelli con la serie 02</div><div><strong>96</strong>viste dei GLB</div></div></div><div class="hero" aria-label="Selezione della collezione"><img src="renders/EXP_STADIUM__refined_expansion__front.png" alt="Stadio con tribune e copertura"><img src="renders/EXP_VILLA_POOL__refined_expansion__front.png" alt="Villa con piscina"><img src="renders/EXP_POWER_NUCLEAR__refined_expansion__front.png" alt="Centrale nucleare"></div></div></header>
<main><nav class="toolbar" aria-label="Filtra la collezione"><button data-group="all" class="active" aria-pressed="true">Tutti · 48</button>__FILTERS__<input id="search" type="search" aria-label="Cerca modelli" placeholder="Cerca nome, dettaglio o ID…"><select id="view" aria-label="Angolo di vista"><option value="front">Fronte + destra</option><option value="rear">Retro + sinistra</option></select></nav><p id="count" aria-live="polite"></p><div id="grid" class="grid"></div><p id="empty">Nessun modello trovato. Prova un altro nome o una categoria diversa.</p><p class="note">Ogni immagine mostra il modello GLB esportato e reimportato in Blender. Apri una scheda per osservare entrambi i lati e scaricare il file con i materiali incorporati. La collezione resta separata dai 91 modelli approvati e dagli asset attivi nel gioco.</p><footer><span>FOCUS! · Espansione 03 · Settembre 2026</span><a href="overview.jpg">Tavola di selezione</a><a href="validation.json">Verifica dei file</a><a href="../../models/refined_v2/README.md">Note e rigenerazione</a></footer></main>
<dialog id="modal" aria-labelledby="mtitle"><div class="modalbar"><div><h2 id="mtitle"></h2><div id="mid" class="sub"></div></div><div class="modnav"><button id="prev" aria-label="Modello precedente">←</button><button id="next" aria-label="Modello successivo">→</button><button id="close" aria-label="Chiudi anteprima">Chiudi</button></div></div><div class="pair" id="pair"></div><div class="modalfoot"><p id="mdesc"></p><a class="download" id="download" download>Scarica GLB ↗</a></div></dialog>
<script>
const assets=__ASSETS__,groups=__GROUPS__;
let group='all',view='front',filtered=assets,index=0;
const $=s=>document.querySelector(s),esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const src=(a,v)=>`renders/${a.id}__refined_expansion__${v}.png`;
function draw(){let q=$('#search').value.toLocaleLowerCase('it');filtered=assets.filter(a=>(group==='all'||a.group===group)&&(a.name+' '+a.description+' '+a.id).toLocaleLowerCase('it').includes(q));$('#count').textContent=`${filtered.length} / ${assets.length} modelli · Apri una scheda per vedere fronte e retro`;$('#empty').style.display=filtered.length?'none':'block';$('#grid').innerHTML=filtered.map(a=>`<article class="card"><button class="shot" data-id="${a.id}" aria-label="Apri ${esc(a.name)}"><img loading="lazy" src="${src(a,view)}" alt="${esc(a.name)}, ${view==='front'?'fronte e destra':'retro e sinistra'}"><span class="pill">${esc(groups[a.group])}</span></button><div class="info"><div class="meta"><span>${a.footprint.join(' × ')} celle</span><span class="palette" aria-label="Palette materiali">${a.palette.map(c=>`<span class="swatch" title="#${c}" style="background:#${c}"></span>`).join('')}</span></div><h2>${esc(a.name)}</h2><p class="desc">${esc(a.description)}</p><div class="foot"><code>${a.id}</code><a href="../../models/refined_v2/${a.model}" download>Modello GLB ↗</a></div></div></article>`).join('')}
function show(){let a=filtered[index];if(!a)return;$('#mtitle').textContent=a.name;$('#mid').textContent=`${a.id} · ${a.footprint.join(' × ')} celle · ${a.triangles.toLocaleString('it')} triangoli`;$('#mdesc').textContent=a.description;$('#download').href=`../../models/refined_v2/${a.model}`;$('#pair').innerHTML=['front','rear'].map(v=>`<figure><img src="${src(a,v)}" alt="${esc(a.name)}, ${v==='front'?'fronte':'retro'}"><figcaption>${v==='front'?'Fronte + destra':'Retro + sinistra'}</figcaption></figure>`).join('')}
document.querySelectorAll('[data-group]').forEach(b=>b.onclick=()=>{group=b.dataset.group;document.querySelectorAll('[data-group]').forEach(x=>{x.classList.toggle('active',x===b);x.setAttribute('aria-pressed',x===b?'true':'false')});draw()});$('#search').oninput=draw;$('#view').onchange=e=>{view=e.target.value;draw()};$('#grid').onclick=e=>{let b=e.target.closest('[data-id]');if(!b)return;index=filtered.findIndex(a=>a.id===b.dataset.id);show();$('#modal').showModal()};$('#close').onclick=()=>$('#modal').close();$('#prev').onclick=()=>{index=(index+filtered.length-1)%filtered.length;show()};$('#next').onclick=()=>{index=(index+1)%filtered.length;show()};document.addEventListener('keydown',e=>{if(!$('#modal').open)return;if(e.key==='ArrowLeft')$('#prev').click();if(e.key==='ArrowRight')$('#next').click()});$('#modal').onclick=e=>{if(e.target===$('#modal'))$('#modal').close()};draw();
</script></body></html>'''

def gallery(catalog):
    counts=Counter(a['group'] for a in catalog)
    filters=''.join(f'<button data-group="{k}" aria-pressed="false">{html.escape(v)} · {counts[k]}</button>' for k,v in GROUPS.items())
    page=PAGE.replace('__FILTERS__',filters).replace('__ASSETS__',json.dumps(catalog,ensure_ascii=False)).replace('__GROUPS__',json.dumps(GROUPS,ensure_ascii=False))
    (OUT/'index.html').write_text(page,encoding='utf-8')
    # Link the currently open, already accepted gallery to the new review library.
    previous=ROOT/'assets/previews/refined_v2/index.html'
    text=previous.read_text(encoding='utf-8')
    if 'id="expansion-link"' not in text:
        text=text.replace('<main>','<main><p id="expansion-link" style="padding:18px 0;margin:0;font-size:15px"><a href="../refined_expansion/index.html" style="color:#254b3b">Scopri l’espansione 03: 48 nuovi modelli →</a></p>',1)
        previous.write_text(text,encoding='utf-8')

def sheet(items,title,filename,cols=4):
    width=1400;cell=width//cols;rowh=cell+69;rows=math.ceil(len(items)/cols)
    image=Image.new('RGB',(width,104+rows*rowh+32),'#eeeee6');d=ImageDraw.Draw(image)
    serif=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',34)
    regular=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',17)
    small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',12)
    d.rectangle((0,0,width,91),fill='#243a35');d.text((26,15),title,font=serif,fill='#f3f0e4')
    d.text((28,59),'FOCUS! / ESPANSIONE 03 / MODELLI 3D REALI / SETTEMBRE 2026',font=small,fill='#c3cfbe')
    for i,a in enumerate(items):
        x=(i%cols)*cell;y=104+(i//cols)*rowh
        p=OUT/'renders'/f'{a["id"]}__refined_expansion__front.png'
        if not p.exists():continue
        with Image.open(p) as im:image.paste(im.convert('RGB').resize((cell-14,cell-14),Image.Resampling.LANCZOS),(x+7,y))
        d.text((x+12,y+cell-6),a['name'],font=regular,fill='#2c4034')
        d.text((x+12,y+cell+21),a['id'],font=small,fill='#71816d')
        for j,c in enumerate(a['palette']):d.ellipse((x+cell-62+j*16,y+cell+22,x+cell-51+j*16,y+cell+33),fill='#'+c)
    image.save(OUT/filename,quality=91)

def notes(report):
    # Le note stanno nella galleria e non nella libreria: da quando i 139 modelli
    # vivono in una cartella sola, quel README lo scrive il kit di base.
    (OUT/'README.md').write_text('''# FOCUS! — Espansione 03

48 asset nativi 3D nello stile di `refined_v2`, dentro la libreria del gioco
insieme ai 91 del kit di base: una cartella sola, `assets/models/refined_v2`.

## Contenuto

- 8 case e ville, con giardini, pergole, parterre, piscina o corte.
- 5 palazzi e 6 grattacieli con sagome e palette distinte.
- 10 negozi e locali con dettagli specifici per attività.
- 6 fabbriche: filanda, shed, logistica, acciaieria, alimentare e precisione.
- 7 impianti: 2 centrali a carbone, nucleare, 2 stazioni pompe, depuratore, sottostazione.
- 6 servizi: stadio, palazzetto, caserma, biblioteca, stazione, serra botanica.

## File e coordinate

Ogni GLB contiene mesh, UV e mappe colore/ruvidità incorporate; il relativo JSON
specifica ID, ingombro, altezza, triangoli, palette, descrizione e collisioni.
Una cella = 2 unità/metri del progetto; fronte -Y in Blender, origine al suolo.
Scala e proporzioni sono quelle del diorama, non un rilievo edilizio in scala reale.
Gli ID `EXP_*` sono nuovi e non toccano nessuno di quelli del kit di base.
Prezzi, impianti e celle costruite di questi modelli stanno in `data/economy.json`.
Le collisioni sono volumi semplici per corpo edilizio; per lo stadio sono
segmentate intorno al campo. Non sono ancora collaudate nel gameplay.

Aprire [la galleria](index.html) per i render
frontali e posteriori dei GLB reimportati. Il file `validation.json` riporta
integrità, geometrie, ingombri, texture, finestre e impronte dei file precedenti.
I modelli sono in gioco: si comprano dal negozio come tutti gli altri.

## Rigenerazione

Dalla radice del progetto, con Blender 5.2 e Python con numpy/Pillow:

```powershell
& 'C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe' -b --python tools/blender/generate_refined_expansion.py
& 'C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe' -b --python tools/blender/render_refined_expansion.py -- --size 600 --samples 16
python tools/blender/review_refined_expansion.py
```

Generatore e renderer accettano `-- --asset EXP_ID` ripetibile. Il renderer
supporta `--shard`, `--shards` e `--skip-existing`. Eliminare o rigenerare le
viste dell’asset se la sua geometria cambia: `--skip-existing` non le aggiorna.
''',encoding='utf-8')
    (OUT/'README.md').write_text(f'''# Galleria — Espansione 03

Aprire `index.html`, anche offline. Filtri, ricerca, scelta fronte/retro e
schede con entrambe le viste. Le frecce della tastiera scorrono il dettaglio.
Il collegamento GLB scarica il modello corrispondente con materiali incorporati.

48 modelli, {report['render_count']} render. Le immagini provengono dai GLB reimportati.
`overview.jpg` presenta 12 esempi; `catalog_*.jpg` comprende tutti i 48 modelli
suddivisi nelle sei categorie. `validation.json` riporta i controlli dei file.
`existing_model_hashes.json` preserva le impronte dei {report['existing_files_unchanged']}
file delle librerie preesistenti. Nessun asset precedente è stato sostituito.
''',encoding='utf-8')

def main():
    p=argparse.ArgumentParser();p.add_argument('--allow-incomplete',action='store_true');args=p.parse_args()
    catalog=[a for a in json.loads((MODELS/'catalog.json').read_text(encoding='utf-8'))['assets']
             if a.get('collection')=='refined_expansion']
    report=validate(catalog,not args.allow_incomplete);gallery(catalog)
    for k,title in GROUPS.items():sheet([a for a in catalog if a['group']==k],title,'catalog_'+k+'.jpg')
    picks=['EXP_VILLA_POOL','EXP_VILLA_FORMAL','EXP_PALAZZO_STEPS','EXP_TOWER_DECO','EXP_TOWER_ROUND','EXP_SHOP_CAFE','EXP_SHOP_FLORIST','EXP_FACTORY_STEEL','EXP_POWER_COAL_LARGE','EXP_POWER_NUCLEAR','EXP_WATER_PUMP_RIVER','EXP_STADIUM']
    sheet([next(a for a in catalog if a['id']==i) for i in picks],'Nuove architetture / Selezione','overview.jpg')
    notes(report);print(json.dumps({k:v for k,v in report.items() if k!='assets'},indent=2))

if __name__=='__main__':main()
