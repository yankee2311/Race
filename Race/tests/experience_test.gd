extends SceneTree
var errors=[]
var game
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:errors.append(label)
func frames(count:int):
	for i in range(count):await physics_frame
func shot(name_:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/v0.3/"+name_+".png")
func tap(position:Vector2):
	var press=InputEventScreenTouch.new();press.index=17;press.position=position;press.pressed=true;root.push_input(press,true)
	await process_frame;press.pressed=false;root.push_input(press,true);await process_frame
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames(5);Engine.max_fps=0
	for resolution in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1024,768),Vector2i(960,600)]:
		root.size=resolution;await frames(5)
		var rect=game.selector.start_button.get_global_rect();var visible=root.get_visible_rect()
		check(visible.encloses(rect),"start visible at "+str(resolution))
		for choice in [game.selector.track_choice,game.selector.vehicle_choice,game.selector.session_mode]:
			check(choice.get_global_rect().size.x>100 and visible.encloses(choice.get_global_rect()),"choice fits "+str(resolution))
		await shot("menu_%dx%d"%[resolution.x,resolution.y])
	root.size=Vector2i(1280,720);await frames(4)
	game.selector.select_track("lab");game.selector.select_vehicle("brio_120")
	game.selector.start_button.pressed.emit();await frames(220)
	check(game.playing and game.car.vehicle_data.id=="brio_120","start action enters selected vehicle")
	game._pause();check(paused,"pause stops physics");game._resume();check(not paused and game.controls.pointers.is_empty(),"resume clears input")
	for mode in range(10):
		game._back_to_menu();game.selector.session_mode.select(mode);game.selector.select_track("lab");game.selector.select_vehicle("gt77")
		if mode==3:game.championship_round=0
		await game._start();Engine.max_fps=0;await frames(400)
		check(game.rules.mode==mode and game.playing,"mode starts: "+str(mode))
		check(game.car.contacts>=3,"mode spawn contacts: "+str(mode))
		if mode in [2,3,7]:check(game.rivals.size()==5 and game.rivals[0].distance>-8,"AI advances after countdown")
		if mode==2:
			game.laps=0;game.lap_tracker.armed=true;game.rules.travel=game.track.length_m*8
			game._update_ranking(20)
			check(game.ranking_distance<game.track.length_m,"invalid travel cannot add laps to ranking")
			var rival=game.rivals[0];rival.finished=true;rival.finish_time=1
			game._update_ranking(20);check(game.rules.position>=2,"already finished rival stays ahead")
			rival.finished=false
		if mode==8:check(game.track.track_id=="drag_strip","drag uses dedicated straight")
		if mode in [2,3,7,8]:await shot("mode_"+str(mode))
		if mode==3:
			game.rules.completed=true;game.rules.message="Carrera terminada";game._finish_event()
			check(game.results.visible and game.championship_scores[0]>0,"championship results award standings")
			game._continue_event();await frames(220);Engine.max_fps=0
			check(game.championship_round==1 and game.track.track_id=="coast","championship advances to second track")
		if mode==4:
			game.rules.score=100;game.rules.completed=true;game._finish_event();var credits=game.profile.data.credits
			game._finish_event();check(game.profile.data.credits==credits,"event payout is idempotent")
		if mode==5:
			game._reset();check(game.rules.completed and game.results.visible,"reset invalidates sprint and opens results")
	game._back_to_menu();game.selector.session_mode.select(0);game.selector.select_track("neon");game.selector.select_vehicle("nova_h1");game.selector.weather_choice.select(1);game.selector.reverse_choice.button_pressed=true
	await game._start();Engine.max_fps=0;await frames(220)
	check(game.car.surface_multiplier<1 and game.rain!=null,"wet condition changes grip and creates rain")
	check(game.car.contacts==4,"reverse procedural track spawn has contact")
	await shot("neon_wet")
	for mode in [0,1,2]:
		game.controls.mode=mode;game.controls.make_zones()
		for zone in game.controls.zones.values():check(root.get_visible_rect().encloses(zone),"control inside screen mode "+str(mode))
	game.controls.mode=2;game.controls.active=true;game.controls.make_zones()
	var touch=InputEventScreenTouch.new();touch.index=0;touch.pressed=true;touch.position=game.controls.zones.wheel.get_center()+Vector2(70,0);root.push_input(touch,true)
	await frames(60);check(game.controls.steering>.5,"virtual steering responds to touch")
	touch.pressed=false;root.push_input(touch,true);await frames(60);check(absf(game.controls.steering)<.01,"virtual wheel returns to centre")
	game.controls.left_handed=true;game.controls.make_zones();check(game.controls.zones.gas.get_center().x<root.get_visible_rect().size.x*.5,"left-handed pedals move to left")
	game._back_to_menu();game.menu.show();game.selector.hide();await frames(5);await shot("settings")
	game.queue_free();await process_frame
	var out=FileAccess.open("res://tests/experience_results.json",FileAccess.WRITE);out.store_string(JSON.stringify({"passed":errors.is_empty(),"errors":errors},"  "));out.close()
	print("EXPERIENCE_RESULT ",JSON.stringify(errors));quit(0 if errors.is_empty() else 1)
