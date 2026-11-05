extends Node3D
class_name GT77Track

var points=PackedVector3Array()
var tangents=PackedVector3Array()
var length_m=0.0
var track_id="lab"
var track_title="GT77 Proving Ground"
var stations=PackedFloat32Array()
var start_transform=Transform3D(Basis.IDENTITY,Vector3(-58,.75,60))
var skid_instances:MultiMeshInstance3D
var skid_index=0
var sky_sun:DirectionalLight3D

func material(color:Color,rough:float=.9)->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=rough;return m

func box(name_:String,pos:Vector3,size:Vector3,mat:Material,solid:bool=false)->Node3D:
	var node=StaticBody3D.new() if solid else Node3D.new();node.name=name_;node.position=pos;add_child(node)
	var visual=MeshInstance3D.new();var m=BoxMesh.new();m.size=size;visual.mesh=m;visual.material_override=mat;node.add_child(visual)
	if solid:
		var c=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;c.shape=shape;node.add_child(c);node.collision_layer=1;node.collision_mask=2
	return node

func _build_environment():
	var environment=WorldEnvironment.new();var env=Environment.new();environment.environment=env
	env.background_mode=Environment.BG_SKY
	var sky=Sky.new();var skymat=ProceduralSkyMaterial.new();skymat.sky_top_color=Color("6296ba");skymat.sky_horizon_color=Color("c5d4d9");skymat.ground_bottom_color=Color("4b564d");skymat.ground_horizon_color=Color("bdc8c3");sky.sky_material=skymat;env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("c6d4e0");env.ambient_light_energy=.32
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	sky_sun=DirectionalLight3D.new();sky_sun.rotation_degrees=Vector3(-43,-32,0);sky_sun.light_color=Color(1.0,.94,.83);sky_sun.light_energy=1.05;sky_sun.shadow_enabled=true;sky_sun.directional_shadow_max_distance=90;add_child(sky_sun)

func _ready():
	_build_environment()
	var grass=material(Color("526c4c"));grass.albedo_texture=load("res://assets/grass.png");grass.uv1_scale=Vector3(100,100,100)
	var ground=box("Ground",Vector3(0,-1.06,0),Vector3(700,2,700),grass,true);ground.set_meta("surface","grass")
	_build_path()
	_build_road()
	_build_surroundings()
	_batch_boxes()
	_build_skids()

func _batch_boxes():
	# Keep collision shapes, but render repeated kerbs/barriers/grid paint in batches.
	var groups={}
	for parent in get_children():
		for child in parent.get_children():
			if child is MeshInstance3D and child.mesh is BoxMesh and child.material_override:
				var key=str(child.mesh.size)+"/"+str(child.material_override.get_instance_id())
				if not groups.has(key):groups[key]=[]
				groups[key].append(child)
	for key in groups:
		var meshes=groups[key]
		if meshes.size()<3:continue
		var instance=MultiMeshInstance3D.new();var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=meshes[0].mesh;mm.instance_count=meshes.size();instance.multimesh=mm;instance.material_override=meshes[0].material_override;add_child(instance)
		for i in range(meshes.size()):
			mm.set_instance_transform(i,global_transform.affine_inverse()*meshes[i].global_transform)
			meshes[i].queue_free()

func _build_path():
	points=preload("res://scripts/track_catalog.gd").lab_points()
	# Rotate indexing so progress zero matches the existing timing stripe.
	var ordered=PackedVector3Array()
	for i in range(points.size()):ordered.append(points[(i+3)%points.size()])
	points=ordered
	_index_path()

func _index_path():
	length_m=0.0;tangents.clear();stations.clear()
	for i in range(points.size()):
		stations.append(length_m)
		tangents.append((points[(i+1)%points.size()]-points[(i-1+points.size())%points.size()]).normalized())
		length_m+=points[i].distance_to(points[(i+1)%points.size()])

func progress_at(point:Vector3)->float:
	var i=closest_index(point);var best=INF;var progress=0.0
	for start in [(i-1+points.size())%points.size(),i]:
		var end=(start+1)%points.size();var edge=points[end]-points[start]
		var t=clampf((point-points[start]).dot(edge)/edge.length_squared(),0,1)
		var d=point.distance_squared_to(points[start]+edge*t)
		if d<best:best=d;progress=stations[start]+edge.length()*t
	return fposmod(progress,length_m)

