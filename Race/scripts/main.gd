extends Node3D
const CarScript=preload("res://scripts/car.gd")
const TrackScript=preload("res://scripts/track.gd")
const SierraScript=preload("res://scripts/sierra_track.gd")
const ExpansionScript=preload("res://scripts/expansion_track.gd")
const Catalog=preload("res://scripts/track_catalog.gd")
const Vehicles=preload("res://scripts/vehicles/vehicle_catalog.gd")
const SelectorScript=preload("res://scripts/track_selector.gd")
const ControlsScript=preload("res://scripts/controls.gd")
const HudScript=preload("res://scripts/hud.gd")
const LapTracker=preload("res://scripts/lap_tracker.gd")
const Rules=preload("res://scripts/gameplay/race_rules.gd")
const Safe=preload("res://scripts/ui/safe_area.gd")
const MobileProfile=preload("res://scripts/core/mobile_profile.gd")
const UXScript=preload("res://scripts/ui/race_ui.gd")
var profile=preload("res://scripts/core/profile.gd").new()
var rules=Rules.new()
var lap_tracker=LapTracker.new()
var selector
var ux
var car
var track
var controls
var hud
var camera:Camera3D
var ui:CanvasLayer
var menu:Control
var pause_menu:Control
var action_ui:Control
var results:Control
var result_label:Label
var continue_button:Button
var style_select:OptionButton
var control_select:OptionButton
var quality_select:OptionButton
var fps_select:OptionButton
var sensitivity:HSlider
var inversion:CheckButton
var sound:CheckButton
var shadows:CheckButton
var lefty:CheckButton
var vibration:CheckButton
var ghost_check:CheckButton
var audio_player
var ghost
var rain:CPUParticles3D
var rivals:Array=[]
var selected_track_id="sierra"
var loaded_track_id="lab"
var loading_track=false
var playing=false
var camera_mode=2
var lap_time=0.0
var best_lap=0.0
var laps=0
var message=""
var message_time=0.0
var game_mode="libre"
var config=ConfigFile.new()
var base_theme:Theme
var record_key=""
var menu_time=0.0
var skid_timer=0.0
var vibration_cooldown=0.0
var championship_round=0
var championship_scores=[0,0,0,0,0,0]
var championship_tracks=["arena","coast","sierra"]
var photo_ui:Control
var photo_mode=false
var sector_delta=0.0
var last_sector=0
var photo_angle=0.0
var photo_height=2.0
var daily_fast=0.0
var results_paid=false
var ranking_distance=0.0
var initial_environment:Environment
var screenshot_mode=false
var reset_hold_active=false
var lite_profile=false
var diagnostic_seconds=0.0

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS;get_tree().quit_on_go_back=false
	DisplayServer.screen_set_keep_on(true)
	if OS.get_name()=="Android":DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	profile.load_profile();config.load("user://settings.cfg")
	lite_profile=OS.get_name()=="Android" and MobileProfile.is_galaxy_a05(OS.get_model_name())
	if lite_profile:
		MobileProfile.apply_lite_defaults(config)
		MobileProfile.configure_engine(true)
		config.save("user://settings.cfg")
	print("RACE_DIAG boot version=0.4.0 model=%s lite=%s physics_hz=%d"%[OS.get_model_name(),str(lite_profile),Engine.physics_ticks_per_second])
	selected_track_id=Catalog.get_entry(config.get_value("session","selected_track","sierra")).id
	track=TrackScript.new();add_child(track)
	car=CarScript.new();add_child(car);car.transform=track.start_transform;car.freeze=true
	camera=Camera3D.new();camera.near=.06;camera.far=4000;add_child(camera);camera.make_current()
	ui=CanvasLayer.new();add_child(ui)
	base_theme=Theme.new();base_theme.default_font=load("res://assets/regular.ttf");base_theme.default_font_size=18
	for state in ["normal","hover","pressed","focus"]:
		var sb=StyleBoxFlat.new();sb.bg_color=Color("203347") if state=="normal" else Color("35556c");sb.set_corner_radius_all(8)
		sb.content_margin_left=14;sb.content_margin_right=14;sb.content_margin_top=8;sb.content_margin_bottom=8
		base_theme.set_stylebox(state,"Button",sb);base_theme.set_stylebox(state,"OptionButton",sb)
	controls=ControlsScript.new();ui.add_child(controls);controls.sensors_missing.connect(func():control_select.select(0);notify("Sensor no disponible. Botones activados."))
	hud=HudScript.new();hud.car=car;hud.controls=controls;hud.track=track;hud.session=self;ui.add_child(hud)
	_build_settings()
	selector=SelectorScript.new();selector.theme=base_theme;selector.selected_id=selected_track_id;selector.profile=profile
	selector.vehicle_id=str(profile.data.settings.get("vehicle","gt77"));ui.add_child(selector)
	selector.selected.connect(_select_track);selector.start_requested.connect(func():championship_round=0;championship_scores=[0,0,0,0,0,0];_start())
	selector.settings_requested.connect(func():selector.hide();menu.show())
	selector.vehicle_selected.connect(_preview_vehicle)
	selector.preview_requested.connect(func():selector.hide();_open_photo())
	selector.upgrade_requested.connect(func(component):profile.buy(selector.vehicle_id,component);selector.refresh_profile())
	_build_actions();_build_pause();_build_results();_build_photo()
	audio_player=preload("res://scripts/engine_audio.gd").new();audio_player.car=car;add_child(audio_player)
	ghost=preload("res://scripts/gameplay/ghost.gd").new();add_child(ghost);ghost.hide()
	_apply_settings();_preview_vehicle(selector.vehicle_id)
	hud.compact=bool(config.get_value("interface","hud_compact",false))
	controls.pedal_full=bool(config.get_value("interface","pedal_full",false))
	var stored_scales=config.get_value("interface","zone_scales",{})
	if stored_scales is Dictionary:controls.zone_scales=stored_scales
	var stored_offsets=config.get_value("interface","zone_offsets",{})
	if stored_offsets is Dictionary:
		for zone in stored_offsets:
			var vec=stored_offsets[zone]
			if vec is Array and vec.size()==2:
				controls.zone_offsets[str(zone)]=Vector2(float(vec[0]),float(vec[1]))
	# Godot --script regression tests continue to exercise the original 0.3 adapter.
	if DisplayServer.get_name()!="headless" and not OS.get_cmdline_args().has("--script"):
		ux=UXScript.new()
		ux.game=self
		ux.theme=base_theme
		ui.add_child(ux)
		selector.hide()

