extends SceneTree
func _initialize():call_deferred("run")
func run():
	var world=Node3D.new();root.add_child(world)
	world.add_child(load("res://scripts/track.gd").new())
	var cam=Camera3D.new();cam.position=Vector3(175,245,205);cam.far=1500;cam.fov=50;world.add_child(cam);cam.look_at(Vector3(-8,0,0));cam.current=true
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://assets/tracks/previews/lab.jpg",.9)
	quit()
