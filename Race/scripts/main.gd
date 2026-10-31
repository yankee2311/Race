extends Node3D

const CarScript=preload("res://scripts/car.gd")
const TrackScript=preload("res://scripts/track.gd")
const ControlsScript=preload("res://scripts/controls.gd")
const HudScript=preload("res://scripts/hud.gd")
const SelectorScript=preload("res://scripts/track_selector.gd")
const Catalog=preload("res://scripts/track_catalog.gd")
const UiTheme=preload("res://scripts/ui_theme.gd")
const SierraScript=preload("res://scripts/sierra_track.gd")
const LapTracker=preload("res://scripts/lap_tracker.gd")
var selector
var selected_track_id="sierra"
var loaded_track_id="lab"
var loading_track=false
var lap_tracker=LapTracker.new()
const AudioScript=preload("res://scripts/engine_audio.gd")
var car
var track
var controls
var hud
var camera:Camera3D
var ui:CanvasLayer
var menu:Control
var pause_menu:Control
var action_ui:Control
var style_select:OptionButton
var control_select:OptionButton
var skin_select:OptionButton
var camera_button:Button
var calibrate_button:Button
var reverse_button:Button
var sensitivity:HSlider
var inversion:CheckButton
var sound:CheckButton
var shadows:CheckButton
var audio_player
var playing=false
var camera_mode=2
var menu_time=0.0
var lap_time=0.0
var best_lap=0.0
var laps=0
var next_sector=1
var last_z=0.0
var message=""
var message_time=0.0
var skid_timer=0.0
var cached_size=Vector2.ZERO
var config=ConfigFile.new()
var base_theme:Theme
var screenshot_mode=false
var vibration_cooldown=0.0
var game_mode="libre"
var snapshot_timer=0.0

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back=false
	DisplayServer.screen_set_keep_on(true)
	Engine.max_fps=60
	config.load("user://settings.cfg")
	selected_track_id=Catalog.get_entry(config.get_value("session","selected_track","sierra")).id
	best_lap=config.get_value("records",selected_track_id,0.0)
	track=TrackScript.new();add_child(track)
	car=CarScript.new();add_child(car);car.transform=track.start_transform;car.freeze=true
	car.visible=true
	camera=Camera3D.new();camera.near=.06;camera.far=4000;add_child(camera);camera.make_current()
	ui=CanvasLayer.new();add_child(ui)
	base_theme=UiTheme.make_theme()
	controls=ControlsScript.new();ui.add_child(controls);controls.sensors_missing.connect(func():control_select.select(0);notify("Sensor no disponible: se activaron los botones."))
	hud=HudScript.new();hud.car=car;hud.controls=controls;hud.track=track;hud.session=self;ui.add_child(hud)
	_build_menu()
	menu.hide()
	selector=SelectorScript.new();selector.theme=base_theme;selector.selected_id=selected_track_id
	ui.add_child(selector)
	selector.selected.connect(_select_track)
	selector.start_requested.connect(_start)
	selector.settings_requested.connect(func():selector.hide();menu.show())
	_build_action_ui()
	_build_pause()
	audio_player=AudioScript.new();audio_player.car=car;add_child(audio_player)
	_apply_settings()
	controls.calibrate()
	last_z=car.position.z
	if "--capture" in OS.get_cmdline_user_args():screenshot_mode=true

func label(parent:Control,text_:String,size_:int=18,color:Color=Color.WHITE)->Label:
	return UiTheme.label(parent,text_,size_,color)

func button(parent:Control,text_:String,callable_:Callable)->Button:
	var b=UiTheme.button(parent,text_,callable_)
	b.theme=base_theme
	return b

func option(parent:Control,items:Array,index:int)->OptionButton:
	var o=OptionButton.new();o.theme=base_theme;o.focus_mode=Control.FOCUS_NONE
	for item in items:o.add_item(item)
	o.select(index);parent.add_child(o);return o

