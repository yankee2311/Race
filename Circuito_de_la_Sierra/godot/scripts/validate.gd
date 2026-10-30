extends SceneTree
var frames: int = 0
func _initialize() -> void:
	var root_scene: Node = load("res://main.tscn").instantiate()
	root.add_child(root_scene)
func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames < 4: return false
	var circuit: Node = root.get_node("CircuitoDeLaSierra")
	var all_bodies: Array[Node] = []
	_collect(circuit, all_bodies)
	var report := {"static_bodies": all_bodies.size(), "asphalt": 0, "loose": 0, "kerb": 0, "triangle_colliders": 0, "path_length_m": circuit.route.curve.get_baked_length()}
	for body in all_bodies:
		if body.is_in_group("surface_asphalt"): report["asphalt"] += 1
		if body.is_in_group("surface_loose"): report["loose"] += 1
		if body.is_in_group("surface_kerb"): report["kerb"] += 1
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is ConcavePolygonShape3D: report["triangle_colliders"] += 1
	var misses: int = 0
	var obstructions: int = 0
	var max_height_error: float = 0.0
	var minimum_up_normal: float = 1.0
	var state: PhysicsDirectSpaceState3D = circuit.get_world_3d().direct_space_state
	for station in range(0, 4200, 5):
		var p: Vector3 = circuit.route.curve.sample_baked(float(station))
		var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p - Vector3.UP * 4.0)
		var hit: Dictionary = state.intersect_ray(query)
		if hit.is_empty():
			misses += 1
			continue
		var collider: Node = hit["collider"]
		var name: String = str(collider.name) + " " + str(collider.get_parent().name)
		if not ("Track_Asphalt" in name or "PitLane_Asphalt" in name): obstructions += 1
		max_height_error = maxf(max_height_error, absf(hit["position"].y - (p.y - 0.2)))
		minimum_up_normal = minf(minimum_up_normal, hit["normal"].y)
	report["road_raycast_samples"] = 840
	report["road_raycast_misses"] = misses
	report["road_obstructions"] = obstructions
	report["max_height_error_m"] = max_height_error
	report["minimum_up_normal"] = minimum_up_normal
	var file := FileAccess.open("res://validation_godot.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("GODOT_VALIDATION ", report)
	if report["static_bodies"] < 100 or report["loose"] < 28 or report["kerb"] < 22 or misses > 0 or obstructions > 0 or max_height_error > 0.12:
		quit(1)
	else: quit(0)
	return false
func _collect(node: Node, found: Array[Node]) -> void:
	if node is StaticBody3D: found.append(node)
	for child in node.get_children(): _collect(child, found)
