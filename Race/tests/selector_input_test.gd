extends SceneTree
var errors=[]
func _initialize():call_deferred("run")
func check(ok:bool,msg:String):
	print(("PASS " if ok else "FAIL ")+msg)
	if not ok:errors.append(msg)
func tap(at:Vector2):
	var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true;Input.parse_input_event(event);Input.flush_buffered_events()
	await process_frame
	event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events()
	await process_frame
func run():
	if DisplayServer.get_name()=="headless":
		printerr("This touchscreen GUI test requires a graphical display. Use capture_ui or Xvfb.");quit(2);return
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.selector.select_track("sierra")
	await tap(game.selector.cards[0].get_global_rect().get_center())
	check(game.selected_track_id=="lab","touch selects original circuit")
	await tap(game.selector.cards[1].get_global_rect().get_center())
	check(game.selected_track_id=="sierra","touch selects Sierra")
	await tap(game.selector.settings_button.get_global_rect().get_center())
	check(game.menu.visible and not game.selector.visible,"touch opens preserved driving settings")
	game.menu.hide();game.selector.show();game.selector.select_track("lab")
	await tap(game.selector.start_button.get_global_rect().get_center())
	for i in range(40):await process_frame
	check(game.playing and game.loaded_track_id=="lab","touch on start enters selected track")
	game._back_to_menu()
	for dimensions in [Vector2i(1280,720),Vector2i(960,720),Vector2i(1600,720)]:
		root.size=dimensions
		await process_frame;await process_frame
		var rect=root.get_visible_rect()
		var ui=game.selector
		check(rect.encloses(ui.start_button.get_global_rect()),"start button fits "+str(dimensions))
		check(not ui.hero_panel.get_global_rect().intersects(ui.details.get_global_rect()),"preview and technical details do not overlap "+str(dimensions))
	var out=FileAccess.open("res://tests/selector_input_results.json",FileAccess.WRITE);out.store_string(JSON.stringify({"passed":errors.is_empty(),"errors":errors},"  "));out.close()
	game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