func _build_menu():
	menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(menu)
	var panel=Panel.new();panel.position=Vector2(24,24);panel.size=Vector2(416,672)
	var sb=UiTheme.card(UiTheme.MENU_PANEL,20);panel.add_theme_stylebox_override("panel",sb);menu.add_child(panel)
	label(panel,"GT77",58).position=Vector2(28,17)
	label(panel,"DRIVE LAB  /  ANDROID",17,UiTheme.MINT).position=Vector2(31,86)
	label(panel,"Una máquina. Tu forma de conducir.",16,UiTheme.TEXT_SUB).position=Vector2(30,116)
	label(panel,"ESTILO DE MANEJO",12,UiTheme.TEXT_LABEL).position=Vector2(30,160)
	style_select=option(panel,["Asistido · ABS + TCS + estabilidad","Sport · ABS + TCS","Simulación · sin ayudas"],config.get_value("drive","style",1));style_select.position=Vector2(28,181);style_select.size=Vector2(360,44)
	label(panel,"CONTROLES",12,UiTheme.TEXT_LABEL).position=Vector2(30,240)
	control_select=option(panel,["Botones en pantalla","Giroscopio / inclinación"],config.get_value("drive","controls",0));control_select.position=Vector2(28,261);control_select.size=Vector2(360,44)
	label(panel,"PINTURA",12,UiTheme.TEXT_LABEL).position=Vector2(30,320)
	skin_select=option(panel,["77 · Rojo y grafito","77 · Arctic cyan","77 · Pearl white"],config.get_value("drive","skin",0));skin_select.position=Vector2(28,341);skin_select.size=Vector2(360,44);skin_select.item_selected.connect(func(index):car.set_skin(index))
	label(panel,"GIRO MÁXIMO DEL TELÉFONO",12,UiTheme.TEXT_LABEL).position=Vector2(30,403)
	sensitivity=HSlider.new();sensitivity.min_value=20;sensitivity.max_value=55;sensitivity.step=1;sensitivity.value=config.get_value("drive","angle",32.0);sensitivity.position=Vector2(30,429);sensitivity.size=Vector2(225,25);panel.add_child(sensitivity)
	var angle_label=label(panel,"32°",17,UiTheme.MINT);angle_label.position=Vector2(279,423);angle_label.text="%d°"%sensitivity.value;sensitivity.value_changed.connect(func(value):angle_label.text="%d°"%value)
	inversion=CheckButton.new();inversion.text="Invertir giro";inversion.theme=base_theme;inversion.position=Vector2(25,463);inversion.button_pressed=config.get_value("drive","invert",false);panel.add_child(inversion)
	sound=CheckButton.new();sound.text="Audio";sound.theme=base_theme;sound.position=Vector2(225,463);sound.button_pressed=config.get_value("drive","sound",true);panel.add_child(sound)
	shadows=CheckButton.new();shadows.text="Sombras · calidad visual";shadows.theme=base_theme;shadows.position=Vector2(25,505);shadows.button_pressed=config.get_value("drive","shadows",true);panel.add_child(shadows)
	var start=button(panel,"GUARDAR Y ELEGIR PISTA   →",func():_apply_settings();menu.hide();selector.show());start.position=Vector2(28,564);start.size=Vector2(360,58)
	var active=UiTheme.card(UiTheme.RED,10);start.add_theme_stylebox_override("normal",active)
	label(panel,"VERSIÓN 0.2.1  ·  DOS CIRCUITOS",11,UiTheme.TEXT_FAINT).position=Vector2(31,640)
	var note=label(menu,"SUSPENSIÓN POR RUEDA  /  AERODINÁMICA\nCAPÓ · ONBOARD · TERCERA PERSONA",14,Color(.92,.97,1,.9));note.position=Vector2(480,643);note.name="Note"

func _build_action_ui():
	action_ui=Control.new();action_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);action_ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(action_ui);action_ui.visible=false
	camera_button=button(action_ui,"CÁMARA",_cycle_camera)
	var pause=button(action_ui,"Ⅱ",_pause);pause.name="Pause"
	var reset=button(action_ui,"RECOLOCAR",_reset);reset.name="Reset"
	reverse_button=button(action_ui,"R / D",_reverse)
	calibrate_button=button(action_ui,"CENTRAR GIRO",func():controls.calibrate();notify("Giro centrado. Mantén el teléfono frente a ti."))