func label_(parent:Node,text_:String,font_size:int=18)->Label:
	var label=Label.new();label.text=text_;label.add_theme_font_size_override("font_size",font_size);parent.add_child(label);return label
func button(parent:Node,text_:String,callback:Callable)->Button:
	var b=Button.new();b.text=text_;b.theme=base_theme;b.custom_minimum_size.y=44;b.pressed.connect(callback);parent.add_child(b);return b
func choose(parent:Node,caption:String,items:Array,section:String,key:String,default:int)->OptionButton:
	label_(parent,caption,14)
	var o=OptionButton.new();o.theme=base_theme;o.custom_minimum_size.y=44
	for item in items:o.add_item(item)
	o.select(clampi(int(config.get_value(section,key,default)),0,items.size()-1));parent.add_child(o);return o
func toggle(parent:Node,caption:String,key:String,default:bool)->CheckButton:
	var b=CheckButton.new();b.text=caption;b.theme=base_theme;b.button_pressed=config.get_value("drive",key,default);b.custom_minimum_size.y=40;parent.add_child(b);return b
func overlay()->Control:
	var root=Control.new();root.theme=base_theme;root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(root)
	var bg=ColorRect.new();bg.color=Color(.025,.045,.075,.96);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(bg)
	var margin=MarginContainer.new();margin.name="Safe";root.add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;margin.add_child(scroll)
	var content=VBoxContainer.new();content.name="Content";content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",10);scroll.add_child(content)
	root.hide();return root
