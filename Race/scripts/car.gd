extends RigidBody3D
class_name GT77Car

const RADIUS=0.366
const REST=0.34
const TRAVEL=0.21
const SPRING=43000.0
const BUMP_DAMP=3900.0
const REBOUND_DAMP=4700.0
const WHEEL_INERTIA=2.8
const RATIOS=[3.15,2.12,1.57,1.23,1.02,0.84]
const FINAL_DRIVE=3.75
var mounts=[Vector3(-0.88,0.10,-1.43),Vector3(0.88,0.10,-1.43),Vector3(-0.88,0.10,1.40),Vector3(0.88,0.10,1.40)]
var wheels=[]
var visual:Node3D
var wheel_meshes=[]
var steering_wheel:Node3D
var throttle_input=0.0
var brake_input=0.0
var steering_input=0.0
var handbrake_input=0.0
var throttle=0.0
var steering=0.0
var driving_mode=1
var gear=1
var reverse=false
var rpm=950.0
var shift_delay=0.0
var speed_kmh=0.0
var downforce=0.0
var drag_force=0.0
var tcs_active=false
var abs_active=false
var contacts=0
var worst_slip=0.0
var lateral_g=0.0
var last_velocity=Vector3.ZERO
var respawn_requested=false
var respawn_transform=Transform3D.IDENTITY
var aero_enabled=true
var physics_enabled=true

func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	mass=1280.0
	center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass=Vector3(0,-0.13,0.10)
	inertia=Vector3(1800,2300,620)
	linear_damp=0.0
	angular_damp=0.15
	continuous_cd=true
	contact_monitor=true
	max_contacts_reported=6
	collision_layer=2
	collision_mask=1
	var shape=CollisionShape3D.new()
	var box=BoxShape3D.new();box.size=Vector3(1.78,0.46,4.20)
	shape.shape=box;shape.position=Vector3(0,-0.08,0);add_child(shape)
	var pm=PhysicsMaterial.new();pm.friction=0.35;pm.bounce=0.08;physics_material_override=pm
	visual=load("res://assets/gt77_mobile.glb").instantiate();add_child(visual);visual.position.y=-0.55
	for tag in ["WHEEL_FL","WHEEL_FR","WHEEL_RL","WHEEL_RR"]:
		var node=visual.find_child(tag,true,false)
		wheel_meshes.append(node)
		wheels.append({"length":REST,"compression":0.0,"omega":0.0,"spin":0.0,"load":0.0,"slip":0.0,"lat_slip":0.0,"ground":false,"point":Vector3.ZERO,"normal":Vector3.UP,"steer":0.0})
	_build_cockpit()

func _build_cockpit():
	steering_wheel=Node3D.new();add_child(steering_wheel);steering_wheel.position=Vector3(-.32,.28,-.62);steering_wheel.rotation.x=deg_to_rad(-12)
	var rim=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=.125;torus.outer_radius=.15;torus.rings=24;torus.ring_segments=8;rim.mesh=torus;rim.rotation.x=PI/2
	var mat=StandardMaterial3D.new();mat.albedo_color=Color(.025,.03,.035);mat.roughness=.8;rim.material_override=mat;steering_wheel.add_child(rim)
	for angle in [0.0,TAU/3,2*TAU/3]:
		var spoke=MeshInstance3D.new();var b=BoxMesh.new();b.size=Vector3(.035,.13,.025);spoke.mesh=b;spoke.position=Vector3(sin(angle),cos(angle),0)*.065;spoke.rotation.z=-angle;spoke.material_override=mat;steering_wheel.add_child(spoke)
	var stripe=MeshInstance3D.new();var s=BoxMesh.new();s.size=Vector3(.023,.04,.03);stripe.mesh=s;stripe.position=Vector3(0,.138,0)
	var red=StandardMaterial3D.new();red.albedo_color=Color("ef4551");stripe.material_override=red;steering_wheel.add_child(stripe)

func set_skin(index:int):
	var files=["reference","arctic","pearl"]
	var tex=load("res://assets/"+files[clampi(index,0,2)]+"_basecolor.png")
	for node in visual.find_children("*","MeshInstance3D",true,false):
		for surf in range(node.mesh.get_surface_count()):
			var mat=node.get_active_material(surf)
			if mat and mat.resource_name.begins_with("LIVERY_BODY"):
				var copy=mat.duplicate();copy.albedo_texture=tex;node.set_surface_override_material(surf,copy)