func strip(left:float,right:float,height:float,mat:Material,collision:bool=false,name_:String="Strip"):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);mat.cull_mode=BaseMaterial3D.CULL_DISABLED;st.set_material(mat)
	var distance=0.0
	for i in range(points.size()):
		var j=(i+1)%points.size();var normal=tangents[i].cross(Vector3.UP);var normal2=tangents[j].cross(Vector3.UP)
		var p=[points[i]+normal*left+Vector3.UP*height,points[i]+normal*right+Vector3.UP*height,points[j]+normal2*right+Vector3.UP*height,points[j]+normal2*left+Vector3.UP*height]
		var next=distance+points[i].distance_to(points[j]);var uv=[Vector2(0,distance/12),Vector2(1,distance/12),Vector2(1,next/12),Vector2(0,next/12)]
		for k in [0,2,1,0,3,2]:st.set_normal(Vector3.UP);st.set_uv(uv[k]);st.add_vertex(p[k])
		distance=next
	var mesh=st.commit();var node=MeshInstance3D.new();node.name=name_;node.mesh=mesh;add_child(node)
	if collision:
		var body=StaticBody3D.new();body.set_meta("surface","asphalt");body.collision_layer=1;body.collision_mask=2;add_child(body)
		var c=CollisionShape3D.new();c.shape=mesh.create_trimesh_shape();c.shape.backface_collision=true;body.add_child(c)

func _build_road():
	var asphalt=material(Color("656970"));asphalt.albedo_texture=load("res://assets/asphalt.png")
	strip(-8,8,0,asphalt,true,"Asphalt_circuit")
	var white=material(Color("e1e1d3"));strip(-7.75,-7.57,.009,white);strip(7.57,7.75,.009,white)
	var red=material(Color("c13c40"));var dark=material(Color("282e35"))
	for i in range(0,points.size(),2):
		var t=tangents[i];var right=t.cross(Vector3.UP)
		for side in [-1,1]:
			var curb=box("Kerb",points[i]+right*8.25*side+Vector3.UP*.025,Vector3(.65,.10,3.6),red if (i/2 as int)%2==0 else white,true);curb.rotation.y=atan2(-t.x,-t.z);curb.set_meta("surface","kerb")
	# Start grid and timing line on the west straight.
	for ix in range(16):
		for iz in range(2):box("Timing_checker",Vector3(-65.5+ix,.038,48+iz*.55),Vector3(.98,.016,.54),white if (ix+iz)%2==0 else dark)
	for j in range(5):
		box("Grid_mark",Vector3(-60,.039,57+j*5),Vector3(2,.012,.13),white)
	var paint=material(Color("edb84a"))
	# Separate flat skid pad and small suspension test obstacles.
	var pad=box("Skid_pad",Vector3(0,-.01,0),Vector3(42,.07,58),asphalt,true);pad.set_meta("surface","asphalt")
	for z in [-14,-7,0,7,14]:
		var bump=box("Suspension_bump",Vector3(11,.035,z),Vector3(4,.13,.60),paint,true);bump.set_meta("surface","kerb")
	for z in range(-20,21,8):_cone(Vector3(-7,.03,z))
	# Pit buildings and lane, off the racing surface.
	box("Pit_lane",Vector3(-85,-.01,10),Vector3(13,.08,75),asphalt,true)
	box("Pit_building",Vector3(-101,3,10),Vector3(15,6,64),material(Color("b8bdb9")),true)
	for z in range(-17,39,9):
		box("Garage",Vector3(-93.46,1.4,z),Vector3(.08,2.8,6),dark)
		box("Garage_header",Vector3(-93.40,3,z),Vector3(.12,.35,6),red)
	box("Pit_roof",Vector3(-98,6.05,10),Vector3(22,.25,66),dark)
	var sign=Label3D.new();sign.text="GT77  /  DRIVE LAB";sign.font_size=100;sign.pixel_size=.025;sign.position=Vector3(-91,5,7);sign.rotation.y=PI/2;sign.modulate=Color.WHITE;add_child(sign)

