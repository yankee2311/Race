extends Control
const Catalog=preload("res://scripts/track_catalog.gd")
var car
var controls
var track
var session
var mono:Font
var font:Font

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=load("res://assets/regular.ttf");mono=load("res://assets/mono.ttf")

func text(at:Vector2,value:String,size_:int,color:Color=Color.WHITE,use_mono:bool=false):
	draw_string(mono if use_mono else font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_,color)

func panel(rect:Rect2,color:Color=Color(.035,.06,.09,.78)):
	var style=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(12);draw_style_box(style,rect)

func _process(_dt):queue_redraw()

func _draw():
	if not is_instance_valid(car) or not is_instance_valid(session) or not session.playing:return
	var w=get_viewport_rect().size.x;var h=get_viewport_rect().size.y
	var muted=Color("a9bac9");var mint=Color("59e8c9")
	panel(Rect2(20,17,234,59));draw_rect(Rect2(20,27,4,37),Color("ef4551"));text(Vector2(35,43),"GT77 / DRIVE LAB",20);text(Vector2(35,63),["ASISTIDO","SPORT","SIMULACIÓN"][car.driving_mode]+"  ·  "+controls.status,11,muted)
	panel(Rect2(w*.5-180,17,360,61))
	text(Vector2(w*.5-163,40),"VUELTA %02d"%(session.laps+1),14,muted)
	text(Vector2(w*.5-163,65),session.time_string(session.lap_time),23,Color.WHITE,true)
	text(Vector2(w*.5+25,40),"MEJOR",12,muted)
	text(Vector2(w*.5+25,64),session.time_string(session.best_lap) if session.best_lap>0 else "--:--.---",20,mint,true)
	# Track map and car direction.
	panel(Rect2(20,94,190,173));var map_rect=Rect2(34,109,161,140)
	var map_transform=Catalog.map_transform(track.points,map_rect)
	var lines=PackedVector2Array()
	for point in track.points:lines.append(map_transform*Vector2(point.x,point.z))
	lines.append(lines[0]);draw_polyline(lines,Color(.55,.65,.73,.55),5,true)
	var pos=map_transform*Vector2(car.position.x,car.position.z)
	draw_circle(pos,4.5,mint)
	var fwd=-car.global_basis.z;draw_line(pos,pos+Vector2(fwd.x,fwd.z)*13,mint,2)
	text(Vector2(33,286),("SIERRA" if track.track_id=="sierra" else "PROVING GROUND")+" / %.0f m"%track.length_m,11,muted)
	# Main tachometer and speed cluster.
	var cx=w*.5
	panel(Rect2(cx-176,h-177,352,153),Color(.03,.05,.075,.89))
	for i in range(24):
		var lit=float(i)/24<(car.rpm-900)/7300
		var color=Color("57dfc0") if i<17 else (Color("e6bd61") if i<21 else Color("f64c5e"))
		draw_rect(Rect2(cx-155+i*13,h-157,10,8),color if lit else Color(.2,.25,.29,.7))
	text(Vector2(cx-153,h-127),"%.0f RPM"%car.rpm,12,muted,true)
	text(Vector2(cx-149,h-62),"%03d"%roundi(car.speed_kmh),65,Color.WHITE,true)
	text(Vector2(cx-149,h-40),"km/h",14,muted)
	text(Vector2(cx+89,h-66),"R" if car.reverse else str(car.gear),54,mint,true)
	text(Vector2(cx+79,h-41),"AUTO",12,muted)
	text(Vector2(cx-155,h-188),"ABS",12,mint if car.abs_active else muted if car.driving_mode<2 else Color(.4,.42,.45))
	text(Vector2(cx-110,h-188),"TCS",12,mint if car.tcs_active else muted if car.driving_mode<2 else Color(.4,.42,.45))
	text(Vector2(cx-54,h-188),"%+.2f G"%car.lateral_g,12,muted,true)
	text(Vector2(cx+46,h-188),"AERO %.0f N"%car.downforce,12,muted,true)
	# Four contact/load indicators. Meaningful live suspension telemetry.
	for i in range(4):
		var bx=cx-155+i*79;var load_fraction=clampf(car.wheels[i].load/6500.0,0,1)
		draw_rect(Rect2(bx,h-223,64,5),Color(.18,.23,.27,.8));draw_rect(Rect2(bx,h-223,64*load_fraction,5),mint if car.wheels[i].ground else Color("ed5463"))
		text(Vector2(bx,h-229),["DI","DD","TI","TD"][i],10,muted)
	if session.message_time>0:
		panel(Rect2(cx-270,95,540,42),Color(.04,.08,.11,.94));text(Vector2(cx-251,122),session.message,17,mint)