func content(root:Control)->VBoxContainer:return root.get_node("Safe").get_child(0).get_child(0)
func _build_settings():
	menu=overlay();var box=content(menu);label_(box,"AJUSTES DE CONDUCCIÓN",30)
	var columns=HBoxContainer.new();columns.add_theme_constant_override("separation",24);box.add_child(columns)
	var a=VBoxContainer.new();a.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(a)
	var b=VBoxContainer.new();b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(b)
	style_select=choose(a,"MANEJO",["Arcade deportivo · estabilidad + ABS + TCS","Sport · ABS + TCS","Simulación · sin ayudas"],"drive","style",0)
	control_select=choose(a,"CONTROLES",["Botones","Inclinación","Volante virtual"],"drive","controls",0)
	label_(a,"Sensibilidad de inclinación / volante",14);sensitivity=HSlider.new();sensitivity.min_value=20;sensitivity.max_value=55;sensitivity.value=config.get_value("drive","angle",32);sensitivity.custom_minimum_size.y=36;a.add_child(sensitivity)
	inversion=toggle(a,"Invertir inclinación","invert",false);lefty=toggle(a,"Modo zurdo · invertir posición de controles","lefty",false)
	ghost_check=toggle(a,"Mostrar fantasma personal","ghost",true)
	quality_select=choose(b,"CALIDAD",["Baja · 70 % resolución 3D","Media · 85 % resolución 3D","Alta · resolución nativa"],"drive","quality",1)
	fps_select=choose(b,"LÍMITE DE CUADROS",["30 FPS","60 FPS"],"drive","fps",1)
	shadows=toggle(b,"Sombras dinámicas","shadows",true);sound=toggle(b,"Audio de motor y neumáticos","sound",true);vibration=toggle(b,"Vibración","vibration",true)
	label_(box,"Teclado: WASD / flechas · Espacio: freno de mano · C: cámara · R: recolocar · Esc: pausa.\nControl Bluetooth: stick izquierdo, RT/LT, A: freno de mano, Start: pausa.",15).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(box,"GUARDAR Y VOLVER",func():_apply_settings();menu.hide();selector.show())
func _build_actions():
	action_ui=Control.new();action_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);action_ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(action_ui);action_ui.hide()
	var row=HBoxContainer.new();row.name="Top";action_ui.add_child(row)
	button(row,"CÁMARA",_cycle_camera)
	var reset=Button.new();reset.text="MANTENER RECOLOCAR";reset.theme=base_theme;reset.custom_minimum_size.y=44;row.add_child(reset)
	reset.button_down.connect(_begin_reset_hold)
	reset.button_up.connect(func():reset_hold_active=false)
	button(row,"PAUSA",_pause)
	var reverse=button(action_ui,"R / D",_reverse);reverse.name="Reverse"
func _build_pause():
	pause_menu=overlay();var box=content(pause_menu);label_(box,"PAUSA EN BOXES",30)
	button(box,"CONTINUAR",_resume);button(box,"CENTRAR INCLINACIÓN",func():controls.calibrate();_resume())
	button(box,"RECOLOCAR COCHE",func():_resume();_reset())
	button(box,"MODO FOTO · OCULTAR INTERFAZ",_open_photo)
	button(box,"VOLVER AL GARAJE",_back_to_menu)
func _build_photo():
	photo_ui=Control.new();photo_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);photo_ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(photo_ui)
	var row=HBoxContainer.new();row.name="Buttons";row.position=Vector2(24,24);photo_ui.add_child(row)
	button(row,"VOLVER",_exit_photo);button(row,"GUARDAR FOTO",_save_photo)
	var help=label_(row,"  Arrastra para girar · C para guardar",16);help.mouse_filter=Control.MOUSE_FILTER_IGNORE
	photo_ui.hide()
func _open_photo():
	if is_instance_valid(ux):ux.hide()
	if audio_player:audio_player.set_active(false)
	photo_mode=true;photo_angle=0;get_tree().paused=true;pause_menu.hide();action_ui.hide();hud.hide();controls.hide();photo_ui.show()
func _build_results():
	results=overlay();var box=content(results);label_(box,"RESULTADOS",34)
	result_label=label_(box,"",22);result_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	continue_button=button(box,"VOLVER AL GARAJE",_continue_event)
	button(box,"GARAJE",_back_to_menu)