func _build_pause():
	pause_menu=Control.new();pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(pause_menu);pause_menu.visible=false
	var dim=ColorRect.new();dim.color=UiTheme.PAUSED_DIM;dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);pause_menu.add_child(dim)
	# Tarjeta central que se auto-dimensiona con su contenido (sin scale manual).
	var card=PanelContainer.new();card.name="Card"
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER);card.grow_horizontal=Control.GROW_DIRECTION_BOTH;card.grow_vertical=Control.GROW_DIRECTION_BOTH
	card.add_theme_stylebox_override("panel",UiTheme.card(Color(.025,.045,.07,.96),20,UiTheme.BORDER_SOFT,1))
	pause_menu.add_child(card)
	var margin=MarginContainer.new()
	margin.add_theme_constant_override("margin_left",30);margin.add_theme_constant_override("margin_right",30)
	margin.add_theme_constant_override("margin_top",26);margin.add_theme_constant_override("margin_bottom",26)
	card.add_child(margin)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",14);margin.add_child(box)
	var title=label(box,"PAUSA EN BOXES",30);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var sub=label(box,"EL CRONÓMETRO ESTÁ DETENIDO",12,UiTheme.TEXT_FAINT);sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for item in [["CONTINUAR",_resume],
	["CENTRAR GIRO",func():controls.calibrate();_resume();notify("Sensor calibrado.")],
	["RECOLOCAR COCHE",func():_resume();_reset()],
	["MENÚ Y AJUSTES",_back_to_menu]]:
		var b=button(box,item[0],item[1]);b.custom_minimum_size=Vector2(330,52)

func _apply_settings():
	car.driving_mode=style_select.selected;controls.mode=control_select.selected;controls.full_angle=sensitivity.value;controls.invert_tilt=inversion.button_pressed
	car.set_skin(skin_select.selected);track.sky_sun.shadow_enabled=shadows.button_pressed
	if audio_player:audio_player.enabled=sound.button_pressed
	config.set_value("drive","style",style_select.selected);config.set_value("drive","controls",control_select.selected);config.set_value("drive","skin",skin_select.selected);config.set_value("drive","angle",sensitivity.value);config.set_value("drive","invert",inversion.button_pressed);config.set_value("drive","sound",sound.button_pressed);config.set_value("drive","shadows",shadows.button_pressed);config.save("user://settings.cfg")

func _select_track(id:String):
	selected_track_id=id;best_lap=config.get_value("records",id,0.0)
	config.set_value("session","selected_track",id);config.save("user://settings.cfg")

func _start():
	if loading_track:return
	loading_track=true;selector.set_loading(true,"PREPARANDO "+Catalog.get_entry(selected_track_id).name.to_upper()+"…")
	car.freeze=true;controls.active=false
	await get_tree().process_frame
	if loaded_track_id!=selected_track_id:
		var resource:PackedScene=null
		if selected_track_id=="sierra":
			var error=ResourceLoader.load_threaded_request(Catalog.SIERRA_SCENE)
			if error!=OK:
				selector.set_loading(false);loading_track=false;notify("No se pudo cargar Sierra.");return
			var state=ResourceLoader.load_threaded_get_status(Catalog.SIERRA_SCENE)
			while state==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
				state=ResourceLoader.load_threaded_get_status(Catalog.SIERRA_SCENE)
			if state!=ResourceLoader.THREAD_LOAD_LOADED:
				selector.set_loading(false);loading_track=false;notify("No se pudo cargar Sierra.");return
			resource=ResourceLoader.load_threaded_get(Catalog.SIERRA_SCENE)
		remove_child(track);track.queue_free()
		await get_tree().process_frame
		if selected_track_id=="sierra":track=SierraScript.new();track.packed=resource
		else:track=TrackScript.new()
		add_child(track);loaded_track_id=selected_track_id;hud.track=track
	_apply_settings();playing=true;menu.hide();selector.hide();selector.set_loading(false);action_ui.show();controls.active=true;controls.clear();controls.calibrate();get_tree().paused=false
	car.freeze=true
	car.global_transform=track.start_transform
	car.visible=true
	car.physics_enabled=true
	car.request_reset(track.start_transform)
	car.freeze=false
	camera.make_current()
	lap_time=0;laps=0;best_lap=config.get_value("records",selected_track_id,0.0)
	lap_tracker.reset(track.length_m,track.progress_at(track.start_transform.origin))
	camera.h_offset=0;camera.position=car.global_transform*Vector3(0,2.7,6.3)
	camera.look_at(car.global_position-car.global_basis.z*3.0,Vector3.UP)
	loading_track=false
	notify(track.track_title+" · Cruza la meta para iniciar el tiempo.")

