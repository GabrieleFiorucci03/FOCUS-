"""48 new native 3D assets in the approved refined style; existing libraries untouched.

blender -b --python tools/blender/generate_refined_expansion.py -- [--asset ID]
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path
import bpy
from mathutils import Matrix,Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import generate_refined_assets as r
base,old=r.base,r.old
ROOT=HERE.parents[1]
OUT=ROOT/'assets/models/refined_v2'
PREVIEW=ROOT/'assets/previews/refined_expansion'
SPECS=[]

def spec(code,name,group,kind,recipe,footprint,palette,description):
    SPECS.append(dict(id='EXP_'+code,name=name,group=group,kind=kind,recipe=recipe,
        footprint=footprint,palette=palette,description=description,seed=3100+len(SPECS),style='refined_v2'))

# Each recipe changes the architecture, layout and equipment, not just the color.
spec('COTTAGE','Cottage dei glicini','residenze','house','cottage',[3,3],['d1c1a4','527466','92624b'],'Intonaco avorio, persiane verdi, tetto in cotto, vialetto e aiuole fiorite.')
spec('VILLA_LIMONAIA','Villa della limonaia','residenze','villa','mediterranean',[4,3],['d1b770','62868a','ad7654'],'Portico mediterraneo, limoni, pergolato e corte pavimentata.')
spec('VILLA_POOL','Villa orizzonte','residenze','villa','modern',[4,4],['d7d8cf','586d78','676e69'],'Volumi sfalsati, vetrate, terrazza, piscina con scala e lettini.')
spec('HOUSE_NORDIC','Casa nordica','residenze','house','nordic',[3,3],['677d89','d1c7ab','4b535b'],'Tetto scuro, rivestimento scandito, abete e orto domestico.')
spec('VILLA_FORMAL','Villa del roseto','residenze','villa','formal',[4,4],['c89b93','6f756c','786657'],'Villa simmetrica, ingresso colonnato, parterre e fontana.')
spec('VILLA_COURT','Villa corte degli ulivi','residenze','villa','courtyard',[4,4],['c1b49c','778465','96755d'],'Pianta a U, corte centrale, olivo, vasca e pergola.')
spec('CHALET','Chalet del bosco','residenze','house','chalet',[3,3],['947657','57756f','595e60'],'Doppia falda pronunciata, balcone in legno e giardino di conifere.')
spec('VILLA_PATIO','Villa del patio','residenze','villa','patio',[4,3],['ad7964','547878','beb39a'],'Mattoni caldi, tetto verde, patio con sedute e pergola a lamelle.')
spec('PALAZZO_COURT','Palazzo della corte','citta','apartment','court',[4,4],['c5b596','6c7d79','786558'],'Quattro ali intorno a un cortile alberato, cornici e cornicione.')
spec('PALAZZO_STEPS','Residenze a terrazze','citta','apartment','steps',[3,3],['a7afa0','b9a881','62736a'],'Tre corpi degradanti, terrazze piantumate e parapetti sottili.')
spec('PALAZZO_BRICK','Palazzo delle officine','citta','apartment','brick',[3,3],['a7735d','607788','706959'],'Mattoni rossi, basamento in pietra e balconi metallici.')
spec('PALAZZO_CORNER','Palazzo angolare','citta','apartment','corner',[3,3],['b8a3b8','72847d','65636e'],'Edificio a L color malva, negozi al piano terra e terrazza comune.')
spec('PALAZZO_LOGGIAS','Casa delle logge','citta','apartment','loggias',[3,3],['cc9f6c','698783','a37857'],'Facciate ocra con logge profonde e fioriere ritmate.')
spec('TOWER_DECO','Torre Aurora','citta','tower','deco',[3,3],['b7aa8b','74898c','656b6a'],'Grattacielo art déco con arretramenti, nervature verticali e guglia.')
spec('TOWER_TWINS','Torri gemelle del porto','citta','tower','twins',[4,3],['6d8592','b8baa9','5b6771'],'Due torri di altezza diversa collegate da un ponte vetrato.')
spec('TOWER_COPPER','Torre Rame','citta','tower','copper',[3,3],['719188','b08962','546563'],'Facciate verde rame, pinne color bronzo e coronamento tecnico.')
spec('TOWER_GARDENS','Torre dei giardini','citta','tower','gardens',[3,3],['c1b7a3','5d7965','78898c'],'Volumi sfalsati e arretrati, terrazze verdi e fioriere.')
spec('TOWER_ROUND','Torre Meridian','citta','tower','round',[3,3],['8598a5','c4b38d','586a76'],'Pianta circolare, vetrate continue, marcapiani e coronamento arretrato.')
spec('TOWER_LANTERN','Torre Lanterna','citta','tower','lantern',[3,3],['a99482','687b80','665a52'],'Basamento pubblico, fusto snello e lanterna panoramica a due livelli.')
spec('SHOP_BAKERY','Panificio del quartiere','negozi','shop','bakery',[2,2],['cba477','7d5c49','ad7654'],'Tenda rigata, vetrina con pagnotte, camino del forno e fioriere.')
spec('SHOP_FLORIST','Fiorista Serra','negozi','shop','florist',[2,2],['a1b39a','ba8d96','6c8071'],'Veranda vetrata e composizioni floreali esposte all’esterno.')
spec('SHOP_BOOKS','Libreria del corso','negozi','shop','books',[2,2],['b98268','608083','806b58'],'Vetrine con scaffali, insegna a libro e panchina per la lettura.')
spec('SHOP_CAFE','Caffè del corso','negozi','shop','cafe',[2,2],['87a8a2','bd927b','71665d'],'Dehors con tavolini, sedute, ombrelloni e insegna a tazzina.')
spec('SHOP_MARKET','Mercato alimentare','negozi','shop','market',[3,2],['cfbd86','7c956e','88715a'],'Tre ingressi, cassette di frutta, pensilina e baie di carico posteriori.')
spec('SHOP_PHARMACY','Farmacia del parco','negozi','shop','pharmacy',[2,2],['c2cec6','5c8a75','728585'],'Facciate chiare, croce verde e ingresso accessibile sotto pensilina.')
spec('SHOP_CINEMA','Cinema Odeon','negozi','shop','cinema',[3,3],['aa7471','bfa778','665c6b'],'Sala alta con torre d’ingresso, marquee, locandine e uscite laterali.')
spec('SHOP_CYCLES','Officina biciclette','negozi','shop','cycles',[2,2],['b8ab70','557b88','6b6860'],'Laboratorio con serranda, biciclette esposte e rastrelliera.')
spec('SHOP_TRATTORIA','Trattoria del pergolato','negozi','shop','restaurant',[3,2],['c09682','6c8464','986d50'],'Sala a L, pergolato, tavoli e fioriere all’ingresso.')
spec('SHOP_DESIGN','Galleria di design','negozi','shop','design',[3,2],['9ca9bf','ad8d73','646d7c'],'Showroom a doppia altezza, brise-soleil e mobili in esposizione.')
spec('FACTORY_MILL','Filanda in mattoni','industria','factory','mill',[4,3],['a57661','64817d','69645c'],'Opificio lungo a più piani con torre scala, ciminiera e carico.')
spec('FACTORY_SAW','Officine a shed','industria','factory','sawtooth',[4,3],['a9b4ae','5e7d8e','728177'],'Tre campate con tetti a shed, lucernari, tubazioni e officina annessa.')
spec('FACTORY_LOGISTICS','Polo logistico','industria','factory','logistics',[5,3],['b3bcc8','647f9b','637383'],'Magazzino basso e largo, cinque baie, ribalte e container.')
spec('FACTORY_STEEL','Acciaieria compatta','industria','factory','steel',[4,4],['997e6a','8b6657','5b6969'],'Due capannoni, altoforno, passerelle, condotte e serbatoi.')
spec('FACTORY_FOOD','Stabilimento alimentare','industria','factory','food',[4,3],['c7bb94','7e9879','84908c'],'Silos inox, edificio produttivo, centrale lavaggio e carico merci.')
spec('FACTORY_TECH','Fabbrica di precisione','industria','factory','tech',[4,3],['c0c8c5','778d9f','7c888b'],'Volumi puliti, ufficio vetrato, macchine HVAC e pannelli solari.')
spec('POWER_COAL_SMALL','Centrale a carbone urbana','impianti','utility','coal_small',[5,4],['a59b87','9b725b','687580'],'Caldaia, ciminiera, deposito del carbone, nastro e trasformatori.')
spec('POWER_COAL_LARGE','Centrale termoelettrica','impianti','utility','coal_large',[6,5],['9ba8b3','b28669','687f7b'],'Due caldaie, due ciminiere, torre di raffreddamento e parco carbone.')
spec('POWER_NUCLEAR','Centrale nucleare','impianti','utility','nuclear',[7,6],['c3c1b3','78919c','868e88'],'Due contenimenti a cupola, torri cave di raffreddamento, sala turbine e sottostazione.')
spec('WATER_PUMP_URBAN','Stazione pompe urbana','impianti','utility','pump_urban',[3,3],['adbdbe','668e9b','777e73'],'Sala pompe, collettori azzurri, valvole, serbatoio e griglie di drenaggio.')
spec('WATER_PUMP_RIVER','Stazione di presa fluviale','impianti','utility','pump_river',[4,3],['bea786','698b8b','78847c'],'Canale di captazione, griglie, pompe e passerella di manutenzione.')
spec('WATER_TREATMENT','Impianto di depurazione','impianti','utility','treatment',[5,4],['bcc1ad','739292','748477'],'Vasche circolari con ponti raschiatori, aerazione, condotte e edificio controllo.')
spec('POWER_SUBSTATION','Sottostazione elettrica','impianti','utility','substation',[3,3],['afada0','789198','6e7e78'],'Tre trasformatori, radiatori, isolatori, portali e recinzione.')
spec('STADIUM','Stadio della città','servizi','sport','stadium',[7,8],['c5c4b4','687e98','aa7b62'],'Campo regolamentare stilizzato, anello di tribune, seggiolini, copertura e torri faro.')
spec('ARENA','Palazzetto polifunzionale','servizi','sport','arena',[4,4],['9cacb9','b79c73','697d83'],'Grande copertura curva, ingresso vetrato, uscite e impianti sul retro.')
spec('FIRE_STATION','Caserma dei vigili del fuoco','servizi','service','fire',[3,3],['ac6f59','af9d80','687786'],'Tre autorimesse, torre di esercitazione e corte di manovra.')
spec('LIBRARY','Biblioteca civica','servizi','service','library',[3,3],['c2aa85','789491','746b62'],'Volumi sovrapposti, grandi finestre, portico, lucernari e giardino di lettura.')
spec('RAIL_STATION','Stazione ferroviaria','servizi','service','station',[5,3],['c6ad88','6a8580','9c7259'],'Fabbricato con orologio, binari, banchine, pensiline e panchine.')
spec('BOTANICAL','Serra botanica','servizi','service','botanical',[4,4],['adc4b8','d0c1a4','749787'],'Padiglione a volte trasparenti, navate laterali e collezione di piante.')

BODIES=[]
RNG=None
S=None
COLLISION_COUNT=0

def box(name,size,loc,key='wall',bevel=.025):
    return old.box(name,size,loc,key,bevel)

def add(size,loc,key='trim',rotation=None):r.add(size,loc,key,rotation)
def beam(a,b,t=.025,key='metal'):r.beam(a,b,t,key)
def cyl(name,radius,depth,loc,key='metal',vertices=24):return old.cylinder(name,radius,depth,loc,key,vertices)

def mesh(name,verts,faces,key):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);r.setmat(obj,key)
    return obj

def collision(size,loc):
    global COLLISION_COUNT
    COLLISION_COUNT+=1
    return box(f'{S["id"]}_{COLLISION_COUNT}-colonly',size,loc,None,0)

def body(x,y,w,d,h,z=.14,key='wall',glazed=False,roof=True):
    ob=box('Tower' if glazed else 'Building',(w,d,h),(x,y,z+h/2),key)
    BODIES.append(ob);collision((w,d,h),(x,y,z+h/2))
    if roof:flat(x,y,w,d,z+h)
    return ob

def flat(x,y,w,d,z,green=False):
    add((w+.06,d+.06,.075),(x,y,z+.027),'roof')
    add((w-.13,d-.13,.025),(x,y,z+.08),'grass' if green else 'roof_membrane')
    for xx in (-1,1):add((.06,d+.06,.15),(x+xx*w/2,y,z+.11),'wall')
    for yy in (-1,1):add((w,.06,.15),(x,y+yy*d/2,z+.11),'wall')
    for xx in range(max(1,int(w/.7))):add((.012,d-.18,.006),(x-w/2+.2+xx*.7,y,z+.097),'metal')

def gable(x,y,w,d,z,h=.6):
    w+=.14;d+=.14
    verts=[(x-w/2,y-d/2,z),(x+w/2,y-d/2,z),(x,y-d/2,z+h),(x-w/2,y+d/2,z),(x+w/2,y+d/2,z),(x,y+d/2,z+h)]
    mesh('GableRoof',verts,[(0,2,1),(3,4,5),(0,1,4,3),(0,3,5,2),(2,5,4,1)],'roof')
    # Tile courses follow the pitch; thin seams rather than noisy random facets.
    for sign in (-1,1):
        for k in range(1,9):
            xx=x+sign*w*.5*k/9;zz=z+h*(1-k/9)+.012
            beam((xx,y-d/2,zz),(xx,y+d/2,zz),.017,'roof_edge')
        for j in range(int(d/.2)+1):
            yy=y-d/2+j*.2
            beam((x,yy,z+h+.01),(x+sign*w/2,yy,z+.01),.008,'roof_edge')
    beam((x,y-d/2,z+h+.025),(x,y+d/2,z+h+.025),.065,'roof_edge')
    for sign in (-1,1):
        beam((x+sign*w/2,y-d/2,z),(x+sign*w/2,y+d/2,z),.045,'metal')
        beam((x+sign*w/2,y+d/2,z),(x+sign*w/2,y+d/2,.18),.032,'metal')

def door(x,y,z=.14,w=.38,h=.65):
    box('Door',(w,.08,h),(x,y,z+h/2),'accent',.012)
    add((w-.07,.015,h*.38),(x,y-.052,z+h*.69),'glass')
    add((.025,.035,.11),(x+w*.32,y-.065,z+h*.43),'metal')
    add((w+.18,.3,.07),(x,y-.12,z+.015),'stone')

def railing(x,y,w,d,z,key='metal'):
    for yy in (-d/2,d/2):
        beam((x-w/2,y+yy,z+.32),(x+w/2,y+yy,z+.32),.027,key)
        for i in range(max(2,int(w/.17))+1):
            xx=x-w/2+w*i/max(2,int(w/.17));beam((xx,y+yy,z),(xx,y+yy,z+.32),.013,key)
    for xx in (-w/2,w/2):
        beam((x+xx,y-d/2,z+.32),(x+xx,y+d/2,z+.32),.027,key)
        for i in range(max(2,int(d/.17))+1):
            yy=y-d/2+d*i/max(2,int(d/.17));beam((x+xx,yy,z),(x+xx,yy,z+.32),.013,key)

def balcony(x,y,w,z):
    add((w,.45,.07),(x,y,z),'stone');railing(x,y,w,.45,z+.035)

def plant(x,y,z=.14,scale=.45,flower=False):
    cyl('Planter',.16*scale,.22*scale,(x,y,z+.11*scale),'terracotta',12)
    old.ico('TrimmedPlant',.25*scale,(x,y,z+.35*scale),(1,1,.85),'leaf',1)
    if flower:
        for k in range(5):
            a=k*math.tau/5
            old.ico('Blossom',.052*scale,(x+.15*scale*math.cos(a),y+.15*scale*math.sin(a),z+.49*scale),(1,1,.7),'flower',1)

def hedge(x,y,w,d,z=.14):box('ClippedHedge',(w,d,.28),(x,y,z+.14),'leaf',.09)
def tree(x,y,z=.14,scale=.65,pine=False):
    before=set(bpy.context.scene.objects);start=len(r.DETAILS['wood']);r.foliage(RNG,x,y,scale,pine)
    for o in set(bpy.context.scene.objects)-before:o.location.z+=z
    for i in range(start,len(r.DETAILS['wood'])):
        size,loc,rot=r.DETAILS['wood'][i]
        r.DETAILS['wood'][i]=(size,(loc[0],loc[1],loc[2]+z),rot)

def bench(x,y,z=.14):
    for off in (-.11,0,.11):add((.65,.08,.04),(x,y+off,z+.24),'wood')
    for xx in (-.24,.24):add((.055,.28,.24),(x+xx,y,z+.12),'metal')
    add((.65,.04,.19),(x,y+.14,z+.37),'wood')

def pergola(x,y,w=1.5,d=1.25,z=.14):
    for xx in (-w/2,w/2):
        for yy in (-d/2,d/2):add((.065,.065,1.15),(x+xx,y+yy,z+.575),'wood')
    for i in range(int(w/.15)+1):add((.055,d+.16,.065),(x-w/2+i*.15,y,z+1.18),'wood')
    for yy in (-d/2,d/2):add((w+.16,.07,.10),(x,y+yy,z+1.10),'wood')

def pool(x,y,w=1.6,d=1.1):
    box('PoolStone',(w+.22,d+.22,.09),(x,y,.16),'stone')
    box('PoolLiner',(w,d,.035),(x,y,.22),'accent')
    add((w-.08,d-.08,.012),(x,y,.24),'water')
    for yy in (-.12,.12):
        beam((x+w/2-.12,y+yy,.23),(x+w/2-.12,y+yy,.52),.021)
        beam((x+w/2-.12,y+yy,.52),(x+w/2+.10,y+yy,.52),.021)
    for xx in range(3):add((.13,.30,.025),(x+w/2-.12,y,.27+xx*.08),'metal')

def garden():
    fx,fy=S['footprint']
    box('Lawn',(fx*2-.18,fy*2-.18,.025),(0,0,.105),'grass',.02)
    for xx in (-fx+.27,fx-.27):
        hedge(xx,0,.21,fy*2-.6)
        for yy in (-fy+.48,fy-.48):plant(xx,yy,scale=.9,flower=True)
    hedge(0,fy-.28,fx*2-.6,.20)
    for yy in [(-fy+.5)+i*.34 for i in range(max(1,int((fy-1.2)/.34)))]:
        add((.55,.25,.035),(0,yy,.14),'stone')
    for xx in (-fx+.75,fx-.75):tree(xx,fy-.75,scale=.65,pine=S['recipe'] in {'nordic','chalet'})
    for xx in (-fx*.55,fx*.55):
        box('FlowerBed',(.8,.52,.06),(xx,-fy+.65,.15),'soil')
        for off in (-.24,0,.24):plant(xx+off,-fy+.65,scale=.65,flower=True)

def hvac(x,y,z,w=.55):
    box('HVAC',(w,.42,.3),(x,y,z+.15),'metal')
    for k in range(5):add((w-.06,.015,.019),(x,y-.22,z+.05+k*.045),'black')
    cyl('Fan',.13,.018,(x,y,z+.31),'black',16)
    for k in range(4):
        a=k*math.pi/4;beam((x-.12*math.cos(a),y-.12*math.sin(a),z+.324),(x+.12*math.cos(a),y+.12*math.sin(a),z+.324),.014,'metal')

def houses():
    recipe=S['recipe'];garden()
    if recipe in {'cottage','nordic','chalet'}:
        h=1.5 if recipe=='chalet' else 1.3
        body(0,.25,2.2,2.0,h,roof=False);gable(0,.25,2.2,2.0,.14+h,.85 if recipe=='chalet' else .60)
        door(0,-.78);box('Chimney',(.25,.3,.8),(.65,.75,h+.5),'stone')
        if recipe=='chalet':balcony(0,-.93,1.7,1.05)
        if recipe=='nordic':
            for xx in [i*.14 for i in range(-7,8)]:add((.02,.025,1.15),(xx,-.765,.78),'accent')
            for xx in (-1.8,1.8):
                box('KitchenGarden',(.55,1.1,.12),(xx,-.65,.18),'wood')
                for yy in (-1,-.7,-.4):plant(xx,yy,.25,.5)
        else:pergola(-1.85,-.3,.8,1.0)
    elif recipe=='mediterranean':
        body(-.45,.35,2.7,2.2,1.5,roof=False);gable(-.45,.35,2.7,2.2,1.64,.52)
        body(1.4,.65,1.0,1.6,.92,roof=False);gable(1.4,.65,1,1.6,1.06,.3)
        add((2.7,.8,.09),(-.45,-1.05,1.36),'roof')
        for xx in (-1.65,-.85,.0,.8):cyl('PorticoColumn',.055,1.2,(xx,-1.35,.74),'stone')
        door(-.45,-.78);pergola(2.65,-.2,1.2,1.5)
        for yy in (-1,0,1):tree(-2.8,yy,scale=.55)
    elif recipe=='modern':
        body(-.75,.4,3.1,2.7,1.35,glazed=True)
        body(-1.05,.75,2.1,1.7,.8,z=1.49,glazed=True)
        pool(1.7,-1.1,2.0,1.5);door(-.8,-.98)
        for xx in (1.1,2.0):
            add((.38,.9,.12),(xx,-2.4,.23),'wood');add((.34,.6,.05),(xx,-2.5,.31),'paper')
        railing(-.75,-.60,2.8,.42,1.58)
    elif recipe=='formal':
        body(0,.65,3.4,2.1,2.05,roof=False);gable(0,.65,3.4,2.1,2.19,.55)
        add((1.3,.65,.13),(0,-.7,1.25),'stone')
        for xx in (-.52,.52):cyl('EntryColumn',.075,1.05,(xx,-.9,.70),'paper')
        door(0,-.43)
        for xx in (-1.7,1.7):
            for yy in (-1.4,-2.35):
                hedge(xx,yy,.9,.45);plant(xx,yy,.43,.65,True)
        cyl('FountainBasin',.48,.13,(0,-2.15,.20),'stone',32)
        cyl('FountainWater',.40,.015,(0,-2.15,.28),'water',32)
        cyl('FountainStem',.09,.35,(0,-2.15,.43),'stone')
    elif recipe=='courtyard':
        body(0,1.55,3.9,1.25,1.35,roof=False);gable(0,1.55,3.9,1.25,1.49,.45)
        for xx in (-1.35,1.35):body(xx,.10,1.2,1.7,1.35)
        door(0,.9);tree(0,.15,scale=.70);pool(0,-1.35,1.1,.6);pergola(-2.8,-.75,1.05,1.3)
    else:
        body(-.6,.45,2.9,2.2,1.15,glazed=recipe=='patio',roof=False)
        flat(-.6,.45,2.9,2.2,1.29,green=True)
        body(1.25,.8,1.2,1.5,.9)
        door(-.6,-.68);pergola(1.2,-1.1,1.65,1.35);bench(1.2,-1.0)
        for xx in (-1.3,-.5,.3):plant(xx,.3,1.4,1.0,True)

def apartments():
    recipe=S['recipe']
    if recipe=='court':
        for x,y,w,d in ((0,2,5.6,1.2),(0,-2,5.6,1.2),(-2.2,0,1.2,2.8),(2.2,0,1.2,2.8)):
            body(x,y,w,d,3.5)
        tree(0,0,scale=.9);bench(.8,.4);door(0,-2.64)
    elif recipe=='steps':
        for x,h in ((-1.55,2.3),(0,3.5),(1.55,4.7)):
            body(x,.25,1.42,3.0,h);railing(x,.25,1.30,2.85,h+.26)
            for yy in (-.7,.5):plant(x,yy,h+.26,1.15)
        door(0,-1.29)
    elif recipe=='corner':
        body(-1.25,.25,1.4,3.8,3.8);body(.65,1.4,2.45,1.5,3.8)
        storefront(-1.25,-1.69,1.15);storefront(.65,.62,1.9);tree(.6,-.7,scale=.8)
    else:
        body(0,.15,3.85,3.1,3.7 if recipe=='brick' else 4.3)
        door(0,-1.45)
        height=3.7 if recipe=='brick' else 4.3
        for z in [1.25,2.05,2.85]+([3.65] if recipe=='loggias' else []):
            for x in (-1.25,1.25):balcony(x,-1.61,.95,z)
            for y in (-.7,.85):
                add((.36,.8,.07),(2.05,y,z),'stone');railing(2.05,y,.36,.8,z+.04)
        if recipe=='brick':
            for z in [.3+i*.16 for i in range(21)]:
                add((3.86,.018,.009),(0,-1.41,z),'roof_edge')
                add((.018,3.1,.009),(1.93,.15,z),'roof_edge')
        else:
            for x in (-1.75,-.7,.7,1.75):add((.10,.36,height),(x,-1.54,.14+height/2),'accent')
        hvac(0,.6,height+.24)
    for x in (-2.35,2.35):plant(x,-2.2,scale=1.1,flower=True)

def lathe(name,x,y,profile,key,n=48,cap=False):
    verts=[(x+rad*math.cos(k*math.tau/n),y+rad*math.sin(k*math.tau/n),z) for rad,z in profile for k in range(n)]
    faces=[]
    for j in range(len(profile)-1):
        for k in range(n):faces.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
    if cap:faces.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+k for k in range(n))])
    return mesh(name,verts,faces,key)

def round_tower(x,y,rad,z,h,levels):
    cyl('CircularCore',rad,h,(x,y,z+h/2),'wall',48);collision((2*rad,2*rad,h),(x,y,z+h/2))
    for level in range(levels):
        zz=z+(level+.5)*h/levels
        for k in range(24):
            a=k*math.tau/24;rot=Matrix.Rotation(a,3,'Z')
            add((.025,rad*.22,h/levels*.72),(x+(rad+.013)*math.cos(a),y+(rad+.013)*math.sin(a),zz),'glass' if k%4 else 'glass_dark',rot)
            add((.045,.018,h/levels),(x+(rad+.036)*math.cos(a+.12),y+(rad+.036)*math.sin(a+.12),zz),'trim',Matrix.Rotation(a+.12,3,'Z'))
        lathe('CircularFloor',x,y,[(rad+.05,z+level*h/levels),(rad+.05,z+level*h/levels+.04)],'metal')

def towers():
    recipe=S['recipe'];body(0,0,4.5,3.7,.7,glazed=True)
    if recipe=='deco':
        for w,d,z,h in ((2.8,2.5,.84,5.3),(2.2,1.95,6.14,1.5),(1.45,1.35,7.64,1.1)):
            body(0,0,w,d,h,z,glazed=True)
            for xx in (-w*.4,0,w*.4):add((.085,.10,h),(xx,-d/2-.04,z+h/2),'accent')
        cyl('Spire',.045,1.3,(0,0,9.40),'metal')
    elif recipe=='twins':
        body(-1.25,.2,1.65,2.2,6.6,.84,glazed=True);body(1.25,.2,1.65,2.2,5.5,.84,glazed=True)
        body(0,.2,.95,.7,.55,4.3,glazed=True)
    elif recipe=='copper':
        body(0,0,2.7,2.5,7.7,.84,glazed=True)
        for xx in [i*.3 for i in range(-4,5)]:
            for yy in (-1.32,1.32):add((.06,.15,7.85),(xx,yy,4.72),'accent')
        for yy in [i*.3 for i in range(-3,4)]:
            for xx in (-1.42,1.42):add((.15,.06,7.85),(xx,yy,4.72),'accent')
        hvac(-.5,0,8.7);hvac(.5,0,8.7)
    elif recipe=='gardens':
        for i,(x,y,w,d) in enumerate(((0,0,3.4,2.8),(.3,.25,2.8,2.3),(-.15,.1,2.2,1.85),(.15,.25,1.6,1.4))):
            z=.84+i*1.75;body(x,y,w,d,1.75,z,glazed=True)
            railing(x,y,w-.13,d-.13,z+1.86)
            for xx in (x-w*.3,x+w*.3):plant(xx,y-d*.35,z+1.86,.9)
    elif recipe=='round':
        round_tower(0,0,1.48,.84,7.5,16);round_tower(.10,0,1.20,8.34,.65,1)
        cyl('Crown',1.23,.07,(.10,0,9.02),'accent',48)
    else:
        body(0,0,1.8,1.8,6.7,.84,glazed=True)
        body(0,0,2.75,2.6,.9,7.54,glazed=True);body(0,0,2.15,2.0,.65,8.6,glazed=True)
        for xx in (-.76,.76):
            for yy in (-.76,.76):add((.12,.12,7.9),(xx,yy,4.8),'accent')
    door(0,-1.9,h=.65)
    for xx in (-2.3,2.3):plant(xx,-1.9,scale=1)

def storefront(x,y,w,z=.14):
    box('Storefront',(w,.06,.84),(x,y,z+.46),'glass_dark',.012)
    for i in (-.5,0,.5):add((.025,.065,.89),(x+i*w,y-.02,z+.46),'trim')
    for zz in (.04,.9):add((w+.04,.075,.025),(x,y-.02,z+zz),'trim')
    add((.02,.03,.18),(x+.08,y-.065,z+.42),'metal')

def awning(x,y,w,z=1.2):
    for i in range(max(2,int(w/.22))):
        n=max(2,int(w/.22));xx=x-w/2+w*(i+.5)/n
        add((w/n,.63,.06),(xx,y-.28,z),'accent' if i%2 else 'paper',Matrix.Rotation(.12,3,'X'))
        add((w/n,.05,.16),(xx,y-.6,z-.11),'accent' if i%2 else 'paper')

def table(x,y,umbrella=False):
    cyl('TableTop',.23,.045,(x,y,.54),'wood',24);cyl('TablePedestal',.025,.38,(x,y,.33))
    for yy in (-.4,.4):
        add((.23,.24,.035),(x,y+yy,.34),'accent');add((.23,.035,.23),(x,y+yy+(.10 if yy>0 else -.10),.44),'accent')
        for xx in (-.08,.08):add((.025,.20,.2),(x+xx,y+yy,.23),'metal')
    if umbrella:
        cyl('UmbrellaPole',.019,1.5,(x,y,.9));old.cone('Umbrella',.52,.06,.25,(x,y,1.66),'paper',12)

def bike(x,y):
    for xx in (-.20,.20):old.torus('BicycleWheel',.13,.014,(x+xx,y,.28),'black',(math.pi/2,0,0))
    for a,b in (((-.2,.28),(-.04,.45)),((-.04,.45),(.10,.29)),((.10,.29),(-.2,.28)),((.10,.29),(.15,.49)),((.15,.49),(-.04,.45)),((.15,.49),(.2,.28))):
        beam((x+a[0],y,a[1]),(x+b[0],y,b[1]),.022,'accent')
    add((.12,.055,.025),(x-.04,y,.48),'black');beam((x+.15,y-.07,.53),(x+.15,y+.07,.53),.02)

def loading(x,y,z=.14):
    box('LoadingDoor',(.68,.06,.78),(x,y,z+.42),'metal',.006)
    for k in range(8):add((.62,.017,.011),(x,y-.04,z+.08+k*.095),'black')
    add((.83,.42,.17),(x,y-.15,z+.03),'concrete')
    for xx in (-.34,.34):add((.06,.08,.23),(x+xx,y-.37,z+.16),'accent')

def shops():
    recipe=S['recipe'];fx,fy=S['footprint'];w=fx*1.25;d=fy*1.1
    h=2.05 if recipe in {'cinema','design'} else 1.22
    body(0,.3,w,d,h,glazed=recipe=='design',roof=recipe not in {'bakery','restaurant'})
    front=.3-d/2-.035
    if recipe in {'bakery','restaurant'}:gable(0,.3,w,d,h+.14,.44)
    if recipe=='market':
        for xx in (-1.25,0,1.25):storefront(xx,front,1.03)
    elif recipe=='cycles':storefront(-.55,front,1.05)
    else:storefront(0,front,w*.78)
    add((w*.83,.09,.20),(0,front-.025,1.19),'accent')
    if recipe in {'bakery','books','cafe','market'}:awning(0,front,w*.9)
    if recipe=='bakery':
        for xx in (-.7,-.4,.3,.6):old.ico('Bread',.11,(xx,front-.08,.53),(1,.6,.55),'ochre',2)
        box('OvenChimney',(.33,.33,1.1),(.7,.8,1.65),'wall')
        for yy in (-1.5,-1.2):plant(1.4,yy,scale=.8,flower=True)
    elif recipe=='florist':
        add((w+.1,.75,.04),(0,front-.34,1.45),'greenhouse_glass')
        for xx in (-1.2,1.2):add((.035,.035,1.3),(xx,front-.65,.79),'metal')
        for xx in (-1,-.5,.5,1):
            for yy in (front-.35,front-.75):plant(xx,yy,scale=1.05,flower=True)
    elif recipe=='books':
        for xx in (-.7,.6):
            for z in (.45,.69):
                add((.5,.16,.025),(xx,front-.08,z),'wood')
                for i in range(6):add((.045,.09,.15),(xx-.2+i*.075,front-.085,z+.085),['accent','ochre','coral'][i%3])
        add((.34,.055,.26),(0,front-.08,1.2),'paper');add((.015,.065,.28),(0,front-.09,1.2),'wood');bench(1.45,-1.05)
    elif recipe in {'cafe','restaurant'}:
        for xx in (-1.0,1.0):table(xx,-1.43,recipe=='cafe')
        if recipe=='restaurant':
            body(-2.1,.6,.9,1.6,.95,roof=False);gable(-2.1,.6,.9,1.6,1.09,.3)
            pergola(0,-1.35,3.4,1.1);plant(2.2,-1,scale=1.3,flower=True)
        else:
            cyl('Cup',.12,.19,(0,front-.10,1.37),'paper')
            old.torus('CupHandle',.065,.018,(.135,front-.1,1.39),'paper',(math.pi/2,0,0))
    elif recipe=='market':
        for xx in (-1.25,0,1.25):
            add((.68,.45,.3),(xx,front-.45,.29),'wood')
            for j in range(8):old.ico('Produce',.065,(xx-.22+(j%4)*.14,front-.55+(j//4)*.16,.49),(1,1,1),'flower' if xx==0 else 'ochre',1)
        loading(1.15,.3+d/2+.04)
    elif recipe=='pharmacy':
        add((.40,.10,.12),(0,front-.1,1.42),'accent');add((.12,.10,.4),(0,front-.1,1.42),'accent')
        add((1.5,.7,.07),(0,front-.3,1.10),'paper');add((.9,.9,.035),(0,front-.45,.16),'stone')
    elif recipe=='cinema':
        body(-1.45,-.65,.65,.7,2.8)
        add((2.6,.85,.17),(0,front-.30,1.21),'accent')
        for xx in (-1,-.5,0,.5,1):cyl('MarqueeLamp',.025,.025,(xx,front-.6,1.10),'window_warm',12)
        for xx in (-1.35,1.35):
            add((.42,.075,.66),(xx,front-.05,.64),'trim');add((.33,.025,.55),(xx,front-.10,.64),'flower')
        hvac(0,.5,2.35)
    elif recipe=='cycles':
        loading(.70,front)
        for xx in (-.7,.05,.8):bike(xx,-1.4)
        beam((-1.1,-1.75,.20),(1.1,-1.75,.20),.035)
        for xx in (-.7,.05,.8):
            beam((xx,-1.77,.16),(xx,-1.77,.46),.025);beam((xx,-1.77,.46),(xx,-1.50,.46),.025)
        old.torus('WheelSign',.22,.027,(0,front-.08,1.29),'trim',(math.pi/2,0,0))
    elif recipe=='design':
        for xx in (-1.5,-1,-.5,0,.5,1,1.5):add((.035,.22,.85),(xx,front-.03,1.76),'accent')
        bench(-.8,front-.11,.18);table(.8,front-.05)
    if recipe not in {'bakery','restaurant','cinema'}:hvac(.65,.7,h+.25,.45)

def chimney(x,y,z=0,h=4.5,radius=.22):
    lathe('Chimney',x,y,[(radius*1.15,z),(radius,z+h*.7),(radius*.83,z+h),(radius*.62,z+h),(radius*.62,z+h-.2)],'wall',32)
    for zz in (.68,.80,.92):lathe('StackBand',x,y,[(radius*.94,z+h*zz),(radius*.94,z+h*zz+.12)],'paper',32)
    cyl('DarkStackThroat',radius*.62,.015,(x,y,z+h-.2),'black',32)
    collision((radius*2,radius*2,h),(x,y,z+h/2))
    for zz in [z+.2+i*.22 for i in range(int(h/.22))]:beam((x-radius-.055,y-.09,zz),(x-radius-.055,y+.09,zz),.014)
    for yy in (-.09,.09):beam((x-radius-.055,y+yy,z+.15),(x-radius-.055,y+yy,z+h-.1),.018)

def tank(x,y,radius=.48,h=1.7,z=.14):
    cyl('TankShell',radius,h,(x,y,z+h/2),'metal',32)
    lathe('TankCap',x,y,[(radius,z+h),(.85*radius,z+h+.12),(.2*radius,z+h+.19),(0,z+h+.19)],'metal',32)
    for zz in (z+.15,z+h*.5,z+h-.12):old.torus('TankHoop',radius+.008,.018,(x,y,zz),'trim')
    collision((radius*2,radius*2,h),(x,y,z+h/2))

def pipe(points,radius=.06,key='accent'):
    for a,b in zip(points,points[1:]):
        va,vb=Vector(a),Vector(b);delta=vb-va
        ob=cyl('Pipe',radius,delta.length,(va+vb)/2,key)
        ob.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
        for t in (.16,.84):
            flange=cyl('PipeFlange',radius*1.28,.027,va+delta*t,'metal')
            flange.rotation_euler=ob.rotation_euler
    for p in points[1:-1]:old.ico('PipeElbow',radius*1.16,p,(1,1,1),key,2)

def cooling(x,y,radius=1,h=3.3):
    z=.4
    prof=[]
    for i in range(19):
        t=i/18;rad=radius*(.68+1.6*(t-.65)**2)
        prof.append((rad,z+t*h))
    top=prof[-1];prof.extend([(top[0]-.065,top[1]),(top[0]-.07,top[1]-.28)])
    lathe('CoolingTowerShell',x,y,prof,'concrete_light',64)
    cyl('CoolingTowerShadow',top[0]-.075,.015,(x,y,z+h-.30),'black',48)
    for k in range(20):
        a=k*math.tau/20;b=a+.08;rr=prof[0][0]
        beam((x+rr*math.cos(a),y+rr*math.sin(a),z),(x+(rr+.1)*math.cos(b),y+(rr+.1)*math.sin(b),.14),.065,'concrete')
    collision((radius*2.6,radius*2.6,z+h),(x,y,(z+h)/2))

def transformer(x,y,scale=1):
    box('Transformer',(.65*scale,.9*scale,.65*scale),(x,y,.14+.325*scale),'metal')
    for sign in (-1,1):
        for i in range(7):add((.12*scale,.055*scale,.56*scale),(x+sign*.40*scale,y+(i-3)*.12*scale,.14+.32*scale),'accent')
    for xx in (-.20,.20):
        for yy in (-.22,.22):
            cyl('Bushing',.028*scale,.30*scale,(x+xx*scale,y+yy*scale,.14+.8*scale),'stone',12)
            for zz in range(4):cyl('Insulator',.068*scale,.028*scale,(x+xx*scale,y+yy*scale,.14+(.70+zz*.065)*scale),'stone',12)

def solar(x,y,z,w=1.1,d=.7):
    add((w,d,.025),(x,y,z),'glass_dark')
    for i in range(7):add((.012,d,.012),(x-w/2+i*w/6,y,z+.02),'metal')
    for j in range(4):add((w,.012,.012),(x,y-d/2+j*d/3,z+.02),'metal')

def factories():
    recipe=S['recipe']
    if recipe=='mill':
        body(-.4,.2,4.8,2.8,2.7,roof=False);gable(-.4,.2,4.8,2.8,2.84,.55)
        body(2.5,.65,.9,1.25,3.4);chimney(-2.9,1.7,.14,4.0,.22)
        for z in (.5,1.25,2.0):add((4.86,2.86,.045),(-.4,.2,z),'stone')
        for x in (-1.5,0,1.5):loading(x,-1.24)
    elif recipe=='sawtooth':
        body(0,.25,5.7,3.25,1.4,roof=False)
        for i in range(3):
            x=-2.85+i*1.9
            mesh('Sawtooth',[(x,-1.45,1.54),(x+1.9,-1.45,1.54),(x+1.9,-1.45,2.22),(x,1.95,1.54),(x+1.9,1.95,1.54),(x+1.9,1.95,2.22)],[(0,2,1),(3,4,5),(0,3,5,2),(1,2,5,4)],'roof')
            add((.025,3.25,.51),(x+1.91,.25,1.88),'glass')
            for yy in (-1,-.4,.2,.8,1.4):add((.04,.025,.60),(x+1.93,yy,1.87),'metal')
        for x in (-1.9,0,1.9):loading(x,-1.40)
        pipe([(-3.1,1.8,.3),(-3.1,1.8,1.2),(-3.1,-1.2,1.2)],.07)
    elif recipe=='logistics':
        body(0,.5,7.5,3.3,1.3);body(-3,-1.3,1.4,.7,.85,glazed=True)
        for x in (-2.8,-1.4,0,1.4,2.8):loading(x,-1.19)
        for x in (-2.6,0,2.6):
            box('Container',(1.8,.8,.75),(x,2.25,.515),'accent')
            for j in range(12):add((.025,.825,.69),(x-.80+j*.145,2.25,.515),'metal')
    elif recipe=='steel':
        body(-1.5,.6,2.6,4.1,1.8,roof=False);gable(-1.5,.6,2.6,4.1,1.94,.5)
        body(1.6,1.8,2.4,1.6,1.25)
        lathe('BlastFurnace',1.4,-.55,[(.65,.3),(.7,1.2),(.48,2.15),(.32,2.9),(.36,3.6)],'roof',32)
        for z in (1.4,2.7):
            add((1.9,1.65,.06),(1.4,-.55,z),'metal');railing(1.4,-.55,1.9,1.65,z+.04)
        for xx in (.6,2.2):
            for yy in (-1.2,.1):beam((xx,yy,.14),(xx,yy,3.3),.10,'metal')
        pipe([(1.4,-.55,3.55),(2.8,-.55,3.55),(2.8,1.3,3.55),(2.8,1.3,1.4)],.16)
        chimney(-2.7,2.8,.14,3.8,.18);tank(2.7,-2.6,.4,1.5)
    elif recipe=='food':
        body(-.65,.4,3.9,3.1,1.65);body(-1.45,-1.3,2.25,.85,.9)
        for x in (1.8,2.85):
            for y in (0,1.25):tank(x,y,.43,2.35)
        pipe([(2.35,-.6,.4),(2.35,-.6,1.5),(0,-.6,1.5)],.055)
        loading(-1.4,-1.76);loading(.35,-1.18)
    else:
        body(-.35,.4,4.9,3.2,1.55);body(1.1,-1.45,2.0,.85,1.2,glazed=True)
        for x in (-1.8,-.4,1.0):
            hvac(x,.75,1.8,.7);solar(x,-.3,1.83)
        for x in (-1.7,-.6):loading(x,-1.25)
    for x in (-3.1,3.1):add((.03,.55,.012),(x,-2.45,.15),'road_line')

def coal(large):
    if large:
        for x in (-1.5,1.1):body(x,.9,2.25,2.3,3.1)
        body(0,-1.0,4.85,1.3,1.45)
        for x in (-1.7,1.6):chimney(x,3.4,.14,5.5,.27)
        cooling(4,1.1,.85,3.0)
        cx,cy=-3.7,-2.1
    else:
        body(-.3,.8,3.2,2.6,2.7);body(-.3,-1.0,3.4,1.0,1.2)
        chimney(1.9,1.8,.14,4.7,.23);cx,cy=-3.1,-1.5
    box('CoalBunker',(1.7,2.1,.12),(cx,cy,.19),'concrete')
    for yy in (-.55,0,.55):old.ico('CoalStockpile',.67,(cx,cy+yy,.4),(1,.75,.43),'black',2)
    start=(cx,cy,.65);end=(-1.5,.45,2.45)
    beam(start,end,.30,'metal');beam((cx,cy,.72),(-1.5,.45,2.52),.22,'black')
    for t in (.3,.7):
        p=tuple(start[i]+t*(end[i]-start[i]) for i in range(3));beam((p[0],p[1],.14),p,.07,'metal')
    for x in (1.0,2.5):transformer(x,-2.6,.8)
    for x in (-1.6,.8):pipe([(x,-.25,3.0),(x,-.55,3.0),(x,-.55,1.5)],.08)

def utilities():
    recipe=S['recipe']
    if recipe.startswith('coal'):coal(recipe=='coal_large')
    elif recipe=='nuclear':
        for x in (-3.2,.1):
            rad=1.02;profile=[(rad,.14),(rad,2.0)]
            profile.extend((rad*math.cos(i*math.pi/24),2+rad*math.sin(i*math.pi/24)) for i in range(1,13))
            lathe('ContainmentDome',x,-.65,profile,'wall',48,True);collision((2.04,2.04,2.9),(x,-.65,1.59))
            for a in (0,math.pi/2,math.pi,math.pi*1.5):add((.12,.12,1.9),(x+1.0*math.cos(a),-.65+1.0*math.sin(a),1.1),'trim')
        body(-1.55,-2.6,5.6,1.25,1.3);body(3.8,-1.8,1.8,2.7,.95,glazed=True)
        cooling(-2.5,3.0,1.2,4.1);cooling(1.6,3.0,1.2,4.1)
        for x in (-3.5,-2.0,-.5):transformer(x,-4.3,.8)
        pipe([(3,2,.35),(3,0,.35),(.3,0,.35)],.13)
        for yy in (-3.0,-1.8):hvac(3.8,yy,1.21)
    elif recipe.startswith('pump'):
        river=recipe=='pump_river';body(-.6,.4,2.4,2.0,1.25);door(-.6,-.64)
        for y in (-.5,.55,1.55):
            cyl('PumpMotor',.16,.4,(1.2,y,.41),'accent')
            pipe([(.7,y,.30),(1.65,y,.30),(1.65,y,.8)],.09)
            old.torus('ValveWheel',.13,.018,(1.65,y,.87),'coral')
        pipe([(1.65,-1,.33),(1.65,2,.33)],.12)
        if river:
            add((1.0,4.8,.045),(-2.8,0,.17),'water')
            for x in (-3.4,-2.2):add((.18,4.95,.24),(x,0,.19),'concrete')
            for yy in (-1.2,-.85,-.5):
                for xx in (-3.15,-2.95,-2.75,-2.55):beam((xx,yy,.23),(xx,yy+.25,.48),.028,'metal')
            add((2.1,.6,.075),(-2,1.35,.6),'metal');railing(-2,1.35,2.1,.6,.64)
            pipe([(-2.8,0,.25),(-1.8,0,.25),(-1.8,0,.7)],.14)
        else:
            tank(-1.7,1.75,.42,1.7)
            for xx in (-.6,.2,1.0):
                add((.50,.24,.015),(xx,-1.6,.15),'black')
                for j in range(7):add((.025,.25,.02),(xx-.22+j*.073,-1.6,.165),'metal')
    elif recipe=='treatment':
        for x in (-2.7,.2):
            lathe('ClarifierWall',x,.75,[(1.12,.14),(1.12,.65),(1.02,.65),(1.02,.2)],'concrete_light',48)
            cyl('ClarifierWater',1.01,.02,(x,.75,.47),'water',48)
            add((2.26,.15,.06),(x,.75,.74),'metal');railing(x,.75,2.2,.2,.77)
            cyl('ClarifierHub',.14,.28,(x,.75,.67),'metal')
        body(2.8,.8,1.65,2.5,1.1);door(2.8,-.49)
        for x in (-2.6,-.1):
            box('AerationTank',(2.0,1.25,.34),(x,-2,.31),'concrete')
            add((1.82,1.06,.025),(x,-2,.49),'water')
            for off in (-.55,0,.55):add((.075,1.2,.075),(x+off,-2,.56),'metal')
        pipe([(-3.7,-.6,.27),(2.8,-.6,.27),(2.8,-1.7,.27)],.06)
    else:
        for x in (-1.65,0,1.65):transformer(x,0,1.05)
        for y in (-1.4,1.4):
            for x in (-2.15,2.15):beam((x,y,.14),(x,y,2.0),.075)
            beam((-2.15,y,2.0),(2.15,y,2.0),.08)
            for x in (-1.6,0,1.6):
                for zz in (1.5,1.6,1.7,1.8):cyl('SuspendedInsulator',.09,.035,(x,y,zz),'stone',12)
                beam((x,-1.4,1.45),(x,1.4,1.45),.012,'black')
        for xx in (-2.6,2.6):railing(xx,0,.02,4.9,.14)

def ellipse_ring(name,rx,ry,innerx,innery,z,h,key,n=96):
    vs=[]
    for a,b,zz in ((rx,ry,z),(rx,ry,z+h),(innerx,innery,z+h),(innerx,innery,z)):
        vs.extend((a*math.cos(k*math.tau/n),b*math.sin(k*math.tau/n),zz) for k in range(n))
    fs=[]
    for j in range(4):
        for k in range(n):fs.append((j*n+k,j*n+(k+1)%n,((j+1)%4)*n+(k+1)%n,((j+1)%4)*n+k))
    return mesh(name,vs,fs,key)

def goal(y):
    sign=1 if y>0 else -1;z=.24;back=y+sign*.35
    for xx in (-.55,.55):
        beam((xx,y,z),(xx,y,z+.58),.035,'white');beam((xx,back,z),(xx,back,z+.58),.025,'white');beam((xx,y,z+.58),(xx,back,z+.58),.025,'white')
    beam((-.55,y,z+.58),(.55,y,z+.58),.035,'white')
    for x in [-.55+i*.11 for i in range(11)]:
        beam((x,back,z),(x,back,z+.58),.005,'frame');beam((x,y,z+.58),(x,back,z+.58),.005,'frame')
    for zz in [z+i*.095 for i in range(7)]:
        beam((-.55,back,zz),(.55,back,zz),.005,'frame')
        for x in (-.55,.55):beam((x,y,zz),(x,back,zz),.005,'frame')

def stadium():
    # Elliptical bowl with separate stepped terraces, individual seats and radial aisles.
    ellipse_ring('Concourse',6.2,7.3,3.35,4.85,.14,.35,'concrete')
    for row in range(12):
        rx=3.43+row*.195;ry=4.94+row*.17;z=.50+row*.14
        ellipse_ring('Terrace',rx+.24,ry+.22,rx,ry,z,.12,'stone')
        for k in range(112):
            if k%14 in (0,1):continue
            a=k*math.tau/112;xx=(rx+.12)*math.cos(a);yy=(ry+.11)*math.sin(a);rot=Matrix.Rotation(a+math.pi/2,3,'Z')
            key='accent' if (k//14)%2==0 else 'paper'
            add((.13,.12,.035),(xx,yy,z+.15),key,rot)
            add((.13,.025,.11),(xx+.047*math.cos(a),yy+.047*math.sin(a),z+.20),key,rot)
    ellipse_ring('BowlFacade',6.0,7.08,5.83,6.91,.5,2.18,'wall')
    for k in range(48):
        a=k*math.tau/48;x=6.02*math.cos(a);y=7.10*math.sin(a);rot=Matrix.Rotation(a,3,'Z')
        add((.075,.26,.83),(x,y,1.0),'glass_dark',rot)
        beam((x,y,.15),(x,y,2.94),.085,'accent')
    ellipse_ring('Canopy',6.25,7.35,4.65,5.95,2.87,.12,'roof')
    ellipse_ring('CanopySkylight',5.12,6.42,4.78,6.08,3.0,.025,'greenhouse_glass')
    for k in range(40):
        a=k*math.tau/40
        beam((6.20*math.cos(a),7.30*math.sin(a),3.04),(4.64*math.cos(a),5.94*math.sin(a),3.04),.032,'metal')
    # Field geometry, touchlines, penalty areas, center and goals.
    for j in range(14):add((4.75,7.3/14,.018),(0,-3.65+(j+.5)*7.3/14,.205),'grass' if j%2 else 'grass_light')
    for x in (-2.375,2.375):beam((x,-3.65,.22),(x,3.65,.22),.028,'white')
    for y in (-3.65,0,3.65):beam((-2.375,y,.22),(2.375,y,.22),.028,'white')
    for k in range(48):
        a=k*math.tau/48;b=(k+1)*math.tau/48;beam((.66*math.cos(a),.66*math.sin(a),.22),(.66*math.cos(b),.66*math.sin(b),.22),.024,'white')
    for sign in (-1,1):
        goal(sign*3.65)
        for w,d in ((2.5,1.13),(1.25,.45)):
            y=sign*(3.65-d)
            beam((-w/2,y,.22),(w/2,y,.22),.025,'white')
            for x in (-w/2,w/2):beam((x,y,.22),(x,sign*3.65,.22),.025,'white')
        add((1.55,.1,.7),(0,sign*6.6,2.52),'black')
        for off in (-.4,.4):add((.35,.02,.35),(off,sign*6.53,2.52),'glass')
    for xx in (-4.8,4.8):
        for yy in (-5.6,5.6):
            beam((xx,yy,.14),(xx,yy,4.0),.1,'metal')
            for off in (-.24,0,.24):add((.18,.15,.2),(xx+off,yy,4.03),'window_warm')
    # Segmented collisions leave the pitch and concourse open.
    for xx in (-5.0,5.0):collision((1.9,9.2,2.7),(xx,0,1.49))
    for yy in (-6.0,6.0):collision((7.8,1.7,2.7),(0,yy,1.49))

def barrel(x,y,w,d,z,h,key='roof'):
    verts=[]
    for yy in (y-d/2,y+d/2):
        verts.extend((x-w/2+w*i/24,yy,z+h*math.sin(i*math.pi/24)) for i in range(25))
    mesh('BarrelRoof',verts,[(i,i+1,26+i,25+i) for i in range(24)],key)
    if key=='greenhouse_glass':
        for yy in (y-d/2,y+d/2):
            arch=[(x-w/2+w*i/24,yy,z+h*math.sin(i*math.pi/24)) for i in range(25)]
            mesh('GlassGable',arch,[tuple(range(25))],key)
            for i in range(1,12):
                xx=x-w/2+w*i/12
                beam((xx,yy,z),(xx,yy,z+h*math.sin(i*math.pi/12)),.017,'metal')
    for j in range(int(d/.4)+1):
        yy=y-d/2+j*.4
        for i in range(24):beam((x-w/2+w*i/24,yy,z+h*math.sin(i*math.pi/24)+.015),(x-w/2+w*(i+1)/24,yy,z+h*math.sin((i+1)*math.pi/24)+.015),.02,'metal')

def civics():
    recipe=S['recipe']
    if recipe=='stadium':stadium()
    elif recipe=='arena':
        body(0,.3,5.8,5.0,1.55,roof=False);barrel(0,.3,6.0,5.2,1.69,.9)
        body(0,-2.35,3.8,.65,.95,glazed=True)
        for x in (-2,-1,0,1,2):door(x,-2.24,w=.35,h=.72)
        for x in (-1.6,1.6):hvac(x,2.45,1.84)
    elif recipe=='fire':
        body(-.3,.5,3.9,2.8,1.45);body(1.9,.95,.8,1.25,3.1)
        for x in (-1.5,-.25,1):loading(x,-.95)
        for z in (.7,1.5,2.3):add((.50,.07,.42),(1.9,.29,z),'glass_dark')
        for x in (-1.5,-.25,1):add((.04,1.3,.012),(x,-1.8,.15),'road_line')
        hvac(-.6,.7,1.72)
    elif recipe=='library':
        body(-.25,.45,4.2,3.0,1.0,glazed=True);body(.4,.65,3.2,2.2,.9,1.14,glazed=True)
        for x in (-1.65,-.65,.35,1.35):add((.06,.8,1.0),(x,-1.3,.64),'accent')
        add((4.1,.8,.08),(-.2,-1.3,1.19),'stone')
        for x in (-.5,.6,1.5):solar(x,.7,2.33,.7,.7)
        tree(-2.2,1.7,scale=.7);bench(-1.2,-2.1);bench(1.0,-2.1)
    elif recipe=='station':
        body(0,-.9,4.8,1.6,1.45,roof=False);gable(0,-.9,4.8,1.6,1.59,.5)
        body(0,-1.25,1.0,.65,2.3)
        old.cylinder('Clock',.24,.035,(0,-1.60,2.03),'paper',32,(math.pi/2,0,0))
        beam((0,-1.63,2.03),(0,-1.63,2.21),.015,'black');beam((0,-1.63,2.03),(.12,-1.63,1.97),.015,'black')
        door(0,-1.76)
        for y in (.45,1.85):
            for x in [-4.6+i*.3 for i in range(32)]:add((.08,.8,.05),(x,y,.17),'wood')
            for yy in (-.28,.28):add((9.5,.035,.055),(0,y+yy,.22),'metal')
        add((9.5,.62,.18),(0,1.15,.2),'stone')
        add((8.6,.78,.055),(0,1.15,1.31),'roof')
        for x in (-3.7,-1.85,0,1.85,3.7):add((.05,.05,.98),(x,1.15,.81),'metal')
        for x in (-2.7,2.7):bench(x,1.15,.30)
    else:
        garden()
        for x,w,z,h in ((0,2.6,.95,.95),(-2,1.35,.7,.48),(2,1.35,.7,.48)):
            box('GlasshousePlinth',(w,4.8,.12),(x,0,.20),'stone')
            add((w,4.8,.7),(x,0,.6),'greenhouse_glass')
            barrel(x,0,w,4.8,z,h,'greenhouse_glass')
            for yy in [-2.4+i*.4 for i in range(13)]:
                for xx in (-w/2,w/2):beam((x+xx,yy,.26),(x+xx,yy,z),.027,'metal')
            for xx in (-w*.28,w*.28):
                for yy in (-1.6,-.8,0,.8,1.6):plant(x+xx,yy,.27,1.1,True)
        door(0,-2.46,h=.85,w=.55)

def generate(s):
    global S,RNG,COLLISION_COUNT
    S=s;RNG=random.Random(s['seed']);COLLISION_COUNT=0;BODIES.clear();r.DETAILS.clear();r.AUDIT.clear()
    old._reset_scene()
    # Cache must be reset so each building actually receives its own selected palette.
    for material in list(bpy.data.materials):bpy.data.materials.remove(material)
    for image in list(bpy.data.images):
        if image.name not in {'Render Result','Viewer Node'}:bpy.data.images.remove(image)
    wall,accent,roof=s['palette']
    r.PALETTE.update(wall=wall,accent=accent,roof=roof,trim='d1cbba',roof_edge=roof,flower=['bf8c94','c4a166','a782a9','b56e62'][s['seed']%4])
    r.TEXTURED.update({'wall','accent','roof','roof_edge','trim','flower'})
    fx,fy=s['footprint']
    box('LotBase',(2*fx-.08,2*fy-.08,.10),(0,0,.05),'sidewalk',.025)
    if s['group'] not in {'residenze','servizi'}:
        add((2*fx-.2,2*fy-.2,.018),(0,0,.109),'concrete' if s['group'] in {'industria','impianti'} else 'stone')
    if s['group']=='residenze':houses()
    elif s['group']=='citta':towers() if s['kind']=='tower' else apartments()
    elif s['group']=='negozi':shops()
    elif s['group']=='industria':factories()
    elif s['group']=='impianti':utilities()
    else:civics()
    bpy.context.view_layer.update()
    if BODIES:
        facade_spec=dict(s,kind='office' if s['kind']=='utility' else s['kind'])
        r.facades(facade_spec,BODIES)
    r.flush();bpy.context.view_layer.update();r.project_uv_and_normals()
    meta=base.finalize_and_export(s,OUT)
    meta.update(name=s['name'],group=s['group'],description=s['description'],recipe=s['recipe'],palette=s['palette'],
        style_variant='refined_v2',collection='refined_expansion',is_new_asset=True,collision_mode='simplified_component_boxes',collision_parts=max(1,COLLISION_COUNT),**r.AUDIT)
    (OUT/(s['id']+'.json')).write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return meta

def _catalogo_unito(path,nuovi):
    """Il catalogo della libreria, rimettendoci dentro i modelli appena rifatti.

    La libreria e' una sola e i generatori sono due, percio' nessuno dei due puo'
    riscrivere catalog.json partendo da zero: si porterebbe via i modelli
    dell'altro. Ognuno sostituisce le proprie voci dove stanno, lascia dove
    stanno quelle che non gli appartengono e accoda quelle mai viste, cosi'
    l'ordine del negozio non si rimescola a ogni rigenerazione e rigenerare un
    solo asset con --asset resta un'operazione innocua."""
    esistenti=json.loads(path.read_text(encoding='utf-8'))['assets'] if path.exists() else []
    da_mettere={a['id']:a for a in nuovi}
    unito=[da_mettere.pop(a['id'],a) for a in esistenti]
    return unito+[a for a in nuovi if a['id'] in da_mettere]


