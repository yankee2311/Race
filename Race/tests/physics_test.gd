extends SceneTree
var car
var errors=[]
var result={}

func _initialize():call_deferred("run")

func check(condition:bool,label:String):
	if not condition:errors.append(label);printerr("FAIL: "+label)
	else:print("PASS: "+label)

func frames(count:int):
	for i in range(count):await physics_frame

func reset():
	car.throttle_input=0;car.brake_input=0;car.steering_input=0;car.handbrake_input=0
	car.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,.75,0)))
	await frames(240)

func run():
	var world=Node3D.new();root.add_child(world)
	var ground=StaticBody3D.new();ground.position.y=-.10;ground.set_meta("surface","asphalt");world.add_child(ground)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2500,.2,2500);shape.shape=box;ground.add_child(shape)
	car=load("res://scripts/car.gd").new();world.add_child(car)
	await reset()
	result.idle_height=car.position.y;result.idle_speed=car.speed_kmh;result.contacts=car.contacts
	check(car.contacts==4,"four wheel contacts at rest")
	check(car.position.y>.35 and car.position.y<.75,"suspension static sag is plausible")
	check(car.speed_kmh<.5,"no spontaneous acceleration at rest")
	check(car.global_basis.y.dot(Vector3.UP)>.98,"chassis upright at rest")
	car.throttle_input=1
	var hundred_time=-1.0
	for i in range(1440):
		await physics_frame
		if car.speed_kmh>=100 and hundred_time<0:hundred_time=i/120.0
	result.acceleration_12s_kmh=car.speed_kmh;result.zero_to_100=hundred_time;result.gear=car.gear;result.acceleration_height=car.position.y
	check(car.speed_kmh>100 and car.speed_kmh<300,"accelerates to highway speed without numerical explosion")
	check(car.gear>1,"automatic gearbox shifts up")
	check(car.position.y<1 and car.global_basis.y.dot(Vector3.UP)>.85,"stable straight-line acceleration")
	car.throttle_input=0;car.brake_input=1
	var brake_start=car.position
	await frames(600)
	result.brake_5s_kmh=car.speed_kmh;result.brake_distance_m=car.position.distance_to(brake_start)
	check(car.speed_kmh<5,"braking brings the vehicle to rest")
	await reset()
	car.reverse=true;car.throttle_input=.7
	await frames(420)
	result.reverse_z=car.position.z
	check(car.position.z>3,"reverse gear moves backward")
	await reset()
	car.linear_velocity=Vector3(0,0,-18)
	car.steering_input=.30;car.throttle_input=.15
	await frames(300)
	result.steering_x=car.position.x;result.steering_up=car.global_basis.y.y
	check(car.position.x>1,"right steering produces a right-hand turn")
	check(car.position.y<1.8 and car.global_basis.y.y>.60,"moderate corner remains on its wheels")
	await reset()
	car.linear_velocity=Vector3(0,0,-50)
	await frames(15)
	result.downforce_180kmh=car.downforce;result.drag_180kmh=car.drag_force
	check(car.downforce>4000 and car.drag_force>800,"quadratic aero forces are applied")
	car.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,1.1,0)));car.throttle_input=0;car.steering_input=0
	await frames(420)
	check(car.position.y>.35 and car.position.y<.75 and absf(car.linear_velocity.y)<.3,"suspension damps a drop")
	var controls=load("res://scripts/controls.gd").new();root.add_child(controls);controls.active=true
	await process_frame
	await process_frame
	controls.make_zones()
	var gas=InputEventScreenTouch.new();gas.index=0;gas.pressed=true;gas.position=controls.zones.gas.get_center();root.push_input(gas,true)
	var left=InputEventScreenTouch.new();left.index=1;left.pressed=true;left.position=controls.zones.left.get_center();root.push_input(left,true)
	await frames(30)
	print("MULTITOUCH ",controls.pointers," throttle ",controls.throttle," steer ",controls.steering)
	result.multitouch_pointers=controls.pointers.duplicate();result.multitouch_throttle=controls.throttle;result.multitouch_steering=controls.steering
	check(controls.throttle>.45 and controls.throttle<.55 and controls.steering<-.2,"multitouch supports proportional half throttle and steering together")
	gas.pressed=false;left.pressed=false;root.push_input(gas,true);root.push_input(left,true)
	await frames(30)
	check(controls.throttle==0 and absf(controls.steering)<.01,"touch release clears driving commands")
	Input.set_gravity(Vector3(0,9.81,0));controls.mode=1;controls.calibrate();Input.set_gravity(Vector3(-4,8.9,0));Input.set_gyroscope(Vector3(0,0,-.25))
	await frames(90)
	result.sensor_steering=controls.steering
	check(controls.steering>.2,"calibrated gravity and gyro produce steering")
	controls.calibrate();Input.set_gyroscope(Vector3.ZERO)
	await frames(90)
	check(absf(controls.steering)<.08,"sensor recalibration returns steering to centre")
	result.errors=errors;result.passed=errors.is_empty()
	var file=FileAccess.open("res://tests/results.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print(JSON.stringify(result))
	world.queue_free();controls.queue_free();await process_frame
	quit(0 if errors.is_empty() else 1)
