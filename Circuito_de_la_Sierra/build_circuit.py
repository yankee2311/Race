"""Circuito de la Sierra — Blender 4.5 LTS.
Run: blender --background --python build_circuit.py
All geometry and textures are generated locally. No external assets required.
"""
import bpy, math, json, os, sys, random
from pathlib import Path
import numpy as np
from mathutils import Vector
BASE=Path(__file__).resolve().parent
random.seed(77)
rng=np.random.default_rng(77)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name!='Collection': bpy.data.collections.remove(c)
scene=bpy.context.scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.render.resolution_x=1800;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
COL={}
for key in ['01_TRACK_CHUNKS','02_RUNOFF','03_BARRIERS','04_PIT_COMPLEX','05_GRANDSTAND','06_LANDSCAPE','07_PROPS','90_EDITABLE_GUIDE','99_PRESENTATION']:
    c=bpy.data.collections.new(key);scene.collection.children.link(c);COL[key]=c

def link(obj,col):
    COL[col].objects.link(obj);return obj

def mat(name,color,rough=.7,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
    return m
M={
'asphalt':mat('Asphalt_PBR',(0.065,.072,.08),.92),
'white':mat('Paint_Ivory',(.88,.88,.79),.42),
'red':mat('Kerb_Racing_Red',(.63,.032,.018),.45),
'gravel':mat('Gravel_PBR',(.43,.30,.16),.96),
'earth':mat('Sierra_Sandstone',(.32,.23,.125),.97),
'concrete':mat('Concrete',(.44,.46,.43),.85),
'metal':mat('Galvanized_Metal',(.23,.28,.29),.37,.7),
'dark':mat('Graphite',(.026,.038,.045),.64),
'glass':mat('Smoked_Blue_Glass',(.045,.16,.20),.18,.4),
'teal':mat('Sierra_Teal',(.015,.27,.29),.48),
'orange':mat('Sierra_Copper',(.87,.16,.025),.46),
'rubber':mat('Rubber',(.012,.015,.017),.97),
'green':mat('Desert_Sage',(.12,.17,.067),.95),
'rock':mat('Rock_Ochre',(.31,.21,.12),1),
}

def image_file(name,pixels,data=False):
    n=pixels.shape[0]; im=bpy.data.images.new(name,width=n,height=n,alpha=False)
    if data:im.colorspace_settings.name='Non-Color'
    rgba=np.ones((n,n,4),dtype=np.float32);rgba[:,:,:3]=pixels if pixels.ndim==3 else pixels[:,:,None]
    im.pixels.foreach_set(rgba.ravel());im.filepath_raw=str(BASE/'textures'/f'{name}.png');im.file_format='PNG';im.save();im.pack();return im

def texture_material(m,prefix,color,n=512,normal_strength=.65):
    # Seamless periodic noise, shared height field -> physical normal map.
    a=rng.random((n,n))
    for k in range(2):a=(a+np.roll(a,1,0)+np.roll(a,-1,0)+np.roll(a,1,1)+np.roll(a,-1,1))/5
    a=(a-a.min())/(a.max()-a.min())
    base=np.clip(np.array(color)[None,None,:]*(.72+.55*a[:,:,None]),0,1)
    im=image_file(prefix+'_basecolor',base)
    nodes=m.node_tree.nodes;links=m.node_tree.links;bs=nodes.get('Principled BSDF')
    t=nodes.new('ShaderNodeTexImage');t.image=im;links.new(t.outputs['Color'],bs.inputs['Base Color'])
    orm=np.ones((n,n,3),np.float32);orm[:,:,1]=.78+.21*a;orm[:,:,2]=0
    im=image_file(prefix+'_orm',orm,True);t=nodes.new('ShaderNodeTexImage');t.image=im
    sep=nodes.new('ShaderNodeSeparateColor');links.new(t.outputs['Color'],sep.inputs['Color']);links.new(sep.outputs['Green'],bs.inputs['Roughness']);links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    dx=np.roll(a,-1,1)-np.roll(a,1,1);dy=np.roll(a,-1,0)-np.roll(a,1,0)
    nor=np.stack((-dx*normal_strength,-dy*normal_strength,np.ones_like(a)),axis=2);nor/=np.linalg.norm(nor,axis=2)[:,:,None]
    im=image_file(prefix+'_normal',nor*.5+.5,True);t=nodes.new('ShaderNodeTexImage');t.image=im
    nm=nodes.new('ShaderNodeNormalMap');links.new(t.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bs.inputs['Normal'])
texture_material(M['asphalt'],'asphalt',(0.095,.105,.115),1024,.55)
texture_material(M['gravel'],'gravel',(.49,.37,.23),512,1.4)

class Builder:
    def __init__(self):self.v=[];self.f=[];self.mi=[]
    def face(self,verts,mi=0):
        b=len(self.v);self.v.extend([tuple(v) for v in verts]);self.f.append(tuple(range(b,b+len(verts))));self.mi.append(mi)
    def box(self,center,size,mi=0,angle=0):
        cx,cy,cz=center;sx,sy,sz=np.array(size)/2;c=math.cos(angle);s=math.sin(angle)
        v=[(cx+c*x-s*y,cy+s*x+c*y,cz+z) for x,y,z in [(-sx,-sy,-sz),(sx,-sy,-sz),(sx,sy,-sz),(-sx,sy,-sz),(-sx,-sy,sz),(sx,-sy,sz),(sx,sy,sz),(-sx,sy,sz)]]
        b=len(self.v);self.v.extend(v)
        for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:self.f.append(tuple(b+i for i in f));self.mi.append(mi)
    def beam(self,a,b,width,mi=0):
        a=Vector(a);b=Vector(b);z=(b-a).normalized();x=z.cross(Vector((0,0,1)))
        if x.length<.01:x=Vector((1,0,0))
        x.normalize();x*=width/2;y=z.cross(x).normalized()*width/2
        vv=[p+x*s+y*t for p in [a,b] for s,t in [(-1,-1),(1,-1),(1,1),(-1,1)]]
        k=len(self.v);self.v.extend([tuple(p) for p in vv])
        for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:self.f.append(tuple(k+i for i in f));self.mi.append(mi)
    def ring(self,center,r=.49,h=.45,mi=0):
        # Hollow low-poly tire, stacked in trackside buffers.
        cx,cy,cz=center;n=8;b=len(self.v)
        for z,rad in [(0,r),(h,r),(h,r*.55),(0,r*.55)]:
            for i in range(n):
                t=i*2*math.pi/n;self.v.append((cx+rad*math.cos(t),cy+rad*math.sin(t),cz+z))
        for k in range(4):
            for i in range(n):self.f.append((b+k*n+i,b+k*n+(i+1)%n,b+((k+1)%4)*n+(i+1)%n,b+((k+1)%4)*n+i));self.mi.append(mi)
    def object(self,name,mats,col,smooth=False):return mesh(name,self.v,self.f,mats,col,self.mi,smooth=smooth)

def mesh(name,v,f,mats,col,indices=None,uv=None,smooth=False):
    me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();o=link(bpy.data.objects.new(name,me),col)
    for m in mats:me.materials.append(m)
    if indices:
        for p,i in zip(me.polygons,indices):p.material_index=i
    if smooth:
        for p in me.polygons:p.use_smooth=True
    layer=me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        for li in p.loop_indices:
            vi=me.loops[li].vertex_index;co=me.vertices[vi].co
            layer.data[li].uv=uv[vi] if uv is not None else (co.x/12,co.y/12)
    return o

def text_obj(body,pos,size,material,col='04_PIT_COMPLEX',rot=(math.pi/2,0,0)):
    cu=bpy.data.curves.new('Sign_'+body,'FONT');cu.body=body;cu.align_x='CENTER';cu.size=size;cu.extrude=.015;cu.space_character=1.15
    o=link(bpy.data.objects.new('Sign_'+body,cu),col);o.location=pos;o.rotation_euler=rot;cu.materials.append(material)
    bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False);return o

