"""Recognizable civic architecture using the shared refined_v2 construction kit.

Front is -Y, one tile is two units. No lettering or external textures.
The original IDs/footprints remain valid; collisions follow the new volumes.
"""
import math


RECIPES = {'hospital', 'clinic', 'police_local', 'police_central',
           'fire_local', 'fire_central', 'fire', 'primary', 'secondary', 'university'}


def base_spec(s):
    """Adapt original civic specs without changing their gameplay identity."""
    if s['kind'] == 'school':
        recipe = s['variant']
        name = 'Scuola elementare' if recipe == 'primary' else 'Scuola superiore'
        palette = ['c9bea9', '748679', '865947']
    else:
        service = s['service']
        recipe = ('clinic' if s.get('variant') == 'clinic' else 'hospital') if service == 'health' else service + ('_central' if s.get('variant') == 'central' else '_local')
        name = {'hospital': 'Ospedale', 'clinic': 'Poliambulatorio',
                'fire_local': 'Caserma dei pompieri', 'fire_central': 'Comando dei pompieri',
                'police_local': 'Stazione di polizia', 'police_central': 'Questura'}[recipe]
        palette = {'health': ['dedbd1', '546d68', '747b79'],
                   'fire': ['b79c88', '91594d', '656863'],
                   'police': ['bbb9ae', '485b70', '656863']}[service]
    return dict(s, recipe=recipe, name=name, palette=palette, group='servizi',
                description='Architettura civica con volumi funzionali e dettagli riconoscibili.')


