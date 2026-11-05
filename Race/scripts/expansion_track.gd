extends "res://scripts/track.gd"
const Catalog=preload("res://scripts/track_catalog.gd")
var definition:Dictionary

func _ready():
	track_id=definition.id;track_title=definition.name
	_build_environment()
	points=Catalog.points_for(track_id);_index_path()
	start_transform=Transform3D(Basis.looking_at(tangents[points.size()-2],Vector3.UP),points[points.size()-2]+Vector3.UP*.75)
	var palette={"desert":"b89966","city":"273240","coast":"8eaa71","snow":"d5e0e9","arena":"5b795e","port":"59626b","canyon":"ae775b","tropical":"356f51","volcano":"464249","express":"323b51"}
	var terrain=material(Color(palette[definition.biome]))
	var ground=box("Terrain",Vector3(0,-3,0),Vector3(6000,5,6000),terrain,true);ground.set_meta("surface","grass")
	var asphalt=material(Color("4e545f"));asphalt.albedo_texture=load("res://assets/asphalt.png")
	if definition.biome=="desert":asphalt.albedo_color=Color("b69b72")
	if definition.biome=="snow":asphalt.albedo_color=Color("b4c6d2")
	strip(-8,8,0,asphalt,true,"Road")
	if definition.biome in ["desert","snow"]:
		for child in get_children():
			if child is StaticBody3D and child!=ground:child.set_meta("surface","gravel" if definition.biome=="desert" else "snow")
	var white=material(Color("eef2e9"));var red=material(Color("ec495b"));var dark=material(Color("192332"))
	strip(-7.9,-7.65,.016,white);strip(7.65,7.9,.016,white)
	var t=tangents[0];var right=t.cross(Vector3.UP)
	for x in range(16):
		for z in range(2):
			var tile=box("Finish",points[0]+right*(x-7.5)+t*(z*.6)+Vector3.UP*.025,Vector3(.98,.025,.58),white if (x+z)%2==0 else dark)
			tile.rotation.y=atan2(-t.x,-t.z)
	var gate=box("StartGantry",points[0]+Vector3.UP*5.5,Vector3(19,.5,.6),red);gate.rotation.y=atan2(-t.x,-t.z)
	for side in [-1,1]:box("GantryPillar",points[0]+right*9*side+Vector3.UP*2.7,Vector3(.4,5.4,.4),dark)
	var sign=Label3D.new();sign.text=track_title.to_upper();sign.font_size=90;sign.pixel_size=.016;sign.position=points[0]+Vector3.UP*6.3;sign.rotation.y=atan2(-t.x,-t.z);add_child(sign)
	var rng=RandomNumberGenerator.new();rng.seed=int(definition.seed)*771
	var urban:bool=definition.biome in ["city","port","express"]
	var rail=material(Color("95a9bb"),.45)
	var scenery=material(Color("284e43") if definition.biome in ["coast","tropical","arena"] else Color("758393") if urban else Color("988b7e"))
	for i in range(0,points.size(),3):
		var tangent=tangents[i];var side=tangent.cross(Vector3.UP)
		for direction in [-1,1]:
			var wall=box("Barrier",points[i]+side*10*direction+Vector3.UP*.5,Vector3(.35,1.0,points[i].distance_to(points[(i+3)%points.size()])+1),rail,true)
			wall.rotation.y=atan2(-tangent.x,-tangent.z)
			if i%9==0:
				var height=rng.randf_range(5,36) if urban else rng.randf_range(6,16)
				var pos=points[i]+side*rng.randf_range(24,60)*direction+Vector3.UP*(height*.5-1)
				if urban:
					var building=box("Warehouse" if definition.biome=="port" else "Building",pos,Vector3(13,height,13),scenery)
					building.rotation.y=float(i)*.1
					if definition.biome!="port":
						var neon=material(Color("36c8d9") if i%2==0 else Color("e55aad"));neon.emission_enabled=true;neon.emission=neon.albedo_color
						box("NeonBand",pos+Vector3(0,height*.25,0),Vector3(13.2,.6,13.2),neon)
				else:
					var node=MeshInstance3D.new();var cone=CylinderMesh.new();cone.top_radius=0;cone.bottom_radius=height*.32;cone.height=height;cone.radial_segments=7
					node.mesh=cone;node.position=pos;node.material_override=scenery;add_child(node);node.visibility_range_end=600
	if definition.biome in ["coast","tropical"]:
		strip(-28,28,-.16,terrain,false,"CoastalVerge")
		var water=material(Color("2384a5"),.25);box("Ocean",Vector3(0,-.35,0),Vector3(6000,.1,6000),water)
	if urban:
		var env:Environment=get_child(0).environment
		env.ambient_light_energy=.65;sky_sun.light_energy=.35
		var sky_mat:ProceduralSkyMaterial=env.sky.sky_material
		sky_mat.sky_top_color=Color("080f28");sky_mat.sky_horizon_color=Color("334062")
	_batch_boxes();_build_skids()
