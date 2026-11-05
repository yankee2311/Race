extends RefCounted
## Original low-poly geometry, generated locally; no external licensed marques.
static func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color; m.metallic = metal; m.roughness = 0.34 if metal > 0 else 0.75
	return m

static func part(parent: Node3D, name_: String, pos: Vector3, size_: Vector3, mat: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new(); node.name = name_
	var mesh = BoxMesh.new(); mesh.size = size_; node.mesh = mesh
	node.position = pos; node.material_override = mat; parent.add_child(node)
	return node

static func loft(parent:Node3D,name_:String,sections:Array,mat:Material)->MeshInstance3D:
	var rings=[]
	for section in sections:
		var z=float(section[0]);var width=float(section[1]);var bottom=float(section[2]);var top=float(section[3])
		rings.append([Vector3(-width*.82,bottom,z),Vector3(width*.82,bottom,z),Vector3(width,bottom+.09,z),Vector3(width,top-.07,z),Vector3(width*.84,top,z),Vector3(-width*.84,top,z),Vector3(-width,top-.07,z),Vector3(-width,bottom+.09,z)])
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(mat)
	for i in range(rings.size()-1):
		for j in range(8):
			var next=(j+1)%8
			for point in [rings[i][j],rings[i+1][j],rings[i+1][next],rings[i][j],rings[i+1][next],rings[i][next]]:surface.add_vertex(point)
	for end in [0,rings.size()-1]:
		for j in range(1,7):
			for index in ([0,j,j+1] if end==0 else [0,j+1,j]):surface.add_vertex(rings[end][index])
	surface.generate_normals()
	var node=MeshInstance3D.new();node.name=name_;node.mesh=surface.commit();parent.add_child(node);return node

static func create(data: Dictionary, mounts: Array, paint: Color) -> Node3D:
	var root = Node3D.new()
	var body = material(paint, 0.65); body.resource_name = "BODY_PAINT"
	var glass = material(Color("172c3e"), 0.4)
	var dark = material(Color("151b25"))
	var lamp = material(Color("d5f3ff")); lamp.emission_enabled = true; lamp.emission = Color("c6e8ff"); lamp.emission_energy_multiplier = 1.4
	var rear = material(Color("ff314e")); rear.emission_enabled = true; rear.emission = Color("ff1933")
	var w: float = data.width; var l: float = data.length; var h: float = data.height
	var formula: bool = data.body == "formula"
	var nose_width=w*(.19 if formula else .43)
	var rear_width=w*(.32 if formula else .46)
	loft(root,"SculptedBody",[[-l*.49,nose_width,.42,.63],[-l*.34,w*(.24 if formula else .49),.39,.78],[-l*.10,w*(.25 if formula else .49),.40,.81],[l*.25,rear_width,.40,.85],[l*.46,rear_width*.94,.44,.77]],body)
	var roof_height=.88+h*.42
	var roof_end=l*(.28 if data.body in ["hatch","rally"] else .13)
	loft(root,"GlassCanopy",[[-l*.24,w*.36,.77,.80],[-l*.07,w*.33,.79,roof_height],[roof_end,w*.31,.80,roof_height],[l*.30,w*.36,.79,.83]],glass)
	if not formula:
		loft(root,"Roof",[[-l*.075,w*.335,roof_height-.01,roof_height+.015],[roof_end,w*.315,roof_height-.01,roof_height+.015]],body)
	if not formula:
		for side in [-1,1]:
			part(root,"Mirror",Vector3(side*w*.53,.93,-.48),Vector3(.17,.10,.22),body)
			part(root,"Door",Vector3(side*w*.485,.68,.08),Vector3(.035,.22,l*.43),body)
			part(root,"Headlight",Vector3(side*w*.32,.69,-l*.47),Vector3(w*.23,.09,.045),lamp)
			part(root,"TailLight",Vector3(side*w*.32,.69,l*.44),Vector3(w*.25,.07,.045),rear)
	part(root,"Splitter",Vector3(0,.39,-l*.43),Vector3(w*1.01,.06,.42),dark)
	part(root,"Grille",Vector3(0,.52,-l*.46),Vector3(w*.5,.13,.04),dark)
	if data.body in ["gt","hyper","formula","rally"]:
		for side in [-1,1]: part(root,"WingMount",Vector3(side*.48,.94,l*.36),Vector3(.06,.40,.11),dark)
		part(root,"Wing",Vector3(0,1.14,l*.36),Vector3(w*1.07,.07,.36),dark)
		if formula: part(root,"FrontWing",Vector3(0,.41,-l*.48),Vector3(w*1.08,.07,.47),body)
	for i in range(4):
		var wheel = Node3D.new(); wheel.name = ["WHEEL_FL","WHEEL_FR","WHEEL_RL","WHEEL_RR"][i]; root.add_child(wheel)
		wheel.position = Vector3(mounts[i].x,.31,mounts[i].z)
		var tire = MeshInstance3D.new(); var mesh = CylinderMesh.new()
		mesh.top_radius = .366; mesh.bottom_radius = .366; mesh.height = .28; mesh.radial_segments = 16
		tire.mesh = mesh; tire.rotation.z = PI/2; tire.material_override = dark; wheel.add_child(tire)
		var hub = MeshInstance3D.new(); var rim = CylinderMesh.new()
		rim.top_radius = .24; rim.bottom_radius = .24; rim.height = .29; rim.radial_segments = 12
		hub.mesh = rim; hub.rotation.z = PI/2; hub.material_override = material(Color("b3bdcb"),.8); wheel.add_child(hub)
	return root
