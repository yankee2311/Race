extends SceneTree
var errors=[]
var report={"vehicles":[],"tracks":[],"stability":[]}
func _initialize():call_deferred("run")
func check(condition:bool,message:String):
	print(("PASS " if condition else "FAIL ")+message)
	if not condition:errors.append(message)
func frames(count:int):
	for i in range(count):await physics_frame
func run():
	var Catalog=load("res://scripts/track_catalog.gd");var Vehicles=load("res://scripts/vehicles/vehicle_catalog.gd")
	check(Catalog.ENTRIES.size()==12,"12 circuits in catalog")
	check(Vehicles.all().size()==24,"24 vehicles in catalog")
	var world=Node3D.new();root.add_child(world)
	var floor_=StaticBody3D.new();world.add_child(floor_)
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(4000,1,4000);collision.shape=box;collision.position.y=-.5;floor_.add_child(collision)
	var car=load("res://scripts/car.gd").new();world.add_child(car)
	for data in Vehicles.all():
		car.configure(data);car.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,.75,0)));car.throttle_input=0;car.brake_input=0;car.steering_input=0
		await frames(200)
		check(car.contacts==4 and car.position.y>.3 and car.position.y<.85,data.id+" rests on four wheels")
		check(car.visual.get_child_count()>0 and car.wheel_meshes.size()==4,data.id+" visible body and wheels")
		car.throttle_input=1;await frames(480)
		check(car.speed_kmh>20 and car.position.is_finite() and car.global_basis.y.y>.9,data.id+" accelerates upright")
		report.vehicles.append({"id":data.id,"speed_4s":car.speed_kmh,"height":car.position.y})
	car.configure(Vehicles.get_vehicle("gt77"))
	for mode in range(3):
		for speed in [80,120,180,220]:
			car.throttle_input=0;car.steering_input=0;car.driving_mode=mode;car.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,.75,0)));await frames(180)
			car.linear_velocity=Vector3(0,0,-float(speed)/3.6)
			for wheel in car.wheels:wheel.omega=float(speed)/3.6/car.RADIUS
			car.steering_input=.35;car.throttle_input=.25;await frames(120);car.steering_input=-.35;await frames(120);car.steering_input=0;await frames(120)
			var stable=car.position.is_finite() and car.position.y<1.5 and car.global_basis.y.y>.65
			check(stable,"lane change mode %d at %d km/h"%[mode,speed]);report.stability.append({"mode":mode,"speed":speed,"upright":car.global_basis.y.y,"height":car.position.y})
	var ghost=load("res://scripts/gameplay/ghost.gd").new();world.add_child(ghost)
	ghost.configure("test/ghost",Vehicles.get_vehicle("gt77"))
	ghost.recording=[[0,0,1,0,0,0,0,1],[1,10,1,0,0,0,0,1]]
	check(ghost.save_best(),"ghost recording saves")
	ghost.configure("test/ghost",Vehicles.get_vehicle("gt77"));ghost.tick(.25,car)
	check(ghost.samples.size()==2 and absf(ghost.position.x-2.5)<.01,"ghost reload and interpolation")
	ghost.new_lap();check(ghost.elapsed==0 and ghost.recording.is_empty(),"ghost resets at start line")
	DirAccess.remove_absolute("user://ghost_"+"test/ghost".sha256_text()+".json")
	world.queue_free();await process_frame;await physics_frame
	for entry in Catalog.ENTRIES:
		if entry.id in ["lab","sierra"]:continue
		var track=load("res://scripts/expansion_track.gd").new();track.definition=entry;root.add_child(track);await frames(3)
		var misses=0
		for p in track.points:
			var hit=track.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP*2,1))
			if hit.is_empty() or hit.position.distance_to(p)>.15:misses+=1
		check(misses==0,entry.id+" road continuous at all 360 samples")
		check(absf(track.length_m-float(entry.length))<1,entry.id+" measured distance matches catalog")
		car=load("res://scripts/car.gd").new();root.add_child(car);car.transform=track.start_transform;await frames(180)
		check(car.contacts==4,entry.id+" spawn has four contacts")
		report.tracks.append({"id":entry.id,"length":track.length_m,"ray_misses":misses,"contacts":car.contacts})
		car.queue_free();track.queue_free();await process_frame;await physics_frame
	var Rules=load("res://scripts/gameplay/race_rules.gd");var rules=Rules.new()
	rules.begin(2,1000,0);rules.tick(1,0,true,0,0,0,0);check(rules.elapsed==0 and rules.countdown==2,"countdown excludes race time")
	rules.begin(4,1000,0)
	for i in range(91):rules.tick(1,float(i)*10,true,50,.3,1,0)
	check(rules.completed and rules.score>0,"drift scores and finishes after 90 seconds")
	rules.begin(5,1000,0);rules.tick(3,0,true,0,0,0,0)
	for i in range(76):rules.tick(.1,float(i)*10,true,50,0,1,0)
	check(rules.completed,"sprint finishes at 75 percent")
	rules.begin(5,1000,0);rules.tick(3,0,true,0,0,0,0);rules.tick(.1,500,true,50,0,1,0);check(not rules.valid and rules.travel==0,"teleport cannot earn sprint progress")
	rules.begin(1,1000,0);rules.tick(1.1,0,false,30,0,1,0);check(not rules.valid,"off-track excursion invalidates lap")
	check(not rules.finish_lap() and rules.laps==0,"invalid lap cannot count toward race")
	check(rules.finish_lap() and rules.laps==1,"following clean lap may count")
	rules.begin(8,1800,0);rules.tick(3,0,true,0,0,0,0)
	for i in range(42):rules.tick(.1,float(i)*10,true,80,0,1,0)
	check(rules.completed and rules.travel>=402,"drag finishes beyond 402 metres")
	rules.begin(2,1000,0);rules.tick(3,0,true,0,0,0,0)
	for i in range(3):rules.finish_lap()
	rules.tick(.1,0,true,50,0,1,0);check(rules.completed,"race finishes after three valid laps")
	rules.begin(9,1000,0);rules.tick(.1,0,true,61,0,1,0);rules.tick(.1,0,true,2,0,0,1)
	for i in range(101):rules.tick(.1,float(i),true,40,0,1,0)
	check(rules.completed and rules.academy_step==2,"academy requires acceleration braking and controlled driving")
	var profile=load("res://scripts/core/profile.gd").new();profile.path="user://test_profile.json"
	check(not profile.buy("gt77","motor"),"insufficient credits do not buy upgrade")
	profile.reward(3000,50);check(profile.buy("gt77","motor") and profile.level("gt77","motor")==1 and profile.data.credits==2500,"purchase deducts correct amount")
	var loaded=load("res://scripts/core/profile.gd").new();loaded.path=profile.path;loaded.load_profile();check(loaded.level("gt77","motor")==1 and loaded.data.credits==2500 and loaded.data.xp==50,"upgrades persist after reload")
	check(profile.record("test",60) and not profile.record("test",70) and profile.record("test",55),"personal records only improve")
	DirAccess.remove_absolute(profile.path)
	report.passed=errors.is_empty();report.errors=errors
	var out=FileAccess.open("res://tests/expansion_results.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	print("EXPANSION_RESULT ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
