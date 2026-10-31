extends Control
const Catalog=preload("res://scripts/track_catalog.gd")
const UiTheme=preload("res://scripts/ui_theme.gd")
var car
var controls
var track
var session
var mono:Font
var font:Font

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=load(UiTheme.FONT_PATH);mono=load(UiTheme.MONO_PATH)

func text(at:Vector2,value:String,size_:int,color:Color=Color.WHITE,use_mono:bool=false):
	draw_string(mono if use_mono else font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_,color)

func panel(rect:Rect2,color:Color=UiTheme.HUD_PANEL,border:bool=false):
	var style=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(12)
	if border:style.set_border_width_all(1);style.border_color=UiTheme.HUD_LINE
	draw_style_box(style,rect)

func _process(_dt):queue_redraw()

func _draw():
	if not is_instance_valid(car) or not is_instance_valid(session) or not session.playing:return
	var w=get_viewport_rect().size.x;var h=get_viewport_rect().size.y
	# Safe area (notch): los paneles anclados a bordes se marginan en dispositivos reales.
	var ins=UiTheme.safe_insets(get_viewport());var l=ins.x;var t=ins.y;var b=ins.w
	var muted=UiTheme.TEXT_MUTED;var mint=UiTheme.MINT
	# Identidad + modo. Barra roja de marca a la izquierda.
	panel(Rect2(20+l,17+t,234,59));draw_rect(Rect2(20+l,27+t,4,37),UiTheme.RED_BRIGHT)
	text(Vector2(35+l,43+t),"GT77 / DRIVE LAB",20)
	text(Vector2(35+l,63+t),["ASISTIDO","SPORT","SIMULACIÓN"][car.driving_mode]+"  ·  "+controls.status,11,muted)
	# Cronómetro: el dato rey. Panel más opaco y borde sutil para destacarlo.
	panel(Rect2(w*.5-180,17+t,360,61),UiTheme.HUD_CHRONO,true)
	text(Vector2(w*.5-163,40+t),"VUELTA %02d"%(session.laps+1),14,muted)
	text(Vector2(w*.5-163,65+t),session.time_string(session.lap_time),23,Color.WHITE,true)
	text(Vector2(w*.5+25,40+t),"MEJOR",12,muted)
	text(Vector2(w*.5+25,64+t),session.time_string(session.best_lap) if session.best_lap>0 else "--:--.---",20,mint,true)
	# Track map and car direction.
	panel(Rect2(20+l,94+t,190,173),UiTheme.HUD_PANEL,true);var map_rect=Rect2(34+l,109+t,161,140)
	var map_transform=Catalog.map_transform(track.points,map_rect)
	var lines=PackedVector2Array()
	for point in track.points:lines.append(map_transform*Vector2(point.x,point.z))
	lines.append(lines[0]);draw_polyline(lines,UiTheme.MAP_TRACK,5,true)
	var pos=map_transform*Vector2(car.position.x,car.position.z)
	draw_circle(pos,4.5,mint)
	var fwd=-car.global_basis.z;draw_line(pos,pos+Vector2(fwd.x,fwd.z)*13,mint,2)
	text(Vector2(33+l,286+t),("SIERRA" if track.track_id=="sierra" else "PROVING GROUND")+" / %.0f m"%track.length_m,11,muted)
	# Main tachometer and speed cluster.
	var cx=w*.5
	panel(Rect2(cx-176,h-177-b,352,153),UiTheme.HUD_CLUSTER,true)
	for i in range(24):
		var lit=float(i)/24<(car.rpm-900)/7300
		var color=UiTheme.TACH_GREEN if i<17 else (UiTheme.AMBER if i<21 else UiTheme.TACH_RED)
		draw_rect(Rect2(cx-155+i*13,h-157-b,10,8),color if lit else Color(.2,.25,.29,.7))
	text(Vector2(cx-153,h-127-b),"%.0f RPM"%car.rpm,12,muted,true)
	text(Vector2(cx-149,h-62-b),"%03d"%roundi(car.speed_kmh),65,Color.WHITE,true)
	text(Vector2(cx-149,h-40-b),"km/h",14,muted)
	text(Vector2(cx+89,h-66-b),"R" if car.reverse else str(car.gear),54,mint,true)
	text(Vector2(cx+79,h-41-b),"AUTO",12,muted)
	text(Vector2(cx-155,h-188-b),"ABS",12,mint if car.abs_active else muted if car.driving_mode<2 else Color(.4,.42,.45))
	text(Vector2(cx-110,h-188-b),"TCS",12,mint if car.tcs_active else muted if car.driving_mode<2 else Color(.4,.42,.45))
	text(Vector2(cx-54,h-188-b),"%+.2f G"%car.lateral_g,12,muted,true)
	text(Vector2(cx+46,h-188-b),"AERO %.0f N"%car.downforce,12,muted,true)
	# Four contact/load indicators. Meaningful live suspension telemetry.
	for i in range(4):
		var bx=cx-155+i*79;var load_fraction=clampf(car.wheels[i].load/6500.0,0,1)
		draw_rect(Rect2(bx,h-223-b,64,5),Color(.18,.23,.27,.8));draw_rect(Rect2(bx,h-223-b,64*load_fraction,5),mint if car.wheels[i].ground else UiTheme.RED_WARN)
		text(Vector2(bx,h-229-b),["DI","DD","TI","TD"][i],10,muted)
	# Toast de mensajes: centrado por defecto, pero sin pisar el minimapa ni salirse de pantalla.
	if session.message_time>0:
		var width=minf(540.0,w-l-32)
		var pos=Vector2(maxf(16+l,cx-width*.5),95+t)
		var min_x=216+l # borde derecho del minimapa + margen
		if pos.x<min_x:pos=Vector2(maxf(16+l,min_x),283+t) # colisión con el minimapa: baja bajo él
		pos.x=clampf(pos.x,16+l,maxf(16+l,w-16-width))
		panel(Rect2(pos,Vector2(width,42)),UiTheme.HUD_TOAST,true)
		text(pos+Vector2(19,27),session.message,17,mint)