func _pause():
	if not playing:return
	controls.clear();get_tree().paused=true;pause_menu.show()

func _resume():
	get_tree().paused=false;pause_menu.hide();controls.clear();controls.calibrate()

func _back_to_menu():
	get_tree().paused=false;pause_menu.hide();playing=false;menu.hide();selector.show();action_ui.hide();controls.active=false;controls.clear();car.freeze=true;car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO;car.transform=track.start_transform
	for wheel in car.wheels:wheel.length=car.REST

func _reset():
	var target=track.reset_near(car.position)
	car.request_reset(target);controls.clear();lap_time=0
	lap_tracker.reset(track.length_m,track.progress_at(target.origin))
	notify("Coche recolocado. Se reinició el tiempo de vuelta.")

func _reverse():
	if car.toggle_reverse():notify("REVERSA · usa GAS para retroceder." if car.reverse else "MARCHA ADELANTE")
	else:notify("Detén el coche para cambiar entre R y D.")

func _cycle_camera():
	camera_mode=(camera_mode+1)%3;notify(["CÁMARA CAPÓ","CÁMARA ONBOARD","CÁMARA TERCERA PERSONA"][camera_mode])

func notify(text_:String):message=text_;message_time=4.5

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if not playing and menu.visible:menu.hide();selector.show()
			elif get_tree().paused:_resume()
			else:_pause()
		elif event.keycode==KEY_C and playing:_cycle_camera()
		elif event.keycode==KEY_R and playing:_reset()
		elif event.keycode==KEY_V and playing:_reverse()

func _notification(what):
	if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		if playing:_pause()
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_tree().paused:_resume()
		elif playing:_pause()
		elif menu.visible:menu.hide();selector.show()
		else:get_tree().quit()

func _physics_process(dt):
	if not playing or get_tree().paused:return
	car.throttle_input=controls.throttle;car.brake_input=controls.brake;car.steering_input=controls.steering;car.handbrake_input=controls.handbrake
	if lap_tracker.armed:lap_time+=dt
	var finished=lap_tracker.update(track.progress_at(car.position))
	if finished:
		laps+=1
		if best_lap<=0 or lap_time<best_lap:
			best_lap=lap_time;config.set_value("records",selected_track_id,best_lap);config.save("user://settings.cfg");notify("NUEVA MEJOR VUELTA  "+time_string(lap_time))
		else:notify("VUELTA COMPLETADA  "+time_string(lap_time))
	if lap_tracker.crossed_start:lap_time=0
	skid_timer+=dt
	if skid_timer>.07:
		skid_timer=0
		for wheel in car.wheels:
			if wheel.ground and car.speed_kmh>15 and (absf(wheel.slip)>.30 or absf(wheel.lat_slip)>.13):track.add_skid(wheel.point,-car.global_basis.z,wheel.normal)
	if car.position.y<-12:_reset()
	# Vibración breve vinculada a recorrido de suspensión, sólo en dispositivos compatibles.
	vibration_cooldown=maxf(0.0,vibration_cooldown-dt)
	if vibration_cooldown<=0.0 and car.speed_kmh>16.0:
		var impact=0.0
		for wheel in car.wheels:
			if wheel.ground:impact=maxf(impact,absf(wheel.compression))
		if impact>0.11:
			Input.vibrate_handheld(22,clampf(impact*1.6,0.12,0.55))
			vibration_cooldown=0.24