func _cone(pos):
	var cone=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=.045;mesh.bottom_radius=.22;mesh.height=.65;mesh.radial_segments=12;cone.mesh=mesh;cone.position=pos+Vector3.UP*.325;cone.material_override=material(Color("ec743c"));add_child(cone)
	box("Cone_base",pos+Vector3.UP*.035,Vector3(.48,.07,.48),material(Color("282d30")))

func _build_surroundings():
	var rail=material(Color("98a4a9"),.5)
	for i in range(0,points.size(),7):
		var t=tangents[i];var right=t.cross(Vector3.UP)
		var wall=box("Outer_barrier",points[i]-right*12+Vector3.UP*.47,Vector3(.32,.94,12.5),rail,true);wall.rotation.y=atan2(-t.x,-t.z)
	var rng=RandomNumberGenerator.new();rng.seed=77
	var trees=MultiMeshInstance3D.new();var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
	var tree_mesh=CylinderMesh.new();tree_mesh.top_radius=0;tree_mesh.bottom_radius=2;tree_mesh.height=8;tree_mesh.radial_segments=7;multi.mesh=tree_mesh;multi.instance_count=180;trees.multimesh=multi;trees.material_override=material(Color("244a3b"));add_child(trees)
	for i in range(180):
		var a=rng.randf()*TAU;var radius=rng.randf_range(165,280);var scale_=rng.randf_range(.7,1.8)
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_),Vector3(cos(a)*radius,4*scale_,sin(a)*radius)))
	for i in range(14):
		var mountain=MeshInstance3D.new();var cone=CylinderMesh.new();cone.bottom_radius=rng.randf_range(40,75);cone.top_radius=6;cone.height=rng.randf_range(22,65);cone.radial_segments=7;mountain.mesh=cone;mountain.position=Vector3(cos(i*TAU/14)*330,cone.height/2-3,sin(i*TAU/14)*330);mountain.material_override=material(Color("354f4e"));add_child(mountain)
	# Braking distance references on both straights.
	for x in [-70.0,70.0]:
		for i in range(3):
			var z=-48+i*22 if x<0 else 48-i*22
			box("Distance_board",Vector3(x,1,z),Vector3(1.9,1.4,.12),material(Color("eef0e8")))
			var text=Label3D.new();text.text=str((i+1)*50);text.font_size=80;text.pixel_size=.012;text.position=Vector3(x,1,z+.08 if x<0 else z-.08);text.rotation.y=0 if x<0 else PI;text.modulate=Color("12202d");add_child(text)

func _build_skids():
	skid_instances=MultiMeshInstance3D.new();var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
	var mesh=PlaneMesh.new();mesh.size=Vector2(.24,.60);mm.mesh=mesh;mm.instance_count=480;mm.visible_instance_count=0;skid_instances.multimesh=mm
	skid_instances.material_override=material(Color(.10,.115,.12));skid_instances.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(skid_instances)

func add_skid(point:Vector3,forward:Vector3,normal:Vector3=Vector3.UP):
	var basis=Basis.looking_at(forward.slide(normal).normalized(),normal)
	skid_instances.multimesh.set_instance_transform(skid_index,Transform3D(basis,point+normal*.012))
	skid_index=(skid_index+1)%480
	skid_instances.multimesh.visible_instance_count=mini(480,skid_instances.multimesh.visible_instance_count+1)

func closest_index(point:Vector3)->int:
	var best=INF;var index=0
	for i in range(points.size()):
		var distance=point.distance_squared_to(points[i])
		if distance<best:best=distance;index=i
	return index

func reset_near(point:Vector3)->Transform3D:
	var i=closest_index(point)
	return Transform3D(Basis.looking_at(tangents[i],Vector3.UP),points[i]+Vector3.UP*.75)

func road_distance(point:Vector3)->float:
	var i=closest_index(point);var best=INF
	for start in [(i-1+points.size())%points.size(),i]:
		var edge=points[(start+1)%points.size()]-points[start]
		var t=clampf((point-points[start]).dot(edge)/maxf(edge.length_squared(),.001),0,1)
		var delta=point-(points[start]+edge*t)
		best=minf(best,Vector2(delta.x,delta.z).length())
	return best
