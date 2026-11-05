extends SceneTree
## Regression of low-cost spatial lookup and 60 Hz vehicle simulation.
const Catalog=preload("res://scripts/track_catalog.gd")
const Mobile=preload("res://scripts/core/mobile_profile.gd")
var errors:Array=[]

func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:errors.append(label)

func _initialize():call_deferred("run")

func run():
	check(Mobile.is_galaxy_a05("SM-A055F"),"A05 detected by Samsung model")
	check(Mobile.is_galaxy_a05("Galaxy A05"),"A05 detected by marketing name")
	check(not Mobile.is_galaxy_a05("SM-A057F"),"A05s is not incorrectly detected")
	check(not Mobile.is_galaxy_a05("GenericDevice"),"desktop does not activate Lite")
	var temp=ConfigFile.new()
	Mobile.apply_lite_defaults(temp)
	check(int(temp.get_value("drive","quality",-1))==0 and int(temp.get_value("drive","fps",-1))==0,"Lite defaults: low quality and 30 FPS")
	temp.set_value("drive","quality",2)
	Mobile.apply_lite_defaults(temp)
	check(int(temp.get_value("drive","quality",-1))==2,"user graphics preference survives further launches")

	var path_script=load("res://scripts/track.gd")
	for entry in Catalog.ENTRIES:
		var track=path_script.new()
		track.points=Catalog.points_for(entry.id)
		track._index_path()
		for i in range(0,track.points.size(),12):
			var sample=track.points[i]+Vector3(3,0,4)
			var near=track.closest_index(sample)
			var reference=INF
			for p in track.points:reference=minf(reference,sample.distance_squared_to(p))
			check(sample.distance_squared_to(track.points[near])<=reference+.01,"grid nearest %s at %d"%[entry.id,i])
		var remote=Vector3(10000,0,10000)
		var far_index=track.closest_index(remote)
		var far_reference=INF
		for p in track.points:far_reference=minf(far_reference,remote.distance_squared_to(p))
		check(remote.distance_squared_to(track.points[far_index])<=far_reference+.01,"offroad fallback "+entry.id)

	Mobile.configure_engine(true)
	check(Engine.physics_ticks_per_second==60,"Lite physics frequency 60 Hz")
	var world=Node3D.new();root.add_child(world)
	var floor_=StaticBody3D.new();floor_.set_meta("surface","asphalt");world.add_child(floor_)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new()
	box.size=Vector3(500,1,500);shape.shape=box;shape.position.y=-.5;floor_.add_child(shape)
	var car=load("res://scripts/car.gd").new();world.add_child(car)
	car.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,.75,0)))
	for i in range(120):await physics_frame
	check(car.contacts==4 and car.position.is_finite(),"car rests on four wheels at 60 Hz")
	car.throttle_input=.8
	for i in range(360):await physics_frame
	check(car.position.is_finite() and car.global_basis.y.y>.7 and car.speed_kmh>40,"six-second acceleration stable at 60 Hz")
	car.throttle_input=0;car.brake_input=1
	for i in range(300):await physics_frame
	check(car.position.is_finite() and car.speed_kmh<10,"five-second braking stable at 60 Hz")
	world.queue_free();await process_frame
	print("MOBILE_LITE_RESULT ",JSON.stringify({"passed":errors.is_empty(),"errors":errors}))
	quit(0 if errors.is_empty() else 1)