# Exact cubic Bezier guide. Sample in arc length; 0.5m kerbs, 2m asphalt.
design=json.loads((BASE/'design.json').read_text());P=np.array(design['nodes']);L=np.array(design['handle_left']);R=np.array(design['handle_right'])
dense=[];t=np.linspace(0,1,1000,endpoint=False)[:,None]
for i in range(len(P)):
    j=(i+1)%len(P);dense.append((1-t)**3*P[i]+3*(1-t)**2*t*R[i]+3*(1-t)*t*t*L[j]+t**3*P[j])
dense=np.vstack(dense+[P[:1]]);ds=np.r_[0,np.cumsum(np.linalg.norm(np.diff(dense,axis=0),axis=1))]
S=np.linspace(0,4200,8401);C=np.array([np.interp(S,ds,dense[:,j]) for j in range(3)]).T
C[-1]=C[0]
T=np.gradient(C,axis=0);T/=np.linalg.norm(T,axis=1)[:,None];T[-1]=T[0]
N=np.stack((-T[:,1],T[:,0],np.zeros(len(T))),axis=1);N/=np.linalg.norm(N,axis=1)[:,None]
heading=np.unwrap(np.arctan2(T[:,1],T[:,0]));curv=np.gradient(heading,.5)
# Positive left turn: outer (right) edge rises. Smooth, saturated banking 8%.
bank=-.08*np.tanh(curv*270)
bank[:1801]=0;bank[-1]=bank[0]
for _ in range(20):bank=(np.roll(bank,1)+bank+np.roll(bank,-1))/3
bank[0]=bank[-1]=0