func _apply_settings():
	base_theme.default_font_size=20 if bool(config.get_value("interface","large_text",false)) else 18
	car.driving_mode=style_select.selected;controls.mode=control_select.selected;controls.full_angle=sensitivity.value;controls.invert_tilt=inversion.button_pressed;controls.left_handed=lefty.button_pressed
	Engine.max_fps=30 if fps_select.selected==0 else 60
	get_viewport().scaling_3d_scale=[.7,.85,1.0][quality_select.selected]
	if track:track.sky_sun.shadow_enabled=shadows.button_pressed and quality_select.selected>0
	if audio_player:audio_player.set_enabled(sound.button_pressed)
	if ghost:ghost.enabled=ghost_check.button_pressed
	var values={"style":style_select.selected,"controls":control_select.selected,"angle":sensitivity.value,"invert":inversion.button_pressed,"lefty":lefty.button_pressed,"quality":quality_select.selected,"fps":fps_select.selected,"shadows":shadows.button_pressed,"sound":sound.button_pressed,"vibration":vibration.button_pressed,"ghost":ghost_check.button_pressed}
	for key in values:config.set_value("drive",key,values[key])
	config.save("user://settings.cfg")
func _preview_vehicle(id:String):
	if not car or not selector:return
	car.configure(Vehicles.get_vehicle(id),selector.paint_colors[selector.paint_choice.selected])
	if id=="gt77":car.set_skin(selector.paint_choice.selected%3)
	profile.data.settings.vehicle=id;profile.save()
func _select_track(id:String):
	selected_track_id=id;config.set_value("session","selected_track",id);config.save("user://settings.cfg")
func _start():
	if loading_track:return
	loading_track=true;selector.set_loading(true);car.freeze=true;controls.active=false;playing=false;hud.hide();get_tree().paused=false
	if audio_player:audio_player.set_active(false)
	await get_tree().process_frame
	for rival in rivals:rival.queue_free()
	rivals.clear()
	if is_instance_valid(rain):rain.queue_free();rain=null
	if selector.session_mode.selected==3:selected_track_id=championship_tracks[championship_round]
	var next_track
	if selector.session_mode.selected==8:next_track=preload("res://scripts/drag_track.gd").new()
	elif selected_track_id=="sierra":
		if not ResourceLoader.has_cached(Catalog.SIERRA_SCENE):ResourceLoader.load_threaded_request(Catalog.SIERRA_SCENE)
		while ResourceLoader.load_threaded_get_status(Catalog.SIERRA_SCENE)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await get_tree().process_frame
		var packed=load(Catalog.SIERRA_SCENE) if ResourceLoader.has_cached(Catalog.SIERRA_SCENE) else ResourceLoader.load_threaded_get(Catalog.SIERRA_SCENE)
		if packed==null:selector.set_loading(false,"No se pudo cargar Sierra");loading_track=false;return
		next_track=SierraScript.new();next_track.packed=packed
	elif selected_track_id=="lab":next_track=TrackScript.new()
	else:next_track=ExpansionScript.new();next_track.definition=Catalog.get_entry(selected_track_id)
	var old_track=track
	remove_child(old_track);old_track.queue_free()
	# Allow the old track and its GPU resources to be released before loading the new scene.
	await get_tree().process_frame
	track=next_track;add_child(track);loaded_track_id=selected_track_id;hud.track=track
	if selector.reverse_choice.button_pressed and selector.session_mode.selected!=8:
		var reverse_points=PackedVector3Array([track.points[0]])
		for i in range(track.points.size()-1,0,-1):reverse_points.append(track.points[i])
		track.points=reverse_points;track._index_path()
		track.start_transform=Transform3D(Basis.looking_at(track.tangents[-2],Vector3.UP),track.points[-2]+Vector3.UP*.8)
	_preview_vehicle(selector.vehicle_id);_apply_settings();_apply_weather()
	car.engine_multiplier=1.0+profile.level(selector.vehicle_id,"motor")*.05
	car.grip_multiplier=1.0+profile.level(selector.vehicle_id,"grip")*.03
	car.brake_multiplier=1.0+profile.level(selector.vehicle_id,"brakes")*.05
	record_key="v03/%s/%s/%d/%d/%s/%d%d%d"%[track.track_id,selector.vehicle_id,style_select.selected,selector.weather_choice.selected,str(selector.reverse_choice.button_pressed),profile.level(selector.vehicle_id,"motor"),profile.level(selector.vehicle_id,"grip"),profile.level(selector.vehicle_id,"brakes")]
	best_lap=float(profile.data.records.get(record_key,0));lap_time=0;laps=0;daily_fast=0;results_paid=false
	rules.begin(selector.session_mode.selected,track.length_m,track.progress_at(track.start_transform.origin));game_mode=Rules.MODES[rules.mode]
	lap_tracker.reset(track.length_m,track.progress_at(track.start_transform.origin))
	ghost.configure(record_key,Vehicles.get_vehicle(selector.vehicle_id));ghost.enabled=ghost_check.button_pressed
	if rules.mode in [2,3,7]:
		for i in range(5):
			var rival=preload("res://scripts/gameplay/opponent.gd").new();add_child(rival);rival.setup(track,Vehicles.get_vehicle(selector.vehicle_id),i,[.65,.85,1.0][selector.difficulty_choice.selected]);rivals.append(rival)
	car.global_transform=track.start_transform;car.request_reset(track.start_transform);car.physics_enabled=true;car.visible=true;car.freeze=false
	playing=true;menu.hide();selector.hide();selector.set_loading(false);results.hide();pause_menu.hide();action_ui.show();hud.show();controls.show();controls.active=true;controls.clear();controls.calibrate()
	if is_instance_valid(ux):ux.hide()
	camera.position=car.global_transform*Vector3(0,2.7,6.3);camera.look_at(car.position-car.basis.z*3,Vector3.UP);camera.make_current()
	loading_track=false
	if audio_player:audio_player.set_active(true)
	print("RACE_DIAG session=start track=%s vehicle=%s mode=%s"%[track.track_id,selector.vehicle_id,game_mode])
	notify("Cruza la meta para iniciar tu vuelta" if rules.mode in [0,1] else game_mode)
