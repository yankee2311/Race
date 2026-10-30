extends Node3D
## Inspection scene; AI Path3D is a guidance curve, not vehicle physics.
const TRACK = preload("res://assets/Circuito_de_la_Sierra.glb")
const ASPHALT = preload("res://physics/asphalt.tres")
const GRAVEL = preload("res://physics/gravel.tres")
const KERB = preload("res://physics/kerb.tres")
var camera: Camera3D
var route: Path3D
var follower: PathFollow3D
var mode: int = 0
var tour_speed: float = 45.0
var label: Label
var status: Label
var collision_count: int = 0

func _ready() -> void:
	var track: Node = TRACK.instantiate()
	add_child(track)
	_configure(track)
	_build_route()
	_build_environment()
	camera = Camera3D.new()
	camera.name = "InspectionCamera"
	camera.far = 8000.0
	camera.near = 0.2
	camera.fov = 65.0
	add_child(camera)
	_overview()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	label = Label.new()
	label.text = "CIRCUITO DE LA SIERRA  /  4.2 KM\n1 Vista general · 2 Recorrido · 3 Cámara libre\nCámara libre: WASD + Q/E · Botón derecho: mirar\nShift: rápido · Rueda: velocidad del recorrido · Esc: salir"
	label.add_theme_font_size_override("font_size", 17)
	rows.add_child(label)
	status = Label.new()
	status.modulate = Color(0.3, 0.85, 0.78)
	rows.add_child(status)
	print("SIERRA_READY collisions=", collision_count, " path_length=", route.curve.get_baked_length())

func _configure(node: Node) -> void:
	if node is StaticBody3D:
		collision_count += 1
		var tag: String = (str(node.name) + " " + str(node.get_parent().name)).to_lower()
		if "gravel" in tag or "terrain" in tag or "embankment" in tag:
			node.physics_material_override = GRAVEL
			node.add_to_group("surface_loose")
		elif "kerb" in tag:
			node.physics_material_override = KERB
			node.add_to_group("surface_kerb")
		else:
			node.physics_material_override = ASPHALT
			node.add_to_group("surface_asphalt")
	if node is MeshInstance3D:
		var tag: String = str(node.name)
		if "LOD0" in tag:
			node.visibility_range_end = 300.0
		elif "LOD1" in tag:
			node.visibility_range_begin = 300.0
			node.visibility_range_end = 750.0
		elif "LOD2" in tag:
			node.visibility_range_begin = 750.0
		elif "Sage_" in tag:
			node.visibility_range_end = 650.0
		elif "Rocks_" in tag:
			node.visibility_range_end = 1000.0
	for child in node.get_children():
		_configure(child)

func _build_route() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/centerline.json"))
	route = Path3D.new()
	route.name = "AI_Centerline"
	route.curve = Curve3D.new()
	route.curve.bake_interval = 2.0
	for p in data["points"]:
		route.curve.add_point(Vector3(p[0], p[1], p[2]))
	route.curve.add_point(route.curve.get_point_position(0))
	add_child(route)
	follower = PathFollow3D.new()
	follower.name = "AI_PathFollow_Demo"
	follower.loop = true
	follower.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	route.add_child(follower)
	# Spawn for future VehicleBody3D or custom raycast vehicle.
	var spawn := Marker3D.new()
	spawn.name = "VehicleSpawn"
	spawn.position = Vector3(-245, 13.1, 300)
	spawn.rotation.y = -PI / 2.0
	add_child(spawn)

func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.19, 0.39, 0.63)
	sky_mat.sky_horizon_color = Color(0.76, 0.82, 0.84)
	sky_mat.ground_horizon_color = Color(0.76, 0.78, 0.73)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.78, 0.88)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47, -35, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 800.0
	add_child(sun)

func _overview() -> void:
	mode = 0
	camera.position = Vector3(-1400, 1740, 1810)
	camera.look_at(Vector3(-80, 40, -135))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _overview()
			KEY_2: mode = 1
			KEY_3: mode = 2
			KEY_ESCAPE: get_tree().quit()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			tour_speed = minf(100.0, tour_speed + 5.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			tour_speed = maxf(5.0, tour_speed - 5.0)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and mode == 2:
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.5, 1.5)

func _process(delta: float) -> void:
	if mode == 1:
		follower.progress += tour_speed * delta
		var pos: Vector3 = follower.global_position + Vector3.UP * 5.0
		var target: Vector3 = route.curve.sample_baked(fmod(follower.progress + 40.0, route.curve.get_baked_length()), true) + Vector3.UP * 2.0
		camera.global_position = pos
		camera.look_at(target)
	elif mode == 2:
		var move := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): move.z -= 1
		if Input.is_physical_key_pressed(KEY_S): move.z += 1
		if Input.is_physical_key_pressed(KEY_A): move.x -= 1
		if Input.is_physical_key_pressed(KEY_D): move.x += 1
		if Input.is_physical_key_pressed(KEY_Q): move.y -= 1
		if Input.is_physical_key_pressed(KEY_E): move.y += 1
		var speed: float = 220.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 60.0
		camera.position += camera.global_basis * move.normalized() * speed * delta
	if is_instance_valid(status):
		status.text = "14 segmentos · Desnivel 120 m · Peralte hasta 8%%\n%s · Recorrido %.0f km/h" % [["VISTA GENERAL", "RECORRIDO GUIADO", "CÁMARA LIBRE"][mode], tour_speed * 3.6]