def sample(s,off=0,z=0):
    a=float(s)%4200;i=min(int(a*2),8399);u=a*2-i
    c=C[i]*(1-u)+C[i+1]*u;n=N[i]*(1-u)+N[i+1]*u;b=bank[i]*(1-u)+bank[i+1]*u
    p=c+n*off;p[2]+=off*b+z;return p

def runoff_edge(s,side):
    # Continuous width through inflections, avoiding steps in barriers.
    k=min(int((s%4200)*2),8399)
    return side*(22.5-5.5*math.tanh(side*curv[k]*300))

def strip(name,stations,offsets,mats,col,z=0,indices=None):
    v=[];uv=[]
    for s in stations:
        for off in offsets:
            d=off(s) if callable(off) else off;p=sample(s,d,z);v.append(p);uv.append((d/5,s/5))
    w=len(offsets);f=[]
    for i in range(len(stations)-1):
        for j in range(w-1):a=i*w+j;f.append((a,a+w,a+w+1,a+1))
    return mesh(name,v,f,mats,col,indices,uv,smooth=True)

# Master curve and editable Array/Curve mesh remain hidden to avoid z-fighting.
cu=bpy.data.curves.new('Sierra_Centerline_Bezier','CURVE');cu.dimensions='3D';cu.resolution_u=64;cu.twist_mode='Z_UP'
sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(P)-1);sp.use_cyclic_u=True
for i,b in enumerate(sp.bezier_points):
    b.co=P[i];b.handle_left_type='FREE';b.handle_right_type='FREE';b.handle_left=L[i];b.handle_right=R[i];b.tilt=float(bank[np.argmin(np.linalg.norm(C-P[i],axis=1))])
guide=link(bpy.data.objects.new('EDIT_Centerline_Bezier',cu),'90_EDITABLE_GUIDE')
master=mesh('EDIT_Asphalt_Array_Curve',[(0,-7,0),(2,-7,0),(2,7,0),(0,7,0)],[(0,1,2,3)],[M['asphalt'],M['white'],M['red']],'90_EDITABLE_GUIDE')
arr=master.modifiers.new('01_Array_Fit_Circuit','ARRAY');arr.fit_type='FIT_CURVE';arr.curve=guide;arr.relative_offset_displace=(1,0,0);arr.use_merge_vertices=True
mod=master.modifiers.new('02_Curve_Tilt_Elevation','CURVE');mod.object=guide;mod.deform_axis='POS_X'
master['note']='Non-destructive design master; export meshes are separate sampled 300m chunks.'
COL['90_EDITABLE_GUIDE'].hide_render=True;COL['90_EDITABLE_GUIDE'].hide_viewport=True