func _apply_weather():
	var weather=selector.weather_choice.selected
	car.surface_multiplier=.73 if weather==1 else 1.0
	var env_node=track.get_child(0)
	if env_node is WorldEnvironment:
		var env:Environment=env_node.environment
		var sky_mat=env.sky.sky_material
		if weather==2:
			track.sky_sun.rotation_degrees.x=-12;track.sky_sun.light_color=Color("ffb37c");sky_mat.sky_top_color=Color("526385");sky_mat.sky_horizon_color=Color("eea276")
		elif weather==3:
			track.sky_sun.light_energy=.22;env.ambient_light_energy=.7;sky_mat.sky_top_color=Color("080e24");sky_mat.sky_horizon_color=Color("34415e")
		elif weather==1:
			track.sky_sun.light_energy=.55;sky_mat.sky_top_color=Color("677b91");sky_mat.sky_horizon_color=Color("9eacb5")
	if weather==1 and quality_select.selected>0:
		rain=CPUParticles3D.new();rain.amount=90;rain.lifetime=1.0;rain.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;rain.emission_box_extents=Vector3(12,1,12);rain.direction=Vector3(0,-1,0);rain.initial_velocity_min=18;rain.initial_velocity_max=24
		var mesh=BoxMesh.new();mesh.size=Vector3(.025,.7,.025);rain.mesh=mesh;rain.color=Color(.65,.8,.95,.45);add_child(rain)
func _pause():
	if not playing or rules.completed:return
	if audio_player:audio_player.set_active(false)
	reset_hold_active=false;controls.clear();get_tree().paused=true;pause_menu.show()
	if is_instance_valid(ux):pause_menu.hide();ux.show_pause()
func _resume():
	if is_instance_valid(ux):ux.hide()
	photo_mode=false;photo_ui.hide();hud.show();controls.show();action_ui.visible=playing;get_tree().paused=false;pause_menu.hide();controls.clear();controls.calibrate()
	if audio_player:audio_player.set_active(playing)
	if not playing:selector.show()
func _exit_photo():
	if photo_mode and is_instance_valid(ux):
		photo_mode=false;photo_ui.hide()
		if ux.photo_origin=="pause":
			get_tree().paused=true;ux.show_pause()
		else:
			get_tree().paused=false;ux.show();ux._to("vehicle")
		return
	_resume()
