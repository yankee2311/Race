extends SceneTree
const UX=preload("res://scripts/ui/race_ui.gd")
func _initialize():call_deferred("run")
func frames(count:int):
	for i in range(count):await process_frame
func run():
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	var shell=UX.new()
	shell.game=game
	shell.theme=game.base_theme
	game.ui.add_child(shell)
	game.ux=shell
	game.selector.hide()
	var directory=ProjectSettings.globalize_path("res://docs/v0.4")
	DirAccess.make_dir_recursive_absolute(directory)
	for name_ in ["home","modes","prepare","tracks","garage","vehicle","upgrades","settings","graphics","progress"]:
		shell._tab(name_)
		await frames(3)
		await RenderingServer.frame_post_draw
		var path="res://docs/v0.4/"+name_+".png"
		var error=root.get_texture().get_image().save_png(path)
		if error!=OK:
			printerr("FAIL screenshot "+name_)
			quit(1)
			return
	print("PASS UI screenshots 10/10")
	quit(0)