def build(e, s):
    b, a, beam = e.box, e.add, e.beam
    fx, fy = s['footprint']
    recipe = s['recipe']

    def cross(x, y, z, size=.42):
        b('HealthCross', (size, .055, size*.28), (x,y,z), 'coral', .01)
        b('HealthCross', (size*.28, .06, size), (x,y-.006,z), 'coral', .01)

    def canopy(x,y,w,d,z,key='accent'):
        b('EntranceCanopy',(w,d,.10),(x,y,z),key)
        for xx in (-w/2+.09,w/2-.09):
            a((.055,.055,z-.19),(x+xx,y-d/2+.1,(z+.09)/2),'metal')

    def flag(x,y,h=1.65):
        e.cyl('FlagBase',.11,.07,(x,y,.15),'stone',16)
        beam((x,y,.17),(x,y,h),.026)
        for i,key in enumerate(('teal','paper','coral')):
            a((.12,.018,.23),(x+.07+i*.12,y,h-.17),key)

    def clock(x,y,z,r=.22):
        e.old.cylinder('ClockRim',r+.035,.055,(x,y,z),'metal',32,(math.pi/2,0,0))
        e.old.cylinder('ClockFace',r,.065,(x,y-.015,z),'paper',32,(math.pi/2,0,0))
        for k in range(12):
            t=k*math.tau/12
            beam((x+math.sin(t)*r*.78,y-.055,z+math.cos(t)*r*.78),
                 (x+math.sin(t)*r*.90,y-.055,z+math.cos(t)*r*.90),.013,'navy')
        beam((x,y-.065,z),(x,y-.065,z+r*.65),.018,'navy')
        beam((x,y-.066,z),(x+r*.49,y-.066,z-r*.23),.019,'navy')

    def vehicle(x,y,kind):
        truck=kind=='fire'
        w,d,h=(.48,.86,.37) if truck else (.40,.70,.23)
        key='coral' if truck else 'paper'
        b('ResponseVehicle',(w,d,h),(x,y,.26+h/2),key,.045)
        b('VehicleCab',(w-.035,d*.39,.20),(x,y-d*.18,.28+h),'paper' if kind=='ambulance' else key,.035)
        a((w-.08,.025,.115),(x,y-d*.39,.33+h),'glass_dark')
        for xx in (-w/2,w/2):
            for yy in (-d*.29,d*.29):
                e.old.cylinder('Wheel',.105,.06,(x+xx,y+yy,.255),'black',16,(0,math.pi/2,0))
            a((.014,d*.65,.065),(x+xx,y,.37),'accent')
        a((w*.68,.08,.05),(x,y-d*.12,.405+h),'blue')
        if truck:
            for xx in (-.12,.12):beam((x+xx,y-.02,.70),(x+xx,y+.37,.70),.022,'metal')
            for yy in range(5):a((.25,.023,.023),(x,y+yy*.08,.70),'metal')
        for xx in (-w*.30,w*.30):a((.065,.025,.045),(x+xx,y-d/2-.012,.36),'paper')

    def garage(x,y,w=.86):
        b('GarageDoor',(w,.07,.91),(x,y,.60),'accent',.012)
        for zz in range(7):a((w-.06,.024,.017),(x,y-.049,.22+zz*.12),'metal')
        for xx in (-w*.27,0,w*.27):a((w*.22,.026,.16),(x+xx,y-.055,.77),'glass_dark')
        for xx in (-w/2-.045,w/2+.045):a((.085,.14,1.05),(x+xx,y,.66),'stone')
        a((w+.18,.14,.09),(x,y,1.20),'stone')

    def shield(x,y,z):
        points=[(-.23,.23),(.23,.23),(.20,-.08),(0,-.29),(-.20,-.08)]
        verts=[(x+u,y+off,z+v) for off in (0,.05) for u,v in points]
        e.mesh('PoliceShield',verts,[(4,3,2,1,0),(5,6,7,8,9)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)],'accent')
        a((.26,.025,.045),(x,y-.015,z+.05),'ochre')
        a((.045,.025,.23),(x,y-.016,z),'ochre')

    def lawn(x,y,w,d):
        b('GardenBed',(w,d,.055),(x,y,.13),'grass',.05)

    if recipe in {'hospital','clinic'}:
        if recipe=='hospital':
            # Open H-shaped wards and a taller diagnostic block behind the atrium.
            e.body(0,1.68,4.75,1.55,2.55)
            for x in (-1.72,1.72):e.body(x,-.12,1.30,2.95,1.90)
            e.body(0,.43,2.15,1.35,1.40,glazed=True)
            e.door(0,-.29,w=.70,h=.84)
            canopy(0,-.93,1.75,1.30,1.11)
            cross(0,.865,2.27,.59)
            # Rooftop landing pad with geometric H marking, on a supported slab.
            e.cyl('Helipad',.66,.065,(1.72,.40,2.22),'navy',48)
            for i in range(32):
                t=i*math.tau/32;u=(i+1)*math.tau/32
                beam((1.72+.55*math.cos(t),.40+.55*math.sin(t),2.258),
                     (1.72+.55*math.cos(u),.40+.55*math.sin(u),2.258),.025,'road_line')
            for xx in (-.15,.15):a((.045,.43,.01),(1.72+xx,.40,2.26),'road_line')
            a((.30,.045,.01),(1.72,.40,2.26),'road_line')
            e.hvac(-.7,1.75,2.91);e.hvac(.3,1.75,2.91)
            vehicle(.66,-1.95,'ambulance')
            for x in (-2.4,2.4):lawn(x,-2.1,.42,1.05);e.plant(x,-2.1,scale=1.0)
        else:
            e.body(-.57,.42,1.75,2.30,1.42)
            e.body(.90,.92,1.2,1.30,.90)
            e.body(.65,-.18,.95,.85,.86,glazed=True)
            e.door(.65,-.64,w=.5)
            canopy(.65,-.91,1.15,.70,.92)
            cross(-.55,-.75,1.10,.43)
            e.hvac(-.6,.8,1.75,.45)
            lawn(-1.15,-1.32,.9,.52);e.bench(-1.1,-1.28)
            vehicle(.95,-1.45,'ambulance')
        flag(-fx+.27,-fy+.4)

    elif recipe in {'fire','fire_local','fire_central'}:
        large=recipe!='fire_local'
        n=3 if large else 2
        front=-.68 if recipe!='fire' else -.83
        tower_x=fx-.62
        width=3.70 if large else 2.25
        center=-.50 if large else -.58
        e.body(center,.52,width,2.35,1.38)
        e.body(tower_x,.70,.79,1.50,2.95 if large else 2.52)
        for i in range(n):
            x=center+(i-(n-1)/2)*(1.15 if large else 1.05)
            garage(x,-.68)
            a((.035,.93,.013),(x-.46,-1.24,.13),'road_line')
        # Visibly recessed drying/exercise tower, roof parapet and external ladder.
        for z in (.55,1.27,1.99):
            b('GarageDoor',(.44,.075,.42),(tower_x,-.075,z),'glass_dark',.008)
            a((.54,.12,.055),(tower_x,-.10,z-.24),'stone')
        for xx in (-.18,.18):beam((tower_x+xx,1.49,.20),(tower_x+xx,1.49,2.65),.022)
        for k in range(13):a((.38,.025,.025),(tower_x,1.49,.25+k*.19),'metal')
        a((width,.07,.13),(center,-.69,1.43),'coral')
        canopy(tower_x,-.42,.74,.45,.93)
        e.door(tower_x,-.085,w=.38)
        vehicle(center-.10,-1.40,'fire')
        e.hvac(center,.7,1.70)
        if recipe=='fire':
            e.body(-.6,2.1,3.9,.75,.85)
            for x in (-1.6,-.4,.8):garage(x,1.70,.85)
            e.bench(1.6,-2.2);flag(2.55,-2.3)

    elif recipe in {'police_local','police_central'}:
        large=recipe=='police_central'
        w=3.35 if large else 2.75
        e.body(-.25,.65,w,2.15,1.78 if large else 1.43)
        e.body(-.65,.82,1.48,1.52,1.08,z=1.92 if large else 1.57)
        e.body(w/2-.22,.05,.90,1.60,.96)
        # Entrance projects out of the facade: stone portal and shielded attic.
        e.body(-.45,-.61,1.18,.48,1.22,roof=False)
        e.door(-.45,-.875,w=.62,h=.78)
        canopy(-.45,-1.02,1.56,.66,1.02,'stone')
        shield(-.45,-.88,1.30)
        a((w,.065,.12),(-.25,-.445,1.48 if not large else 1.85),'accent')
        flag(-fx+.32,-1.35,1.93)
        vehicle(fx-.69,-1.19,'police')
        for x in (-.99,.09):e.cyl('SecurityBollard',.045,.30,(x,-1.49,.29),'metal',12)
        z=3.15 if large else 2.8
        beam((-.65,1.1,z),(-.65,1.1,z+.62),.024)
        for zz in (.18,.36):beam((-.91,1.1,z+zz),(-.39,1.1,z+zz),.015)
        e.hvac(.55,.85,2.10 if large else 1.75,.45)
        lawn(-1.1,1.72,1.3,.25)

    elif recipe=='primary':
        # Low, sheltered U: tiled classroom roofs, entrance clock, play courtyard.
        e.body(0,1.40,4.65,1.40,1.32,roof=False)
        e.gable(0,1.4,4.65,1.40,1.46,.52)
        for x in (-1.78,1.78):
            e.body(x,-.03,1.10,2.2,.91,roof=False)
            e.gable(x,-.03,1.10,2.2,1.05,.38)
        e.body(0,.62,1.0,.48,1.70,roof=False)
        e.gable(0,.62,1.0,.48,1.84,.26)
        clock(0,.35,1.53,.18);e.door(0,.34,w=.56)
        canopy(0,-.02,1.20,.68,.99)
        lawn(-.65,-1.41,1.12,1.17)
        # A-frame swings with suspended seats.
        for xx in (-1.05,-.22):
            for yy in (-1.72,-1.11):beam((xx,yy,.17),(xx,-1.42,1.0),.045,'wood')
        beam((-1.12,-1.42,1.0),(-.15,-1.42,1.0),.055,'wood')
        for xx in (-.83,-.44):
            for dx in (-.08,.08):beam((xx+dx,-1.42,.97),(xx+dx,-1.42,.39),.012)
            a((.23,.16,.045),(xx,-1.42,.36),'accent')
        b('Sandbox',(.72,.65,.10),(.65,-1.49,.19),'wood')
        a((.61,.54,.02),(.65,-1.49,.25),'cream')
        for x in (-2.45,2.45):e.tree(x,2.35,scale=.43)
        for x in (-1.7,1.7):e.bench(x,-2.20)
        flag(-2.55,-2.15)

    elif recipe=='secondary':
        # Academic L and detached sports hall; court remains legible from above.
        e.body(-.3,1.55,6.25,1.65,2.05)
        e.body(-2.68,-.35,1.5,2.25,1.38)
        e.body(-.45,.59,1.35,.58,2.42,roof=False)
        clock(-.45,.27,2.18,.20)
        e.door(-.45,.27,w=.68,h=.83)
        canopy(-.45,-.10,1.65,.8,1.14)
        gym=e.body(2.60,-.53,1.70,2.60,1.02,roof=False);gym.name='Gym'
        e.barrel(2.6,-.53,1.80,2.70,1.16,.48)
        e.door(2.6,-1.87,w=.55,h=.72)
        b('SportsCourt',(2.8,1.88,.035),(-.35,-1.5,.14),'teal',.015)
        e.railing(-.35,-1.5,2.92,2.0,.16)
        for x in (-1.63,.93):a((.025,1.67,.008),(x,-1.5,.164),'road_line')
        for y in (-2.33,-.67):a((2.58,.025,.008),(-.35,y,.164),'road_line')
        a((2.58,.025,.008),(-.35,-1.5,.164),'road_line')
        for y in (-2.24,-.76):
            beam((-.35,y,.16),(-.35,y,.95),.025)
            a((.44,.035,.29),(-.35,y,.97),'paper')
            e.cyl('BasketRim',.10,.018,(-.35,y+(.15 if y< -1.5 else -.15),.83),'coral',20)
        for x in (-1.9,.9):e.hvac(x,1.65,2.36)
        flag(-3.6,-1.95);e.bench(-2.65,-2.15)

    elif recipe=='university':
        # Symmetric quadrangle, arcaded portico, pediment and copper cupola.
        e.body(0,2.34,7.8,1.62,2.42,roof=False)
        e.gable(0,2.34,7.8,1.62,2.56,.59)
        for x in (-3.15,3.15):
            e.body(x,.06,1.48,3.0,1.87,roof=False)
            e.gable(x,.06,1.48,3.0,2.01,.48)
        e.body(0,1.43,2.5,1.07,2.81,roof=False)
        e.door(0,.865,w=.82,h=1.07)
        # Deep porch with independent columns, bases and capitals.
        b('PorticoEntablature',(3.18,1.17,.20),(0,.37,1.75),'stone')
        for x in (-1.29,-.78,.78,1.29):
            e.cyl('Column',.080,1.31,(x,-.04,.91),'paper',20)
            for z in (.24,1.57):b('ColumnCapital',(.24,.24,.095),(x,-.04,z),'stone',.01)
        e.mesh('Pediment',[(-1.66,-.25,1.87),(1.66,-.25,1.87),(0,-.25,2.59),
                           (-1.66,.10,1.87),(1.66,.10,1.87),(0,.10,2.59)],
               [(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)],'wall')
        for x in (-1.66,1.66):beam((x,-.28,1.87),(0,-.28,2.59),.09,'stone')
        clock(0,-.29,2.13,.15)
        e.cyl('CupolaDrum',.53,.42,(0,1.66,3.04),'stone',32)
        for k in range(12):
            t=k*math.tau/12
            a((.08,.08,.30),(.47*math.cos(t),1.66+.47*math.sin(t),3.08),'paper')
        e.lathe('CopperDome',0,1.66,[(.58,3.24),(.55,3.36),(.43,3.52),(.24,3.65),(.08,3.69)],'accent',48,True)
        e.cyl('CupolaFinial',.035,.24,(0,1.66,3.80),'metal',16)
        for x in (-2.27,2.27):
            for y in (-1.1,-.35,.4,1.1):
                e.cyl('ArcadeColumn',.045,1.1,(x,y,.72),'stone',16)
            b('CloisterCanopy',(.45,3.0,.08),(x,.03,1.31),'stone')
        # A central walk between lawns leads straight to the columned entrance.
        a((1.05,3.3,.035),(0,-1.75,.135),'stone')
        for x in (-1.40,1.40):
            lawn(x,-1.05,1.30,1.36);e.bench(x,-2.15)
            e.tree(x,-1.05,scale=.46)
        for x in (-4.25,4.25):e.tree(x,2.45,scale=.62)
        flag(-2.4,-2.65,2.05)
    else:
        raise ValueError(recipe)

    e.r.AUDIT['architecture_revision'] = 'civic_v3'