func _process(dt):
	if not is_instance_valid(car):return
	var screen=get_viewport().get_visible_rect().size
	if screen!=cached_size:
		cached_size=screen;_layout(screen)
	message_time=maxf(0,message_time-dt)
	var basis=car.global_basis
	if not playing:
		menu_time+=dt;var a=-.80+sin(menu_time*.16)*.20
		camera.position=car.position+Vector3(sin(a)*6.6,2.0,-cos(a)*6.6);camera.h_offset=-1.55;camera.fov=52
		camera.look_at(car.position+Vector3(0,.1,0),Vector3.UP)
	elif not get_tree().paused:
		camera.h_offset=0
		if camera_mode==2:
			var target=car.position+basis*Vector3(0,2.55,6.6)
			var origin=car.position+Vector3.UP*.7
			var ray=PhysicsRayQueryParameters3D.create(origin,target,1,[car.get_rid()]);var hit=get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty():target=hit.position+(origin-hit.position).normalized()*.4
			camera.position=camera.position.lerp(target,1-exp(-dt*8));camera.fov=lerpf(camera.fov,66+minf(car.speed_kmh/30,7),minf(dt*3,1))
			camera.look_at(car.position+basis*Vector3(0,.25,-1.5),Vector3.UP)
		else:
			var offset=Vector3(0,.33,-1.36) if camera_mode==0 else Vector3(-.32,.53,-.22)
			camera.position=car.global_transform*offset;camera.fov=76 if camera_mode==0 else 80
			camera.look_at(camera.position-basis.z*20+basis.y*.02,basis.y)
	calibrate_button.visible=playing and controls.mode==1
	reverse_button.text="R" if car.reverse else "D"
	camera_button.text=["CAPÓ","ONBOARD","3ª PERSONA"][camera_mode]
	if screenshot_mode:
		snapshot_timer+=dt
		if snapshot_timer>4:
			screenshot_mode=false;await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://menu.png")
			_start()
			await get_tree().create_timer(3).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://game.png")
			camera_mode=0
			await get_tree().create_timer(1).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://hood.png")
			camera_mode=1
			await get_tree().create_timer(1).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://onboard.png")
			get_tree().quit()

func _layout(size_:Vector2):
	# Safe area (notch / barras del sistema en Android): no tapar cámara ni gestos.
	var ins=UiTheme.safe_insets(get_viewport());var sl=ins.x;var st=ins.y;var sr=ins.z;var sb_=ins.w
	camera_button.position=Vector2(size_.x-228-sr,20+st);camera_button.size=Vector2(132,47)
	action_ui.get_node("Pause").position=Vector2(size_.x-81-sr,20+st);action_ui.get_node("Pause").size=Vector2(58,47)
	action_ui.get_node("Reset").position=Vector2(size_.x-168-sr,87+st);action_ui.get_node("Reset").size=Vector2(145,39)
	reverse_button.position=Vector2(28+sl,size_.y-223-sb_);reverse_button.size=Vector2(65,48)
	calibrate_button.position=Vector2(28+sl,size_.y-285-sb_);calibrate_button.size=Vector2(190,43)
	menu.get_node("Note").position=Vector2(maxf(24,size_.x-430),size_.y-77)
	var menu_panel=menu.get_child(0)
	var factor=minf(1.0,minf((size_.y-20)/700.0,(size_.x-20)/840.0))
	menu_panel.scale=Vector2(factor,factor)
	menu_panel.position=Vector2(12,12)

func time_string(seconds:float)->String:
	var ms=roundi(seconds*1000)
	return "%02d:%02d.%03d"%[ms/60000,(ms/1000)%60,ms%1000]