func _back_to_menu():
	if audio_player:audio_player.set_active(false)
	photo_mode=false;photo_ui.hide();get_tree().paused=false;pause_menu.hide();results.hide();playing=false;menu.hide();selector.show();selector.refresh_profile();action_ui.hide();controls.active=false;controls.show();controls.clear();reset_hold_active=false;hud.show();car.freeze=true;car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO;ghost.hide()
	for rival in rivals:rival.queue_free()
	rivals.clear()
	if is_instance_valid(ux):selector.hide();ux.show();ux._tab("home")
func _begin_reset_hold():
	if not playing:return
	reset_hold_active=true
	var timer=get_tree().create_timer(.65,false)
	timer.timeout.connect(func():
		if reset_hold_active and playing and not get_tree().paused:
			reset_hold_active=false
			_reset())
func _reset():
	if not playing:return
	var target=track.reset_near(car.position);car.request_reset(target);controls.clear();lap_time=0
	lap_tracker.reset(track.length_m,track.progress_at(target.origin));rules.invalidate();rules.previous=track.progress_at(target.origin);ghost.new_lap()
	if rules.mode in [5,6,8]:rules.completed=true;rules.message="Intento invalidado por recolocación";_finish_event()
	notify("Recolocado · vuelta invalidada")
func _reverse():
	if car.toggle_reverse():notify("REVERSA" if car.reverse else "MARCHA ADELANTE")
	else:notify("Reduce a 5 km/h o menos para cambiar R / D")
func _cycle_camera():camera_mode=(camera_mode+1)%3
func notify(value:String):message=value;message_time=4.0
func _unhandled_input(event):
	if photo_mode:
		if event is InputEventScreenDrag:photo_angle-=event.relative.x*.006;photo_height=clampf(photo_height-event.relative.y*.01,.5,12)
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):photo_angle-=event.relative.x*.006
	if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START:
		if get_tree().paused:_resume()
		else:_pause()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if is_instance_valid(ux) and ux.visible:ux.back()
			elif get_tree().paused:_resume()
			elif menu.visible:menu.hide();selector.show()
			else:_pause()
		elif event.keycode==KEY_C and playing:
			if photo_mode:_save_photo()
			else:_cycle_camera()
		elif event.keycode==KEY_R and playing:_reset()
		elif event.keycode==KEY_V and playing:_reverse()
func _save_photo():
	photo_ui.hide()
	await RenderingServer.frame_post_draw
	var file="user://RACE_photo_%d.png"%Time.get_unix_time_from_system()
	var error=get_viewport().get_texture().get_image().save_png(file)
	photo_ui.show()
	notify("Foto guardada en datos de la app" if error==OK else "No se pudo guardar la foto")
func _notification(what):
	if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		if playing:_pause()
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(ux) and ux.visible:ux.back()
		elif get_tree().paused:_exit_photo() if photo_mode else _resume()
		elif playing:_pause()
		elif menu.visible:menu.hide();selector.show()
		else:get_tree().quit()