# Ribbon geometry and bank-continuous boundaries.
for chunk in range(14):
    a=chunk*300;b=(chunk+1)*300;ss=np.linspace(a,b,151)
    road=strip(f'Track_Asphalt_{chunk:02d}-col',ss,[-7,-3.5,0,3.5,7],[M['asphalt'],M['white'],M['red']],'01_TRACK_CHUNKS')
    road['surface']='asphalt';road['chainage_start_m']=a;road['length_m']=300
    for side in [-1,1]:
        strip(f'Edge_Paint_{chunk:02d}_{side}',ss,[side*6.70,side*6.85] if side>0 else [side*6.85,side*6.70],[M['white']],'01_TRACK_CHUNKS',.018)
        # Entire curve outer runoff and narrower inner runoff. Straight has compact apron.
        def edge(s,side=side):
            return runoff_edge(s,side)
        offs=[-8.5,edge] if side<0 else [8.5,edge]
        if side<0:offs=[edge,-8.5]
        strip(f'Gravel_{chunk:02d}_{side}-col',ss,offs,[M['gravel']],'02_RUNOFF',-.10)
        # Earth embankment closes the road platform into the landscape.
        vv=[];ff=[]
        for s in ss:
            e=edge(s)
            for off,zz in [(e,-.1),(e+side*5,-.8),(e+side*12,-2.2)]:
                vv.append(sample(s,off,zz))
        for i in range(len(ss)-1):
            for j in range(2):
                q=(i*3+j,(i+1)*3+j,(i+1)*3+j+1,i*3+j+1)
                ff.append(q if side>0 else tuple(reversed(q)))
        mesh(f'Embankment_{chunk:02d}_{side}-col',vv,ff,[M['rock']],'02_RUNOFF',smooth=True)
    if chunk>=3:
        ss2=np.linspace(a,b,1201)
        for side in [-1,1]:
            v=[];uv=[];f=[];mi=[]
            for s in ss2:
                ridge=.055*(.5+.5*math.cos(s*2*math.pi/.5))
                for off,zz in [(side*7,.015),(side*7.18,.06),(side*8.25,ridge+.06),(side*8.5,0)]:v.append(sample(s,off,zz));uv.append((off,s/4))
            for i in range(len(ss2)-1):
                for j in range(3):
                    ids=(i*4+j,(i+1)*4+j,(i+1)*4+j+1,i*4+j+1)
                    f.append(ids if side>0 else tuple(reversed(ids)));mi.append(int((a+i*.25)//3)%2)
            mesh(f'Kerb_{chunk:02d}_{side}-col',v,f,[M['red'],M['white']],'01_TRACK_CHUNKS',mi,uv)
    # Concrete containment and fences, batched by 300m spatial chunk.
    wall=Builder();fence=Builder();tires=Builder()
    for s in np.arange(a,b,6):
        if s<900:continue # pit/grandstand receive dedicated straight barriers
        for side in [-1,1]:
            outer=side*curv[int(s*2)]<0;off=runoff_edge(s,side)-side*.4
            p=sample(s,off,-.1);q=sample(s+6,runoff_edge(s+6,side)-side*.4,-.1);mid=(p+q)/2
            angle=math.atan2(q[1]-p[1],q[0]-p[0]);wall.box(mid+(0,0,.65),(6.05,.5,1.3),0,angle)
            fence.beam(p+(0,0,1.3),p+(0,0,4),.09)
            for z in [1.5,2.2,3,3.8]:fence.beam(p+(0,0,z),q+(0,0,z),.035)
            fence.beam(p+(0,0,1.4),q+(0,0,3.8),.025)
            if outer and (s>2900 or 930<s<1150):
                for t in [0,1,2,3,4,5]:
                    loc=sample(s+t,off-side*.85)
                    for row in range(2):tires.ring(loc+(0,0,row*.45-.1),mi=int(s//12)%2)
    if wall.v:wall.object(f'Wall_{chunk:02d}-col',[M['concrete']],'03_BARRIERS')
    if fence.v:fence.object(f'Fence_{chunk:02d}',[M['metal']],'03_BARRIERS')
    if tires.v:tires.object(f'Tire_Buffer_{chunk:02d}',[M['rubber'],M['white']],'03_BARRIERS')
print('TRACK COMPLETE',flush=True)

# Terrain is lowered beneath track and apron; smooth engineered platform around pits.
coarse=C[::8];cn=N[::8];cb=bank[::8]
def terrain_height(xy,return_distance=False):
    xy=np.array(xy);out=[];distances=[]
    for k in range(0,len(xy),1000):
        q=xy[k:k+1000];d2=((q[:,None,:]-coarse[None,:,:2])**2).sum(2);idx=d2.argmin(1);d=np.sqrt(d2[np.arange(len(q)),idx]);delta=q-coarse[idx,:2]
        near=coarse[idx,2]+(delta*cn[idx,:2]).sum(1)*cb[idx]-1.5
        x=q[:,0];y=q[:,1]
        hills=25+48*np.sin(x/320+.8)*np.cos(y/240)+28*np.sin(x/150+y/220)
        hills+=210*np.exp(-((y-870)/380)**2)+155*np.exp(-((x+1200)/380)**2)+170*np.exp(-((x-1000)/410)**2)
        hills+=18*np.sin(x/41)*np.cos(y/57)+8*np.sin(x/17+y/23)
        blend=np.clip((d-42)/110,0,1);blend=blend*blend*(3-2*blend)
        h=near*(1-blend)+hills*blend
        # Paddock and seating terrace on the main straight.
        f=np.clip((np.abs(x)-360)/40,0,1);g=np.clip((np.abs(y+323)-85)/35,0,1);pl=np.maximum(f,g);h=10.2*(1-pl)+h*pl
        out.extend(h);distances.extend(d)
    return (np.array(out),np.array(distances)) if return_distance else np.array(out)

# 36 independent landscape patches, about 60k triangles total.
for ix in range(6):
    for iy in range(6):
        xs=np.linspace(-1500+ix*450,-1500+(ix+1)*450,33);ys=np.linspace(-1100+iy*450,-1100+(iy+1)*450,33)
        xx,yy=np.meshgrid(xs,ys);xy=np.c_[xx.ravel(),yy.ravel()];zz=terrain_height(xy);v=np.c_[xy,zz]
        f=[]
        for j in range(32):
            for i in range(32):k=j*33+i;f.extend([(k,k+1,k+34),(k,k+34,k+33)])
        o=mesh(f'Terrain_{ix}_{iy}-col',v,f,[M['earth']],'06_LANDSCAPE',smooth=True)
        # Baked vertex color provides broad mineral variation, exported to glTF.
        attr=o.data.color_attributes.new(name='Sierra_Tones',type='FLOAT_COLOR',domain='POINT')
        for k,(x,y,z) in enumerate(v):
            f=.86+.16*math.sin(x/53)*math.cos(y/67)+.12*math.sin(z/11)
            attr.data[k].color=(.45*f,.33*f,.19*f,1)
M['earth'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.45,.33,.19,1)
vcol=M['earth'].node_tree.nodes.new('ShaderNodeVertexColor');vcol.layer_name='Sierra_Tones';M['earth'].node_tree.links.new(vcol.outputs['Color'],M['earth'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'])

# Pit lane tapers into the main straight with an unobstructed entry/exit.
v=[];f=[]
for i,x in enumerate(np.linspace(-420,430,171)):
    if x<-330:u=(x+420)/90;off=26*(u*u*(3-2*u))
    elif x>340:u=(430-x)/90;off=26*(u*u*(3-2*u))
    else:off=26
    for y in [-300-off-4,-300-off+4]:v.append((x,y,12.025))
for i in range(170):f.append((2*i,2*i+2,2*i+3,2*i+1))
mesh('PitLane_Asphalt-col',v,f,[M['asphalt']],'04_PIT_COMPLEX')
b=Builder();b.box((-5,-358,11.6),(690,58,.7));b.object('Paddock_Apron-col',[M['concrete']],'04_PIT_COMPLEX')
b=Builder();b.box((-5,-314.5,12.7),(655,.6,1.4));b.box((-20,-284.5,12.7),(830,.6,1.4));b.object('Pit_Safety_Walls-col',[M['concrete']],'03_BARRIERS')
# Modular garages, steel doors, slim roof, upper gallery.
b=Builder();details=Builder()
for i in range(26):
    x=-310+i*24
    b.box((x,-359,16),(23.5,25,8),0);b.box((x,-358,20.5),(24,29,1),1)
    details.box((x,-346.42,15.2),(17,.15,5.9),0)
    details.box((x,-346.3,18.8),(20,.16,1),1)
    details.box((x-10.5,-346.1,16),(1,.8,8),2)
    for z in np.arange(12.7,18,.65):details.box((x,-346.25,z),(17,.1,.04),2)
    text_obj(f'{i+1:02d}',(x,-346.05,19),.75,M['white'],rot=(math.pi/2,0,math.pi))
    # Pit stall markings on apron, oriented toward travel.
    details.box((x,-337,12.07),(19,.12,.03),3)
    details.box((x-9.5,-333,12.07),(.12,8,.03),3)
b.object('Garage_Modules-col',[M['white'],M['dark']],'04_PIT_COMPLEX');details.object('Garage_Facades',[M['glass'],M['teal'],M['metal'],M['white']],'04_PIT_COMPLEX')
b=Builder();b.box((45,-375,25),(32,23,26),0);b.box((45,-374,39),(38,29,3),1);b.box((45,-375,35),(32.3,23.3,6),2);b.box((45,-375,41),(40,31,1),1)
b.object('Race_Control-col',[M['concrete'],M['dark'],M['glass']],'04_PIT_COMPLEX')
text_obj('SIERRA / RACE CONTROL',(45,-387,29),1.25,M['white'])
# Grandstand with tapered cantilever roof. Three actual geometry levels.
for lod in range(3):
    b=Builder();seat=Builder();length=340
    if lod<2:
        for row in range(9):
            y=-263+row*2.7;z=12+row*1.1
            b.box((-75,y,(z+11)/2),(length,2.8,z-11+1.1),0)
            if lod==0:
                for x in np.arange(-240,95,1.25):
                    if abs((x+240)%42-21)<2.5:continue
                    seat.box((x,y,z+.75),(.85,.9,.25),0 if (int(x//42)+row)%3 else 1)
                    seat.box((x,y+.42,z+1.1),(.85,.12,.65),0 if (int(x//42)+row)%3 else 1)
        for x in np.arange(-240,110,28):
            b.beam((x,-236,11),(x,-236,31),.65,1);b.beam((x,-236,31),(x,-269,27),.55,1)
        b.face([(-252,-271,27),(102,-271,27),(102,-232,32),(-252,-232,32)],2)
        b.face([(-252,-271,27),(-252,-271,27.6),(102,-271,27.6),(102,-271,27)],3)
    else:
        b.box((-75,-251,17),(340,26,10),0);b.box((-75,-251,28),(354,39,1),2)
    o=b.object(f'Grandstand_LOD{lod}',[M['concrete'],M['metal'],M['dark'],M['orange']],'05_GRANDSTAND')
    if seat.v:seat.object('Seats_LOD0',[M['teal'],M['white']],'05_GRANDSTAND')
    o.hide_render=lod>0;o.hide_set(lod>0)
# Start / finish line, staggered grid, gantry.
b=Builder()
for row in range(2):
    for j in range(28):b.box((-185+row*.5,-306.75+j*.5,12.035),(.5,.5,.03),(j+row)%2)
for i in range(24):
    x=-210-i*8;y=-303 if i%2 else -297;b.box((x,y,12.04),(.15,2.4,.03),0);b.box((x+2,y-1.2,12.04),(4,.13,.03),0)
b.object('Start_Finish_Grid',[M['white'],M['dark']],'01_TRACK_CHUNKS')
b=Builder()
for y in [-312,-288]:b.box((-183,y,18),(.9,.9,12),0)
b.box((-183,-300,24),(1.5,27,3.2),1)
b.object('Timing_Gantry-col',[M['metal'],M['dark']],'04_PIT_COMPLEX')
text_obj('CIRCUITO DE LA SIERRA',(-184,-300,23.5),1.12,M['white'],rot=(math.pi/2,0,-math.pi/2))
# Brake boards for approach to hairpin.
for dist in [150,100,50]:
    s=900-dist;p=sample(s,11,.9);b=Builder();b.box(p,(1.6,.15,1.8));b.object(f'Brake_Board_{dist}',[M['white']],'07_PROPS');text_obj(str(dist),p+(-.81,0,-.25),.6,M['dark'],rot=(math.pi/2,0,-math.pi/2))
print('FACILITIES COMPLETE',flush=True)

# Interpolate the actual terrain triangles so small props rest on the mesh.
def terrain_surface(xy):
    xy=np.array(xy);step=450/32
    local=(xy-np.array([-1500,-1100]))/step
    cell=np.floor(local);uv=local-cell;corner=cell*step+np.array([-1500,-1100])
    h00=terrain_height(corner);h10=terrain_height(corner+[step,0])
    h01=terrain_height(corner+[0,step]);h11=terrain_height(corner+[step,step])
    u=uv[:,0];v=uv[:,1]
    return np.where(u>=v,h00+(h10-h00)*u+(h11-h10)*v,h00+(h11-h01)*u+(h01-h00)*v)-.2

# Natural scatter, low polygon rock and sage clusters by terrain patch.
for group in range(12):
    rocks=Builder();shrubs=Builder()
    xy=np.c_[rng.uniform(-1300,1000,100),rng.uniform(-850,1350,100)];_,dist=terrain_height(xy,True);heights=terrain_surface(xy)
    for (x,y),z,d in zip(xy,heights,dist):
        if d<42 or (-520<x<520 and -440<y<-200):continue
        radius=random.uniform(1.2,5.5)
        if random.random()<.5:
            # Irregular faceted boulder, no physics on tiny scenery.
            n=7;v=[]
            for k in range(n):
                t=k*2*math.pi/n;v.append((x+math.cos(t)*radius,y+math.sin(t)*radius,z))
            top=(x+radius*.2,y-radius*.1,z+radius*.85)
            for k in range(n):rocks.face([v[k],v[(k+1)%n],top])
        else:
            for l in range(3):
                r=radius*(1-l*.24);zz=z+l*radius*.42
                n=6;top=(x,y,zz+radius*.7)
                for k in range(n):
                    t=k*2*math.pi/n;t2=(k+1)*2*math.pi/n
                    shrubs.face([(x+r*math.cos(t),y+r*math.sin(t),zz),(x+r*math.cos(t2),y+r*math.sin(t2),zz),top])
    if rocks.v:rocks.object(f'Rocks_{group:02d}',[M['rock']],'07_PROPS')
    if shrubs.v:shrubs.object(f'Sage_{group:02d}',[M['green']],'07_PROPS')

# Save the AI guide in Godot coordinates (Blender X,Y,Z -> Godot X,Z,-Y).
path=[]
for s in np.arange(0,4200,5):
    p=sample(s,0,.2);path.append([round(float(p[0]),5),round(float(p[2]),5),round(float(-p[1]),5)])
(BASE/'godot/assets/centerline.json').write_text(json.dumps({'closed':True,'length_m':4200,'points':path},separators=(',',':')))
# Presentation sun and cameras are intentionally excluded from GLB.
world=bpy.data.worlds.new('Sierra_Daylight');world.use_nodes=True;scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.48,.64,.8,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45
ld=bpy.data.lights.new('Sun','SUN');ld.energy=3;ld.angle=math.radians(8);sun=link(bpy.data.objects.new('Sun',ld),'99_PRESENTATION');sun.rotation_euler=(.48,-.55,-.65)

def camera(name,loc,target,lens=45,ortho=None):
    data=bpy.data.cameras.new(name);o=link(bpy.data.objects.new(name,data),'99_PRESENTATION');o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();data.lens=lens;data.clip_end=10000
    if ortho:data.type='ORTHO';data.ortho_scale=ortho
    return o
cam=camera('Overview',(-1400,-1810,1740),(-80,135,40),ortho=2010)
cam2=camera('Pit_Lane_View',(-440,-282,62),(-70,-344,17),lens=45)
cam3=camera('Mountain_Sector',(690,55,248),(250,205,85),lens=38)
scene.camera=cam
scene.world.color=(.4,.5,.6)
# Object origins improve visibility ranges and per-mesh culling.
for o in list(bpy.data.objects):
    if o.type=='MESH' and not o.name.startswith('EDIT_'):
        coords=np.array([v.co[:] for v in o.data.vertices]);center=(coords.min(0)+coords.max(0))/2
        for v in o.data.vertices:v.co-=Vector(center)
        o.location+=Vector(center)
# Expose useful startup viewport in saved Blender file.
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.clip_end=10000;area.spaces.active.region_3d.view_distance=1700;area.spaces.active.region_3d.view_location=Vector((-80,100,20));area.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion();area.spaces.active.shading.type='MATERIAL'
# Metadata + useful guide embedded in the .blend.
scene['Circuit']='Circuito de la Sierra';scene['Length_m']=4200;scene['Main_straight_m']=900;scene['Max_banking_percent']=8;scene['Version']='1.0.0'
info=bpy.data.texts.new('LEEME_CIRCUITO');info.write('Circuito de la Sierra | 4.2 km | Blender 4.5 LTS\n14 chunks de 300 m. 14 m de ancho. Desnivel 120 m.\n90_EDITABLE_GUIDE: curva Bezier y master Array + Curve (ocultos).\nLos chunks de exportación son independientes del master.\nCambiar el master no actualiza los chunks: usa design.json + build_circuit.py.\n99_PRESENTATION: cámaras y luz sólo para Blender.\nLOD1 y LOD2 están ocultos en Blender; Godot controla sus distancias.\nVer README.md para límites y uso.\n')
# Export all real geometry, incl alternate LODs, without cameras/lights/editor guide.
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type=='MESH' and not o.name.startswith('EDIT_'):o.hide_set(False);o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(BASE/'godot/assets/Circuito_de_la_Sierra.glb'),export_format='GLB',use_selection=True,export_apply=True,export_texcoords=True,export_normals=True,export_tangents=True,export_cameras=False,export_lights=False,export_extras=True,export_yup=True,export_materials='EXPORT')
for o in bpy.data.objects:
    if 'LOD1' in o.name or 'LOD2' in o.name:o.hide_set(True)
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active=guide
# Aggregate check report.
triangles=sum(len(p.vertices)-2 for o in bpy.data.objects if o.type=='MESH' and not o.name.startswith('EDIT_') for p in o.data.polygons)
report={'version':'1.0.0','blender':bpy.app.version_string,'length_m':float(ds[-1]),'main_straight_m':900,'width_m':14,'elevation_min_m':float(C[:,2].min()),'elevation_max_m':float(C[:,2].max()),'max_grade_percent':float(np.max(np.abs(np.gradient(C[:,2],.5)))*100),'max_banking_percent':float(np.abs(bank).max()*100),'road_chunks':14,'chunk_length_m':300,'triangles_all_lods':triangles,'mesh_objects':sum(o.type=='MESH' and not o.name.startswith('EDIT_') for o in bpy.data.objects),'closure_gap_m':float(np.linalg.norm(C[0]-C[-1]))}
(BASE/'validation_blender.json').write_text(json.dumps(report,indent=2));print('REPORT',report,flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'Circuito_de_la_Sierra.blend'),compress=True)
# Render cameras. Actual mesh render, never concept imagery.
for c,filename in [(cam,'01_Overview.png'),(cam2,'02_Pit_Lane.png'),(cam3,'03_Mountain_Sector.png')]:
    scene.camera=c;scene.render.filepath=str(BASE/'previews'/filename)
    bpy.ops.render.render(write_still=True)
scene.camera=cam
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'Circuito_de_la_Sierra.blend'),compress=True)
print('BUILD COMPLETE',flush=True)
