extends Control
## RACE 0.4.0 — responsive menu flows. The 0.3.1 gameplay selector remains
## the authoritative adapter for modes, vehicles, tracks and settings.
const Catalog=preload("res://scripts/track_catalog.gd")
const Vehicles=preload("res://scripts/vehicles/vehicle_catalog.gd")
const Rules=preload("res://scripts/gameplay/race_rules.gd")
const Safe=preload("res://scripts/ui/safe_area.gd")
const TrackMap=preload("res://scripts/track_map.gd")
const MINT=Color("59e8c9")
const RED=Color("db3d53")
const INK=Color("0b121a")
const PANEL=Color("182532")
const SUBTLE=Color("b4c4d4")

var game
var page="home"
var history:Array[String]=[]
var safe_root:MarginContainer
var body:VBoxContainer
var navigation:HBoxContainer
var title_label:Label
var confirm:ConfirmationDialog
var selected_paint=0
var selected_component="motor"
var track_filter="Todos"
var car_filter="Todos"
var car_query=""
var photo_origin="garage"
var control_zone="gas"
var _first_open=true

func _ready():
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade=ColorRect.new()
	shade.color=Color("08121dc6")
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)
	safe_root=MarginContainer.new()
	add_child(safe_root)
	for side in ["top","bottom","left","right"]:
		safe_root.add_theme_constant_override("margin_"+side,14)
	var outer=VBoxContainer.new()
	outer.add_theme_constant_override("separation",8)
	safe_root.add_child(outer)
	var header=HBoxContainer.new()
	header.custom_minimum_size.y=52
	outer.add_child(header)
	var logo=_text(header,"RACE  ///",34,MINT)
	logo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title_label=_text(header,"",21)
	title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var line=ColorRect.new()
	line.color=MINT
	line.custom_minimum_size.y=3
	outer.add_child(line)
	var scroll=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	body=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12)
	scroll.add_child(body)
	navigation=HBoxContainer.new()
	navigation.custom_minimum_size.y=66
	navigation.add_theme_constant_override("separation",7)
	outer.add_child(navigation)
	confirm=ConfirmationDialog.new()
	confirm.title="CONFIRMAR"
	confirm.ok_button_text="CONFIRMAR"
	confirm.cancel_button_text="CANCELAR"
	confirm.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(confirm)
	if _first_open and not bool(game.profile.data.settings.get("onboarding_040",false)):
		page="welcome"
	_first_open=false
	_render()

func _process(_dt):
	if is_instance_valid(safe_root):
		var safe=Safe.rect(self)
		safe_root.position=safe.position
		safe_root.size=safe.size

func _text(parent:Node,value:String,size_:int=19,color:Color=Color.WHITE)->Label:
	var label=Label.new()
	label.text=value
	label.add_theme_font_size_override("font_size",size_)
	label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(parent:Node,value:String,action:Callable,primary:bool=false)->Button:
	var b=Button.new()
	b.text=value
	b.custom_minimum_size=Vector2(125,54)
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.add_theme_color_override("font_color",Color.WHITE if primary else Color("eff6ff"))
	var style=StyleBoxFlat.new()
	style.bg_color=RED if primary else Color("223b4e")
	style.border_color=RED if primary else Color("567385")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left=10
	style.content_margin_right=10
	b.add_theme_stylebox_override("normal",style)
	var pressed=style.duplicate()
	pressed.bg_color=MINT
	b.add_theme_stylebox_override("pressed",pressed)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _line(parent:Node)->void:
	var l=ColorRect.new()
	l.color=Color("426274")
	l.custom_minimum_size.y=1
	parent.add_child(l)

func _row(parent:Node)->HBoxContainer:
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	parent.add_child(row)
	return row

