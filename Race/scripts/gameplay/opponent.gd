extends Node3D
## Lightweight trajectory AI. Rivals do not collide in this offline alpha.
var track
var distance=0.0
var start_progress=0.0
var pace=1.0
var lane=0.0
var speed=0.0
var finished=false
var driver_name=""
var visual:Node3D
var wheels=[]
func setup(track_,data:Dictionary,index:int,difficulty:float):
	track=track_;pace=difficulty*(.94+index*.025);lane=-3 if index%2==0 else 3
	start_progress=track.progress_at(track.start_transform.origin)
	distance=-8.0-float(index)*7.0
	driver_name=["VEGA","CRUZ","SOL","NOVA","RÍOS"][index%5]
	var mounts=[Vector3(-.88,.1,-1.43),Vector3(.88,.1,-1.43),Vector3(-.88,.1,1.4),Vector3(.88,.1,1.4)]
	visual=preload("res://scripts/vehicles/vehicle_visual.gd").create(data,mounts,Color(data.color));add_child(visual);visual.position.y=-.55
	for tag in ["WHEEL_FL","WHEEL_FR","WHEEL_RL","WHEEL_RR"]:wheels.append(visual.find_child(tag,true,false))
	var label=Label3D.new();label.text=driver_name;label.position.y=1.6;label.font_size=40;label.pixel_size=.015;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(label)
	place()
func sample(progress:float)->Transform3D:
	var p=fposmod(progress,track.length_m)
	var index=0
	# Binary search station table: AI sampling stays logarithmic on long circuits.
	var lo=0;var hi=track.stations.size()-1
	while lo<=hi:
		var mid=(lo+hi)/2
		if track.stations[mid]<=p:index=mid;lo=mid+1
		else:hi=mid-1
	var next=(index+1)%track.points.size()
	var edge:Vector3=track.points[next]-track.points[index]
	var fraction=clampf((p-track.stations[index])/maxf(edge.length(),.01),0,1)
	var tangent:Vector3=track.tangents[index].lerp(track.tangents[next],fraction).normalized()
	return Transform3D(Basis.looking_at(tangent,Vector3.UP),track.points[index].lerp(track.points[next],fraction))
func place():
	var pose=sample(start_progress+distance)
	global_transform=pose;position+=pose.basis.x*lane+Vector3.UP*.55
func tick(dt:float,player:Vector3):
	if finished:return
	var current=sample(start_progress+distance);var ahead=sample(start_progress+distance+35)
	var curve=acos(clampf(current.basis.z.dot(ahead.basis.z),-1,1))/35.0
	var target=clampf(sqrt(8.5/maxf(curve,.002)),13,64)*pace
	speed=move_toward(speed,target,dt*(5.5 if target>speed else 12.0))
	if global_position.distance_to(player)<10:lane=move_toward(lane,3.3 if current.basis.x.dot(player-current.origin)<0 else -3.3,dt*2)
	distance+=speed*dt;place()
	for wheel in wheels:wheel.rotation.x-=speed*dt/.366
