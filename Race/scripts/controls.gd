extends Control
class_name DriveControls

const Safe=preload("res://scripts/ui/safe_area.gd")
var left_handed=false
var active=false
var mode=0
var invert_tilt=false
var full_angle=32.0
var throttle=0.0
var brake=0.0
var steering=0.0
var handbrake=0.0
var pointers={}
var pointer_amounts={}
var zones={}
var zone_offsets:Dictionary={}
var neutral=Vector3(0,9.81,0)
var filtered_gravity=Vector3(0,9.81,0)
var fused_angle=0.0
var sensor_available=false
var gyro_available=false
var sensor_wait=0.0
var status="BOTONES"
var target_steering=0.0
signal sensors_missing

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_mode=Node.PROCESS_MODE_ALWAYS

func calibrate():
	var g=Input.get_gravity()
	if g.length()<1:g=Input.get_accelerometer()
	if g.length()>1:neutral=g;filtered_gravity=g
	fused_angle=0;steering=0;sensor_wait=0

func clear():
	pointers.clear();pointer_amounts.clear();throttle=0;brake=0;steering=0;handbrake=0;target_steering=0

func make_zones():
	var safe=Safe.rect(self);var w=safe.size.x;var h=safe.size.y
	if mode==1:
		zones={"gas":Rect2(w-160,h-210,135,177),"brake":Rect2(24,h-185,135,152),"hand":Rect2(24,h-252,135,57)}
	else:
		zones={"gas":Rect2(w-148,h-199,118,164),"brake":Rect2(w-282,h-157,112,122),"hand":Rect2(w-282,h-223,112,53)}
	if mode==0:
		zones["left"]=Rect2(28,h-157,112,122);zones["right"]=Rect2(156,h-157,112,122)
	elif mode==2:zones["wheel"]=Rect2(28,h-230,220,200)
	for key in zones:
		var rect:Rect2=zones[key]
		if left_handed:rect.position.x=w-rect.end.x
		rect.position+=safe.position
		rect.position+=zone_offsets.get(key,Vector2.ZERO)
		rect.position.x=clampf(rect.position.x,safe.position.x,safe.end.x-rect.size.x)
		rect.position.y=clampf(rect.position.y,safe.position.y,safe.end.y-rect.size.y)
		zones[key]=rect

func _input(event):
	if not active or get_tree().paused:return
	if event is InputEventScreenTouch:
		if event.pressed:
			make_zones()
			for key in zones:
				if zones[key].has_point(event.position):pointers[event.index]=key;pointer_amounts[event.index]=_pedal_amount(event.position,key);break
		else:
			pointers.erase(event.index)
			pointer_amounts.erase(event.index)
	elif event is InputEventScreenDrag and pointers.has(event.index):
		var key=pointers[event.index]
		if not zones.has(key) or not zones[key].grow(60).has_point(event.position):
			pointers.erase(event.index);pointer_amounts.erase(event.index)
		else:pointer_amounts[event.index]=_pedal_amount(event.position,key)

func _pedal_amount(pos:Vector2,key:String)->float:
	if key=="wheel":return clampf((pos.x-zones[key].get_center().x)/(zones[key].size.x*.4),-1,1)
	if key not in ["gas","brake"]:return 1.0
	var rect:Rect2=zones[key]
	return clampf((rect.end.y-pos.y)/rect.size.y,0.05,1.0)

func pedal_value(key:String)->float:
	var amount=0.0
	for index in pointers:
		if pointers[index]==key:amount=maxf(amount,pointer_amounts.get(index,1.0))
	return amount

func pressed(key:String)->bool:
	return key in pointers.values()

