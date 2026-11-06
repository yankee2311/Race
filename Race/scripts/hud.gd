extends Control
const Catalog=preload("res://scripts/track_catalog.gd")
const Safe=preload("res://scripts/ui/safe_area.gd")
var car
var controls
var track
var session
var compact=false
var font:Font
var mono:Font
var _cached_track:Node3D
var _cached_rect=Rect2()
var _cached_map_transform=Transform2D()
var _cached_polyline=PackedVector2Array()
func _cache_map(map_rect:Rect2)->void:
	if track==_cached_track and map_rect==_cached_rect:return
	_cached_track=track;_cached_rect=map_rect;_cached_polyline.clear()
	if not is_instance_valid(track) or track.points.is_empty():return
	_cached_map_transform=Catalog.map_transform(track.points,map_rect)
	for point in track.points:_cached_polyline.append(_cached_map_transform*Vector2(point.x,point.z))
	_cached_polyline.append(_cached_polyline[0])
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=load("res://assets/regular.ttf");mono=load("res://assets/mono.ttf")
func text(at:Vector2,value:String,size_:int,color:Color=Color.WHITE,use_mono:bool=false):
	draw_string(mono if use_mono else font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_,color)
func panel(rect:Rect2):
	var style=StyleBoxFlat.new();style.bg_color=Color(.025,.04,.07,.88);style.set_corner_radius_all(10);draw_style_box(style,rect)
func _process(_dt):queue_redraw()
func _draw():
	if not is_instance_valid(car) or not is_instance_valid(session) or not session.playing:return
	var safe=Safe.rect(self);draw_set_transform(safe.position)
	var w=safe.size.x;var h=safe.size.y;var mint=Color("59e8c9");var muted=Color("a9bfd1")
	# The center is reserved for the track; goals stay on the top band.
	panel(Rect2(w*.5-215,14,430,94))
	var mode=session.rules.mode
	if mode==4:
		text(Vector2(w*.5-185,48),"DRIFT · %d PTS"%int(session.rules.score),27,mint)
		text(Vector2(w*.5-185,78),"COMBO ×%.1f · %.0f s RESTANTES"%[session.rules.combo,maxf(0,90-session.rules.elapsed)],17,Color.WHITE)
	elif mode in [5,6,8]:
		var target=402.0 if mode==8 else session.track.length_m*.75
		text(Vector2(w*.5-185,46),session.game_mode.to_upper()+" · "+session.time_string(session.rules.elapsed),21,mint)
		text(Vector2(w*.5-185,75),"QUEDAN %d m"%maxi(0,int(target-session.rules.travel)),20,Color.WHITE)
	elif mode==9:
		text(Vector2(w*.5-185,46),"ACADEMIA · %d/3"%mini(3,session.rules.academy_step+1),22,mint)
		text(Vector2(w*.5-185,75),session.rules.message,15,Color.WHITE)
	elif mode==7:
		text(Vector2(w*.5-185,46),"ELIMINACIÓN · %d/%d"%[session.rules.position,session.rivals.size()+1],20,mint)
		text(Vector2(w*.5-185,75),"CORTE EN %d s"%int(maxf(0,session.rules.elimination_at-session.rules.elapsed)),18,Color.WHITE)
	else:
		text(Vector2(w*.5-185,45),session.game_mode.to_upper()+"  ·  VUELTA %d"%(session.laps+1),21,mint)
		text(Vector2(w*.5-185,78),session.time_string(session.lap_time),26,Color.WHITE,true)
	panel(Rect2(18,20,166,146));_cache_map(Rect2(30,32,140,116))
	if _cached_polyline.size()<2:return
	var map_transform=_cached_map_transform
	draw_polyline(_cached_polyline,Color(.5,.65,.77,.65),4,true)
	for rival in session.rivals:draw_circle(map_transform*Vector2(rival.position.x,rival.position.z),3,Color("ff6584"))
	var pos=map_transform*Vector2(car.position.x,car.position.z);draw_circle(pos,5,mint)
	var fwd=-car.global_basis.z;draw_line(pos,pos+Vector2(fwd.x,fwd.z)*12,mint,2)
	if not session.rivals.is_empty():text(Vector2(24,191),"POS %d / %d"%[session.rules.position,session.rivals.size()+1],18,mint)
	if session.rules.mode in [0,1,2,3] and session.last_sector>0:text(Vector2(w*.5-145,136),"Δ MEJOR SECTOR %+.3f s"%session.sector_delta,17,mint if session.sector_delta<=0 else Color("ff6b80"))
	var cx=w*.5;panel(Rect2(cx-135,h-113,270,103))
	for i in range(20):draw_rect(Rect2(cx-109+i*11,h-101,8,6),mint if i/20.0<(car.rpm-900)/7300 else Color("253a4d"))
	text(Vector2(cx-107,h-43),"%03d"%roundi(car.speed_kmh),54,Color.WHITE,true)
	text(Vector2(cx+67,h-46),"R" if car.reverse else str(car.gear),40,mint,true)
	if not compact:
		text(Vector2(cx-106,h-22),"km/h   ·   %d RPM"%int(car.rpm),12,muted)
		text(Vector2(cx-106,h-5),"%s   %s   %s"%["ABS" if car.abs_active else "", "TCS" if car.tcs_active else "",controls.status],11,mint)
	if not session.rules.valid:text(Vector2(cx-104,h-135),"VUELTA INVALIDADA",14,Color("ff6b80"))
	if session.message_time>0:
		panel(Rect2(cx-300,200,600,40));text(Vector2(cx-282,226),session.message,16,mint)
	if session.rules.countdown>0:
		panel(Rect2(cx-55,h*.4,110,110));text(Vector2(cx-25,h*.4+78),str(ceili(session.rules.countdown)),68,mint,true)
