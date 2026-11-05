extends "res://scripts/track.gd"
func _ready():
	track_id="drag_strip";track_title="RACE · 402 m"
	_build_environment()
	# Long rectangle; only the first straight belongs to the timed event.
	for z in range(80,-661,-4):points.append(Vector3(0,.025,z))
	for x in range(4,81,4):points.append(Vector3(x,.025,-660))
	for z in range(-656,81,4):points.append(Vector3(80,.025,z))
	for x in range(76,0,-4):points.append(Vector3(x,.025,80))
	_index_path();start_transform=Transform3D(Basis.IDENTITY,Vector3(0,.75,60))
	box("Ground",Vector3(0,-1,0),Vector3(1000,2,2000),material(Color("566b50")),true)
	strip(-8,8,.025,material(Color("505964")),true)
	var white=material(Color.WHITE)
	for z in [60,-342]:box("Line",Vector3(0,.065,z),Vector3(16,.03,.5),white)
	for z in range(60,-660,-25):
		for x in [-10,10]:box("Barrier",Vector3(x,.5,z),Vector3(.4,1,25),white,true)
	_build_skids()