func _physics_process(dt):
	if not playing or get_tree().paused or rules.completed:return
	if not car.global_transform.is_finite() or not car.linear_velocity.is_finite():
		print("RACE_DIAG physics=recover_invalid_transform")
		car.request_reset(track.start_transform)
		return
	var progress=track.progress_at(car.position)
	var road_distance=track.road_distance(car.position)
	var on_road=road_distance<11.0 and car.contacts>=2
	var local_velocity=car.global_basis.inverse()*car.linear_velocity
	var angle=atan2(local_velocity.x,maxf(absf(local_velocity.z),1))
	rules.tick(dt,progress,on_road,car.speed_kmh,angle,controls.throttle,controls.brake)
	var ready=rules.countdown<=0
	car.throttle_input=controls.throttle if ready else 0.0;car.brake_input=controls.brake if ready else 1.0;car.steering_input=controls.steering if ready else 0.0;car.handbrake_input=controls.handbrake if ready else 1.0
	if not ready:return
	var race_goal=track.length_m*rules.target_laps+track.length_m-track.progress_at(track.start_transform.origin)
	for rival in rivals:
		rival.tick(dt,car.position)
		if rules.mode in [2,3] and not rival.finished and rival.distance>=race_goal:
			rival.finished=true;rival.finish_time=rules.elapsed;rival.distance=race_goal;rival.place()
	_update_ranking(progress)
	if rules.mode==7 and rules.elapsed>=rules.elimination_at:
		rules.elimination_at+=30
		if rules.position==rivals.size()+1:rules.completed=true;rules.message="Has sido eliminado"
		elif not rivals.is_empty():
			var last=rivals[0]
			for rival in rivals:
				if rival.distance<last.distance:last=rival
			rivals.erase(last);last.queue_free();notify("Rival eliminado")
			if rivals.is_empty():rules.completed=true;rules.message="Victoria en eliminación"
	if lap_tracker.armed:lap_time+=dt;ghost.tick(dt,car)
	var checkpoint_before=lap_tracker.next_checkpoint
	var finished=lap_tracker.update(progress)
	if lap_tracker.next_checkpoint>checkpoint_before:
		rules.checkpoint_passed(checkpoint_before);last_sector=checkpoint_before
		var sector_time=float(rules.sectors[-1]);var key=record_key+"/sector/"+str(checkpoint_before)
		sector_delta=sector_time-float(profile.data.records.get(key,sector_time))
		if rules.valid:profile.record(key,sector_time)
	if finished:
		var valid=rules.finish_lap()
		if valid and lap_time>3:
			laps+=1
			if profile.record(record_key,lap_time):best_lap=lap_time;ghost.save_best();notify("RÉCORD PERSONAL  "+time_string(lap_time))
			else:notify("VUELTA  "+time_string(lap_time))
			profile.reward(100,30);_daily("vuelta",1,1,200)
		else:notify("VUELTA INVALIDADA")
	if lap_tracker.crossed_start:
		lap_time=0;ghost.new_lap();rules.valid=true;rules.checkpoint=1;rules.last_sector_time=rules.elapsed
	if car.speed_kmh>=150:daily_fast+=dt;_daily("velocidad",daily_fast,10,250)
	_daily("drift",rules.drift_distance,500,300)
	skid_timer+=dt
	if skid_timer>.1:
		skid_timer=0
		for wheel in car.wheels:
			if wheel.ground and car.speed_kmh>15 and (absf(wheel.slip)>.3 or absf(wheel.lat_slip)>.13):track.add_skid(wheel.point,-car.global_basis.z,wheel.normal)
	if car.position.y<-12:_reset()
	vibration_cooldown=maxf(0,vibration_cooldown-dt)
	if vibration.button_pressed and vibration_cooldown<=0 and car.speed_kmh>20 and car.get_contact_count()>0:Input.vibrate_handheld(30,.3);vibration_cooldown=.5
	if rules.completed:_update_ranking(progress);_finish_event()
func _update_ranking(progress:float):
	# Only accepted laps advance classification. A shortcut never adds a lap to the ranking.
	ranking_distance=float(laps+(1 if lap_tracker.armed else 0))*track.length_m+progress-track.progress_at(track.start_transform.origin)
	rules.position=1
	for rival in rivals:
		if rival.finished or rival.distance>ranking_distance:rules.position+=1

func _daily(id:String,value:float,target:float,reward:int):
	if value<target:return
	var date=Time.get_date_string_from_system();var key=date+"/"+id
	if profile.data.daily.has(key):return
	profile.data.daily[key]=true;profile.reward(reward,50);notify("DESAFÍO DIARIO  +%d CR"%reward)