func _process(dt):
	if not active or get_tree().paused:
		clear();queue_redraw();return
	throttle=1.0 if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) else pedal_value("gas")
	brake=1.0 if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) else pedal_value("brake")
	handbrake=1.0 if pressed("hand") or Input.is_physical_key_pressed(KEY_SPACE) else 0.0
	var keyboard=float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	if mode==0:
		target_steering=clampf(float(pressed("right"))-float(pressed("left"))+keyboard,-1,1);status="BOTONES"
	elif mode==2:
		target_steering=keyboard
		for index in pointers:
			if pointers[index]=="wheel":target_steering=pointer_amounts.get(index,0.0)*32.0/full_angle
		target_steering=clampf(target_steering,-1,1);status="VOLANTE"
	else:
		var g=Input.get_gravity();var gyro=Input.get_gyroscope()
		if g.length()<1:
			filtered_gravity=filtered_gravity.lerp(Input.get_accelerometer(),minf(dt*5,1));g=filtered_gravity
		sensor_available=g.length()>2
		gyro_available=gyro_available or gyro.length()>.001
		if sensor_available:
			var a=Vector2(g.x,g.y);var b=Vector2(neutral.x,neutral.y)
			var measured=0.0
			if a.length()>2 and b.length()>2:measured=-atan2(a.x*b.y-a.y*b.x,a.dot(b))
			else:measured=asin(clampf((g.x-neutral.x)/9.81,-.95,.95))
			fused_angle=lerp_angle(fused_angle-gyro.z*dt,measured,1.0-exp(-dt*5))
			target_steering=clampf(fused_angle/deg_to_rad(full_angle),-1,1)*(-1.0 if invert_tilt else 1.0)
			if absf(target_steering)<.035:target_steering=0
			status="GIRO + GRAVEDAD" if gyro_available else "INCLINACIÓN"
		else:
			sensor_wait+=dt;target_steering=keyboard;status="BUSCANDO SENSOR"
			if sensor_wait>3.0:mode=0;sensors_missing.emit()
	var joypads=Input.get_connected_joypads()
	if not joypads.is_empty():
		var joy=joypads[0];var axis=Input.get_joy_axis(joy,JOY_AXIS_LEFT_X)
		if absf(axis)>.12:target_steering=signf(axis)*(absf(axis)-.12)/.88;status="MANDO"
		throttle=maxf(throttle,Input.get_joy_axis(joy,JOY_AXIS_TRIGGER_RIGHT));brake=maxf(brake,Input.get_joy_axis(joy,JOY_AXIS_TRIGGER_LEFT))
		if Input.is_joy_button_pressed(joy,JOY_BUTTON_A):handbrake=1
	steering=move_toward(steering,target_steering,dt*(3.0 if mode==0 else 4.5))
	queue_redraw()

func _draw():
	if not active:return
	make_zones()
	var font=ThemeDB.fallback_font
	for key in zones:
		var rect:Rect2=zones[key]
		var on=pressed(key)
		var style=StyleBoxFlat.new();style.bg_color=Color(.06,.09,.13,.78) if not on else Color(.12,.6,.54,.90)
		if key=="brake" and on:style.bg_color=Color(.75,.15,.20,.9)
		style.set_corner_radius_all(17);style.set_border_width_all(2);style.border_color=Color(.7,.82,.88,.25) if not on else Color("63efce")
		draw_style_box(style,rect)
		var label={"gas":"GAS","brake":"FRENO","hand":"F. MANO","left":"◀","right":"▶","wheel":"VOLANTE"}[key]
		var font_size=26 if key in ["gas","left","right"] else 19
		var tw=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(font,rect.get_center()+Vector2(-tw*.5,8),label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)
		if key in ["gas","brake"]:
			var fraction=pedal_value(key)
			draw_rect(Rect2(rect.position.x+5,rect.end.y-6-(rect.size.y-12)*fraction,5,(rect.size.y-12)*fraction),Color("59e8c9"))
		if key=="wheel":
			var center=rect.get_center();draw_arc(center,72,0,TAU,48,Color("59e8c9"),5,true)
			var direction=Vector2(cos(steering),sin(steering))*68;draw_line(center-direction,center+direction,Color("59e8c9"),5,true)
		if key=="gas":
			for j in range(4):draw_line(rect.position+Vector2(28,25+j*10),rect.position+Vector2(rect.size.x-28,25+j*10),Color(.8,1,.95,.3),2)
	if mode==1:
		var center=Vector2(125,get_viewport_rect().size.y-103)
		draw_arc(center,48,0,TAU,48,Color(.8,.92,1,.42),4)
		var angle=steering*.9
		var offset=Vector2(cos(angle),sin(angle))*43
		draw_line(center-offset,center+offset,Color("59e8c9"),5)
		draw_circle(center,7,Color("59e8c9"))
		draw_string(font,center+Vector2(-65,74),"INCLINA PARA GIRAR",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(.8,.9,1))
