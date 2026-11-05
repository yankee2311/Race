extends Node3D
var samples:Array=[]
var recording:Array=[]
var elapsed=0.0
var sample_clock=0.0
var playback_index=0
var key=""
var ghost_visual:Node3D
var enabled=true
func configure(record_key:String,data:Dictionary):
	key=record_key.sha256_text();samples.clear();recording.clear();elapsed=0;sample_clock=0;playback_index=0
	if is_instance_valid(ghost_visual):ghost_visual.queue_free()
	ghost_visual=preload("res://scripts/vehicles/vehicle_visual.gd").create(data,[Vector3(-.88,.1,-1.43),Vector3(.88,.1,-1.43),Vector3(-.88,.1,1.4),Vector3(.88,.1,1.4)],Color("50dcdf"));add_child(ghost_visual)
	for mesh in ghost_visual.find_children("*","MeshInstance3D",true,false):
		var mat=StandardMaterial3D.new();mat.albedo_color=Color(.25,.85,.95,.28);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=mat;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var path="user://ghost_"+key+".json"
	if FileAccess.file_exists(path):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Array and parsed.size()<=24000:
			var valid=true;var previous_time=-1.0
			for row in parsed:
				if not row is Array or row.size()!=8:valid=false;break
				for value in row:
					if not (value is float or value is int):valid=false
				if not valid:break
				if float(row[0])<previous_time:valid=false;break
				previous_time=float(row[0])
			if valid:samples=parsed
	visible=enabled and not samples.is_empty()
func new_lap():
	elapsed=0;sample_clock=0;playback_index=0;recording.clear()
func tick(dt:float,car:Node3D):
	elapsed+=dt;sample_clock+=dt
	if sample_clock>=.05 and recording.size()<24000:
		sample_clock=0;var p=car.position;var q=car.basis.get_rotation_quaternion()
		recording.append([elapsed,p.x,p.y,p.z,q.x,q.y,q.z,q.w])
	visible=enabled and samples.size()>1 and elapsed<=float(samples[-1][0])
	if not visible:return
	while playback_index<samples.size()-2 and float(samples[playback_index+1][0])<elapsed:playback_index+=1
	var a=samples[playback_index];var b=samples[playback_index+1]
	var fraction=clampf((elapsed-float(a[0]))/maxf(float(b[0])-float(a[0]),.001),0,1)
	var pa=Vector3(a[1],a[2],a[3]);var pb=Vector3(b[1],b[2],b[3])
	var qa=Quaternion(a[4],a[5],a[6],a[7]).normalized();var qb=Quaternion(b[4],b[5],b[6],b[7]).normalized()
	transform=Transform3D(Basis(qa.slerp(qb,fraction)),pa.lerp(pb,fraction));ghost_visual.position.y=-.55
func save_best()->bool:
	if recording.size()<2:return false
	var file=FileAccess.open("user://ghost_"+key+".json",FileAccess.WRITE)
	if not file:return false
	file.store_string(JSON.stringify(recording));file.close();samples=recording.duplicate(true);return true
