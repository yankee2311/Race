extends SceneTree
func _initialize():call_deferred("run")
func shot(name_:String):
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	var error=root.get_texture().get_image().save_png("res://docs/v0.3/"+name_+".png")
	if error!=OK:printerr("FAIL screenshot "+name_);quit(1)
func run():
	DirAccess.make_dir_recursive_absolute("res://docs/v0.3")
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await shot("garage")
	root.size=Vector2i(1024,768);await shot("tablet")
	root.size=Vector2i(1600,720);await shot("ultrawide")
	root.size=Vector2i(1280,720)
	game.selector.select_vehicle("nova_h1");game.selector.select_track("neon");game.selector.session_mode.select(2)
	await game._start()
	for i in range(160):await physics_frame
	await shot("neon_race")
	game._back_to_menu();game.selector.select_vehicle("gt77");game.selector.select_track("sierra");game.selector.session_mode.select(1)
	await game._start()
	for i in range(160):await physics_frame
	await shot("sierra_time_trial")
	game._back_to_menu();game.selector.hide();game.menu.show();await shot("settings")
	game.queue_free();await process_frame;quit()