func _card(parent:Node,heading:String="")->VBoxContainer:
	var panel=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style=StyleBoxFlat.new()
	style.bg_color=PANEL
	style.border_color=Color("426b7a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left=17
	style.content_margin_top=12
	style.content_margin_right=17
	style.content_margin_bottom=12
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var content=VBoxContainer.new()
	content.add_theme_constant_override("separation",9)
	panel.add_child(content)
	if heading!="":_text(content,heading,23)
	return content

func _heading(value:String)->void:
	_text(body,value,29)

func _caption(parent:Node,value:String)->void:
	_text(parent,value,15,SUBTLE)

func _setting(parent:Node,caption:String,choices:Array,selected:int,on_select:Callable)->void:
	var block=VBoxContainer.new()
	parent.add_child(block)
	_text(block,caption,17,SUBTLE)
	var row=_row(block)
	for i in range(choices.size()):
		var index=i
		var label=str(choices[i])
		_button(row,("● " if i==selected else "")+label,func():on_select.call(index);_render(),i==selected)

func _track_art(parent:Node,id:String)->void:
	var path="res://assets/tracks/previews/"+id+".jpg"
	if ResourceLoader.exists(path):
		var texture=TextureRect.new()
		texture.texture=load(path)
		texture.custom_minimum_size=Vector2(180,135)
		texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		parent.add_child(texture)
	else:
		var drawing=TrackMap.new()
		drawing.custom_minimum_size=Vector2(180,112)
		parent.add_child(drawing)
		drawing.set_track(id)

func _check(parent:Node,label_:String,widget:CheckButton)->void:
	var toggle=CheckButton.new()
	toggle.text=label_
	toggle.button_pressed=widget.button_pressed
	toggle.custom_minimum_size.y=53
	toggle.toggled.connect(func(active):widget.button_pressed=active)
	parent.add_child(toggle)

func _dialog(title_:String,message:String,action:Callable,confirm_text:String="CONFIRMAR")->void:
	for old in confirm.confirmed.get_connections():
		confirm.confirmed.disconnect(old.callable)
	confirm.title=title_
	confirm.dialog_text=message
	confirm.ok_button_text=confirm_text
	confirm.confirmed.connect(action,CONNECT_ONE_SHOT)
	confirm.popup_centered_ratio(.55)

func _to(name_:String)->void:
	if page!=name_:history.append(page)
	page=name_
	_render()

func _tab(name_:String)->void:
	history.clear()
	page=name_
	_render()

func back()->void:
	if page=="pause":
		game._resume()
		return
	if not history.is_empty():
		page=history.pop_back()
	else:page="home"
	_render()

func _render()->void:
	if not is_instance_valid(body):return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	for child in navigation.get_children():
		navigation.remove_child(child)
		child.queue_free()
	title_label.text=page.to_upper().replace("_"," ")
	match page:
		"welcome":_welcome()
		"home":_home()
		"modes":_modes()
		"prepare":_prepare()
		"tracks":_tracks()
		"garage":_garage()
		"vehicle":_vehicle()
		"paint":_paint()
		"upgrades":_upgrades()
		"review":_review()
		"progress":_progress()
		"records":_records()
		"championship":_championship()
		"settings":_settings()
		"controls":_controls()
		"layout_editor":_layout_editor()
		"handling":_handling()
		"graphics":_graphics()
		"audio":_audio()
		"interface":_interface()
		"help":_help()
		"support":_support()
		"gallery":_gallery()
		"pause":_pause()
		"results":_results()
	if page not in ["welcome","pause","results"]:
		for item in [["Inicio","home"],["Jugar","modes"],["Garaje","garage"],["Progreso","progress"],["Ajustes","settings"]]:
			var target=item[1]
			_button(navigation,("◆ " if page==target else "")+item[0],func():_tab(target),page==target)
	else:
		_button(navigation,"VOLVER" if page!="welcome" else "RACE 0.4.0",func():back())

func _go_home()->void:
	game.profile.data.settings["onboarding_040"]=true
	game.profile.save()
	_tab("home")

func _welcome()->void:
	_heading("¿CÓMO PREFIERES CONDUCIR?")
	var card=_card(body,"PRIMERA CONFIGURACIÓN")
	_caption(card,"Elige un método. Siempre podrás cambiarlo en Ajustes.")
	_setting(card,"Dirección",["Botones","Inclinación","Volante"],game.control_select.selected,func(i):game.control_select.select(i))
	var actions=_row(body)
	_button(actions,"EMPEZAR ACADEMIA",func():_go_home();game.selector.session_mode.select(9);_to("prepare"),true)
	_button(actions,"IR AL INICIO",_go_home)

func _home()->void:
	_heading("TU PRÓXIMA CARRERA")
	var row=_row(body)
	var car_card=_card(row,"GT77 DRIVE LAB · GARAJE")
	var data=Vehicles.get_vehicle(game.selector.vehicle_id)
	_text(car_card,data.name+"  ·  CLASE "+str(data.vehicle_class),26,MINT)
	_caption(car_card,str(data.family)+"  ·  "+str(data.drive))
	_button(car_card,"CAMBIAR AUTO",func():_to("garage"))
	var next=_card(row,"TU PRÓXIMA SESIÓN")
	_track_art(car_card,game.selector.selected_id)
	var mode=Rules.MODES[game.selector.session_mode.selected]
	var track=Catalog.get_entry(game.selector.selected_id).name
	if game.selector.session_mode.selected==8:track="Recta Drag · 402 m"
	_text(next,mode+"  ·  "+track,19)
	_caption(next,["Seco de día","Mojado","Atardecer","Noche"][game.selector.weather_choice.selected]+"  ·  "+["Arcade","Sport","Simulación"][game.style_select.selected])
	_button(next,"▶  JUGAR AHORA",_begin,true)
	_button(next,"PREPARAR EVENTO",func():_to("prepare"))
	var progress=_card(body,"PROGRESO ACTUAL")
	_text(progress,"%d CR   ·   NIVEL %d"%[int(game.profile.data.credits),1+int(game.profile.data.xp)/500],22,MINT)
	_caption(progress,"DESAFÍOS  ·  vuelta válida +200 CR  ·  velocidad +250 CR  ·  drift +300 CR")
	_button(progress,"VER DESAFÍOS Y RÉCORDS",func():_to("progress"))

func _modes()->void:
	_heading("¿CÓMO QUIERES CORRER?")
	_caption(body,"Practicar · competir · modos especiales")
	var grid=GridContainer.new();grid.columns=5;body.add_child(grid)
	var details=[
		"Explora y practica sin cronómetro final",
		"Busca tu mejor tiempo por vuelta",
		"Tres ejercicios de conducción",
		"Tres vueltas y cinco rivales virtuales",
		"Tres rondas: Arena, Costa y Sierra",
		"90 segundos de derrapes y combos",
		"Completa el 75 % de una pista",
		"Tramo de rally contrarreloj",
		"El último piloto sale cada 30 s",
		"Recta oficial de 402 metros"
	]
	for i in range(Rules.MODES.size()):
		var mode=i
		var label=Rules.MODES[i]+"\n"+details[i]
		_button(grid,label,func():game.selector.session_mode.select(mode);_to("prepare"),game.selector.session_mode.selected==i)
	_caption(body,"Todos los modos mantienen las reglas de juego offline de RACE 0.3.1.")

func _prepare()->void:
	var mode=game.selector.session_mode.selected
	_heading("PREPARAR · "+Rules.MODES[mode].to_upper())
	var row=_row(body)
	var route=_card(row,"CIRCUITO")
	if mode not in [3,8]:_track_art(route,game.selector.selected_id)
	if mode==8:
		_text(route,"RECTA DE DRAG · 402 m",20,MINT)
		_caption(route,"Recorrido fijo; sentido inverso no disponible.")
	elif mode==3:
		_text(route,"ARENA → COSTA → SIERRA",20,MINT)
		_caption(route,"Tres rondas del campeonato · 3 vueltas por ronda.")
	else:
		var entry=Catalog.get_entry(game.selector.selected_id)
		_text(route,str(entry.name)+"  ·  %.2f km"%[float(entry.length)/1000],20,MINT)
		_button(route,"ELEGIR CIRCUITO",func():_to("tracks"))
	var options=_card(row,"CONDICIONES Y REGLAS")
	_setting(options,"Clima",["Seco","Mojado","Tarde","Noche"],game.selector.weather_choice.selected,func(i):game.selector.weather_choice.select(i))
	if mode!=8:
		_setting(options,"Sentido",["Normal","Inverso"],int(game.selector.reverse_choice.button_pressed),func(i):game.selector.reverse_choice.button_pressed=i==1)
	if mode in [2,3,7]:
		_setting(options,"Rivales IA",["Accesible","Competitivo","Experto"],game.selector.difficulty_choice.selected,func(i):game.selector.difficulty_choice.select(i))
	else:_caption(options,"Sin rivales virtuales")
	var rules=["Sesión abierta · vueltas válidas","Récord de vuelta","3 vueltas · 6 participantes","3 rondas · 6 participantes","90 segundos","75 % del circuito","75 % del circuito","Eliminación cada 30 s","402 metros","3 ejercicios"]
	_caption(options,rules[mode])
	var car=_card(body,"VEHÍCULO Y MANEJO")
	_text(car,Vehicles.get_vehicle(game.selector.vehicle_id).name+"  ·  "+["Arcade","Sport","Simulación"][game.style_select.selected]+"  ·  "+["Botones","Inclinación","Volante"][game.control_select.selected],18)
	var buttons=_row(car)
	_button(buttons,"CAMBIAR AUTO",func():_to("garage"))
	_button(buttons,"CAMBIAR CONTROLES",func():_to("controls"))
	_button(body,"REVISAR EVENTO",func():_to("review"),true)

func _tracks()->void:
	_heading("CIRCUITOS · 12 DISPONIBLES")
	var tabs=_row(body)
	for name_ in ["Todos","Asfalto","Grava","Nieve"]:
		var f=name_
		_button(tabs,name_,func():track_filter=f;_render(),track_filter==name_)
	var grid=GridContainer.new();grid.columns=3;body.add_child(grid)
	for entry in Catalog.ENTRIES:
		var surface=str(entry.surface)
		if track_filter!="Todos" and not surface.to_lower().contains(track_filter.to_lower()):continue
		var id=str(entry.id)
		var card=_card(grid,str(entry.name))
		_track_art(card,id)
		_text(card,"%.2f km · %s"%[float(entry.length)/1000,surface],16,MINT)
		_caption(card,str(entry.difficulty))
		_button(card,"USAR CIRCUITO"+(" ✓" if game.selector.selected_id==id else ""),func():game.selector.select_track(id);_to("prepare"),game.selector.selected_id==id)
	_caption(body,"Drag utiliza una recta especial de 402 m y no cuenta como circuito número 13.")

func _garage()->void:
	_heading("GARAJE · 24 VEHÍCULOS")
	var bar=_row(body)
	_text(bar,"%d CR"%int(game.profile.data.credits),21,MINT)
	_button(bar,"VOLVER AL EVENTO",func():_to("prepare"))
	var filters=_row(body)
	for filter_ in ["Todos","Compactos","Street","Deportivos","GT Racing","Rally","Prototipos"]:
		var key=filter_
		_button(filters,filter_,func():car_filter=key;_render(),car_filter==key)
	var search=_row(body)
	var input=LineEdit.new();input.placeholder_text="Buscar vehículo por nombre";input.text=car_query;input.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search.add_child(input)
	_button(search,"BUSCAR",func():car_query=input.text.strip_edges().to_lower();_render())
	var grid=GridContainer.new();grid.columns=3;body.add_child(grid)
	var found=0
	for entry in Vehicles.all():
		if car_filter!="Todos" and str(entry.family)!=car_filter:continue
		if not car_query.is_empty() and not str(entry.name).to_lower().contains(car_query):continue
		found+=1
		var id=str(entry.id)
		var c=_card(grid,str(entry.name))
		var bar=ColorRect.new()
		bar.color=Color(str(entry.color))
		bar.custom_minimum_size=Vector2(120,8)
		c.add_child(bar)
		_text(c,str(entry.family)+"  ·  CLASE "+str(entry.vehicle_class),17,MINT)
		_caption(c,str(entry.drive)+" · "+str(entry.mass)+" kg · "+str(entry.torque)+" Nm")
		_button(c,"SELECCIONADO ✓" if game.selector.vehicle_id==id else "VER VEHÍCULO",func():game.selector.select_vehicle(id);_to("vehicle"),game.selector.vehicle_id==id)
	if found==0:
		_caption(body,"Sin coincidencias para estos filtros.")
		_button(body,"LIMPIAR FILTROS",func():car_filter="Todos";car_query="";_render())

func _vehicle()->void:
	var data=Vehicles.get_vehicle(game.selector.vehicle_id)
	_heading(str(data.name).to_upper()+"  ·  CLASE "+str(data.vehicle_class))
	var c=_card(body,"FICHA DEL VEHÍCULO")
	_text(c,str(data.family)+"  ·  "+str(data.drive),22,MINT)
	_caption(c,"%d kg  ·  %d Nm  ·  carrocería %s"%[int(data.mass),int(data.torque),str(data.body)])
	var actions=_row(body)
	_button(actions,"VER 360°",func():photo_origin="vehicle";hide();game._open_photo())
	_button(actions,"PINTURA",func():selected_paint=game.selector.paint_choice.selected;_to("paint"))
	_button(actions,"MEJORAS",func():_to("upgrades"))
	_button(actions,"RÉCORDS",func():_to("records"))
	var buttons=_row(body)
	_button(buttons,"USAR VEHÍCULO",func():game.selector.select_vehicle(str(data.id));_to("prepare"),true)
	_button(buttons,"VOLVER AL CATÁLOGO",func():_to("garage"))

func _paint()->void:
	var id=game.selector.vehicle_id
	_heading("PINTURA · "+str(Vehicles.get_vehicle(id).name))
	var c=_card(body,"ELIGE UN ACABADO")
	var names=["Racing red","Arctic cyan","Solar gold","Pearl white","Ultraviolet","Mint"]
	var choices=names
	if id=="gt77":
		choices=["Reference (rojo)","Arctic (cian)","Pearl (blanco)"]
		_caption(c,"GT77 dispone de tres materiales reales. No se muestran tres colores duplicados.")
	var row=GridContainer.new();row.columns=3;c.add_child(row)
	for i in range(choices.size()):
		var idx=i
		_button(row,("✓ " if selected_paint==i else "")+choices[i],func():selected_paint=idx;_render(),selected_paint==i)
	var foot=_row(body)
	_button(foot,"CANCELAR",back)
	_button(foot,"APLICAR PINTURA",func():
		game.selector.paint_choice.select(selected_paint)
		game._preview_vehicle(game.selector.vehicle_id)
		var paints=game.profile.data.settings.get("paints",{})
		paints[id]=selected_paint
		game.profile.data.settings["paints"]=paints
		game.profile.save()
		_to("vehicle"),true)

func _upgrades()->void:
	_heading("MEJORAS · "+str(Vehicles.get_vehicle(game.selector.vehicle_id).name))
	_text(body,"%d CR DISPONIBLES"%int(game.profile.data.credits),20,MINT)
	var r=_row(body)
	for component in ["motor","grip","brakes"]:
		var part=component
		var level=game.profile.level(game.selector.vehicle_id,component)
		var cost=500*(level+1)
		var impact={"motor":"+5 % de potencia por nivel","grip":"+3 % de agarre por nivel","brakes":"+5 % de frenado por nivel"}
		var name_={"motor":"MOTOR","grip":"NEUMÁTICOS","brakes":"FRENOS"}[component]
		var c=_card(r,name_)
		_text(c,"NIVEL %d/3"%level,21,MINT)
		_caption(c,impact[component])
		_button(c,"MÁXIMO" if level==3 else "COMPRAR · %d CR"%cost,func():_buy(part),level<3)
	_button(body,"VOLVER AL VEHÍCULO",func():_to("vehicle"))

func _buy(component:String)->void:
	var level=game.profile.level(game.selector.vehicle_id,component)
	var cost=500*(level+1)
	var current=int(game.profile.data.credits)
	if level>=3:
		_dialog("MÁXIMO","La mejora ya se encuentra en nivel 3/3.",func():pass,"VOLVER")
	elif current<cost:
		_dialog("SALDO INSUFICIENTE","Te faltan %d CR para esta mejora."%(cost-current),func():_to("progress"),"VER DESAFÍOS")
	else:
		_dialog("CONFIRMAR COMPRA","Nivel %d → %d\nCosto: %d CR\nSaldo después: %d CR"%[level,level+1,cost,current-cost],func():
			if not game.profile.buy(game.selector.vehicle_id,component):
				_dialog("ERROR DE GUARDADO","No se pudo guardar la compra. No se aplicó el cobro.",func():_render(),"VOLVER")
			else:
				game.selector.refresh_profile()
				_render(),"COMPRAR")

func _review()->void:
	var mode=game.selector.session_mode.selected
	_heading("TODO LISTO PARA CORRER")
	var c=_card(body,Rules.MODES[mode].to_upper())
	_text(c,"Circuito: "+("Recta Drag · 402 m" if mode==8 else "Arena → Costa → Sierra" if mode==3 else str(Catalog.get_entry(game.selector.selected_id).name)),20)
	_text(c,"Vehículo: "+str(Vehicles.get_vehicle(game.selector.vehicle_id).name),19)
	_text(c,"Condiciones: "+["Seco","Mojado","Atardecer","Noche"][game.selector.weather_choice.selected],18)
	_text(c,"Manejo: "+["Arcade","Sport","Simulación"][game.style_select.selected],18)
	_text(c,"Controles: "+["Botones","Inclinación","Volante"][game.control_select.selected],18)
	_caption(c,"Cinco rivales sin colisiones" if mode in [2,3,7] else "Sin rivales")
	var row=_row(body)
	_button(row,"MODIFICAR EVENTO",func():_to("prepare"))
	_button(row,"INICIAR CARRERA",_begin,true)

func _begin()->void:
	game.championship_round=0
	game.championship_scores=[0,0,0,0,0,0]
	game._start()

func _progress()->void:
	_heading("PROGRESO Y DESAFÍOS")
	var c=_card(body,"PILOTO")
	_text(c,"%d CR  ·  NIVEL %d"%[int(game.profile.data.credits),1+int(game.profile.data.xp)/500],23,MINT)
	_caption(c,"Experiencia actual: %d XP  ·  siguiente nivel en %d XP"%[int(game.profile.data.xp),500-int(game.profile.data.xp)%500])
	var today=Time.get_date_string_from_system()
	for item in [["vuelta","Vuelta válida",200],["velocidad","Acumula 10 s a 150 km/h",250],["drift","Derrapa 500 m en Drift",300]]:
		var done=game.profile.data.daily.has(today+"/"+str(item[0]))
		var row=_card(body,str(item[1]))
		_text(row,"COMPLETADO ✓" if done else "PENDIENTE  ·  +%d CR"%int(item[2]),18,MINT if done else SUBTLE)
		if not done:
			var index=4 if item[0]=="drift" else 0
			_button(row,"JUGAR DESAFÍO",func():game.selector.session_mode.select(index);_to("prepare"))
	var links=_row(body)
	_button(links,"MIS RÉCORDS",func():_to("records"))
	_button(links,"CAMPEONATO",func():_to("championship"))

func _records()->void:
	_heading("RÉCORDS PERSONALES")
	_caption(body,"Tiempos registrados por circuito, vehículo y configuración.")
	var entries=game.profile.data.records.keys()
	entries.sort()
	var shown=0
	for key in entries:
		if "/sector/" in str(key):continue
		var elapsed=float(game.profile.data.records[key])
		var row=_card(body,str(key))
		_text(row,"MEJOR VUELTA  "+game.time_string(elapsed),20,MINT)
		shown+=1
		if shown>=25:break
	if shown==0:
		_caption(body,"Todavía no tienes una vuelta válida registrada.")
		_button(body,"INICIAR CONTRARRELOJ",func():game.selector.session_mode.select(1);_to("prepare"),true)

func _championship()->void:
	_heading("CAMPEONATO · 3 RONDAS")
	_caption(body,"GRAND PRIX ARENA → COSTA DEL PACÍFICO → CIRCUITO DE LA SIERRA")
	var names=["TÚ","VEGA","CRUZ","SOL","NOVA","RÍOS"]
	var rankings=[]
	for i in range(names.size()):
		rankings.append({"name":names[i],"points":int(game.championship_scores[i])})
	rankings.sort_custom(func(a,b):return a.points>b.points)
	var card=_card(body,"CLASIFICACIÓN ACTUAL")
	for i in range(rankings.size()):
		_text(card,"%d. %s  ·  %d PTS"%[i+1,rankings[i].name,rankings[i].points],20,MINT if rankings[i].name=="TÚ" else Color.WHITE)
	_button(body,"PREPARAR CAMPEONATO",func():game.selector.session_mode.select(3);_to("prepare"),true)

func _settings()->void:
	_heading("AJUSTES")
	for item in [["CONTROLES","controls","Botones · inclinación · volante"],["MANEJO Y FANTASMA","handling","Arcade · Sport · Simulación"],["GRÁFICOS Y RENDIMIENTO","graphics","Baja · 30 FPS · Galaxy A05"],["AUDIO Y VIBRACIÓN","audio","Sonido del juego"],["INTERFAZ","interface","HUD · Cámara · Accesibilidad"],["AYUDA Y SOPORTE","help","Guías · Diagnóstico"]]:
		var page_=item[1]
		var card=_card(body,item[0])
		_caption(card,item[2])
		_button(card,"ABRIR",func():_to(page_))

func _save_settings()->void:
	game._apply_settings()
	game.config.set_value("interface","pedal_full",game.controls.pedal_full)
	game.config.save("user://settings.cfg")
	_to("settings")

func _controls()->void:
	_heading("CONTROLES")
	var card=_card(body,"MODO DE DIRECCIÓN")
	_setting(card,"Dirección",["Botones","Inclinación","Volante"],game.control_select.selected,func(i):game.control_select.select(i))
	_caption(card,"El volante virtual funciona deslizando horizontalmente.")
	var slider=_card(body,"SENSIBILIDAD · INCLINACIÓN / VOLANTE")
	_text(slider,"%d°"%int(game.sensitivity.value),20,MINT)
	var bar=HSlider.new()
	bar.min_value=20;bar.max_value=55;bar.step=1;bar.value=game.sensitivity.value
	bar.custom_minimum_size.y=54
	bar.value_changed.connect(func(v):game.sensitivity.value=v)
	slider.add_child(bar)
	_check(slider,"Invertir inclinación",game.inversion)
	_check(slider,"Modo zurdo",game.lefty)
	var pedal=CheckButton.new()
	pedal.text="Pedales al 100 % con un toque"
	pedal.button_pressed=game.controls.pedal_full
	pedal.toggled.connect(func(v):game.controls.pedal_full=v)
	slider.add_child(pedal)
	_button(body,"EDITAR DISTRIBUCIÓN DE CONTROLES",func():_to("layout_editor"))
	_button(body,"CENTRAR INCLINACIÓN",func():game.controls.calibrate())
	_button(body,"GUARDAR CONTROLES",_save_settings,true)

func _layout_editor()->void:
	_heading("DISTRIBUCIÓN DE CONTROLES")
	_caption(body,"Ajusta la posición por zona en el espacio seguro. Cambios inmediatos, conservados al guardar.")
	var areas=["left","right","wheel","gas","brake","hand"]
	var grid=GridContainer.new();grid.columns=3;body.add_child(grid)
	for name_ in areas:
		var zone=name_
		_button(grid,name_.to_upper(),func():control_zone=zone;_render(),control_zone==name_)
	var shift=game.controls.zone_offsets.get(control_zone,Vector2.ZERO)
	var card=_card(body,"ZONA: "+control_zone.to_upper())
	_text(card,"Desplazamiento: x=%d, y=%d"%[int(shift.x),int(shift.y)],21,MINT)
	var horizontal=_row(card)
	_button(horizontal,"◀  -12",func():_nudge(Vector2(-12,0)))
	_button(horizontal,"+12  ▶",func():_nudge(Vector2(12,0)))
	var vertical=_row(card)
	_button(vertical,"SUBIR",func():_nudge(Vector2(0,-12)))
	_button(vertical,"BAJAR",func():_nudge(Vector2(0,12)))
	var scale_=float(game.controls.zone_scales.get(control_zone,1.0))
	_text(card,"Tamaño: %d %%"%int(scale_*100.0),17)
	var sizes=_row(card)
	_button(sizes,"REDUCIR",func():_resize_zone(-.10))
	_button(sizes,"AGRANDAR",func():_resize_zone(.10))
	_caption(card,"Los controles se limitan al área segura de Android.")
	var foot=_row(body)
	_button(foot,"RESTAURAR",func():game.controls.zone_offsets.clear();game.controls.zone_scales.clear();_render())
	_button(foot,"GUARDAR",func():
		game.config.set_value("interface","zone_offsets",_serialize_offsets())
		game.config.set_value("interface","zone_scales",game.controls.zone_scales)
		game.config.save("user://settings.cfg")
		_to("controls"),true)

func _nudge(amount:Vector2)->void:
	var prior=game.controls.zone_offsets.get(control_zone,Vector2.ZERO)
	game.controls.zone_offsets[control_zone]=(prior+amount).clamp(Vector2(-100,-90),Vector2(100,90))
	_render()

func _resize_zone(amount:float)->void:
	var current=float(game.controls.zone_scales.get(control_zone,1.0))
	game.controls.zone_scales[control_zone]=clampf(current+amount,.8,1.35)
	_render()

func _serialize_offsets()->Dictionary:
	var out={}
	for key in game.controls.zone_offsets:
		var v=game.controls.zone_offsets[key]
		out[key]=[v.x,v.y]
	return out

func _handling()->void:
	_heading("MANEJO Y FANTASMA")
	var card=_card(body,"ESTILO DE CONDUCCIÓN")
	_setting(card,"Ayudas",["ARCADE","SPORT","SIMULACIÓN"],game.style_select.selected,func(i):game.style_select.select(i))
	_caption(card,"Arcade: estabilidad + ABS + TCS. Sport: ABS + TCS. Simulación: sin ayudas.")
	_check(card,"Mostrar fantasma personal",game.ghost_check)
	_button(card,"VER RÉCORDS",func():_to("records"))
	_button(body,"GUARDAR MANEJO",_save_settings,true)

func _graphics()->void:
	_heading("GRÁFICOS Y RENDIMIENTO")
	var card=_card(body,"RENDIMIENTO")
	if game.lite_profile:_text(card,"GALAXY A05 · PERFIL DE ESTABILIDAD",20,MINT)
	_setting(card,"Calidad",["BAJA 70 %","MEDIA 85 %","ALTA 100 %"],game.quality_select.selected,func(i):game.quality_select.select(i))
	_setting(card,"Cuadros",["30 FPS","60 FPS"],game.fps_select.selected,func(i):game.fps_select.select(i))
	_check(card,"Sombras dinámicas (no disponibles en Baja)",game.shadows)
	_button(body,"RESTAURAR PERFIL GALAXY A05",func():
		game.quality_select.select(0);game.fps_select.select(0);game.shadows.button_pressed=false;game.vibration.button_pressed=false;_render())
	_button(body,"GUARDAR GRÁFICOS",_save_settings,true)

func _audio()->void:
	_heading("AUDIO Y VIBRACIÓN")
	var card=_card(body,"SONIDO DEL JUEGO")
	_check(card,"Motor y neumáticos",game.sound)
	_check(card,"Vibración",game.vibration)
	_caption(card,"El motor se detiene al pausar y no consume CPU cuando está silenciado.")
	_button(body,"GUARDAR AUDIO",_save_settings,true)

func _interface()->void:
	_heading("INTERFAZ Y ACCESIBILIDAD")
	var card=_card(body,"PREFERENCIAS")
	var compact=CheckButton.new()
	compact.text="HUD compacto"
	compact.button_pressed=game.hud.compact
	compact.toggled.connect(func(v):game.hud.compact=v)
	card.add_child(compact)
	var larger=CheckButton.new()
	larger.text="Texto más grande en menús"
	larger.button_pressed=bool(game.config.get_value("interface","large_text",false))
	larger.toggled.connect(func(v):game.config.set_value("interface","large_text",v))
	card.add_child(larger)
	_caption(card,"Controles en área segura; pedales y dirección independientes.")
	_button(body,"GUARDAR INTERFAZ",func():
		game.config.set_value("interface","hud_compact",game.hud.compact)
		game.config.save("user://settings.cfg")
		_to("settings"),true)

func _help()->void:
	_heading("AYUDA Y APRENDIZAJE")
	for item in [
		["CÓMO CONDUCIR","Dirección + acelerador; frena antes de la curva y acelera progresivamente."],
		["REGLAS","Libre, Contrarreloj, Academia, Carrera rápida, Campeonato, Drift, Sprint, Rally, Eliminación y Drag."],
		["CONTROLES TÁCTILES","Mantén pulsados dirección y gas con dedos independientes; el freno de mano puede requerir otro dedo."],
		["MANDO Y TECLADO","WASD/flechas, Espacio freno de mano, C cámara, R recolocar, V reversa, Esc pausa."],
		["CRÉDITOS Y MEJORAS","Completa vueltas y desafíos para mejorar Motor, Neumáticos o Frenos. Compra con confirmación."],
		["FANTASMA","Tu mejor vuelta se guarda para configuraciones compatibles."],
		["FOTOS","Pausa → Foto. Las imágenes se guardan dentro de los datos de la app."],
		["RENDIMIENTO","Galaxy A05 utiliza perfil Lite; registra fallos con RACE_DIAG."]
	]:
		var card=_card(body,item[0])
		_caption(card,item[1])
	var foot=_row(body)
	_button(foot,"PRACTICAR EN ACADEMIA",func():game.selector.session_mode.select(9);_to("prepare"),true)
	_button(foot,"SOPORTE Y DATOS",func():_to("support"))

func _support()->void:
	_heading("AYUDA Y SOPORTE")
	var card=_card(body,"RACE 0.4.0 · OFFLINE")
	_text(card,"Dispositivo: "+OS.get_model_name(),18)
	_text(card,"Perfil: "+("Lite (Galaxy A05)" if game.lite_profile else "Personalizado"),18,MINT)
	_caption(card,"Progreso y ajustes guardados localmente; los informes no se envían automáticamente.")
	_button(body,"COPIAR INFORMACIÓN TÉCNICA",func():
		DisplayServer.clipboard_set("RACE 0.4.0\nModelo: "+OS.get_model_name()+"\nPerfil Lite: "+str(game.lite_profile)+"\nPista: "+game.selector.selected_id+"\nVehículo: "+game.selector.vehicle_id))
	_button(body,"VER GALERÍA INTERNA",func():_to("gallery"))
	_button(body,"VOLVER A AYUDA",func():_to("help"))

func _gallery()->void:
	_heading("GALERÍA · FOTOS LOCALES")
	var directory=DirAccess.open("user://")
	if directory==null:
		_caption(body,"No se pudo acceder al almacenamiento de fotos.");return
	var found=false
	for filename in directory.get_files():
		if not filename.begins_with("RACE_photo_") or not filename.ends_with(".png"):continue
		found=true
		var card=_card(body,filename)
		var image_=Image.new()
		if image_.load("user://"+filename)==OK:
			var display=TextureRect.new()
			display.texture=ImageTexture.create_from_image(image_)
			display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			display.custom_minimum_size=Vector2(200,220)
			card.add_child(display)
		var name_=filename
		_button(card,"ELIMINAR FOTO",func():_dialog("ELIMINAR FOTO","Esta foto se perderá definitivamente.",func():
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://"+name_))
			_render(),"ELIMINAR"))
	if not found:_caption(body,"Todavía no hay fotografías guardadas en la aplicación.")
	_caption(body,"Exportar al álbum del teléfono y compartir son funciones futuras; no están disponibles en esta compilación.")

func show_pause()->void:
	page="pause"
	show()
	_render()

func show_results()->void:
	page="results"
	show()
	_render()

func _pause()->void:
	_heading("PAUSA · "+game.game_mode.to_upper())
	_caption(body,Catalog.get_entry(game.selector.selected_id).name)
	var columns=GridContainer.new()
	columns.columns=2
	body.add_child(columns)
	_button(columns,"REINTENTAR",func():_dialog("REINTENTAR","Perderás el progreso del intento actual.",func():game._back_to_menu();game._start(),"REINTENTAR"))
	_button(columns,"RECOLOCAR",func():_dialog("RECOLOCAR","Recolocar invalidará la vuelta actual o terminará un tramo.",func():game._resume();game._reset(),"RECOLOCAR"))
	_button(columns,"CAMBIAR CÁMARA",func():game._cycle_camera();_render())
	_button(columns,"MODO FOTO",func():photo_origin="pause";hide();game._open_photo())
	_button(columns,"CENTRAR INCLINACIÓN",func():game.controls.calibrate())
	_button(columns,"AJUSTES",func():_to("settings"))
	_button(columns,"AYUDA",func():_to("help"))
	_button(columns,"VOLVER AL GARAJE",func():_dialog("ABANDONAR","Perderás el progreso de este intento.",func():game._back_to_menu(),"SALIR"))
	if game.rules.mode in [0,1]:
		_button(columns,"TERMINAR SESIÓN",func():
			game.rules.completed=true
			game.rules.message="Sesión finalizada"
			game._finish_event())
	_button(body,"▶ CONTINUAR",func():hide();game._resume(),true)

func _results()->void:
	_heading("RESULTADOS · "+game.game_mode.to_upper())
	var c=_card(body,game.rules.message)
	_text(c,"TIEMPO TOTAL: "+game.time_string(game.rules.elapsed),24,MINT)
	var mode=game.rules.mode
	if mode in [0,1]:
		_text(c,"VUELTAS VÁLIDAS: %d"%game.laps,21)
		_text(c,"MEJOR VUELTA: "+(game.time_string(game.best_lap) if game.best_lap>0 else "Sin récord"),18)
	elif mode in [2,3,7]:
		_text(c,"POSICIÓN: %d / %d"%[game.rules.position,game.rivals.size()+1],21)
	elif mode==4:
		_text(c,"PUNTOS DRIFT: %d"%int(game.rules.score),21)
	elif mode in [5,6,8]:
		_text(c,"TRAMO: %d METROS"%int(game.rules.travel),21)
	elif mode==9:
		_text(c,"EJERCICIOS: %d / 3"%game.rules.academy_step,21)
	_caption(c,"Las recompensas se calculan una sola vez al finalizar la sesión.")
	var actions=_row(body)
	if mode==3 and game.championship_round<2:
		_button(actions,"SIGUIENTE RONDA",func():hide();game._continue_event(),true)
	else:
		_button(actions,"REINTENTAR",func():game._back_to_menu();game._start(),true)
	_button(actions,"GARAJE",func():game._back_to_menu())
	_button(actions,"CAMBIAR EVENTO",func():game._back_to_menu();_to("modes"))