func _finish_event():
	if results_paid:return
	results_paid=true;controls.clear();controls.active=false;car.freeze=true;action_ui.hide();ghost.hide();results.show()
	if audio_player:audio_player.set_active(false)
	if is_instance_valid(ux):results.hide();ux.show_results()
	var success=rules.mode not in [0,1] and rules.valid and not ("invalidado" in rules.message or "agotado" in rules.message or "eliminado" in rules.message)
	var reward=maxi(100,700-rules.position*80) if success else 0
	if success:profile.reward(reward,100)
	var text="%s\n%s\nTiempo: %s\nPosición: %d / %d\nPuntos drift: %d\nRecompensa: %d CR"%[game_mode,rules.message,time_string(rules.elapsed),rules.position,rivals.size()+1,int(rules.score),reward]
	if rules.mode==3:
		var ranking=[{"id":0,"distance":ranking_distance,"time":rules.elapsed}]
		for i in range(rivals.size()):ranking.append({"id":i+1,"distance":rivals[i].distance,"time":rivals[i].finish_time})
		ranking.sort_custom(func(a,b):return a.time<b.time if a.time!=b.time else a.distance>b.distance)
		for i in range(ranking.size()):championship_scores[ranking[i].id]+=[10,8,6,4,2,1][i]
		text+="\n\nCAMPEONATO · RONDA %d / 3\n"%(championship_round+1)
		for i in range(championship_scores.size()):text+=("TÚ" if i==0 else ["VEGA","CRUZ","SOL","NOVA","RÍOS"][i-1])+": %d puntos\n"%championship_scores[i]
	result_label.text=text;continue_button.text="SIGUIENTE RONDA" if rules.mode==3 and championship_round<2 else "VOLVER AL GARAJE"
func _continue_event():
	if rules.mode==3 and championship_round<2:championship_round+=1;results.hide();_start()
	else:_back_to_menu()
func _process(dt):
	if not is_instance_valid(car):return
	message_time=maxf(0,message_time-dt)
	if OS.get_name()=="Android" and playing and not get_tree().paused:
		diagnostic_seconds+=dt
		if diagnostic_seconds>=10.0:
			diagnostic_seconds=0.0
			print("RACE_DIAG tick track=%s vehicle=%s fps=%.1f physics_ms=%.2f mem_mb=%.1f nodes=%d objects=%d speed=%.1f"%[track.track_id,car.vehicle_data.id,Performance.get_monitor(Performance.TIME_FPS),Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),int(Performance.get_monitor(Performance.OBJECT_COUNT)),car.speed_kmh])
	for panel in [menu,pause_menu,results]:
		if panel and panel.visible:
			var safe=Safe.rect(panel);panel.get_node("Safe").position=safe.position;panel.get_node("Safe").size=safe.size
	if action_ui:
		var safe=Safe.rect(action_ui)
		photo_ui.get_node("Buttons").position=safe.position+Vector2(24,24)
		var row=action_ui.get_node("Top");row.position=Vector2(safe.end.x-row.size.x-20,safe.position.y+18)
		action_ui.get_node("Reverse").position=Vector2(safe.position.x+24,safe.end.y-265)
	if is_instance_valid(rain):rain.position=car.position+Vector3.UP*12
	if photo_mode:
		camera.position=car.position+Vector3(sin(photo_angle)*7,photo_height,cos(photo_angle)*7);camera.look_at(car.position,Vector3.UP);return
	if not car.global_transform.is_finite():return
	if not playing:
		menu_time+=dt;var angle=menu_time*.15
		camera.position=car.position+Vector3(sin(angle)*6.6,2,-cos(angle)*6.6);camera.fov=52;camera.look_at(car.position,Vector3.UP)
	elif not get_tree().paused:
		var basis=car.global_basis
		if camera_mode==2:
			var target=car.position+basis*Vector3(0,2.55,6.6);var origin=car.position+Vector3.UP*.7
			var hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,target,1,[car.get_rid()]))
			if not hit.is_empty():target=hit.position+(origin-hit.position).normalized()*.4
			camera.position=camera.position.lerp(target,1-exp(-dt*8));camera.fov=lerpf(camera.fov,66+minf(car.speed_kmh/22,12),minf(dt*3,1));camera.look_at(car.position+basis*Vector3(0,.25,-1.5),Vector3.UP)
		else:
			camera.position=car.global_transform*(Vector3(0,.33,-1.36) if camera_mode==0 else Vector3(-.32,.53,-.22));camera.fov=76 if camera_mode==0 else 80;camera.look_at(camera.position-basis.z*20+basis.y*.02,basis.y)
func time_string(seconds:float)->String:
	var ms=roundi(seconds*1000);return "%02d:%02d.%03d"%[ms/60000,(ms/1000)%60,ms%1000]