func request_reset(where:Transform3D):
	respawn_transform=where;respawn_requested=true

func _integrate_forces(state:PhysicsDirectBodyState3D):
	if respawn_requested:
		state.transform=respawn_transform;state.linear_velocity=Vector3.ZERO;state.angular_velocity=Vector3.ZERO
		for w in wheels:w.omega=0.0;w.length=REST;w.load=0.0
		throttle=0;rpm=950;gear=1;reverse=false;respawn_requested=false;last_velocity=Vector3.ZERO
		return
	if not physics_enabled:return
	var dt=state.step
	var basis=state.transform.basis
	var up=basis.y
	var forward=-basis.z
	var velocity=state.linear_velocity
	speed_kmh=velocity.length()*3.6
	var forward_speed=velocity.dot(forward)
	lateral_g=lerpf(lateral_g,(velocity-last_velocity).dot(basis.x)/maxf(dt,0.001)/9.81,.08)
	last_velocity=velocity
	throttle=move_toward(throttle,throttle_input,dt*(2.2 if throttle_input>throttle else 7.0))
	var steering_max=lerpf(.52,[.115,.18,.30][driving_mode],clampf(speed_kmh/170.0,0,1))
	steering=move_toward(steering,-steering_input*steering_max,dt*1.8)
	shift_delay=maxf(0.0,shift_delay-dt)
	var ratio=3.0 if reverse else RATIOS[gear-1]
	var road_rpm=absf((wheels[2].omega+wheels[3].omega)*.5)*ratio*FINAL_DRIVE*60.0/TAU
	rpm=lerpf(rpm,clampf(maxf(950.0+throttle*1500.0,road_rpm),950,8500),minf(dt*10,1))
	if not reverse and shift_delay<=0:
		if rpm>7350 and gear<6:gear+=1;shift_delay=.22
		elif rpm<2650 and gear>1:gear-=1;shift_delay=.18
	var torque_curve=clampf(1.0-0.34*pow((rpm-5400)/3600.0,2.0),.35,1.0)
	var engine_torque=520.0*torque_curve*throttle
	if shift_delay>0 or rpm>8200:engine_torque*=.10
	var direction=-1.0 if reverse else 1.0
	var axle_torque=engine_torque*ratio*FINAL_DRIVE*.90*direction
	tcs_active=false;abs_active=false;contacts=0;worst_slip=0
	var space=state.get_space_state()
	for i in range(4):
		var w=wheels[i]
		var origin=state.transform*mounts[i]
		var query=PhysicsRayQueryParameters3D.create(origin,origin-up*(REST+TRAVEL+RADIUS),1,[get_rid()])
		var hit=space.intersect_ray(query)
		w.ground=not hit.is_empty();w.load=0
		w.steer=steering if i<2 else 0.0
		# Ackermann: inside wheel turns more on a tight corner.
		if i<2 and absf(steering)>.01:
			var turning_radius=2.83/tan(absf(steering))
			var inside=(i==0 and steering>0) or (i==1 and steering<0)
			w.steer=signf(steering)*atan(2.83/maxf(turning_radius+(-.88 if inside else .88),1.0))
		if not w.ground:
			w.length=move_toward(w.length,REST+TRAVEL,dt*.8);w.compression=0
			w.omega=move_toward(w.omega,0,dt*2);w.spin+=w.omega*dt
			continue
		contacts+=1
		w.point=hit.position;w.normal=hit.normal
		w.length=clampf(origin.distance_to(hit.position)-RADIUS,.09,REST+TRAVEL)
		w.compression=REST-w.length
		var relative=hit.position-state.transform.origin
		var point_velocity=velocity+state.angular_velocity.cross(relative)
		var damping=BUMP_DAMP if point_velocity.dot(up)<0 else REBOUND_DAMP
		var spring_force=clampf(SPRING*w.compression-damping*point_velocity.dot(up),0,18500)
		w.load=spring_force
		state.apply_force(hit.normal*spring_force,relative)
		var fwd=(basis*Basis(Vector3.UP,w.steer)*Vector3.FORWARD).slide(hit.normal).normalized()
		var right=fwd.cross(hit.normal).normalized()
		var vlong=point_velocity.dot(fwd)
		var vlat=point_velocity.dot(right)
		var friction=1.28
		var rolling=.016
		if hit.collider.has_meta("surface"):
			if hit.collider.get_meta("surface")=="grass":friction=.58;rolling=.065
			elif hit.collider.get_meta("surface")=="gravel":friction=.45;rolling=.12
			elif hit.collider.get_meta("surface")=="kerb":friction=1.0
		# Mild load sensitivity, plus lower rear grip under the handbrake.
		friction*=clampf(1.08-.08*spring_force/3200.0,.88,1.08)
		if i>=2 and handbrake_input>.1:friction*=.74
		var capacity=maxf(0.01,friction*spring_force)
		var wheel_torque=axle_torque*.5 if i>=2 else 0.0
		var wheel_brake=brake_input*(1900.0 if i<2 else 1250.0)
		if i>=2:wheel_brake+=handbrake_input*2600.0
		# Engine braking through the driven axle.
		if i>=2 and throttle<.03 and absf(vlong)>1:wheel_brake+=55.0*ratio
		var fx_sum=0.0
		for substep in range(4):
			var slip=(w.omega*RADIUS-vlong)/maxf(absf(vlong),6.0)
			w.slip=slip
			var tq=wheel_torque
			var br=wheel_brake
			if driving_mode<2 and i>=2 and slip*direction>.13 and throttle>.03:
				tq*=clampf(.13/absf(slip),.03,1);tcs_active=true
			if driving_mode<2 and brake_input>.05 and slip*signf(vlong)<-.17 and absf(vlong)>3:
				br*=.15;abs_active=true
			var fx=capacity*tanh(slip*6.2)
			fx_sum+=fx
			var free_omega=w.omega+(tq-fx*RADIUS-w.omega*.04)*dt/4.0/WHEEL_INERTIA
			w.omega=clampf(move_toward(free_omega,0.0,br*dt/4.0/WHEEL_INERTIA),-350,350)
		var fx=fx_sum/4.0
		fx-=spring_force*rolling*tanh(vlong)
		fx=clampf(fx,-capacity,capacity)
		var slip_angle=atan2(vlat,absf(vlong)+2.5)
		w.lat_slip=slip_angle
		var lat_capacity=sqrt(maxf(0.0,capacity*capacity-fx*fx))
		var fy=-lat_capacity*tanh(slip_angle*58000.0/maxf(lat_capacity,1))
		state.apply_force(fwd*fx+right*fy,relative)
		w.spin+=w.omega*dt
		worst_slip=maxf(worst_slip,maxf(absf(w.slip),absf(slip_angle)*2))
	# Anti-roll bars transfer load across each axle; no fictitious upright lock.
	for pair in [[0,1],[2,3]]:
		var a=wheels[pair[0]];var b=wheels[pair[1]]
		var arb=(a.compression-b.compression)*6500.0
		if a.ground:state.apply_force(up*arb,basis*mounts[pair[0]])
		if b.ground:state.apply_force(-up*arb,basis*mounts[pair[1]])
	var speed=velocity.length()
	drag_force=.5*1.225*.36*2.0*speed*speed
	if speed>.1:state.apply_central_force(-velocity.normalized()*drag_force)
	downforce=.5*1.225*1.65*2.0*forward_speed*forward_speed if aero_enabled else 0.0
	if up.dot(Vector3.UP)>0.3:
		state.apply_force(-up*downforce*.42,basis*Vector3(0,0,-1.0))
		state.apply_force(-up*downforce*.58,basis*Vector3(0,0,1.0))
	# Assisted mode adds a small yaw damper. Sport/Simulation retain raw chassis dynamics.
	if driving_mode<2 and contacts>=3:
		var yaw_rate=state.angular_velocity.dot(up)
		var stability=2400.0 if driving_mode==0 else 800.0
		state.apply_torque(-up*yaw_rate*stability)
		# Reducir sobreviraje de potencia en modos con ayudas, conservando simulación libre.
		if absf(yaw_rate)>0.7 and throttle>0.1:
			state.apply_torque(-up*signf(yaw_rate)*minf(absf(yaw_rate),2.0)*900.0)

func _process(_dt):
	for i in range(wheel_meshes.size()):
		var node=wheel_meshes[i]
		if not is_instance_valid(node):continue
		var w=wheels[i]
		node.position=Vector3(mounts[i].x,.55+mounts[i].y-w.length,mounts[i].z)
		node.rotation=Vector3(-fmod(w.spin,TAU),w.steer,0)
	if steering_wheel:steering_wheel.rotation.z=steering*2.4

func toggle_reverse()->bool:
	if speed_kmh>5:return false
	reverse=not reverse;gear=1;rpm=950
	return true
