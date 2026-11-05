extends SceneTree
var errors=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:errors.append(label)
func tap(at:Vector2):
	for pressed in [true,false]:
		var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed;Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
func run():
	if DisplayServer.get_name()=="headless":printerr("Graphical test requires Xvfb or a display");quit(2);return
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	for i in range(8):await process_frame
	game.selector.select_track("lab");game.selector.select_vehicle("brio_120")
	var position=game.selector.start_button.get_global_rect().get_center()
	print("START RECT ",game.selector.start_button.get_global_rect()," SCREEN ",root.get_visible_rect())
	await tap(root.get_screen_transform()*position)
	for i in range(80):await process_frame
	check(game.playing and game.car.vehicle_data.id=="brio_120","physical touch starts chosen vehicle")
	if game.playing:
		game._pause();check(paused,"pause freezes world");game._resume();check(not paused,"resume restores world")
	var out=FileAccess.open("res://tests/selector_input_results.json",FileAccess.WRITE);out.store_string(JSON.stringify({"passed":errors.is_empty(),"errors":errors},"  "));out.close()
	game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