def main():
    p=argparse.ArgumentParser();p.add_argument('--asset',action='append');args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    OUT.mkdir(parents=True,exist_ok=True);PREVIEW.mkdir(parents=True,exist_ok=True)
    # OUT e' la libreria che il gioco importa: solo la galleria resta fuori da Godot.
    (PREVIEW/'.gdignore').touch()
    snapshot=PREVIEW/'existing_model_hashes.json'
    if not snapshot.exists():
        hashes={str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for folder in ('generated','realistic') for p in sorted((ROOT/'assets/models'/folder).glob('*')) if p.is_file()}
        snapshot.write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf-8')
    old.install_realistic_primitives();old.realistic_material=r.material;base.material=r.material;base.GENERATOR_VERSION=2100
    selected=[s for s in SPECS if not args.asset or s['id'] in args.asset]
    if args.asset and len(selected)!=len(set(args.asset)):raise ValueError('Unknown asset ID')
    catalog=[]
    for i,s in enumerate(selected):
        print(f'[EXPANSION] {i+1}/{len(selected)} {s["id"]}',flush=True);catalog.append(generate(s))
    path=OUT/'catalog.json'
    by_id={s['id']:s for s in SPECS}
    for a in catalog:
        for field in ('name','description'):a[field]=by_id[a['id']][field]
        a['collision_parts']=max(1,a['collision_parts'])
        (OUT/(a['id']+'.json')).write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    catalog=_catalogo_unito(path,catalog)
    path.write_text(json.dumps(dict(style_variant='refined_v2',grid_unit_meters=2.0,elevation_step_meters=0.5,assets=catalog),ensure_ascii=False,indent=2)+chr(10),encoding='utf-8')
    print('[EXPANSION] Complete',len(catalog),flush=True)

if __name__=='__main__':main()
