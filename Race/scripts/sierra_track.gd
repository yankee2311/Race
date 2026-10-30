extends "res://scripts/track.gd"
const Catalog=preload("res://scripts/track_catalog.gd")
var packed:PackedScene
var colliders=0
func _ready():
	track_id="sierra";track_title="Circuito de la Sierra"
	_build_environment();sky_sun.directional_shadow_max_distance=180
	if packed==null:packed=load(Catalog.SIERRA_SCENE)
	var scene=packed.instantiate();add_child(scene);_configure(scene)
	var raw=Catalog.points_for("sierra")
	for i in range(raw.size()):points.append(raw[(i+53)%raw.size()])
	_index_path()
	start_transform=Transform3D(Basis.looking_at(tangents[points.size()-3],Vector3.UP),points[points.size()-3]+Vector3.UP*.8)
	_build_skids()
func _configure(node:Node):
	if node is StaticBody3D:
		colliders+=1;node.collision_layer=1;node.collision_mask=2
		var tag=(str(node.name)+" "+str(node.get_parent().name)).to_lower()
		var surface="asphalt"
		if "gravel" in tag:surface="gravel"
		elif "terrain" in tag or "embankment" in tag:surface="grass"
		elif "kerb" in tag:surface="kerb"
		node.set_meta("surface",surface)
		var pm=PhysicsMaterial.new();pm.friction=1.0 if surface=="asphalt" else (.8 if surface=="kerb" else .4);node.physics_material_override=pm
	if node is MeshInstance3D:
		var tag=str(node.name)
		if "LOD0" in tag:node.visibility_range_end=250
		elif "LOD1" in tag:node.visibility_range_begin=250
		elif tag.begins_with("Tire_Buffer"):node.visibility_range_end=320;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif tag.begins_with("Fence"):node.visibility_range_end=550;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif tag.begins_with("Sage"):node.visibility_range_end=650
		elif tag.begins_with("Rocks"):node.visibility_range_end=900
	for child in node.get_children():_configure(child)
func reset_near(point:Vector3)->Transform3D:
	var i=closest_index(point)
	var up=Vector3.UP
	if is_inside_tree():
		var query=PhysicsRayQueryParameters3D.create(points[i]+Vector3.UP*4,points[i]-Vector3.UP*4,1)
		var hit=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():up=hit.normal
	return Transform3D(Basis.looking_at(tangents[i].slide(up).normalized(),up),points[i]+up*.8)
