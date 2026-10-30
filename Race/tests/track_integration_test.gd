extends SceneTree
const Catalog=preload("res://scripts/track_catalog.gd")
const Lap=preload("res://scripts/lap_tracker.gd")
var errors=[]
var report={}
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
	print(("PASS " if ok else "FAIL ")+message)
	if not ok:errors.append(message)
func frames(n:int):
	for i in range(n):await physics_frame
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	await process_frame
	check(game.selector.visible and not game.playing,"track selector opens before driving")
	game.selector.select_track("sierra")
	check(game.selected_track_id=="sierra" and game.selector.map.points.size()==840,"selection updates Sierra preview, metadata and path")
	await game._start()
	await frames(180)
	check(game.loaded_track_id=="sierra" and game.playing,"Sierra is playable from the selector")
	check(game.car.contacts==4 and game.car.position.y>12,"car spawns above elevated asphalt with four contacts")
	report["sierra_spawn_height"]=game.car.position.y
	report["sierra_contacts"]=game.car.contacts
	var track=game.track
	var misses=0;var obstructions=0;var surface_counts={}
	var state=game.get_world_3d().direct_space_state
	for p in track.points:
		var hit=state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*4,p-Vector3.UP*4,1))
		if hit.is_empty():misses+=1;continue
		var tag=str(hit.collider.name)+str(hit.collider.get_parent().name)
		if not ("Track_Asphalt" in tag or "PitLane_Asphalt" in tag):obstructions+=1
	for node in track.find_children("*","StaticBody3D",true,false):
		var surface=str(node.get_meta("surface","none"));surface_counts[surface]=surface_counts.get(surface,0)+1
	check(misses==0 and obstructions==0,"all 840 Sierra route samples land on asphalt")
	check(surface_counts.get("gravel",0)==28 and surface_counts.get("kerb",0)==22,"Sierra gravel and kerbs carry physical surface tags")
	report["raycast_misses"]=misses;report["road_obstructions"]=obstructions;report["surface_counts"]=surface_counts
	# Respawn on an uphill technical section; preserve height and slope orientation.
	var target=track.reset_near(track.points[350]+Vector3(15,4,12))
	game.car.request_reset(target);await frames(180)
	check(game.car.position.y>50 and game.car.contacts>=3,"reset on mountain preserves terrain elevation")
	check(game.car.global_basis.y.y>.95,"mountain respawn remains upright")
	game.car.request_reset(track.start_transform);await frames(120)
	var start=game.car.position
	game.controls.pointers[99]="gas"
	await frames(480)
	game.controls.clear()
	check(game.car.position.distance_to(start)>15 and game.car.speed_kmh>30,"GT77 accelerates on Sierra with touch throttle")
	report["sierra_speed_after_4s"]=game.car.speed_kmh
	# Switch away and back, so colliders/environments do not accumulate.
	game._back_to_menu();game.selector.select_track("lab");await game._start();await frames(180)
	check(game.loaded_track_id=="lab" and game.car.position.y<1 and game.car.contacts==4,"switching to original track resets height and vehicle state")
	check(game.track.length_m>580 and game.track.length_m<590,"original track length is measured")
	check(game.track.find_children("*","WorldEnvironment",true,false).size()==1,"one environment is active per track")
	game._back_to_menu()
	game.selector.select_track("sierra");await game._start();await frames(120)
	check(game.car.contacts==4,"Sierra can be reloaded after another track")
	# Lap logic rejects reverse crossings and shortcuts; counts a full forward lap.
	for length_ in [584.4,4200.0]:
		var lap=Lap.new();lap.reset(length_,length_-10)
		check(not lap.update(0) and lap.armed,"start line arms lap at %.0f m"%length_)
		var finish_count=0
		for p in range(1,1001):
			if lap.update(fposmod(length_*float(p)/1000,length_)):finish_count+=1
		check(finish_count==1,"exactly one completed lap at %.0f m"%length_)
		lap.reset(length_,10);check(not lap.update(length_-10) and not lap.armed,"reverse crossing cannot start or finish a lap")
		lap.reset(length_,length_-1);lap.update(0);lap.update(length_*.55)
		check(not lap.armed and not lap.update(0),"teleport invalidates the lap")
	for id in ["lab","sierra"]:
		var pts=Catalog.points_for(id);var rect=Rect2(0,0,150,120);var tx=Catalog.map_transform(pts,rect)
		var inside=true
		for p in pts:
			if not rect.grow(.1).has_point(tx*Vector2(p.x,p.z)):inside=false
		check(inside,"HUD map fits all "+id+" points")
	report["passed"]=errors.is_empty();report["errors"]=errors
	var out=FileAccess.open("res://tests/track_integration_results.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	print("INTEGRATION_RESULT ",JSON.stringify(report))
	game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
