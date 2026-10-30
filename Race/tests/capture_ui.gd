extends SceneTree
func _initialize():call_deferred("run")
func shot(name_:String):
	await create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/"+name_+".png")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	game.selector.select_track("lab")
	await shot("Selector_Proving_Ground")
	game.selector.select_track("sierra")
	await shot("Selector_Sierra")
	await game._start()
	await create_timer(3).timeout
	await shot("Sierra_Gameplay")
	game._back_to_menu()
	game.selector.select_track("lab")
	await game._start()
	await create_timer(2).timeout
	await shot("Lab_Gameplay")
	quit()
