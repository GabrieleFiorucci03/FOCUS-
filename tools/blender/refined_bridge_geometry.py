"""Pure geometry for continuous bridge boundaries and mitered profiles.

Coordinates use the project convention: north=-Y, one tile=2 units.
Only exposed edges get a barrier. Connected tile boundaries remain open.
"""
import math

RAIL_CENTER=.665
DECK_HALF=.73
ROAD_HALF=.46
CURB_HALF=.0425
PORTS={'north':(1,0),'south':(1,2),'west':(0,1),'east':(2,1)}


def boundary_paths(connections):
    coords=(-1.,-RAIL_CENTER,RAIL_CENTER,1.)
    cells={(1,1)}|{PORTS[d] for d in connections}
    edges=[]
    for i,j in sorted(cells):
        x0,x1=coords[i:i+2];y0,y1=coords[j:j+2]
        for neighbor,a,b in (
            ((i,j-1),(x0,y0),(x1,y0)),
            ((i+1,j),(x1,y0),(x1,y1)),
            ((i,j+1),(x1,y1),(x0,y1)),
            ((i-1,j),(x0,y1),(x0,y0)),
        ):
            if neighbor in cells:continue
            # The only outline edges on +/-1 are the connection mouths.
            if any(abs(a[k])==1 and a[k]==b[k] for k in (0,1)):continue
            edges.append((a,b))
    outgoing=dict(edges);ends={b for _,b in edges};paths=[]
    for start in sorted(a for a,_ in edges if a not in ends):
        path=[start]
        while path[-1] in outgoing:path.append(outgoing.pop(path[-1]))
        simplified=[path[0]]
        for i in range(1,len(path)-1):
            a,b,c=path[i-1:i+2]
            cross=(b[0]-a[0])*(c[1]-b[1])-(b[1]-a[1])*(c[0]-b[0])
            if abs(cross)>1e-8:simplified.append(b)
        simplified.append(path[-1]);paths.append(simplified)
    assert not outgoing,'Untraced barrier outline'
    return paths


def grade(y,rise=0.,direction='up'):
    return rise*((y+1)/2 if direction=='up' else (1-y)/2)


def sweep(path,profile,rise=0.,direction='up'):
    """One watertight mesh per path, shared miter rings at every corner.

    Profile points are (horizontal offset, vertical height above the deck).
    The slope is evaluated at each vertex, so curb feet follow ramps exactly.
    """
    normals=[]
    for a,b in zip(path,path[1:]):
        dx,dy=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dy)
        normals.append((-dy/length,dx/length))
    vertices=[];faces=[];n=len(profile)
    for i,(x,y) in enumerate(path):
        if i==0:mx,my=normals[0]
        elif i==len(path)-1:mx,my=normals[-1]
        else:
            a,b=normals[i-1],normals[i];den=1+a[0]*b[0]+a[1]*b[1]
            assert den>1e-8,'Reversed boundary segment'
            mx,my=(a[0]+b[0])/den,(a[1]+b[1])/den
        for offset,z in profile:
            xx,yy=x+mx*offset,y+my*offset
            vertices.append((xx,yy,grade(yy,rise,direction)+z))
    for i in range(len(path)-1):
        for j in range(n):faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
    faces.extend([tuple(reversed(range(n))),tuple((len(path)-1)*n+j for j in range(n))])
    return vertices,faces


def post_positions(path):
    """Single corner posts; tile ends use continuous rails without duplicates."""
    points=set(path[1:-1])
    for a,b in zip(path,path[1:]):
        length=math.dist(a,b);count=max(1,math.ceil(length/.48))
        for i in range(count):
            t=(i+.5)/count
            points.add((round(a[0]+(b[0]-a[0])*t,6),round(a[1]+(b[1]-a[1])*t,6)))
    return sorted(points)


def picket_positions(path,posts):
    points=[]
    for a,b in zip(path,path[1:]):
        length=math.dist(a,b);count=max(1,math.ceil(length/.105))
        for i in range(count):
            t=(i+.5)/count;p=(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)
            if min(math.dist(p,q) for q in posts)>.043:points.append(p)
    return points
